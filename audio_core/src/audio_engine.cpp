#include "hwcontrol_audio/audio_engine.hpp"

#include <algorithm>
#include <cmath>
#include <limits>

namespace hwcontrol::audio {
namespace {
constexpr float kMinDb = -90.0F;
constexpr float kMaxDb = 12.0F;
constexpr float kMinFrequency = 10.0F;
constexpr float kMinQ = 0.1F;
constexpr float kMaxQ = 20.0F;
constexpr double kPi = 3.14159265358979323846;

float dbToLinear(float db) noexcept {
  return std::pow(10.0F, db / 20.0F);
}

float linearToDb(float value) noexcept {
  if (!(value > 0.0F)) return -120.0F;
  return 20.0F * std::log10(value);
}

float finiteOr(float value, float fallback) noexcept {
  return std::isfinite(value) ? value : fallback;
}
}  // namespace

AudioEngine::AudioEngine() noexcept {
  (void)configure(config_, sampleRateHz_);
}

void AudioEngine::Biquad::setPeaking(float frequencyHz, float gainDb, float q,
                                     double sampleRateHz) noexcept {
  const double frequency = static_cast<double>(frequencyHz);
  const double bandwidth = static_cast<double>(q);
  const double a = std::pow(10.0, static_cast<double>(gainDb) / 40.0);
  const double omega = 2.0 * kPi * frequency / sampleRateHz;
  const double sine = std::sin(omega);
  const double cosine = std::cos(omega);
  const double alpha = sine / (2.0 * bandwidth);
  const double a0 = 1.0 + alpha / a;

  b0 = static_cast<float>((1.0 + alpha * a) / a0);
  b1 = static_cast<float>((-2.0 * cosine) / a0);
  b2 = static_cast<float>((1.0 - alpha * a) / a0);
  a1 = static_cast<float>((-2.0 * cosine) / a0);
  a2 = static_cast<float>((1.0 - alpha / a) / a0);
}

void AudioEngine::Biquad::setHighPass(float frequencyHz,
                                        double sampleRateHz) noexcept {
  const double omega = 2.0 * kPi * static_cast<double>(frequencyHz) / sampleRateHz;
  const double cosine = std::cos(omega);
  const double sine = std::sin(omega);
  const double alpha = sine / (2.0 * 0.7071067811865476);
  const double a0 = 1.0 + alpha;
  b0 = static_cast<float>((1.0 + cosine) * 0.5 / a0);
  b1 = static_cast<float>(-(1.0 + cosine) / a0);
  b2 = b0;
  a1 = static_cast<float>(-2.0 * cosine / a0);
  a2 = static_cast<float>((1.0 - alpha) / a0);
}

float AudioEngine::Biquad::tick(float input, std::size_t channel) noexcept {
  const float output = b0 * input + z1[channel];
  z1[channel] = b1 * input - a1 * output + z2[channel];
  z2[channel] = b2 * input - a2 * output;
  if (!std::isfinite(output) || !std::isfinite(z1[channel]) ||
      !std::isfinite(z2[channel])) {
    z1[channel] = 0.0F;
    z2[channel] = 0.0F;
    return 0.0F;
  }
  return output;
}

void AudioEngine::Biquad::clear() noexcept {
  z1.fill(0.0F);
  z2.fill(0.0F);
}

bool AudioEngine::configure(const ProcessorConfig& requested,
                            double sampleRateHz) noexcept {
  bool valid = true;
  if (!std::isfinite(sampleRateHz) || sampleRateHz < 8000.0 ||
      sampleRateHz > 192000.0) {
    sampleRateHz = 48000.0;
    valid = false;
  }
  sampleRateHz_ = sampleRateHz;
  config_ = requested;

  config_.inputGainDb = std::clamp(finiteOr(config_.inputGainDb, 0.0F), kMinDb, kMaxDb);
  config_.gateThresholdDb = std::clamp(finiteOr(config_.gateThresholdDb, -72.0F), kMinDb, 0.0F);
  config_.compressorThresholdDb = std::clamp(finiteOr(config_.compressorThresholdDb, -12.0F), kMinDb, 0.0F);
  config_.compressorRatio = std::clamp(finiteOr(config_.compressorRatio, 2.0F), 1.0F, 20.0F);
  config_.compressorAttackMs = std::clamp(finiteOr(config_.compressorAttackMs, 10.0F), 0.1F, 200.0F);
  config_.compressorReleaseMs = std::clamp(finiteOr(config_.compressorReleaseMs, 100.0F), 1.0F, 2000.0F);
  config_.compressorKneeDb = std::clamp(finiteOr(config_.compressorKneeDb, 6.0F), 0.0F, 24.0F);
  config_.highPassFrequencyHz = std::clamp(finiteOr(config_.highPassFrequencyHz, 80.0F),
      20.0F, static_cast<float>(sampleRateHz_ * 0.40));
  compressorAttackCoefficient_ = static_cast<float>(std::exp(
      -1.0 / (static_cast<double>(config_.compressorAttackMs) * 0.001 * sampleRateHz_)));
  compressorReleaseCoefficient_ = static_cast<float>(std::exp(
      -1.0 / (static_cast<double>(config_.compressorReleaseMs) * 0.001 * sampleRateHz_)));
  highPassFilter_.setHighPass(config_.highPassFrequencyHz, sampleRateHz_);
  highPassFilter_.clear();
  compressorEnvelope_.fill(0.0F);
  config_.limiterCeilingDb = std::clamp(finiteOr(config_.limiterCeilingDb, -1.0F), -24.0F, 0.0F);

  for (std::size_t i = 0; i < kEqBandCount; ++i) {
    auto& band = config_.eq[i];
    const float maxFrequency = static_cast<float>(sampleRateHz_ * 0.45);
    band.frequencyHz = std::clamp(finiteOr(band.frequencyHz, 1000.0F),
                                  kMinFrequency, maxFrequency);
    band.gainDb = std::clamp(finiteOr(band.gainDb, 0.0F), -24.0F, 24.0F);
    band.q = std::clamp(finiteOr(band.q, 0.707F), kMinQ, kMaxQ);
    filters_[i].setPeaking(band.frequencyHz, band.gainDb, band.q, sampleRateHz_);
    filters_[i].clear();
  }
  reset();
  return valid;
}

void AudioEngine::process(float* samples, std::size_t frameCount) noexcept {
  if (samples == nullptr || frameCount == 0) return;

  double inputSquares = 0.0;
  double outputSquares = 0.0;
  float inputPeak = 0.0F;
  float outputPeak = 0.0F;
  std::uint64_t clipped = 0;
  const float gain = dbToLinear(config_.inputGainDb);
  const float gate = dbToLinear(config_.gateThresholdDb);
  const float limiterCeiling = dbToLinear(config_.limiterCeilingDb);

  for (std::size_t frame = 0; frame < frameCount; ++frame) {
    for (std::size_t channel = 0; channel < kChannelCount; ++channel) {
      const std::size_t index = frame * kChannelCount + channel;
      float value = samples[index];
      if (!std::isfinite(value)) value = 0.0F;
      inputPeak = std::max(inputPeak, std::abs(value));
      inputSquares += static_cast<double>(value) * static_cast<double>(value);

      value *= gain;
      if (config_.noiseGateEnabled && std::abs(value) < gate) value = 0.0F;
      if (config_.highPassEnabled) value = highPassFilter_.tick(value, channel);
      for (std::size_t band = 0; band < kEqBandCount; ++band) {
        if (config_.eqEnabled[band]) value = filters_[band].tick(value, channel);
      }
      if (config_.compressorEnabled) {
        const float magnitude = std::abs(value);
        const float coefficient = magnitude > compressorEnvelope_[channel]
            ? compressorAttackCoefficient_ : compressorReleaseCoefficient_;
        compressorEnvelope_[channel] =
            coefficient * compressorEnvelope_[channel] + (1.0F - coefficient) * magnitude;
        const float levelDb = linearToDb(compressorEnvelope_[channel]);
        const float overThreshold = levelDb - config_.compressorThresholdDb;
        const float knee = config_.compressorKneeDb;
        float gainReductionDb = 0.0F;
        if (knee <= 0.0F) {
          if (overThreshold > 0.0F) {
            gainReductionDb = overThreshold * (1.0F - 1.0F / config_.compressorRatio);
          }
        } else if (overThreshold > -knee * 0.5F) {
          if (overThreshold >= knee * 0.5F) {
            gainReductionDb = overThreshold * (1.0F - 1.0F / config_.compressorRatio);
          } else {
            const float shifted = overThreshold + knee * 0.5F;
            gainReductionDb = shifted * shifted / (2.0F * knee) *
                (1.0F - 1.0F / config_.compressorRatio);
          }
        }
        if (gainReductionDb > 0.0F) value *= dbToLinear(-gainReductionDb);
      }
      if (config_.limiterEnabled) {
        value = std::clamp(value, -limiterCeiling, limiterCeiling);
      }
      if (!std::isfinite(value)) value = 0.0F;
      if (std::abs(value) >= 1.0F) ++clipped;
      outputPeak = std::max(outputPeak, std::abs(value));
      outputSquares += static_cast<double>(value) * static_cast<double>(value);
      samples[index] = value;
    }
  }

  const double sampleCount = static_cast<double>(frameCount * kChannelCount);
  metrics_.inputPeak = inputPeak;
  metrics_.outputPeak = outputPeak;
  metrics_.inputRms = static_cast<float>(std::sqrt(inputSquares / sampleCount));
  metrics_.outputRms = static_cast<float>(std::sqrt(outputSquares / sampleCount));
  metrics_.clippedSamples += clipped;
  metrics_.processedFrames += static_cast<std::uint64_t>(frameCount);
}

void AudioEngine::reset() noexcept {
  for (auto& filter : filters_) filter.clear();
  highPassFilter_.clear();
  compressorEnvelope_.fill(0.0F);
  metrics_ = AudioMetrics{};
}

}  // namespace hwcontrol::audio
