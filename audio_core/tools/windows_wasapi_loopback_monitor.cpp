#include "miniaudio.h"
#include "hwcontrol_audio/audio_engine.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <limits>
#include <string>

namespace {
constexpr std::size_t kChannels = hwcontrol::audio::kChannelCount;
constexpr std::uint64_t kQueueFrames = 16384;  // 341 ms at 48 kHz.
constexpr std::uint64_t kQueueMask = kQueueFrames - 1;

struct AudioRing {
  std::array<std::array<float, kChannels>, kQueueFrames> frames{};
  alignas(64) std::atomic<std::uint64_t> writeFrame{0};
  alignas(64) std::atomic<std::uint64_t> readFrame{0};
  std::atomic<std::uint64_t> droppedInputFrames{0};
  std::atomic<std::uint64_t> outputUnderrunFrames{0};
};

struct MonitorState {
  hwcontrol::audio::AudioEngine engine;
  AudioRing ring;
  std::atomic<std::uint64_t> capturedFrames{0};
  std::atomic<std::uint64_t> playedFrames{0};
  std::atomic<float> inputPeak{0.0F};
  std::atomic<float> processedPeak{0.0F};
};

bool sameDeviceId(const ma_device_id& left, const ma_device_id& right) {
  return std::memcmp(&left, &right, sizeof(ma_device_id)) == 0;
}

void captureCallback(ma_device* device, void*, const void* input, ma_uint32 frameCount) {
  auto* state = static_cast<MonitorState*>(device->pUserData);
  if (state == nullptr || input == nullptr || frameCount == 0) return;

  const auto* samples = static_cast<const float*>(input);
  std::array<float, 2048 * kChannels> block{};
  std::uint64_t captured = 0;
  float peakIn = 0.0F;
  float peakOut = 0.0F;

  std::size_t offset = 0;
  while (offset < static_cast<std::size_t>(frameCount)) {
    const std::size_t frames = std::min<std::size_t>(
        2048, static_cast<std::size_t>(frameCount) - offset);
    for (std::size_t i = 0; i < frames * kChannels; ++i) {
      float sample = samples[offset * kChannels + i];
      if (!std::isfinite(sample)) sample = 0.0F;
      block[i] = sample;
      peakIn = std::max(peakIn, std::abs(sample));
    }
    (void)state->engine.process(block.data(), frames);

    auto write = state->ring.writeFrame.load(std::memory_order_relaxed);
    const auto read = state->ring.readFrame.load(std::memory_order_acquire);
    for (std::size_t frame = 0; frame < frames; ++frame) {
      if (write - read >= kQueueFrames) {
        state->ring.droppedInputFrames.fetch_add(1, std::memory_order_relaxed);
        continue;
      }
      auto& destination = state->ring.frames[write & kQueueMask];
      destination[0] = block[frame * kChannels];
      destination[1] = block[frame * kChannels + 1];
      peakOut = std::max(peakOut, std::max(std::abs(destination[0]), std::abs(destination[1])));
      ++write;
      state->ring.writeFrame.store(write, std::memory_order_release);
      ++captured;
    }
    offset += frames;
  }

  state->capturedFrames.fetch_add(captured, std::memory_order_relaxed);
  state->inputPeak.store(peakIn, std::memory_order_relaxed);
  state->processedPeak.store(peakOut, std::memory_order_relaxed);
}

void playbackCallback(ma_device* device, void* output, const void*, ma_uint32 frameCount) {
  auto* state = static_cast<MonitorState*>(device->pUserData);
  auto* samples = static_cast<float*>(output);
  if (state == nullptr || samples == nullptr) return;

  auto read = state->ring.readFrame.load(std::memory_order_relaxed);
  const auto write = state->ring.writeFrame.load(std::memory_order_acquire);
  std::uint64_t played = 0;
  for (ma_uint32 frame = 0; frame < frameCount; ++frame) {
    if (read == write) {
      samples[frame * kChannels] = 0.0F;
      samples[frame * kChannels + 1] = 0.0F;
      state->ring.outputUnderrunFrames.fetch_add(1, std::memory_order_relaxed);
      continue;
    }
    const auto& source = state->ring.frames[read & kQueueMask];
    samples[frame * kChannels] = source[0];
    samples[frame * kChannels + 1] = source[1];
    ++read;
    ++played;
  }
  state->ring.readFrame.store(read, std::memory_order_release);
  state->playedFrames.fetch_add(played, std::memory_order_relaxed);
}
}  // namespace

int main(int argc, char** argv) {
#if !defined(_WIN32)
  (void)argc;
  (void)argv;
  std::cerr << "This monitor is Windows-only (WASAPI loopback).\n";
  return 2;
#else
  ma_backend backends[] = {ma_backend_wasapi};
  ma_context context{};
  ma_result result = ma_context_init(backends, 1, nullptr, &context);
  if (result != MA_SUCCESS) {
    std::cerr << "WASAPI context initialization failed: " << static_cast<int>(result) << '\n';
    return 1;
  }

  ma_device_info* playbackDevices = nullptr;
  ma_uint32 playbackCount = 0;
  ma_device_info* captureDevices = nullptr;
  ma_uint32 captureCount = 0;
  result = ma_context_get_devices(&context, &playbackDevices, &playbackCount,
                                  &captureDevices, &captureCount);
  (void)captureDevices;
  (void)captureCount;
  if (result != MA_SUCCESS || playbackCount < 2) {
    std::cerr << "At least two playback endpoints are required: one source endpoint and a distinct processed-output endpoint.\n";
    ma_context_uninit(&context);
    return 1;
  }

  std::cout << "WASAPI playback endpoints (the DEFAULT endpoint is captured):\n";
  ma_uint32 defaultIndex = playbackCount;
  for (ma_uint32 i = 0; i < playbackCount; ++i) {
    std::cout << "  [" << i << "] " << playbackDevices[i].name;
    if (playbackDevices[i].isDefault) {
      std::cout << "  <DEFAULT SOURCE>";
      defaultIndex = i;
    }
    std::cout << '\n';
  }
  if (defaultIndex == playbackCount) {
    std::cerr << "Could not identify the default playback endpoint.\n";
    ma_context_uninit(&context);
    return 1;
  }
  if (argc != 2) {
    std::cout << "\nUsage: hwcontrol_windows_wasapi_loopback_monitor.exe <output-index>\n"
              << "Choose an output index different from the default source endpoint.\n"
              << "This test intentionally refuses same-endpoint routing to avoid a feedback loop.\n";
    ma_context_uninit(&context);
    return 0;
  }

  char* end = nullptr;
  const long parsedIndex = std::strtol(argv[1], &end, 10);
  if (end == argv[1] || *end != '\0' || parsedIndex < 0 ||
      static_cast<unsigned long>(parsedIndex) >= playbackCount) {
    std::cerr << "Invalid playback endpoint index.\n";
    ma_context_uninit(&context);
    return 2;
  }
  const auto outputIndex = static_cast<ma_uint32>(parsedIndex);
  if (outputIndex == defaultIndex ||
      sameDeviceId(playbackDevices[outputIndex].id, playbackDevices[defaultIndex].id)) {
    std::cerr << "Refusing to capture and play to the same endpoint. Choose a different output device.\n";
    ma_context_uninit(&context);
    return 2;
  }

  MonitorState state;
  hwcontrol::audio::ProcessorConfig processorConfig;
  (void)state.engine.configure(processorConfig, 48000.0);

  ma_device_config captureConfig = ma_device_config_init(ma_device_type_loopback);
  captureConfig.capture.pDeviceID = &playbackDevices[defaultIndex].id;
  captureConfig.capture.format = ma_format_f32;
  captureConfig.capture.channels = static_cast<ma_uint32>(kChannels);
  captureConfig.sampleRate = 48000;
  captureConfig.dataCallback = captureCallback;
  captureConfig.pUserData = &state;

  ma_device captureDevice{};
  result = ma_device_init(&context, &captureConfig, &captureDevice);
  if (result != MA_SUCCESS) {
    std::cerr << "Loopback capture initialization failed: " << static_cast<int>(result) << '\n';
    ma_context_uninit(&context);
    return 1;
  }
  (void)state.engine.configure(processorConfig,
      captureDevice.sampleRate > 0 ? static_cast<double>(captureDevice.sampleRate) : 48000.0);

  ma_device_config playbackConfig = ma_device_config_init(ma_device_type_playback);
  playbackConfig.playback.pDeviceID = &playbackDevices[outputIndex].id;
  playbackConfig.playback.format = ma_format_f32;
  playbackConfig.playback.channels = static_cast<ma_uint32>(kChannels);
  playbackConfig.sampleRate = captureDevice.sampleRate;
  playbackConfig.dataCallback = playbackCallback;
  playbackConfig.pUserData = &state;

  ma_device playbackDevice{};
  result = ma_device_init(&context, &playbackConfig, &playbackDevice);
  if (result != MA_SUCCESS) {
    std::cerr << "Processed-output initialization failed: " << static_cast<int>(result) << '\n';
    ma_device_uninit(&captureDevice);
    ma_context_uninit(&context);
    return 1;
  }

  result = ma_device_start(&playbackDevice);
  if (result == MA_SUCCESS) result = ma_device_start(&captureDevice);
  if (result != MA_SUCCESS) {
    std::cerr << "Audio device start failed: " << static_cast<int>(result) << '\n';
    (void)ma_device_stop(&captureDevice);
    (void)ma_device_stop(&playbackDevice);
    ma_device_uninit(&captureDevice);
    ma_device_uninit(&playbackDevice);
    ma_context_uninit(&context);
    return 1;
  }

  std::cout << "\nProcessed monitor running. Default endpoint is captured; output is sent to: "
            << playbackDevices[outputIndex].name << "\n"
            << "Do not select the same endpoint. This is a diagnostic monitor, not system-wide routing.\n"
            << "Press Enter to stop.\n";
  std::string line;
  std::getline(std::cin, line);

  (void)ma_device_stop(&captureDevice);
  (void)ma_device_stop(&playbackDevice);
  ma_device_uninit(&captureDevice);
  ma_device_uninit(&playbackDevice);
  std::cout << "captured_frames=" << state.capturedFrames.load()
            << " played_frames=" << state.playedFrames.load()
            << " dropped_input_frames=" << state.ring.droppedInputFrames.load()
            << " output_underrun_frames=" << state.ring.outputUnderrunFrames.load()
            << " input_peak=" << state.inputPeak.load()
            << " processed_peak=" << state.processedPeak.load() << '\n';
  ma_context_uninit(&context);
  return 0;
#endif
}
