#include "hwvision/render_pipeline.hpp"

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <limits>

using namespace hwvision::render;
namespace {
int failures = 0;
void check(bool value, int line, const char* expression) {
  if (!value) { std::cerr << "FAIL line " << line << ": " << expression << '\n'; ++failures; }
}
#define CHECK(x) check((x), __LINE__, #x)
bool near(double a, double b, double tolerance = 1.0e-4) {
  return std::abs(a - b) <= tolerance;
}
}

int main() {
  CHECK(near(decode_transfer(0.0, TransferFunction::srgb, 100.0), 0.0));
  CHECK(near(encode_transfer(100.0, TransferFunction::srgb, 100.0), 1.0));
  CHECK(near(decode_transfer(1.0, TransferFunction::st2084_pq, 100.0), 10000.0, 0.1));
  CHECK(near(encode_transfer(10000.0, TransferFunction::st2084_pq, 100.0), 1.0));
  const double pq_mid = 0.508078;
  CHECK(near(decode_transfer(pq_mid, TransferFunction::st2084_pq, 100.0), 100.0, 0.5));
  CHECK(near(encode_transfer(100.0, TransferFunction::st2084_pq, 100.0), pq_mid, 0.001));

  RgbaImage input{2U, 1U, {1.0F, 0.0F, 0.0F, 0.25F, 0.0F, 1.0F, 0.0F, 0.75F}};
  RenderConfig config;
  config.source = {TransferFunction::srgb, ColorPrimaries::bt709, 100.0, 100.0};
  config.output = {TransferFunction::srgb, ColorPrimaries::bt709, 100.0, 100.0};
  config.target_peak_nits = 100.0;
  config.tone_map = ToneMapOperator::none;
  RgbaImage output;
  CHECK(process(input, config, output).ok());
  CHECK(output.width == 2U && output.height == 1U);
  CHECK(output.pixels.size() == input.pixels.size());
  CHECK(near(output.pixels[0], 1.0, 0.001));
  CHECK(near(output.pixels[5], 1.0, 0.001));
  CHECK(near(output.pixels[3], 0.25, 1.0e-6));
  CHECK(near(output.pixels[7], 0.75, 1.0e-6));

  config.output = {TransferFunction::st2084_pq, ColorPrimaries::bt2020, 100.0, 1000.0};
  config.target_peak_nits = 1000.0;
  CHECK(process(input, config, output).ok());
  CHECK(std::isfinite(output.pixels[0]));
  CHECK(output.pixels[0] >= 0.0F && output.pixels[0] <= 1.0F);

  // A source highlight above the output target is compressed without a hard knee.
  RgbaImage highlight{1U, 1U, {1.0F, 1.0F, 1.0F, 1.0F}};
  config.source = {TransferFunction::linear, ColorPrimaries::bt709, 1000.0, 1000.0};
  config.output = {TransferFunction::linear, ColorPrimaries::bt709, 100.0, 100.0};
  config.target_peak_nits = 100.0;
  config.tone_map = ToneMapOperator::exponential_shoulder;
  CHECK(process(highlight, config, output).ok());
  CHECK(output.pixels[0] <= 1.0F);
  CHECK(output.pixels[0] > 0.75F);

  RgbaImage malformed{1U, 1U, {1.0F, 0.0F, 0.0F}};
  CHECK(process(malformed, config, output).error == RenderError::invalid_buffer_size);
  malformed = {1U, 1U, {1.0F, 0.0F, 0.0F, 1.0F}};
  malformed.pixels[0] = std::numeric_limits<float>::quiet_NaN();
  CHECK(process(malformed, config, output).error == RenderError::non_finite_pixel);
  malformed.pixels[0] = 1.0F;
  config.target_peak_nits = std::numeric_limits<double>::infinity();
  CHECK(process(malformed, config, output).error == RenderError::invalid_config);

  CHECK(quantize_u8(0.0, 0U, 0U, false) == 0U);
  CHECK(quantize_u8(1.0, 0U, 0U, false) == 255U);
  CHECK(quantize_u8(-1.0, 0U, 0U, false) == 0U);
  CHECK(quantize_u8(2.0, 0U, 0U, false) == 255U);
  CHECK(quantize_u8(0.5, 0U, 0U, true) != quantize_u8(0.5, 1U, 0U, true));

  return failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
