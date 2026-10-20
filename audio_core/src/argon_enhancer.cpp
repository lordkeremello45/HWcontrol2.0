#include "hwcontrol_audio/argon_enhancer.hpp"

#include <algorithm>
#include <cmath>
#include <limits>

namespace hwcontrol::audio {
namespace {
constexpr float kPi = 3.14159265358979323846F;
constexpr float kBassCutoffHz = 180.0F;
constexpr float kTrebleCutoffHz = 3000.0F;

bool finite(float value) noexcept { return std::isfinite(value); }

float soft_limit(float sample, float threshold) noexcept {
    const float magnitude = std::fabs(sample);
    if (magnitude <= threshold) return sample;
    const float span = 1.0F - threshold;
    if (span <= std::numeric_limits<float>::epsilon()) {
        return std::copysign(threshold, sample);
    }
    const float normalized = (magnitude - threshold) / span;
    const float shaped = threshold + span * std::tanh(normalized) / std::tanh(1.0F);
    return std::copysign(std::min(shaped, 1.0F), sample);
}
}  // namespace

ArgonEnhancer::ArgonEnhancer(std::uint32_t sample_rate) noexcept
    : sample_rate_(sample_rate == 0 ? 48000 : sample_rate),
      low_alpha_(1.0F - std::exp(-2.0F * kPi * kBassCutoffHz /
                                  static_cast<float>(sample_rate_))),
      high_alpha_(std::exp(-2.0F * kPi * kTrebleCutoffHz /
                           static_cast<float>(sample_rate_))) {}

ProcessStatus ArgonEnhancer::set_settings(const EnhancementSettings& settings) noexcept {
    if (!finite(settings.output_gain) || !finite(settings.bass_gain) ||
        !finite(settings.treble_gain) || !finite(settings.limiter_threshold)) {
        return ProcessStatus::invalid_configuration;
    }
    if (settings.output_gain < 0.0F || settings.output_gain > 4.0F ||
        settings.bass_gain < 0.0F || settings.bass_gain > 4.0F ||
        settings.treble_gain < 0.0F || settings.treble_gain > 4.0F ||
        settings.limiter_threshold < 0.1F || settings.limiter_threshold > 1.0F) {
        return ProcessStatus::invalid_configuration;
    }
    settings_ = settings;
    return ProcessStatus::success;
}

void ArgonEnhancer::reset() noexcept {
    channels_[0] = {};
    channels_[1] = {};
}

ProcessStatus ArgonEnhancer::process_stereo(float* interleaved,
                                             std::size_t frames) noexcept {
    if (frames != 0 && interleaved == nullptr) return ProcessStatus::invalid_input;
    if (!settings_.enabled || frames == 0) return ProcessStatus::success;

    for (std::size_t frame = 0; frame < frames; ++frame) {
        for (std::size_t channel = 0; channel < 2; ++channel) {
            const std::size_t index = frame * 2 + channel;
            const float input = interleaved[index];
            if (!finite(input)) {
                interleaved[index] = 0.0F;
                continue;
            }

            auto& state = channels_[channel];
            state.low += low_alpha_ * (input - state.low);
            const float high = high_alpha_ *
                (state.high_previous_output + input - state.high_previous_input);
            state.high_previous_input = input;
            state.high_previous_output = high;

            float output = input +
                (settings_.bass_gain - 1.0F) * state.low +
                (settings_.treble_gain - 1.0F) * high;
            output *= settings_.output_gain;
            if (!finite(output)) output = 0.0F;
            output = soft_limit(output, settings_.limiter_threshold);
            interleaved[index] = std::clamp(output, -1.0F, 1.0F);
        }
    }
    return ProcessStatus::success;
}

}  // namespace hwcontrol::audio
