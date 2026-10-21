#pragma once
#include <array>
#include <cstddef>
#include <cstdint>
namespace hwcontrol_audio {
// Real-time-safe parametric binaural approximation, not a measured HRTF renderer.
struct SpatialAudioParams {
  float azimuth_degrees = 0.0F;   // -90 = left, 0 = front/center, +90 = right; rear/front disambiguation is not modeled
  float elevation_degrees = 0.0F; // Validated; elevation filter profiles are future work.
  float distance_meters = 1.0F;
  float wet_mix = 1.0F;
  bool enabled = true;
};
class SpatialAudioProcessor final {
 public:
  static constexpr std::uint32_t kMinSampleRate = 8000;
  static constexpr std::uint32_t kMaxSampleRate = 192000;
  static constexpr std::size_t kMaxInterauralDelaySamples = 128;
  explicit SpatialAudioProcessor(std::uint32_t sample_rate = 48000) noexcept;
  bool configure(const SpatialAudioParams& params) noexcept;
  bool set_sample_rate(std::uint32_t sample_rate) noexcept;
  void reset() noexcept;
  // mono_input: frame_count samples; stereo_output: frame_count * 2 interleaved L,R.
  // This function performs no allocation and takes no locks.
  void process(const float* mono_input, float* stereo_output, std::size_t frame_count) noexcept;
  const SpatialAudioParams& params() const noexcept { return params_; }
  std::uint32_t sample_rate() const noexcept { return sample_rate_; }
 private:
  float process_lowpass(float input, float coefficient, float& state) noexcept;
  static bool valid_params(const SpatialAudioParams& params) noexcept;
  SpatialAudioParams params_{};
  std::uint32_t sample_rate_ = 48000;
  std::array<float, kMaxInterauralDelaySamples> left_delay_{};
  std::array<float, kMaxInterauralDelaySamples> right_delay_{};
  std::size_t delay_cursor_ = 0;
  float left_filter_state_ = 0.0F;
  float right_filter_state_ = 0.0F;
};
}  // namespace hwcontrol_audio
