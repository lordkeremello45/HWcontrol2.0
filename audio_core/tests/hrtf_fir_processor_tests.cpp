#include "hwcontrol_audio/hrtf_fir_processor.hpp"
#include <array>
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <limits>
namespace {
void require(bool ok, const char* message) {
  if (!ok) { std::cerr << "FAIL: " << message << '\n'; std::exit(1); }
}
}
int main() {
  using hwcontrol_audio::HrtfFirProcessor;
  HrtfFirProcessor processor(48000);
  const std::array<float, 3> left{{1.0F, 0.5F, 0.25F}};
  const std::array<float, 3> right{{0.5F, 0.25F, 0.125F}};
  require(processor.configure(left.data(), right.data(), left.size()), "valid HRIR accepted");
  require(processor.tap_count() == 3, "tap count published");
  const std::array<float, 5> impulse{{1.0F, 0.0F, 0.0F, 0.0F, 0.0F}};
  std::array<float, 10> stereo{};
  processor.process(impulse.data(), stereo.data(), impulse.size());
  require(std::abs(stereo[0] - 1.0F) < 1.0e-6F, "left impulse first tap");
  require(std::abs(stereo[1] - 0.5F) < 1.0e-6F, "right impulse first tap");
  require(std::abs(stereo[2] - 0.5F) < 1.0e-6F, "left impulse second tap");
  require(std::abs(stereo[4] - 0.25F) < 1.0e-6F, "left impulse third tap");
  require(stereo[6] == 0.0F && stereo[8] == 0.0F, "FIR history drains");
  const auto old_count = processor.tap_count();
  const std::array<float, 1> invalid{{std::numeric_limits<float>::quiet_NaN()}};
  require(!processor.configure(invalid.data(), invalid.data(), 1), "non-finite HRIR rejected");
  require(processor.tap_count() == old_count, "invalid HRIR leaves active configuration unchanged");
  require(!processor.configure(left.data(), right.data(), 0), "empty HRIR rejected");
  require(!processor.configure(left.data(), right.data(), HrtfFirProcessor::kMaxTaps + 1), "oversized HRIR rejected");
  const std::array<float, 2> excessive{{5.0F, 5.0F}};
  require(!processor.configure(excessive.data(), excessive.data(), excessive.size()), "excessive gain rejected");
  processor.reset();
  std::array<float, 3> malformed{{std::numeric_limits<float>::quiet_NaN(), std::numeric_limits<float>::infinity(), 0.25F}};
  std::array<float, 6> sanitized{};
  processor.process(malformed.data(), sanitized.data(), malformed.size());
  for (float sample : sanitized) require(std::isfinite(sample), "bad input contained");
  require(!processor.set_sample_rate(1000), "invalid sample rate rejected");
  require(processor.sample_rate() == 48000, "invalid rate preserves previous rate");
  const std::array<float, 1> next_left{{0.25F}};
  const std::array<float, 1> next_right{{0.75F}};
  require(processor.request_configuration(next_left.data(), next_right.data(), 1),
          "valid runtime HRIR update queued");
  require(!processor.request_configuration(left.data(), right.data(), left.size()),
          "second pending update rejected instead of racing the callback");
  constexpr std::size_t transitionFrames = HrtfFirProcessor::kProfileCrossfadeFrames + 8;
  std::array<float, transitionFrames> steady_input{};
  steady_input.fill(0.1F);
  std::array<float, transitionFrames * 2U> transitioned{};
  processor.process(steady_input.data(), transitioned.data(), steady_input.size());
  require(std::abs(transitioned[(HrtfFirProcessor::kProfileCrossfadeFrames - 1U) * 2U] - 0.025F) < 1.0e-5F,
          "runtime HRIR update crossfades to the new left filter");
  require(std::abs(transitioned[(HrtfFirProcessor::kProfileCrossfadeFrames - 1U) * 2U + 1U] - 0.075F) < 1.0e-5F,
          "runtime HRIR update crossfades to the new right filter");
  require(processor.tap_count() == 1, "runtime configuration applied at block boundary");
  require(processor.set_sample_rate(96000), "valid sample rate accepted");
  std::cout << "HRTF FIR processor tests passed\n";
  return 0;
}
