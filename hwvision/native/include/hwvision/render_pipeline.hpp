#pragma once

#include <cstddef>
#include <cstdint>
#include <vector>

namespace hwvision::render {

enum class TransferFunction : std::uint8_t { srgb, bt709, st2084_pq, linear };
enum class ColorPrimaries : std::uint8_t { bt709, bt2020 };
enum class ToneMapOperator : std::uint8_t { none, reinhard };

struct ColorDescription {
  TransferFunction transfer = TransferFunction::srgb;
  ColorPrimaries primaries = ColorPrimaries::bt709;
  double reference_white_nits = 100.0;
  double mastering_peak_nits = 100.0;
};

struct RenderConfig {
  ColorDescription source{};
  ColorDescription output{};
  ToneMapOperator tone_map = ToneMapOperator::reinhard;
  double target_peak_nits = 100.0;
  bool clamp_output_gamut = true;
};

struct RgbaImage {
  std::uint32_t width = 0;
  std::uint32_t height = 0;
  std::vector<float> pixels;
};

enum class RenderError : std::uint8_t {
  none,
  invalid_dimensions,
  invalid_buffer_size,
  invalid_config,
  non_finite_pixel
};

struct RenderResult {
  RenderError error = RenderError::none;
  [[nodiscard]] bool ok() const noexcept { return error == RenderError::none; }
};

// CPU reference pipeline. RGB input/output is interleaved, alpha is preserved.
// PQ values are decoded to absolute nits; SDR values use reference_white_nits.
[[nodiscard]] RenderResult process(const RgbaImage& source,
                                   const RenderConfig& config,
                                   RgbaImage& destination) noexcept;

// Transfer helpers are public to support independent conformance tests.
[[nodiscard]] double decode_transfer(double value, TransferFunction transfer,
                                     double reference_white_nits) noexcept;
[[nodiscard]] double encode_transfer(double nits, TransferFunction transfer,
                                     double reference_white_nits) noexcept;

// Deterministic 8-bit quantizer with optional ordered 4x4 Bayer dithering.
[[nodiscard]] std::uint8_t quantize_u8(double value, std::uint32_t x,
                                       std::uint32_t y, bool dither) noexcept;

}  // namespace hwvision::render
