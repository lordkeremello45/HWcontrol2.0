#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

#include "hwcontrol_audio/audio_device_host.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstring>
#include <mutex>
#include <thread>
#include <utility>

namespace hwcontrol::audio {
namespace {
constexpr std::size_t kMaxCallbackFrames = 2048;
constexpr std::size_t kSamplesPerFrame = kChannelCount;
constexpr std::size_t kSpectrumQueueSlots = 4;
constexpr std::size_t kSpectrumSamples = kFftSize * kSamplesPerFrame;
}

struct AudioDeviceHost::Impl {
  ma_context context{};
  bool contextReady = false;
  ma_device device{};
  bool deviceReady = false;
  bool monitorOutput = false;
  AudioEngine engine;
  std::vector<AudioDeviceInfo> captureDevices;
  std::vector<AudioDeviceInfo> playbackDevices;
  std::vector<ma_device_id> captureIds;
  std::vector<ma_device_id> playbackIds;
  std::atomic<float> inputPeak{0.0F};
  std::atomic<float> outputPeak{0.0F};
  std::atomic<float> inputRms{0.0F};
  std::atomic<float> outputRms{0.0F};
  std::atomic<std::uint64_t> processedFrames{0};
  std::atomic<bool> isRunning{false};
  std::mutex lifecycleMutex;

  // Single-producer/single-consumer queue: the real-time callback owns writeIndex
  // and partialFrame; the worker owns readIndex. A full queue drops a spectrum
  // frame rather than blocking or delaying the audio callback.
  std::array<std::array<float, kSpectrumSamples>, kSpectrumQueueSlots> spectrumQueue{};
  std::array<float, kSpectrumSamples> partialFrame{};
  std::size_t partialSamples = 0;
  std::atomic<std::uint64_t> writeIndex{0};
  std::atomic<std::uint64_t> readIndex{0};
  std::atomic<bool> analysisStop{false};
  std::thread analysisThread;
  std::atomic<double> analysisSampleRateHz{48000.0};
  std::array<std::atomic<float>, kSpectrumBinCount> spectrumMagnitude{};
  std::atomic<float> spectrumPeakFrequencyHz{0.0F};
  std::atomic<float> spectrumRms{0.0F};
  std::atomic<bool> spectrumAvailable{false};

  Impl() {
    contextReady = ma_context_init(nullptr, 0, nullptr, &context) == MA_SUCCESS;
  }

  ~Impl() {
    stopLocked();
    if (contextReady) ma_context_uninit(&context);
  }

  void startAnalysisWorker() {
    writeIndex.store(0, std::memory_order_relaxed);
    readIndex.store(0, std::memory_order_relaxed);
    partialSamples = 0;
    analysisStop.store(false, std::memory_order_release);
    spectrumAvailable.store(false, std::memory_order_release);
    analysisThread = std::thread([this] {
      AudioAnalyzer analyzer;
      SpectrumFrame frame;
      for (;;) {
        const std::uint64_t read = readIndex.load(std::memory_order_relaxed);
        const std::uint64_t write = writeIndex.load(std::memory_order_acquire);
        if (read == write) {
          if (analysisStop.load(std::memory_order_acquire)) break;
          std::this_thread::sleep_for(std::chrono::milliseconds(2));
          continue;
        }
        const auto& samples = spectrumQueue[static_cast<std::size_t>(read % kSpectrumQueueSlots)];
        if (analyzer.analyze(samples.data(), kFftSize,
                             analysisSampleRateHz.load(std::memory_order_relaxed), frame)) {
          for (std::size_t i = 0; i < kSpectrumBinCount; ++i) {
            spectrumMagnitude[i].store(frame.magnitude[i], std::memory_order_relaxed);
          }
          spectrumPeakFrequencyHz.store(frame.peakFrequencyHz, std::memory_order_relaxed);
          spectrumRms.store(frame.rms, std::memory_order_relaxed);
          spectrumAvailable.store(true, std::memory_order_release);
        }
        readIndex.store(read + 1, std::memory_order_release);
      }
    });
  }

  void stopAnalysisWorker() noexcept {
    analysisStop.store(true, std::memory_order_release);
    if (analysisThread.joinable()) analysisThread.join();
  }

  void enqueueSpectrumSample(float sample) noexcept {
    partialFrame[partialSamples++] = sample;
    if (partialSamples != kSpectrumSamples) return;

    const std::uint64_t write = writeIndex.load(std::memory_order_relaxed);
    const std::uint64_t read = readIndex.load(std::memory_order_acquire);
    if (write - read < kSpectrumQueueSlots) {
      auto& slot = spectrumQueue[static_cast<std::size_t>(write % kSpectrumQueueSlots)];
      std::copy(partialFrame.begin(), partialFrame.end(), slot.begin());
      writeIndex.store(write + 1, std::memory_order_release);
    }
    // Reset even when full; audio must never wait for analysis to catch up.
    partialSamples = 0;
  }

  void stopLocked() noexcept {
    if (deviceReady) {
      (void)ma_device_stop(&device);
      ma_device_uninit(&device);
      deviceReady = false;
    }
    isRunning.store(false, std::memory_order_release);
    stopAnalysisWorker();
  }

  static void callback(ma_device* device, void* output, const void* input,
                       ma_uint32 frameCount) {
    auto* self = static_cast<Impl*>(device->pUserData);
    if (self == nullptr) return;
    auto* out = static_cast<float*>(output);
    const auto* in = static_cast<const float*>(input);
    std::array<float, kMaxCallbackFrames * kSamplesPerFrame> scratch{};
    float inPeak = 0.0F;
    float outPeak = 0.0F;
    double inSquares = 0.0;
    double outSquares = 0.0;
    std::uint64_t samplesSeen = 0;

    std::size_t offset = 0;
    while (offset < static_cast<std::size_t>(frameCount)) {
      const std::size_t blockFrames = std::min(
          kMaxCallbackFrames, static_cast<std::size_t>(frameCount) - offset);
      const std::size_t sampleCount = blockFrames * kSamplesPerFrame;
      for (std::size_t i = 0; i < sampleCount; ++i) {
        float value = in == nullptr ? 0.0F : in[offset * kSamplesPerFrame + i];
        if (!std::isfinite(value)) value = 0.0F;
        scratch[i] = value;
        inPeak = std::max(inPeak, std::abs(value));
        inSquares += static_cast<double>(value) * static_cast<double>(value);
      }

      self->engine.process(scratch.data(), blockFrames);
      for (std::size_t i = 0; i < sampleCount; ++i) {
        const float value = scratch[i];
        self->enqueueSpectrumSample(value);
        outPeak = std::max(outPeak, std::abs(value));
        outSquares += static_cast<double>(value) * static_cast<double>(value);
        if (out != nullptr) {
          out[offset * kSamplesPerFrame + i] = self->monitorOutput ? value : 0.0F;
        }
      }
      samplesSeen += static_cast<std::uint64_t>(sampleCount);
      offset += blockFrames;
    }

    if (samplesSeen != 0) {
      self->inputPeak.store(inPeak, std::memory_order_relaxed);
      // Report processed DSP levels even when monitor playback is disabled.
      // The monitoring flag controls routing to the output device, not analysis.
      self->outputPeak.store(outPeak, std::memory_order_relaxed);
      self->inputRms.store(static_cast<float>(std::sqrt(inSquares / static_cast<double>(samplesSeen))), std::memory_order_relaxed);
      self->outputRms.store(static_cast<float>(std::sqrt(outSquares / static_cast<double>(samplesSeen))), std::memory_order_relaxed);
      self->processedFrames.fetch_add(static_cast<std::uint64_t>(frameCount), std::memory_order_relaxed);
    }
  }

  std::vector<AudioDeviceInfo> enumerateLocked(DeviceDirection direction) {
    std::vector<AudioDeviceInfo> result;
    if (!contextReady) return result;
    ma_device_info* playback = nullptr;
    ma_uint32 playbackCount = 0;
    ma_device_info* capture = nullptr;
    ma_uint32 captureCount = 0;
    if (ma_context_get_devices(&context, &playback, &playbackCount,
                               &capture, &captureCount) != MA_SUCCESS) {
      return result;
    }

    const bool isCapture = direction == DeviceDirection::Capture;
    const ma_uint32 count = isCapture ? captureCount : playbackCount;
    const ma_device_info* infos = isCapture ? capture : playback;
    auto& ids = isCapture ? captureIds : playbackIds;
    auto& devices = isCapture ? captureDevices : playbackDevices;
    ids.clear();
    devices.clear();
    ids.reserve(count);
    devices.reserve(count);
    result.reserve(count);
    for (ma_uint32 i = 0; i < count; ++i) {
      AudioDeviceInfo item;
      item.index = static_cast<std::size_t>(i);
      item.name = infos[i].name;
      item.isDefault = infos[i].isDefault == MA_TRUE;
      ids.push_back(infos[i].id);
      devices.push_back(item);
      result.push_back(item);
    }
    return result;
  }
};

AudioDeviceHost::AudioDeviceHost() : impl_(std::make_unique<Impl>()) {}
AudioDeviceHost::~AudioDeviceHost() = default;

std::vector<AudioDeviceInfo> AudioDeviceHost::enumerate(DeviceDirection direction) {
  std::lock_guard<std::mutex> lock(impl_->lifecycleMutex);
  return impl_->enumerateLocked(direction);
}

bool AudioDeviceHost::start(std::size_t captureIndex, std::size_t playbackIndex,
                            const ProcessorConfig& config, bool monitorOutput,
                            std::string& error) {
  std::lock_guard<std::mutex> lock(impl_->lifecycleMutex);
  impl_->stopLocked();
  if (!impl_->contextReady) {
    error = "Audio context initialization failed.";
    return false;
  }
  if (captureIndex >= impl_->captureIds.size() ||
      playbackIndex >= impl_->playbackIds.size()) {
    error = "Audio device list is stale or the selected device index is invalid.";
    return false;
  }

  impl_->monitorOutput = monitorOutput;
  impl_->inputPeak.store(0.0F, std::memory_order_relaxed);
  impl_->outputPeak.store(0.0F, std::memory_order_relaxed);
  impl_->inputRms.store(0.0F, std::memory_order_relaxed);
  impl_->outputRms.store(0.0F, std::memory_order_relaxed);
  impl_->processedFrames.store(0, std::memory_order_relaxed);
  impl_->spectrumPeakFrequencyHz.store(0.0F, std::memory_order_relaxed);
  impl_->spectrumRms.store(0.0F, std::memory_order_relaxed);
  for (auto& magnitude : impl_->spectrumMagnitude) magnitude.store(0.0F, std::memory_order_relaxed);
  impl_->spectrumAvailable.store(false, std::memory_order_release);

  ma_device_config deviceConfig = ma_device_config_init(ma_device_type_duplex);
  deviceConfig.capture.pDeviceID = &impl_->captureIds[captureIndex];
  deviceConfig.capture.format = ma_format_f32;
  deviceConfig.capture.channels = static_cast<ma_uint32>(kChannelCount);
  deviceConfig.playback.pDeviceID = &impl_->playbackIds[playbackIndex];
  deviceConfig.playback.format = ma_format_f32;
  deviceConfig.playback.channels = static_cast<ma_uint32>(kChannelCount);
  deviceConfig.sampleRate = 48000;
  deviceConfig.dataCallback = &Impl::callback;
  deviceConfig.pUserData = impl_.get();

  const ma_result initResult = ma_device_init(&impl_->context, &deviceConfig, &impl_->device);
  if (initResult != MA_SUCCESS) {
    error = "Could not open the selected capture/playback devices (miniaudio error " +
            std::to_string(static_cast<int>(initResult)) + ").";
    return false;
  }
  impl_->deviceReady = true;
  const double actualSampleRate = impl_->device.sampleRate > 0
      ? static_cast<double>(impl_->device.sampleRate) : 48000.0;
  if (!impl_->engine.configure(config, actualSampleRate)) {
    error = "Could not configure the DSP engine for the selected sample rate.";
    impl_->stopLocked();
    return false;
  }
  impl_->analysisSampleRateHz.store(actualSampleRate, std::memory_order_relaxed);
  impl_->startAnalysisWorker();

  const ma_result startResult = ma_device_start(&impl_->device);
  if (startResult != MA_SUCCESS) {
    error = "Could not start the audio stream (miniaudio error " +
            std::to_string(static_cast<int>(startResult)) + ").";
    impl_->stopLocked();
    return false;
  }
  impl_->isRunning.store(true, std::memory_order_release);
  error.clear();
  return true;
}

void AudioDeviceHost::stop() noexcept {
  std::lock_guard<std::mutex> lock(impl_->lifecycleMutex);
  impl_->stopLocked();
}

bool AudioDeviceHost::running() const noexcept {
  return impl_->isRunning.load(std::memory_order_acquire);
}

LiveAudioMetrics AudioDeviceHost::metrics() const noexcept {
  LiveAudioMetrics result;
  result.inputPeak = impl_->inputPeak.load(std::memory_order_relaxed);
  result.outputPeak = impl_->outputPeak.load(std::memory_order_relaxed);
  result.inputRms = impl_->inputRms.load(std::memory_order_relaxed);
  result.outputRms = impl_->outputRms.load(std::memory_order_relaxed);
  result.processedFrames = impl_->processedFrames.load(std::memory_order_relaxed);
  result.running = running();
  result.spectrumAvailable = impl_->spectrumAvailable.load(std::memory_order_acquire);
  result.spectrumPeakFrequencyHz = impl_->spectrumPeakFrequencyHz.load(std::memory_order_relaxed);
  result.spectrumRms = impl_->spectrumRms.load(std::memory_order_relaxed);
  result.sampleRateHz = impl_->analysisSampleRateHz.load(std::memory_order_relaxed);
  for (std::size_t i = 0; i < kSpectrumBinCount; ++i) {
    result.spectrumMagnitude[i] = impl_->spectrumMagnitude[i].load(std::memory_order_relaxed);
  }
  return result;
}

}  // namespace hwcontrol::audio
