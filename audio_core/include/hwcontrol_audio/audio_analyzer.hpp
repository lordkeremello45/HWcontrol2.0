#pragma once

#include <array>
#include <cstddef>

namespace hwcontrol::audio {

constexpr std::size_t kFftSize = 1024;
constexpr std::size_t kSpectrumBinCount = (kFftSize / 2) + 1;

struct SpectrumFrame {
  std::array<float, kSpectrumBinCount> magnitude{};
  float peakFrequencyHz = 0.0F;
  float rms = 0.0F;
};

// Fixed-size analyzer for a worker/analysis thread. Do not call from a device
// callback: FFT work is bounded and allocation-free, but still costs CPU time.
class AudioAnalyzer final {
 public:
  bool analyze(const float* interleavedStereo, std::size_t frameCount,
               double sampleRateHz, SpectrumFrame& output) noexcept;
};

}  // namespace hwcontrol::audio
