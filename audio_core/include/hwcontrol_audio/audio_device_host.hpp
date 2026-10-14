#pragma once

#include "hwcontrol_audio/audio_engine.hpp"

#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace hwcontrol::audio {

enum class DeviceDirection { Capture, Playback };

struct AudioDeviceInfo {
  std::size_t index = 0;
  std::string name;
  bool isDefault = false;
};

struct LiveAudioMetrics {
  float inputPeak = 0.0F;
  float outputPeak = 0.0F;
  float inputRms = 0.0F;
  float outputRms = 0.0F;
  std::uint64_t processedFrames = 0;
  bool running = false;
};

// Device enumeration and lifecycle live on the control thread. The callback
// uses fixed stack storage and never sends audio through the Go bridge.
// Monitoring is opt-in because routing a microphone to speakers can feed back.
class AudioDeviceHost final {
 public:
  AudioDeviceHost();
  ~AudioDeviceHost();
  AudioDeviceHost(const AudioDeviceHost&) = delete;
  AudioDeviceHost& operator=(const AudioDeviceHost&) = delete;

  std::vector<AudioDeviceInfo> enumerate(DeviceDirection direction);
  bool start(std::size_t captureIndex, std::size_t playbackIndex,
             const ProcessorConfig& config, bool monitorOutput,
             std::string& error);
  void stop() noexcept;
  bool running() const noexcept;
  LiveAudioMetrics metrics() const noexcept;

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace hwcontrol::audio
