#include "miniaudio.h"
#include "hwcontrol_audio/audio_engine.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <limits>
#include <string>

namespace {
constexpr std::size_t kMaxFramesPerBlock = 2048;
constexpr std::size_t kChannels = hwcontrol::audio::kChannelCount;

struct ProbeState {
  hwcontrol::audio::AudioEngine engine;
  std::atomic<std::uint64_t> processedFrames{0};
  std::atomic<std::uint64_t> nonFiniteSamples{0};
  std::atomic<float> inputPeak{0.0F};
  std::atomic<float> processedPeak{0.0F};
  std::atomic<float> inputRms{0.0F};
  std::atomic<float> processedRms{0.0F};
};

void dataCallback(ma_device* device, void*, const void* input, ma_uint32 frameCount) {
  auto* state = static_cast<ProbeState*>(device->pUserData);
  if (state == nullptr || input == nullptr || frameCount == 0) return;

  const auto* source = static_cast<const float*>(input);
  std::array<float, kMaxFramesPerBlock * kChannels> block{};
  float peakIn = 0.0F;
  float peakOut = 0.0F;
  double squaresIn = 0.0;
  double squaresOut = 0.0;
  std::uint64_t seen = 0;

  std::size_t offset = 0;
  while (offset < static_cast<std::size_t>(frameCount)) {
    const std::size_t frames = std::min(
        kMaxFramesPerBlock, static_cast<std::size_t>(frameCount) - offset);
    const std::size_t samples = frames * kChannels;
    for (std::size_t i = 0; i < samples; ++i) {
      float value = source[offset * kChannels + i];
      if (!std::isfinite(value)) {
        value = 0.0F;
        state->nonFiniteSamples.fetch_add(1, std::memory_order_relaxed);
      }
      block[i] = value;
      peakIn = std::max(peakIn, std::abs(value));
      squaresIn += static_cast<double>(value) * value;
    }

    (void)state->engine.process(block.data(), frames);
    for (std::size_t i = 0; i < samples; ++i) {
      const float value = block[i];
      peakOut = std::max(peakOut, std::abs(value));
      squaresOut += static_cast<double>(value) * value;
    }
    seen += static_cast<std::uint64_t>(samples);
    offset += frames;
  }

  if (seen != 0) {
    state->inputPeak.store(peakIn, std::memory_order_relaxed);
    state->processedPeak.store(peakOut, std::memory_order_relaxed);
    state->inputRms.store(static_cast<float>(std::sqrt(squaresIn / seen)),
                           std::memory_order_relaxed);
    state->processedRms.store(static_cast<float>(std::sqrt(squaresOut / seen)),
                               std::memory_order_relaxed);
    state->processedFrames.fetch_add(frameCount, std::memory_order_relaxed);
  }
}
}  // namespace

int main() {
#if !defined(_WIN32)
  std::cerr << "This probe is Windows-only: WASAPI loopback is not a portable API.\n";
  return 2;
#else
  ProbeState state;
  hwcontrol::audio::ProcessorConfig processorConfig;
  // Keep the initial pass neutral except for the core's safe default limiter.
  (void)state.engine.configure(processorConfig, 48000.0);

  ma_backend backends[] = {ma_backend_wasapi};
  ma_device_config config = ma_device_config_init(ma_device_type_loopback);
  config.capture.pDeviceID = nullptr;  // Default Windows playback endpoint.
  config.capture.format = ma_format_f32;
  config.capture.channels = static_cast<ma_uint32>(kChannels);
  config.sampleRate = 48000;
  config.dataCallback = dataCallback;
  config.pUserData = &state;

  ma_device device{};
  const ma_result initResult = ma_device_init_ex(
      backends, sizeof(backends) / sizeof(backends[0]), nullptr, &config, &device);
  if (initResult != MA_SUCCESS) {
    std::cerr << "WASAPI loopback initialization failed (miniaudio error "
              << static_cast<int>(initResult) << ").\n";
    return 1;
  }

  (void)state.engine.configure(processorConfig,
      device.sampleRate > 0 ? static_cast<double>(device.sampleRate) : 48000.0);

  const ma_result startResult = ma_device_start(&device);
  if (startResult != MA_SUCCESS) {
    std::cerr << "WASAPI loopback start failed (miniaudio error "
              << static_cast<int>(startResult) << ").\n";
    ma_device_uninit(&device);
    return 1;
  }

  std::cout << "Windows WASAPI loopback capture + native DSP isolation probe\n"
            << "Play audio in any application. No file is written and samples are not transmitted.\n"
            << "This probe measures the processed loopback stream; it does NOT reroute system output.\n"
            << "Press Enter to stop.\n";

  auto lastReport = std::chrono::steady_clock::now();
  std::uint64_t previousFrames = 0;
  while (std::cin.peek() == std::char_traits<char>::eof()) {
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
    const auto now = std::chrono::steady_clock::now();
    if (now - lastReport < std::chrono::seconds(1)) continue;

    const auto frames = state.processedFrames.load(std::memory_order_relaxed);
    const auto delta = frames - previousFrames;
    previousFrames = frames;
    std::cout << "sample_rate=" << device.sampleRate
              << " captured_and_processed_frames=" << frames
              << " frames_last_second=" << delta
              << " input_rms=" << state.inputRms.load(std::memory_order_relaxed)
              << " processed_rms=" << state.processedRms.load(std::memory_order_relaxed)
              << " input_peak=" << state.inputPeak.load(std::memory_order_relaxed)
              << " processed_peak=" << state.processedPeak.load(std::memory_order_relaxed)
              << " non_finite_samples=" << state.nonFiniteSamples.load(std::memory_order_relaxed)
              << '\n';
    lastReport = now;
  }

  (void)ma_device_stop(&device);
  ma_device_uninit(&device);
  return 0;
#endif
}
