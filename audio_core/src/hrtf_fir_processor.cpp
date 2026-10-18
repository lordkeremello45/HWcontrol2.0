#include "hwcontrol_audio/hrtf_fir_processor.hpp"
#include <algorithm>
#include <cmath>
namespace hwcontrol_audio {
namespace {
constexpr float kMaxImpulseResponseAbsoluteSum = 8.0F;
}
HrtfFirProcessor::HrtfFirProcessor(std::uint32_t sample_rate) noexcept {
  if (sample_rate >= kMinSampleRate && sample_rate <= kMaxSampleRate) sample_rate_ = sample_rate;
}
bool HrtfFirProcessor::validate_taps(const float* left_taps, const float* right_taps,
                                     std::size_t tap_count) noexcept {
  if (left_taps == nullptr || right_taps == nullptr || tap_count == 0 || tap_count > kMaxTaps) return false;
  float left_sum = 0.0F;
  float right_sum = 0.0F;
  for (std::size_t i = 0; i < tap_count; ++i) {
    if (!std::isfinite(left_taps[i]) || !std::isfinite(right_taps[i])) return false;
    left_sum += std::abs(left_taps[i]);
    right_sum += std::abs(right_taps[i]);
    if (!std::isfinite(left_sum) || !std::isfinite(right_sum) ||
        left_sum > kMaxImpulseResponseAbsoluteSum || right_sum > kMaxImpulseResponseAbsoluteSum) return false;
  }
  return true;
}
bool HrtfFirProcessor::configure(const float* left_taps, const float* right_taps,
                                 std::size_t tap_count) noexcept {
  if (!validate_taps(left_taps, right_taps, tap_count) ||
      pending_state_.load(std::memory_order_acquire) != 0) return false;
  left_taps_.fill(0.0F);
  right_taps_.fill(0.0F);
  std::copy_n(left_taps, tap_count, left_taps_.begin());
  std::copy_n(right_taps, tap_count, right_taps_.begin());
  tap_count_ = tap_count;
  previous_tap_count_ = 0;
  crossfade_remaining_ = 0;
  reset();
  return true;
}
bool HrtfFirProcessor::request_configuration(const float* left_taps, const float* right_taps,
                                             std::size_t tap_count) noexcept {
  if (!validate_taps(left_taps, right_taps, tap_count)) return false;
  std::array<float, kMaxTaps> validated_left{};
  std::array<float, kMaxTaps> validated_right{};
  std::copy_n(left_taps, tap_count, validated_left.begin());
  std::copy_n(right_taps, tap_count, validated_right.begin());
  std::uint8_t expected = 0;
  if (!pending_state_.compare_exchange_strong(expected, 1, std::memory_order_acquire,
                                               std::memory_order_relaxed)) return false;
  pending_left_taps_ = validated_left;
  pending_right_taps_ = validated_right;
  pending_tap_count_ = tap_count;
  pending_state_.store(2, std::memory_order_release);
  return true;
}
bool HrtfFirProcessor::set_sample_rate(std::uint32_t sample_rate) noexcept {
  if (sample_rate < kMinSampleRate || sample_rate > kMaxSampleRate ||
      pending_state_.load(std::memory_order_acquire) != 0) return false;
  sample_rate_ = sample_rate;
  reset();
  return true;
}
void HrtfFirProcessor::reset() noexcept {
  history_.fill(0.0F);
  write_cursor_ = 0;
  crossfade_remaining_ = 0;
  previous_tap_count_ = 0;
}
void HrtfFirProcessor::apply_pending_configuration() noexcept {
  std::uint8_t expected = 2;
  if (!pending_state_.compare_exchange_strong(expected, 3, std::memory_order_acquire,
                                               std::memory_order_relaxed)) return;
  previous_left_taps_ = left_taps_;
  previous_right_taps_ = right_taps_;
  previous_tap_count_ = tap_count_;
  left_taps_ = pending_left_taps_;
  right_taps_ = pending_right_taps_;
  tap_count_ = pending_tap_count_;
  crossfade_remaining_ = kProfileCrossfadeFrames;
  pending_state_.store(0, std::memory_order_release);
}
void HrtfFirProcessor::process(const float* input, float* output, std::size_t frames) noexcept {
  if (input == nullptr || output == nullptr || frames == 0) return;
  apply_pending_configuration();
  for (std::size_t frame = 0; frame < frames; ++frame) {
    float sample = input[frame];
    if (!std::isfinite(sample)) sample = 0.0F;
    sample = std::clamp(sample, -1.0F, 1.0F);
    history_[write_cursor_] = sample;
    double left = 0.0;
    double right = 0.0;
    double previous_left = 0.0;
    double previous_right = 0.0;
    std::size_t read_cursor = write_cursor_;
    for (std::size_t tap = 0; tap < tap_count_; ++tap) {
      const double delayed = static_cast<double>(history_[read_cursor]);
      left += delayed * static_cast<double>(left_taps_[tap]);
      right += delayed * static_cast<double>(right_taps_[tap]);
      read_cursor = read_cursor == 0 ? kMaxTaps - 1 : read_cursor - 1;
    }
    if (crossfade_remaining_ != 0) {
      read_cursor = write_cursor_;
      for (std::size_t tap = 0; tap < previous_tap_count_; ++tap) {
        const double delayed = static_cast<double>(history_[read_cursor]);
        previous_left += delayed * static_cast<double>(previous_left_taps_[tap]);
        previous_right += delayed * static_cast<double>(previous_right_taps_[tap]);
        read_cursor = read_cursor == 0 ? kMaxTaps - 1 : read_cursor - 1;
      }
      const double alpha = static_cast<double>(kProfileCrossfadeFrames - crossfade_remaining_ + 1U) /
                           static_cast<double>(kProfileCrossfadeFrames);
      left = previous_left + (left - previous_left) * alpha;
      right = previous_right + (right - previous_right) * alpha;
      --crossfade_remaining_;
    }
    const float out_left = static_cast<float>(left);
    const float out_right = static_cast<float>(right);
    output[frame * 2U] = std::isfinite(out_left) ? out_left : 0.0F;
    output[frame * 2U + 1U] = std::isfinite(out_right) ? out_right : 0.0F;
    write_cursor_ = (write_cursor_ + 1U) % kMaxTaps;
  }
}
}  // namespace hwcontrol_audio
