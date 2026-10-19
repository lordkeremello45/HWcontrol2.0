#include "hw_game_core/upscaler.hpp"

#include <algorithm>
#include <cmath>
#include <limits>

namespace hwcontrol::game {
namespace {

bool multiply_overflows(std::size_t a, std::size_t b) noexcept {
    return b != 0 && a > std::numeric_limits<std::size_t>::max() / b;
}

std::uint8_t interpolate_channel(std::uint8_t top_left,
                                 std::uint8_t top_right,
                                 std::uint8_t bottom_left,
                                 std::uint8_t bottom_right,
                                 float horizontal,
                                 float vertical) noexcept {
    const float top = static_cast<float>(top_left) +
        (static_cast<float>(top_right) - static_cast<float>(top_left)) * horizontal;
    const float bottom = static_cast<float>(bottom_left) +
        (static_cast<float>(bottom_right) - static_cast<float>(bottom_left)) * horizontal;
    const float value = top + (bottom - top) * vertical;
    return static_cast<std::uint8_t>(std::clamp(value + 0.5F, 0.0F, 255.0F));
}

}  // namespace

UpscaleResult upscale_bilinear_rgba8(Rgba8ImageView source,
                                     std::uint32_t output_width,
                                     std::uint32_t output_height) {
    UpscaleResult result;
    if (source.pixels == nullptr || source.width == 0 || source.height == 0 ||
        output_width == 0 || output_height == 0) {
        result.status = UpscaleStatus::invalid_input;
        return result;
    }

    if (output_width < source.width || output_height < source.height) {
        result.status = UpscaleStatus::invalid_dimensions;
        return result;
    }

    constexpr std::size_t channels = 4;
    const auto source_row_bytes = static_cast<std::size_t>(source.width);
    if (multiply_overflows(source_row_bytes, channels)) {
        result.status = UpscaleStatus::size_overflow;
        return result;
    }
    const std::size_t minimum_source_stride = source_row_bytes * channels;
    if (source.row_stride_bytes < minimum_source_stride ||
        multiply_overflows(static_cast<std::size_t>(source.height - 1),
                           source.row_stride_bytes) ||
        static_cast<std::size_t>(source.height - 1) * source.row_stride_bytes >
            std::numeric_limits<std::size_t>::max() - minimum_source_stride) {
        result.status = UpscaleStatus::invalid_input;
        return result;
    }

    const std::size_t output_row_bytes = static_cast<std::size_t>(output_width) * channels;
    if (multiply_overflows(static_cast<std::size_t>(output_width), channels) ||
        multiply_overflows(output_row_bytes, static_cast<std::size_t>(output_height))) {
        result.status = UpscaleStatus::size_overflow;
        return result;
    }

    result.image.width = output_width;
    result.image.height = output_height;
    result.image.row_stride_bytes = output_row_bytes;
    result.image.pixels.resize(output_row_bytes * static_cast<std::size_t>(output_height));

    const float x_scale = static_cast<float>(source.width) / static_cast<float>(output_width);
    const float y_scale = static_cast<float>(source.height) / static_cast<float>(output_height);

    for (std::uint32_t y = 0; y < output_height; ++y) {
        const float source_y = std::clamp((static_cast<float>(y) + 0.5F) * y_scale - 0.5F,
                                          0.0F, static_cast<float>(source.height - 1));
        const auto y0 = static_cast<std::uint32_t>(source_y);
        const auto y1 = std::min(y0 + 1, source.height - 1);
        const float fy = source_y - static_cast<float>(y0);

        for (std::uint32_t x = 0; x < output_width; ++x) {
            const float source_x = std::clamp((static_cast<float>(x) + 0.5F) * x_scale - 0.5F,
                                              0.0F, static_cast<float>(source.width - 1));
            const auto x0 = static_cast<std::uint32_t>(source_x);
            const auto x1 = std::min(x0 + 1, source.width - 1);
            const float fx = source_x - static_cast<float>(x0);

            const std::size_t p00 = static_cast<std::size_t>(y0) * source.row_stride_bytes +
                                    static_cast<std::size_t>(x0) * channels;
            const std::size_t p10 = static_cast<std::size_t>(y0) * source.row_stride_bytes +
                                    static_cast<std::size_t>(x1) * channels;
            const std::size_t p01 = static_cast<std::size_t>(y1) * source.row_stride_bytes +
                                    static_cast<std::size_t>(x0) * channels;
            const std::size_t p11 = static_cast<std::size_t>(y1) * source.row_stride_bytes +
                                    static_cast<std::size_t>(x1) * channels;
            const std::size_t destination = static_cast<std::size_t>(y) * output_row_bytes +
                                            static_cast<std::size_t>(x) * channels;
            for (std::size_t c = 0; c < channels; ++c) {
                result.image.pixels[destination + c] = interpolate_channel(
                    source.pixels[p00 + c], source.pixels[p10 + c],
                    source.pixels[p01 + c], source.pixels[p11 + c], fx, fy);
            }
        }
    }

    result.status = UpscaleStatus::success;
    return result;
}

}  // namespace hwcontrol::game
