#include "hwcontrol_audio/headphone_profiles.hpp"

namespace hwcontrol::audio {

HeadphoneProfile make_competitive_fps_profile() noexcept {
  HeadphoneProfile profile{};
  profile.id = "argon.fps.competitive.v1";
  profile.displayName = "ARGON Competitive FPS";
  profile.useCase = HeadphoneUseCase::CompetitiveFps;

  // A neutral low shelf is intentionally not assumed: unknown headphones vary
  // widely. A modest presence lift is a starting preset, not a calibration.
  profile.dsp.inputGainDb = 0.0F;
  profile.dsp.noiseGateEnabled = false;
  profile.dsp.highPassEnabled = true;
  profile.dsp.highPassFrequencyHz = 55.0F;
  profile.dsp.compressorEnabled = false;
  profile.dsp.limiterEnabled = true;
  profile.dsp.limiterCeilingDb = -1.5F;

  profile.dsp.eq[0] = {120.0F, 0.0F, 0.707F};
  profile.dsp.eq[1] = {2800.0F, 2.0F, 0.9F};
  profile.dsp.eq[2] = {6500.0F, 1.0F, 0.8F};
  profile.dsp.eqEnabled = {{false, true, true}};

  profile.spatial.azimuth_degrees = 0.0F;
  profile.spatial.elevation_degrees = 0.0F;
  profile.spatial.distance_meters = 1.0F;
  profile.spatial.wet_mix = 1.0F;
  profile.spatial.enabled = true;

  profile.isDeviceCalibrated = false;
  profile.calibrationNote =
      "Generic starting point; not measured or calibrated for a specific headset.";
  return profile;
}

}  // namespace hwcontrol::audio
