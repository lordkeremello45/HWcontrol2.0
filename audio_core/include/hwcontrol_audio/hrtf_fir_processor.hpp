#pragma once
#include <array>
#include <cstddef>
#include <cstdint>
namespace hwcontrol_audio {
class HrtfFirProcessor final {
 public:
  static constexpr std::size_t kMaxTaps = 256;
  static constexpr std::uint32_t kMinSampleRate = 8000;
  static constexpr std::uint32_t kMaxSampleRate = 192000;
  explicit HrtfFirProcessor(std::uint32_t sample_rate = 48000) noexcept;
  // Configure only while processing is stopped; never concurrently with process().
  // Rejects empty/oversized, non-finite, or excessively high-gain impulse responses.
  bool configure(const float* left_taps, const float* right_taps, std::size_t tap_count) noexcept;
  bool set_sample_rate(std::uint32_t sample_rate) noexcept;
  void reset() noexcept;
  // Mono input; interleaved stereo output. Fixed memory, no allocation or locks in process().
  void process(const float* mono_input, float* stereo_output, std::size_t frame_count) noexcept;
  std::size_t tap_count() const noexcept { return tap_count_; }
  std::uint32_t sample_rate() const noexcept { return sample_rate_; }
 private:
  std::array<float, kMaxTaps> left_taps_{};
  std::array<float, kMaxTaps> right_taps_{};
  std::array<float, kMaxTaps> history_{};
  std::size_t tap_count_ = 0;
  std::size_t write_cursor_ = 0;
  std::uint32_t sample_rate_ = 48000;
};
}  // namespace hwcontrol_audio
