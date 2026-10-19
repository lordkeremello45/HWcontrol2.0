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
    return 0;
}
