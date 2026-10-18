#include "hwcontrol_audio/spatial_audio.hpp"
#include <algorithm>
#include <cmath>
namespace hwcontrol_audio {
namespace {
constexpr float kPi = 3.14159265358979323846F;
constexpr float kMinDistance = 0.25F;
constexpr float kMaxDistance = 50.0F;
constexpr float kMaxItdSeconds = 0.00065F;
constexpr float kMinSample = -1.0F;
constexpr float kMaxSample = 1.0F;
}
SpatialAudioProcessor::SpatialAudioProcessor(std::uint32_t sample_rate) noexcept {
  if (sample_rate >= kMinSampleRate && sample_rate <= kMaxSampleRate) sample_rate_ = sample_rate;
}
bool SpatialAudioProcessor::valid_params(const SpatialAudioParams& p) noexcept {
  return std::isfinite(p.azimuth_degrees) && std::isfinite(p.elevation_degrees) &&
    std::isfinite(p.distance_meters) && std::isfinite(p.wet_mix) &&
    p.azimuth_degrees >= -180.0F && p.azimuth_degrees <= 180.0F &&
    p.elevation_degrees >= -90.0F && p.elevation_degrees <= 90.0F &&
    p.distance_meters >= kMinDistance && p.distance_meters <= kMaxDistance &&
    p.wet_mix >= 0.0F && p.wet_mix <= 1.0F;
}
bool SpatialAudioProcessor::configure(const SpatialAudioParams& params) noexcept {
  if (!valid_params(params)) return false;
  params_ = params;
  return true;
}
bool SpatialAudioProcessor::set_sample_rate(std::uint32_t rate) noexcept {
  if (rate < kMinSampleRate || rate > kMaxSampleRate) return false;
  sample_rate_ = rate;
  reset();
  return true;
}
void SpatialAudioProcessor::reset() noexcept {
  left_delay_.fill(0.0F); right_delay_.fill(0.0F);
  delay_cursor_ = 0; left_filter_state_ = 0.0F; right_filter_state_ = 0.0F;
}
float SpatialAudioProcessor::process_lowpass(float input, float coefficient, float& state) noexcept {
  state += coefficient * (input - state);
  return state;
}
void SpatialAudioProcessor::process(const float* input, float* output, std::size_t frames) noexcept {
  if (input == nullptr || output == nullptr || frames == 0) return;
  const float azimuth = params_.azimuth_degrees * (kPi / 180.0F);
  const float side = std::sin(azimuth);
  const float left_gain = std::sqrt(std::max(0.0F, 0.5F * (1.0F - side)));
  const float right_gain = std::sqrt(std::max(0.0F, 0.5F * (1.0F + side)));
  const float distance_gain = 1.0F / (1.0F + 0.12F * (params_.distance_meters - 1.0F));
  const float shadow = 0.18F * std::abs(side);
  const float left_coefficient = std::max(0.035F, 0.72F - (side > 0.0F ? shadow : 0.0F));
  const float right_coefficient = std::max(0.035F, 0.72F - (side < 0.0F ? shadow : 0.0F));
  const auto delay = static_cast<std::size_t>(std::min<float>(
      static_cast<float>(kMaxInterauralDelaySamples - 1),
      static_cast<float>(sample_rate_) * kMaxItdSeconds * std::abs(side)));
  const bool delay_left = side > 0.0F;
  for (std::size_t i = 0; i < frames; ++i) {
    float sample = input[i];
    if (!std::isfinite(sample)) sample = 0.0F;
    sample = std::max(kMinSample, std::min(kMaxSample, sample));
    float left = process_lowpass(sample * left_gain, left_coefficient, left_filter_state_);
    float right = process_lowpass(sample * right_gain, right_coefficient, right_filter_state_);
    left_delay_[delay_cursor_] = left; right_delay_[delay_cursor_] = right;
    const std::size_t left_read = (delay_cursor_ + kMaxInterauralDelaySamples - (delay_left ? delay : 0U)) % kMaxInterauralDelaySamples;
    const std::size_t right_read = (delay_cursor_ + kMaxInterauralDelaySamples - (delay_left ? 0U : delay)) % kMaxInterauralDelaySamples;
    const float delayed_left = left_delay_[left_read];
    const float delayed_right = right_delay_[right_read];
    delay_cursor_ = (delay_cursor_ + 1U) % kMaxInterauralDelaySamples;
    const float dry = sample * 0.70710678F;
    float out_left = dry * (1.0F - params_.wet_mix) + delayed_left * distance_gain * params_.wet_mix;
    float out_right = dry * (1.0F - params_.wet_mix) + delayed_right * distance_gain * params_.wet_mix;
    if (!params_.enabled) { out_left = dry; out_right = dry; }
    if (!std::isfinite(out_left)) out_left = 0.0F;
    if (!std::isfinite(out_right)) out_right = 0.0F;
    output[i * 2U] = std::max(kMinSample, std::min(kMaxSample, out_left));
    output[i * 2U + 1U] = std::max(kMinSample, std::min(kMaxSample, out_right));
  }
}
}  // namespace hwcontrol_audio
