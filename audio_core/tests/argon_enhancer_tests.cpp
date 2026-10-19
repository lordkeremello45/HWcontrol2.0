#include "hwcontrol_audio/argon_enhancer.hpp"

#include <array>
#include <cassert>
#include <cmath>
#include <limits>

using hwcontrol::audio::ArgonEnhancer;
using hwcontrol::audio::EnhancementSettings;
using hwcontrol::audio::ProcessStatus;

int main() {
    ArgonEnhancer enhancer(48000);
    std::array<float, 8> samples{0.1F, -0.1F, 0.2F, -0.2F, 0.4F, -0.4F, 0.8F, -0.8F};

    EnhancementSettings unity;
    assert(enhancer.set_settings(unity) == ProcessStatus::success);
    assert(enhancer.process_stereo(samples.data(), 4) == ProcessStatus::success);
    for (float sample : samples) {
        assert(std::isfinite(sample));
        assert(sample >= -1.0F && sample <= 1.0F);
    }

    EnhancementSettings invalid;
    invalid.output_gain = std::numeric_limits<float>::quiet_NaN();
    assert(enhancer.set_settings(invalid) == ProcessStatus::invalid_configuration);
    invalid = {};
    invalid.bass_gain = 8.0F;
    assert(enhancer.set_settings(invalid) == ProcessStatus::invalid_configuration);
    assert(enhancer.process_stereo(nullptr, 1) == ProcessStatus::invalid_input);
    assert(enhancer.process_stereo(nullptr, 0) == ProcessStatus::success);

    EnhancementSettings boosted;
    boosted.output_gain = 4.0F;
    assert(enhancer.set_settings(boosted) == ProcessStatus::success);
    std::array<float, 4> loud{0.7F, -0.7F, 1.0F, -1.0F};
    assert(enhancer.process_stereo(loud.data(), 2) == ProcessStatus::success);
    for (float sample : loud) {
        assert(std::isfinite(sample));
        assert(sample >= -1.0F && sample <= 1.0F);
    }

    enhancer.reset();

    // Disabled enhancement must be a transparent pass-through, including
    // full-scale samples, so existing audio paths can opt out safely.
    EnhancementSettings bypass;
    bypass.enabled = false;
    assert(enhancer.set_settings(bypass) == ProcessStatus::success);
    std::array<float, 6> bypassSamples{0.99F, -0.99F, 0.25F, -0.25F, 1.0F, -1.0F};
    const auto original = bypassSamples;
    assert(enhancer.process_stereo(bypassSamples.data(), 3) == ProcessStatus::success);
    assert(bypassSamples == original);

    // Enabling non-unity output gain must measurably affect ordinary samples.
    EnhancementSettings gain;
    gain.output_gain = 0.5F;
    assert(enhancer.set_settings(gain) == ProcessStatus::success);
    std::array<float, 2> gainSamples{0.2F, -0.2F};
    assert(enhancer.process_stereo(gainSamples.data(), 1) == ProcessStatus::success);
    assert(std::abs(gainSamples[0] - 0.1F) < 0.01F);
    assert(std::abs(gainSamples[1] + 0.1F) < 0.01F);

    enhancer.reset();
    return 0;
}
