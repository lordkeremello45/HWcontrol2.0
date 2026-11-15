#include "hwvision/render_pipeline.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <limits>
#include <utility>

namespace hwvision::render {
namespace {
constexpr double kPqM1 = 2610.0 / 16384.0;
constexpr double kPqM2 = 2523.0 / 32.0;
constexpr double kPqC1 = 3424.0 / 4096.0;
constexpr double kPqC2 = 2413.0 / 128.0;
constexpr double kPqC3 = 2392.0 / 128.0;
constexpr double kMaxPqNits = 10000.0;
constexpr double kEpsilon = 1.0e-9;

struct Vec3 { double r; double g; double b; };

Vec3 multiply(const std::array<std::array<double, 3>, 3>& m, Vec3 v) noexcept {
  return {
    m[0][0] * v.r + m[0][1] * v.g + m[0][2] * v.b,
    m[1][0] * v.r + m[1][1] * v.g + m[1][2] * v.b,
    m[2][0] * v.r + m[2][1] * v.g + m[2][2] * v.b
  };
}

constexpr std::array<std::array<double, 3>, 3> kBt709ToXyz{{
  {{0.4123907993, 0.3575843394, 0.1804807884}},
  {{0.2126390059, 0.7151686788, 0.0721923154}},
  {{0.0193308187, 0.1191947798, 0.9505321522}}
}};
constexpr std::array<std::array<double, 3>, 3> kXyzToBt709{{
  {{3.2409699419, -1.5373831776, -0.4986107603}},
  {{-0.9692436363, 1.8759675015, 0.0415550574}},
  {{0.0556300797, -0.2039769589, 1.0569715142}}
}};
constexpr std::array<std::array<double, 3>, 3> kBt2020ToXyz{{
  {{0.6369580483, 0.1446169036, 0.1688809752}},
  {{0.2627002120, 0.6779980715, 0.0593017165}},
  {{0.0000000000, 0.0280726930, 1.0609850577}}
}};
constexpr std::array<std::array<double, 3>, 3> kXyzToBt2020{{
  {{1.7166511880, -0.3556707838, -0.2533662814}},
  {{-0.6666843518, 1.6164812366, 0.0157685458}},
  {{0.0176398574, -0.0427706133, 0.9421031212}}
}};

bool valid_description(const ColorDescription& d) noexcept {
  return std::isfinite(d.reference_white_nits) && d.reference_white_nits > 0.0 &&
         d.reference_white_nits <= kMaxPqNits &&
         std::isfinite(d.mastering_peak_nits) && d.mastering_peak_nits > 0.0 &&
         d.mastering_peak_nits <= kMaxPqNits;
}

Vec3 to_xyz(Vec3 rgb, ColorPrimaries primaries) noexcept {
  return primaries == ColorPrimaries::bt2020
      ? multiply(kBt2020ToXyz, rgb) : multiply(kBt709ToXyz, rgb);
}
Vec3 from_xyz(Vec3 xyz, ColorPrimaries primaries) noexcept {
  return primaries == ColorPrimaries::bt2020
      ? multiply(kXyzToBt2020, xyz) : multiply(kXyzToBt709, xyz);
}

double tone_map_luminance(double luminance_nits, double target_peak_nits) noexcept {
  if (luminance_nits <= 0.0) return 0.0;
  const double knee = target_peak_nits * 0.75;
  if (luminance_nits <= knee) return luminance_nits;
  const double shoulder = target_peak_nits - knee;
  return knee + shoulder *
      (1.0 - std::exp(-(luminance_nits - knee) / shoulder));
}
}  // namespace

double decode_transfer(double value, TransferFunction transfer,
                       double reference_white_nits) noexcept {
  if (!std::isfinite(value) || !std::isfinite(reference_white_nits) ||
      reference_white_nits <= 0.0) return 0.0;
  const double v = std::max(0.0, value);
  switch (transfer) {
    case TransferFunction::linear:
      return v * reference_white_nits;
    case TransferFunction::srgb:
      return (v <= 0.04045 ? v / 12.92
                           : std::pow((v + 0.055) / 1.055, 2.4)) * reference_white_nits;
    case TransferFunction::bt709:
      return (v < 0.081 ? v / 4.5
                        : std::pow((v + 0.099) / 1.099, 1.0 / 0.45)) * reference_white_nits;
    case TransferFunction::st2084_pq: {
      const double p = std::pow(std::min(v, 1.0), 1.0 / kPqM2);
      const double numerator = std::max(p - kPqC1, 0.0);
      const double denominator = kPqC2 - kPqC3 * p;
      if (denominator <= kEpsilon) return kMaxPqNits;
      return kMaxPqNits * std::pow(numerator / denominator, 1.0 / kPqM1);
    }
  }
  return 0.0;
}

double encode_transfer(double nits, TransferFunction transfer,
                       double reference_white_nits) noexcept {
  if (!std::isfinite(nits) || !std::isfinite(reference_white_nits) ||
      reference_white_nits <= 0.0) return 0.0;
  const double v = std::max(0.0, nits);
  switch (transfer) {
    case TransferFunction::linear:
      return v / reference_white_nits;
    case TransferFunction::srgb: {
      const double linear = v / reference_white_nits;
      return linear <= 0.0031308 ? 12.92 * linear
                                : 1.055 * std::pow(linear, 1.0 / 2.4) - 0.055;
    }
    case TransferFunction::bt709: {
      const double linear = v / reference_white_nits;
      return linear < 0.018 ? 4.5 * linear
                            : 1.099 * std::pow(linear, 0.45) - 0.099;
    }
    case TransferFunction::st2084_pq: {
      const double l = std::pow(std::min(v / kMaxPqNits, 1.0), kPqM1);
      return std::pow((kPqC1 + kPqC2 * l) / (1.0 + kPqC3 * l), kPqM2);
    }
  }
  return 0.0;
}

std::uint8_t quantize_u8(double value, std::uint32_t x, std::uint32_t y,
                         bool dither) noexcept {
  if (!std::isfinite(value)) return 0U;
  constexpr std::array<std::array<int, 4>, 4> bayer{{
    {{0, 8, 2, 10}}, {{12, 4, 14, 6}}, {{3, 11, 1, 9}}, {{15, 7, 13, 5}}
  }};
  double adjusted = value;
  if (dither) {
    const auto xi = static_cast<std::size_t>(x % 4U);
    const auto yi = static_cast<std::size_t>(y % 4U);
    adjusted += (static_cast<double>(bayer[yi][xi]) - 7.5) / (16.0 * 255.0);
  }
  const double bounded = std::clamp(adjusted, 0.0, 1.0);
  return static_cast<std::uint8_t>(std::lround(bounded * 255.0));
}

RenderResult process(const RgbaImage& source, const RenderConfig& config,
                     RgbaImage& destination) {
  if (source.width == 0U || source.height == 0U) return {RenderError::invalid_dimensions};
  const std::size_t width = static_cast<std::size_t>(source.width);
  const std::size_t height = static_cast<std::size_t>(source.height);
  if (height > std::numeric_limits<std::size_t>::max() / width ||
      width * height > std::numeric_limits<std::size_t>::max() / 4U ||
      source.pixels.size() != width * height * 4U) {
    return {RenderError::invalid_buffer_size};
  }
  if (!valid_description(config.source) || !valid_description(config.output) ||
      !std::isfinite(config.target_peak_nits) || config.target_peak_nits <= 0.0 ||
      config.target_peak_nits > kMaxPqNits ||
      config.target_peak_nits > config.output.mastering_peak_nits ||
      static_cast<unsigned int>(config.source.transfer) > static_cast<unsigned int>(TransferFunction::linear) ||
      static_cast<unsigned int>(config.output.transfer) > static_cast<unsigned int>(TransferFunction::linear) ||
      static_cast<unsigned int>(config.source.primaries) > static_cast<unsigned int>(ColorPrimaries::bt2020) ||
      static_cast<unsigned int>(config.output.primaries) > static_cast<unsigned int>(ColorPrimaries::bt2020) ||
      static_cast<unsigned int>(config.tone_map) > static_cast<unsigned int>(ToneMapOperator::exponential_shoulder)) {
    return {RenderError::invalid_config};
  }

  RgbaImage result;
  result.width = source.width;
  result.height = source.height;
  result.pixels.resize(source.pixels.size());
  for (std::size_t pixel = 0U; pixel < width * height; ++pixel) {
    const std::size_t offset = pixel * 4U;
    for (std::size_t channel = 0U; channel < 4U; ++channel) {
      if (!std::isfinite(source.pixels[offset + channel])) {
        return {RenderError::non_finite_pixel};
      }
    }
    Vec3 rgb{
      decode_transfer(static_cast<double>(source.pixels[offset]), config.source.transfer,
                      config.source.reference_white_nits),
      decode_transfer(static_cast<double>(source.pixels[offset + 1U]), config.source.transfer,
                      config.source.reference_white_nits),
      decode_transfer(static_cast<double>(source.pixels[offset + 2U]), config.source.transfer,
                      config.source.reference_white_nits)
    };
    Vec3 xyz = to_xyz(rgb, config.source.primaries);
    const double luminance = std::max(0.0, xyz.g);
    if (config.tone_map == ToneMapOperator::exponential_shoulder) {
      const double mapped = tone_map_luminance(luminance, config.target_peak_nits);
      const double scale = mapped / std::max(luminance, kEpsilon);
      xyz.r *= scale;
      xyz.g *= scale;
      xyz.b *= scale;
    }
    Vec3 output_rgb = from_xyz(xyz, config.output.primaries);
    if (config.clamp_output_gamut) {
      output_rgb.r = std::clamp(output_rgb.r, 0.0, config.target_peak_nits);
      output_rgb.g = std::clamp(output_rgb.g, 0.0, config.target_peak_nits);
      output_rgb.b = std::clamp(output_rgb.b, 0.0, config.target_peak_nits);
    }
    result.pixels[offset] = static_cast<float>(encode_transfer(
        output_rgb.r, config.output.transfer, config.output.reference_white_nits));
    result.pixels[offset + 1U] = static_cast<float>(encode_transfer(
        output_rgb.g, config.output.transfer, config.output.reference_white_nits));
    result.pixels[offset + 2U] = static_cast<float>(encode_transfer(
        output_rgb.b, config.output.transfer, config.output.reference_white_nits));
    result.pixels[offset + 3U] = source.pixels[offset + 3U];
  }
  destination = std::move(result);
  return {};
}

}  // namespace hwvision::render
