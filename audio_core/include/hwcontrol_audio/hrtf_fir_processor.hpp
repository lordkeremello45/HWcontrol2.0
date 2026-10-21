#pragma once
#include <array>
#include <atomic>
#include <cstddef>
#include <cstdint>
namespace hwcontrol_audio {
class HrtfFirProcessor final {
 public:
  static constexpr std::size_t kMaxTaps = 256;
  static constexpr std::size_t kProfileCrossfadeFrames = 128;
  static constexpr std::uint32_t kMinSampleRate = 8000;
  static constexpr std::uint32_t kMaxSampleRate = 192000;
  explicit HrtfFirProcessor(std::uint32_t sample_rate = 48000) noexcept;
  // Configure only while processing is stopped; never concurrently with process().
  bool configure(const float* left_taps, const float* right_taps, std::size_t tap_count) noexcept;
  // Single control-thread producer: stages a validated HRIR update for the next
  // process() block. Returns false if another update is pending or taps are invalid.
  // The audio thread consumes it without locking and crossfades over 128 frames.
  bool request_configuration(const float* left_taps, const float* right_taps,
                             std::size_t tap_count) noexcept;
  bool set_sample_rate(std::uint32_t sample_rate) noexcept;
  void reset() noexcept;
  // Mono input; interleaved stereo output. Fixed memory, no allocation or locks in process().
  void process(const float* mono_input, float* stereo_output, std::size_t frame_count) noexcept;
  std::size_t tap_count() const noexcept { return tap_count_; }
  std::uint32_t sample_rate() const noexcept { return sample_rate_; }
 private:
  static bool validate_taps(const float* left_taps, const float* right_taps,
                            std::size_t tap_count) noexcept;
  void apply_pending_configuration() noexcept;
  std::array<float, kMaxTaps> left_taps_{};
  std::array<float, kMaxTaps> right_taps_{};
  std::array<float, kMaxTaps> previous_left_taps_{};
  std::array<float, kMaxTaps> previous_right_taps_{};
  std::array<float, kMaxTaps> pending_left_taps_{};
  std::array<float, kMaxTaps> pending_right_taps_{};
  std::array<float, kMaxTaps> history_{};
  std::size_t tap_count_ = 0;
  std::size_t previous_tap_count_ = 0;
  std::size_t pending_tap_count_ = 0;
  std::size_t crossfade_remaining_ = 0;
  std::size_t write_cursor_ = 0;
  std::uint32_t sample_rate_ = 48000;
  // 0=idle, 1=writer filling slot, 2=ready, 3=audio thread consuming slot.
  std::atomic<std::uint8_t> pending_state_{0};
};
}  // namespace hwcontrol_audio
