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
bool HrtfFirProcessor::configure(const float* left_taps, const float* right_taps,
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
  left_taps_.fill(0.0F);
  right_taps_.fill(0.0F);
  std::copy_n(left_taps, tap_count, left_taps_.begin());
  std::copy_n(right_taps, tap_count, right_taps_.begin());
  tap_count_ = tap_count;
  reset();
  return true;
}
bool HrtfFirProcessor::set_sample_rate(std::uint32_t sample_rate) noexcept {
  if (sample_rate < kMinSampleRate || sample_rate > kMaxSampleRate) return false;
  sample_rate_ = sample_rate;
  reset();
  return true;
}
void HrtfFirProcessor::reset() noexcept {
  history_.fill(0.0F);
  write_cursor_ = 0;
}
void HrtfFirProcessor::process(const float* input, float* output, std::size_t frames) noexcept {
  if (input == nullptr || output == nullptr || frames == 0) return;
  for (std::size_t frame = 0; frame < frames; ++frame) {
    float sample = input[frame];
    if (!std::isfinite(sample)) sample = 0.0F;
    sample = std::clamp(sample, -1.0F, 1.0F);
    history_[write_cursor_] = sample;
    double left = 0.0;
    double right = 0.0;
    std::size_t read_cursor = write_cursor_;
    for (std::size_t tap = 0; tap < tap_count_; ++tap) {
      const double delayed = static_cast<double>(history_[read_cursor]);
      left += delayed * static_cast<double>(left_taps_[tap]);
      right += delayed * static_cast<double>(right_taps_[tap]);
      read_cursor = read_cursor == 0 ? kMaxTaps - 1 : read_cursor - 1;
    }
    const float out_left = static_cast<float>(left);
    const float out_right = static_cast<float>(right);
    output[frame * 2U] = std::isfinite(out_left) ? out_left : 0.0F;
    output[frame * 2U + 1U] = std::isfinite(out_right) ? out_right : 0.0F;
    write_cursor_ = (write_cursor_ + 1U) % kMaxTaps;
  }
}
}  // namespace hwcontrol_audio
