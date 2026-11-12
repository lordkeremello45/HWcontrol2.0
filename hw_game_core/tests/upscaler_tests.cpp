#include "hw_game_core/upscaler.hpp"

#include <array>
#include <cassert>
#include <cstdint>

using hwcontrol::game::Rgba8ImageView;
using hwcontrol::game::UpscaleStatus;
using hwcontrol::game::upscale_bilinear_rgba8;

int main() {
    // A single pixel should scale to a solid image without changing its channels.
    const std::array<std::uint8_t, 4> pixel{12, 64, 128, 255};
    const auto solid = upscale_bilinear_rgba8({pixel.data(), 1, 1, 4}, 3, 2);
    assert(solid.status == UpscaleStatus::success);
    assert(solid.image.width == 3 && solid.image.height == 2);
    assert(solid.image.row_stride_bytes == 12);
    for (std::size_t i = 0; i < solid.image.pixels.size(); i += 4) {
        assert(solid.image.pixels[i] == 12);
        assert(solid.image.pixels[i + 1] == 64);
        assert(solid.image.pixels[i + 2] == 128);
        assert(solid.image.pixels[i + 3] == 255);
    }

    // Padded source rows are accepted and padding is not treated as pixels.
    const std::array<std::uint8_t, 12> padded{
        0, 0, 0, 255, 99, 99, 99, 99,
        255, 255, 255, 255
    };
    const auto scaled = upscale_bilinear_rgba8({padded.data(), 1, 2, 8}, 1, 4);
    assert(scaled.status == UpscaleStatus::success);
    assert(scaled.image.pixels.size() == 16);
    assert(scaled.image.pixels.front() == 0);
    assert(scaled.image.pixels.back() == 255);

    assert(upscale_bilinear_rgba8({nullptr, 1, 1, 4}, 2, 2).status ==
           UpscaleStatus::invalid_input);
    assert(upscale_bilinear_rgba8({pixel.data(), 1, 1, 3}, 2, 2).status ==
           UpscaleStatus::invalid_input);
    assert(upscale_bilinear_rgba8({pixel.data(), 2, 1, 8}, 1, 1).status ==
           UpscaleStatus::invalid_dimensions);
    assert(upscale_bilinear_rgba8({pixel.data(), 1, 1, 4}, 0, 2).status ==
           UpscaleStatus::invalid_input);

    return 0;
}
