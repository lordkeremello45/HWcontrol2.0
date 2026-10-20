#pragma once

#include <cstddef>
#include <cstdint>

namespace hwcontrol::audio {

struct EnhancementSettings {
    float output_gain = 1.0F;
    float bass_gain = 1.0F;
    float treble_gain = 1.0F;
    float limiter_threshold = 0.98F;
    bool enabled = true;
};

enum class ProcessStatus {
    success,
    invalid_input,
    invalid_configuration
};

// Allocation-free, stateful stereo DSP reference processor.
// The caller owns the audio device/stream and supplies interleaved float PCM
// normalized to [-1, 1]. This is an audio effect engine, not an OS driver.
class ArgonEnhancer final {
public:
    explicit ArgonEnhancer(std::uint32_t sample_rate = 48000) noexcept;

    ProcessStatus set_settings(const EnhancementSettings& settings) noexcept;
    void reset() noexcept;

    // Processes frames in-place: [L, R, L, R, ...]. No allocation or locking.
    ProcessStatus process_stereo(float* interleaved, std::size_t frames) noexcept;

private:
    struct ChannelState {
        float low = 0.0F;
        float high_previous_input = 0.0F;
        float high_previous_output = 0.0F;
    };

    std::uint32_t sample_rate_;
    EnhancementSettings settings_{};
    ChannelState channels_[2]{};
    float low_alpha_;
    float high_alpha_;
};

}  // namespace hwcontrol::audio
