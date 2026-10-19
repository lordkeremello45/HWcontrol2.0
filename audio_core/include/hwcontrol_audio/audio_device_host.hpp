#pragma once

#include "hwcontrol_audio/argon_enhancer.hpp"
#include "hwcontrol_audio/audio_analyzer.hpp"
#include "hwcontrol_audio/audio_engine.hpp"

#include <array>
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
  std::uint64_t droppedSpectrumFrames = 0;
  std::uint64_t limitedSamples = 0;
  double callbackProcessingTimeUs = 0.0;
  double maxCallbackProcessingTimeUs = 0.0;
  std::uint64_t callbackBudgetOverruns = 0;
  bool running = false;
  bool spectrumAvailable = false;
  bool momentaryLufsAvailable = false;
  double momentaryLufs = -120.0;
  bool integratedLufsAvailable = false;
  double integratedLufs = -120.0;
  float spectrumPeakFrequencyHz = 0.0F;
  float spectrumRms = 0.0F;
  float spectrumLeftRms = 0.0F;
  float spectrumRightRms = 0.0F;
  float stereoCorrelation = 0.0F;
  std::array<float, kSpectrumBinCount> spectrumMagnitude{};
  double sampleRateHz = 0.0;
};

// Device enumeration and lifecycle live on the control thread. The callback
// uses fixed storage and a bounded SPSC queue; FFT work runs on an analysis
// worker. Audio samples never leave the native process.
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
  // Explicit ARGON enhancement settings are configured before the stream starts.
  // The overload without settings preserves the legacy processing behavior.
  bool start(std::size_t captureIndex, std::size_t playbackIndex,
             const ProcessorConfig& config, const EnhancementSettings& enhancement,
             bool monitorOutput, std::string& error);
  void stop() noexcept;
  bool running() const noexcept;
  LiveAudioMetrics metrics() const noexcept;

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace hwcontrol::audio
