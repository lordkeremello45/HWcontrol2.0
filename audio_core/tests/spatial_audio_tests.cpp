#include "hwcontrol_audio/spatial_audio.hpp"
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <vector>
namespace {
void require(bool ok, const char* msg) { if (!ok) { std::cerr << "FAIL: " << msg << '\n'; std::exit(1); } }
float energy(const std::vector<float>& v, std::size_t channel) {
  double sum = 0.0;
  for (std::size_t i = channel; i < v.size(); i += 2U) sum += static_cast<double>(v[i]) * v[i];
  return static_cast<float>(sum);
}
}
int main() {
  constexpr std::size_t frames = 4096;
  std::vector<float> mono(frames, 0.25F), stereo(frames * 2U, 0.0F);
  hwcontrol_audio::SpatialAudioProcessor p(48000);
  hwcontrol_audio::SpatialAudioParams params;
  require(p.configure(params), "center params accepted");
  p.process(mono.data(), stereo.data(), frames);
  require(std::abs(energy(stereo, 0) - energy(stereo, 1)) < 0.01F, "center source balanced");
  p.reset(); params.azimuth_degrees = -90.0F; require(p.configure(params), "left params accepted");
  p.process(mono.data(), stereo.data(), frames);
  require(energy(stereo, 0) > energy(stereo, 1) * 3.0F, "left source biased left");
  p.reset(); params.azimuth_degrees = 90.0F; require(p.configure(params), "right params accepted");
  p.process(mono.data(), stereo.data(), frames);
  require(energy(stereo, 1) > energy(stereo, 0) * 3.0F, "right source biased right");
  const auto previous = p.params(); params.azimuth_degrees = 181.0F;
  require(!p.configure(params), "invalid azimuth rejected");
  require(p.params().azimuth_degrees == previous.azimuth_degrees, "invalid config unchanged");
  params.azimuth_degrees = 0.0F; params.distance_meters = 1.0F;
  require(p.configure(params), "near distance accepted"); p.reset(); p.process(mono.data(), stereo.data(), frames);
  const float near_energy = energy(stereo, 0) + energy(stereo, 1);
  params.distance_meters = 10.0F; require(p.configure(params), "far distance accepted");
  p.reset(); p.process(mono.data(), stereo.data(), frames);
  require(energy(stereo, 0) + energy(stereo, 1) < near_energy, "distance attenuates");
  mono[17] = std::numeric_limits<float>::quiet_NaN(); mono[18] = std::numeric_limits<float>::infinity();
  p.reset(); p.process(mono.data(), stereo.data(), frames);
  for (float sample : stereo) { require(std::isfinite(sample), "finite output"); require(std::abs(sample) <= 1.0F, "bounded output"); }
  require(!p.set_sample_rate(1000), "invalid rate rejected");
  require(p.sample_rate() == 48000, "invalid rate leaves state unchanged");
  require(p.set_sample_rate(96000), "valid rate accepted");
  std::cout << "Spatial audio processor tests passed\n";
  return 0;
}
