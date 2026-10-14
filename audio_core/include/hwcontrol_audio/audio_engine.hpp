#pragma once

#include <array>
#include <cstddef>
#include <cstdint>

namespace hwcontrol::audio {

constexpr std::size_t kChannelCount = 2;
constexpr std::size_t kEqBandCount = 3;

// Parameters are changed on the control thread between processing blocks.
// Do not mutate a configuration concurrently with process().
struct EqBand {
  float frequencyHz = 1000.0F;
  float gainDb = 0.0F;
  float q = 0.707F;
};

struct ProcessorConfig {
  float inputGainDb = 0.0F;
  float gateThresholdDb = -72.0F;
  float compressorThresholdDb = -12.0F;
  float compressorRatio = 2.0F;
  float compressorAttackMs = 10.0F;
  float compressorReleaseMs = 100.0F;
  float compressorKneeDb = 6.0F;
  float highPassFrequencyHz = 80.0F;
  float limiterCeilingDb = -1.0F;
  bool noiseGateEnabled = false;
  bool highPassEnabled = false;
  bool compressorEnabled = false;
  bool limiterEnabled = true;
  std::array<EqBand, kEqBandCount> eq{{
      {100.0F, 0.0F, 0.707F},
      {1000.0F, 0.0F, 0.707F},
      {8000.0F, 0.0F, 0.707F},
  }};
  std::array<bool, kEqBandCount> eqEnabled{{false, false, false}};
};

struct AudioMetrics {
  float inputPeak = 0.0F;
  float outputPeak = 0.0F;
  float inputRms = 0.0F;
  float outputRms = 0.0F;
  std::uint64_t clippedSamples = 0;
  std::uint64_t processedFrames = 0;
};

// Allocation-free, interleaved stereo float processor. This is the DSP core,
// not a device backend: it does not open microphones or capture system audio.
class AudioEngine final {
 public:
  AudioEngine() noexcept;

  // Numeric controls are clamped to safe ranges. Returns false only when the
  // sample rate is invalid and the 48 kHz fallback is selected. Call only
  // while processing is stopped or before the audio callback is started.
  bool configure(const ProcessorConfig& config,
                double sampleRateHz) noexcept;

  // Processes frames in-place. A frame contains left then right samples.
  // The caller owns the buffers and must ensure they contain frameCount * 2
  // float samples. No allocation, locks, I/O, or logging occurs here.
  void process(float* interleavedStereo, std::size_t frameCount) noexcept;

  const AudioMetrics& metrics() const noexcept { return metrics_; }
  void reset() noexcept;

 private:
  struct Biquad {
    float b0 = 1.0F;
    float b1 = 0.0F;
    float b2 = 0.0F;
    float a1 = 0.0F;
    float a2 = 0.0F;
    std::array<float, kChannelCount> z1{{0.0F, 0.0F}};
    std::array<float, kChannelCount> z2{{0.0F, 0.0F}};

    void setPeaking(float frequencyHz, float gainDb, float q,
                    double sampleRateHz) noexcept;
    void setHighPass(float frequencyHz, double sampleRateHz) noexcept;
    float tick(float input, std::size_t channel) noexcept;
    void clear() noexcept;
  };

  ProcessorConfig config_{};
  std::array<Biquad, kEqBandCount> filters_{};
  Biquad highPassFilter_{};
  std::array<float, kChannelCount> compressorEnvelope_{{0.0F, 0.0F}};
  double sampleRateHz_ = 48000.0;
  float compressorAttackCoefficient_ = 0.0F;
  float compressorReleaseCoefficient_ = 0.0F;
  AudioMetrics metrics_{};
};

}  // namespace hwcontrol::audio
