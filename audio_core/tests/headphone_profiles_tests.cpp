#include "hwcontrol_audio/audio_format_capabilities.hpp"
#include "hwcontrol_audio/headphone_profiles.hpp"

#include <cmath>
#include <cstdlib>
#include <iostream>

namespace {
void require(bool condition, const char* message) {
  if (!condition) {
    std::cerr << "FAIL: " << message << '\n';
    std::exit(1);
  }
}
}

int main() {
  const auto profile = hwcontrol::audio::make_competitive_fps_profile();
  require(profile.id == "argon.fps.competitive.v1", "stable profile id");
  require(profile.useCase == hwcontrol::audio::HeadphoneUseCase::CompetitiveFps, "FPS use case");
  require(!profile.isDeviceCalibrated, "generic profile must not claim calibration");
  require(profile.dsp.highPassEnabled, "low-frequency rumble filter enabled");
  require(profile.dsp.eqEnabled[1] && profile.dsp.eqEnabled[2], "presence bands enabled");
  require(!profile.dsp.compressorEnabled, "competitive preset preserves transient dynamics");
  require(profile.dsp.limiterEnabled, "output limiter enabled");
  require(std::abs(profile.dsp.limiterCeilingDb + 1.5F) < 0.001F, "safe limiter ceiling");
  require(profile.spatial.enabled && profile.spatial.azimuth_degrees == 0.0F, "spatial engine starts centered");
  require(profile.calibrationNote.find("not measured") != std::string_view::npos,
          "profile discloses lack of measurement");

  bool foundAtmos = false;
  bool foundHrtf = false;
  for (const auto& capability : hwcontrol::audio::kAudioFormatCapabilities) {
    if (capability.id == "dolby-atmos") {
      foundAtmos = capability.status == hwcontrol::audio::CapabilityStatus::DecoderNotIntegrated;
    }
    if (capability.id == "hrtf-measured") {
      foundHrtf = capability.status == hwcontrol::audio::CapabilityStatus::DecoderNotIntegrated;
    }
  }
  require(foundAtmos, "Atmos decoder status is truthful");
  require(foundHrtf, "measured HRTF status is truthful");
  std::cout << "Headphone profile tests passed\n";
  return 0;
}
