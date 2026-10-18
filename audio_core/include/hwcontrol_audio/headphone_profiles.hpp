#pragma once

#include "hwcontrol_audio/audio_engine.hpp"
#include "hwcontrol_audio/spatial_audio.hpp"

#include <string_view>

namespace hwcontrol::audio {

enum class HeadphoneUseCase { CompetitiveFps, Cinema, Music, Everyday };

struct HeadphoneProfile {
  std::string_view id;
  std::string_view displayName;
  HeadphoneUseCase useCase;
  ProcessorConfig dsp;
  hwcontrol_audio::SpatialAudioParams spatial;
  bool isDeviceCalibrated = false;
  std::string_view calibrationNote;
};

// Built-in profiles are generic starting points, not measured correction curves.
// The competitive FPS preset prioritizes conservative dynamics and clarity.
HeadphoneProfile make_competitive_fps_profile() noexcept;

}  // namespace hwcontrol::audio
