#include "hwcontrol_audio/loudness_meter.hpp"

#include <algorithm>
#include <cmath>

namespace hwcontrol::audio {
namespace {
constexpr double kPi = 3.14159265358979323846;
constexpr double kLoudnessOffset = -0.691;
constexpr double kAbsoluteGateLufs = -70.0;
constexpr double kRelativeGateLufs = -10.0;

}  // namespace

double LoudnessMeter::Biquad::tick(double input, std::size_t channel) noexcept {
  const double output = b0 * input + z1[channel];
  z1[channel] = b1 * input - a1 * output + z2[channel];
  z2[channel] = b2 * input - a2 * output;
  if (!std::isfinite(output) || !std::isfinite(z1[channel]) ||
      !std::isfinite(z2[channel])) {
    z1[channel] = 0.0;
    z2[channel] = 0.0;
    return 0.0;
  }
  return output;
}

void LoudnessMeter::Biquad::clear() noexcept {
  z1.fill(0.0);
  z2.fill(0.0);
}

bool LoudnessMeter::configure(double sampleRateHz) noexcept {
  if (!std::isfinite(sampleRateHz) || sampleRateHz < 8000.0 ||
      sampleRateHz > 192000.0) return false;

  sampleRateHz_ = sampleRateHz;
  windowFrames_ = static_cast<std::size_t>(std::llround(sampleRateHz_ * 0.4));
  hopFrames_ = static_cast<std::size_t>(std::llround(sampleRateHz_ * 0.1));
  if (windowFrames_ == 0 || windowFrames_ > kMaxWindowFrames || hopFrames_ == 0) {
    return false;
  }

  // BS.1770 K-weighting consists of a +4 dB high shelf followed by a
  // high-pass stage. Coefficients are generated for the active sample rate.
  const double shelfGain = std::pow(10.0, 4.0 / 40.0);
  const double shelfFrequency = 1681.974450955533;
  const double shelfQ = 0.7071752369554196;
  const double shelfOmega = 2.0 * kPi * shelfFrequency / sampleRateHz_;
  const double shelfCos = std::cos(shelfOmega);
  const double shelfSin = std::sin(shelfOmega);
  const double shelfAlpha = shelfSin / (2.0 * shelfQ);
  const double shelfBeta = 2.0 * std::sqrt(shelfGain) * shelfAlpha;
  const double shelfA0 = (shelfGain + 1.0) - (shelfGain - 1.0) * shelfCos + shelfBeta;
  auto& shelf = kWeighting_[0];
  shelf.b0 = shelfGain * ((shelfGain + 1.0) + (shelfGain - 1.0) * shelfCos + shelfBeta) / shelfA0;
  shelf.b1 = -2.0 * shelfGain * ((shelfGain - 1.0) + (shelfGain + 1.0) * shelfCos) / shelfA0;
  shelf.b2 = shelfGain * ((shelfGain + 1.0) + (shelfGain - 1.0) * shelfCos - shelfBeta) / shelfA0;
  shelf.a1 = 2.0 * ((shelfGain - 1.0) - (shelfGain + 1.0) * shelfCos) / shelfA0;
  shelf.a2 = ((shelfGain + 1.0) - (shelfGain - 1.0) * shelfCos - shelfBeta) / shelfA0;

  const double hpFrequency = 38.13547087602444;
  const double hpQ = 0.5003270373238773;
  const double omega = 2.0 * kPi * hpFrequency / sampleRateHz_;
  const double cosine = std::cos(omega);
  const double sine = std::sin(omega);
  const double alpha = sine / (2.0 * hpQ);
  const double a0 = 1.0 + alpha;
  auto& highPass = kWeighting_[1];
  highPass.b0 = ((1.0 + cosine) * 0.5) / a0;
  highPass.b1 = -(1.0 + cosine) / a0;
  highPass.b2 = highPass.b0;
  highPass.a1 = -2.0 * cosine / a0;
  highPass.a2 = (1.0 - alpha) / a0;

  reset();
  return true;
}

double LoudnessMeter::energyToLufs(double energy) noexcept {
  if (!(energy > 0.0) || !std::isfinite(energy)) return -120.0;
  return kLoudnessOffset + 10.0 * std::log10(energy);
}

void LoudnessMeter::process(const float* samples, std::size_t frameCount) {
  if (samples == nullptr || frameCount == 0) return;
  for (std::size_t frame = 0; frame < frameCount; ++frame) {
    double weightedEnergy = 0.0;
    for (std::size_t channel = 0; channel < 2; ++channel) {
      double value = static_cast<double>(samples[frame * 2 + channel]);
      if (!std::isfinite(value)) value = 0.0;
      value = kWeighting_[1].tick(kWeighting_[0].tick(value, channel), channel);
      weightedEnergy += value * value;
    }

    if (ringCount_ == windowFrames_) {
      rollingEnergy_ -= energyRing_[ringWrite_];
    } else {
      ++ringCount_;
    }
    energyRing_[ringWrite_] = weightedEnergy;
    rollingEnergy_ += weightedEnergy;
    ringWrite_ = (ringWrite_ + 1) % windowFrames_;

    ++framesSinceBlock_;
    if (ringCount_ == windowFrames_ && framesSinceBlock_ >= hopFrames_) {
      const double blockEnergy = std::max(0.0, rollingEnergy_ / static_cast<double>(windowFrames_));
      blockEnergies_.push_back(blockEnergy);
      framesSinceBlock_ = 0;
    }
  }
}

LoudnessMetrics LoudnessMeter::metrics() const noexcept {
  LoudnessMetrics result;
  if (blockEnergies_.empty()) return result;

  const double latest = blockEnergies_.back();
  result.momentaryAvailable = true;
  result.momentaryLufs = energyToLufs(latest);

  double absoluteGateEnergy = 0.0;
  std::size_t absoluteGateCount = 0;
  for (double energy : blockEnergies_) {
    if (energyToLufs(energy) >= kAbsoluteGateLufs) {
      absoluteGateEnergy += energy;
      ++absoluteGateCount;
    }
  }
  if (absoluteGateCount == 0) return result;

  const double ungatedMean = absoluteGateEnergy / static_cast<double>(absoluteGateCount);
  const double relativeThreshold = energyToLufs(ungatedMean) + kRelativeGateLufs;
  double gatedEnergy = 0.0;
  std::size_t gatedCount = 0;
  for (double energy : blockEnergies_) {
    if (energyToLufs(energy) >= kAbsoluteGateLufs &&
        energyToLufs(energy) >= relativeThreshold) {
      gatedEnergy += energy;
      ++gatedCount;
    }
  }
  if (gatedCount != 0) {
    result.integratedAvailable = true;
    result.integratedLufs = energyToLufs(gatedEnergy / static_cast<double>(gatedCount));
  }
  return result;
}

void LoudnessMeter::reset() noexcept {
  for (auto& filter : kWeighting_) filter.clear();
  energyRing_.fill(0.0);
  ringWrite_ = 0;
  ringCount_ = 0;
  framesSinceBlock_ = 0;
  rollingEnergy_ = 0.0;
  blockEnergies_.clear();
}

}  // namespace hwcontrol::audio
