#pragma once

#include <array>
#include <string_view>

namespace hwcontrol::audio {

enum class CapabilityStatus {
  NativeProcessing,     // Native core can process this representation.
  BackendDependent,     // Device backend/OS may expose it; runtime query required.
  DecoderNotIntegrated  // No decoder/integration is shipped by this module.
};

struct AudioFormatCapability {
  std::string_view id;
  std::string_view label;
  CapabilityStatus status;
  std::string_view evidence;
};

// Describes only the current ARGON Audio module. It is not a system-wide
// capability probe and must not be presented as a detected device inventory.
inline constexpr std::array<AudioFormatCapability, 7> kAudioFormatCapabilities{{
    {"pcm-f32-stereo", "Float PCM stereo processing", CapabilityStatus::NativeProcessing,
     "AudioEngine processes interleaved float stereo buffers."},
    {"pcm-device-endpoints", "PCM device capture/playback", CapabilityStatus::BackendDependent,
     "miniaudio opens system endpoints; actual formats depend on device/backend."},
    {"spatial-parametric", "ARGON parametric stereo spatialization", CapabilityStatus::NativeProcessing,
     "Prototype spatializer; not measured HRTF and not a multichannel decoder."},
    {"hrtf-measured", "Measured HRTF rendering", CapabilityStatus::DecoderNotIntegrated,
     "No measured HRTF dataset or full HRTF renderer integrated."},
    {"dolby-atmos", "Dolby Atmos decoding", CapabilityStatus::DecoderNotIntegrated,
     "No Dolby Atmos decoder or licensed integration in this module."},
    {"dts-x", "DTS:X decoding", CapabilityStatus::DecoderNotIntegrated,
     "No DTS:X decoder or licensed integration in this module."},
    {"360-reality-audio", "360 Reality Audio decoding", CapabilityStatus::DecoderNotIntegrated,
     "No 360 Reality Audio decoder or licensed integration in this module."},
}};

}  // namespace hwcontrol::audio
