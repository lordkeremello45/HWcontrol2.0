#pragma once

#include <cstddef>
#include <cstdint>
#include <vector>

namespace hwcontrol::game {

struct Rgba8ImageView {
    const std::uint8_t* pixels = nullptr;
    std::uint32_t width = 0;
    std::uint32_t height = 0;
    std::size_t row_stride_bytes = 0;
};

struct Rgba8Image {
    std::uint32_t width = 0;
    std::uint32_t height = 0;
    std::size_t row_stride_bytes = 0;
    std::vector<std::uint8_t> pixels;
};

enum class UpscaleStatus {
    success,
    invalid_input,
    invalid_dimensions,
    size_overflow
};

struct UpscaleResult {
    UpscaleStatus status = UpscaleStatus::invalid_input;
    Rgba8Image image;

    explicit operator bool() const noexcept { return status == UpscaleStatus::success; }
};

// Deterministic CPU reference path for validating the HW Game Core image contract.
// This is spatial bilinear scaling, not a temporal/AI upscaler and not a claim of
// FSR/DLSS-equivalent quality. RGBA8 alpha is interpolated like the color channels.
UpscaleResult upscale_bilinear_rgba8(Rgba8ImageView source,
                                     std::uint32_t output_width,
                                     std::uint32_t output_height);

}  // namespace hwcontrol::game
