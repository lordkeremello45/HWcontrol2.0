#include "hwcontrol_audio/audio_analyzer.hpp"

#include <algorithm>
#include <cmath>
#include <complex>
#include <cstdint>
#include <limits>

namespace hwcontrol::audio {
namespace {
constexpr double kPi = 3.14159265358979323846;
using ComplexBuffer = std::array<std::complex<float>, kFftSize>;

void fft(ComplexBuffer& values) noexcept {
  for (std::size_t i = 1, j = 0; i < kFftSize; ++i) {
    std::size_t bit = kFftSize >> 1;
    for (; (j & bit) != 0U; bit >>= 1U) j ^= bit;
    j ^= bit;
    if (i < j) std::swap(values[i], values[j]);
  }

  for (std::size_t length = 2; length <= kFftSize; length <<= 1U) {
    const float angle = static_cast<float>(-2.0 * kPi / static_cast<double>(length));
    const std::complex<float> step(std::cos(angle), std::sin(angle));
    for (std::size_t base = 0; base < kFftSize; base += length) {
      std::complex<float> weight(1.0F, 0.0F);
      const std::size_t half = length / 2;
      for (std::size_t offset = 0; offset < half; ++offset) {
        const auto even = values[base + offset];
        const auto odd = values[base + offset + half] * weight;
        values[base + offset] = even + odd;
        values[base + offset + half] = even - odd;
        weight *= step;
      }
    }
  }
}
}  // namespace

bool AudioAnalyzer::analyze(const float* samples, std::size_t frameCount,
                            double sampleRateHz, SpectrumFrame& output) noexcept {
  output = SpectrumFrame{};
  if (samples == nullptr || frameCount != kFftSize ||
      !std::isfinite(sampleRateHz) || sampleRateHz < 8000.0 ||
      sampleRateHz > 192000.0) {
    return false;
  }

  ComplexBuffer buffer{};
  double squareSum = 0.0;
  double leftSquareSum = 0.0;
  double rightSquareSum = 0.0;
  double leftSum = 0.0;
  double rightSum = 0.0;
  double crossProductSum = 0.0;
  double windowSum = 0.0;
  for (std::size_t i = 0; i < kFftSize; ++i) {
    float left = samples[i * 2];
    float right = samples[i * 2 + 1];
    if (!std::isfinite(left)) left = 0.0F;
    if (!std::isfinite(right)) right = 0.0F;
    const double leftDouble = static_cast<double>(left);
    const double rightDouble = static_cast<double>(right);
    leftSquareSum += leftDouble * leftDouble;
    rightSquareSum += rightDouble * rightDouble;
    leftSum += leftDouble;
    rightSum += rightDouble;
    crossProductSum += leftDouble * rightDouble;
    // Average in double precision so finite float samples cannot overflow
    // during addition before the FFT's sanitization boundary.
    const double monoDouble = (leftDouble + rightDouble) * 0.5;
    const float mono = std::isfinite(monoDouble) ? static_cast<float>(monoDouble) : 0.0F;
    const double window = 0.5 * (1.0 - std::cos(
        2.0 * kPi * static_cast<double>(i) / static_cast<double>(kFftSize - 1)));
    buffer[i] = std::complex<float>(mono * static_cast<float>(window), 0.0F);
    squareSum += static_cast<double>(mono) * static_cast<double>(mono);
    windowSum += window;
  }

  fft(buffer);
  const double frameCountDouble = static_cast<double>(kFftSize);
  output.rms = static_cast<float>(std::sqrt(squareSum / frameCountDouble));
  output.leftRms = static_cast<float>(std::sqrt(leftSquareSum / frameCountDouble));
  output.rightRms = static_cast<float>(std::sqrt(rightSquareSum / frameCountDouble));
  const double centeredLeftSquares = std::max(
      0.0, leftSquareSum - (leftSum * leftSum / frameCountDouble));
  const double centeredRightSquares = std::max(
      0.0, rightSquareSum - (rightSum * rightSum / frameCountDouble));
  const double centeredCrossProduct =
      crossProductSum - (leftSum * rightSum / frameCountDouble);
  const double correlationDenominator = std::sqrt(
      centeredLeftSquares * centeredRightSquares);
  if (correlationDenominator > 0.0 && std::isfinite(correlationDenominator)) {
    const double correlation = centeredCrossProduct / correlationDenominator;
    if (std::isfinite(correlation)) {
      output.stereoCorrelation = static_cast<float>(std::clamp(correlation, -1.0, 1.0));
    }
  }
  float largest = 0.0F;
  std::size_t largestBin = 0;
  for (std::size_t bin = 0; bin < kSpectrumBinCount; ++bin) {
    float magnitude = static_cast<float>(std::abs(buffer[bin]) * (2.0 / windowSum));
    if (bin == 0 || bin == kFftSize / 2) magnitude *= 0.5F;
    if (!std::isfinite(magnitude)) magnitude = 0.0F;
    output.magnitude[bin] = magnitude;
    if (magnitude > largest) {
      largest = magnitude;
      largestBin = bin;
    }
  }
  output.peakFrequencyHz = static_cast<float>(
      static_cast<double>(largestBin) * sampleRateHz / static_cast<double>(kFftSize));
  return true;
}

}  // namespace hwcontrol::audio
