#include "hwcontrol_audio/audio_device_host.hpp"

#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <iostream>
#include <sstream>
#include <cmath>
#include <string>
#include <thread>
#include <vector>

namespace {
std::string hexEncode(const std::string& value) {
  constexpr char digits[] = "0123456789abcdef";
  std::string output;
  output.reserve(value.size() * 2);
  for (unsigned char c : value) {
    output += digits[(c >> 4) & 0x0f];
    output += digits[c & 0x0f];
  }
  return output;
}

void writeDeviceArray(const std::vector<hwcontrol::audio::AudioDeviceInfo>& devices) {
  std::cout << "[";
  for (std::size_t i = 0; i < devices.size(); ++i) {
    if (i != 0) std::cout << ",";
    const auto& device = devices[i];
    std::cout << "{\"index\":" << device.index
              << ",\"nameHex\":\"" << hexEncode(device.name)
              << "\",\"isDefault\":" << (device.isDefault ? "true" : "false") << "}";
  }
  std::cout << "]";
}

const hwcontrol::audio::AudioDeviceInfo* findDefault(
    const std::vector<hwcontrol::audio::AudioDeviceInfo>& devices) {
  const auto it = std::find_if(devices.begin(), devices.end(),
      [](const auto& device) { return device.isDefault; });
  return it == devices.end() ? (devices.empty() ? nullptr : &devices.front()) : &*it;
}
}

void writeMetrics(const hwcontrol::audio::LiveAudioMetrics& metrics) {
  std::cout << "{\"status\":\"SUCCESS\",\"data\":{"
            << "\"running\":" << (metrics.running ? "true" : "false")
            << ",\"inputPeak\":" << metrics.inputPeak
            << ",\"outputPeak\":" << metrics.outputPeak
            << ",\"inputRms\":" << metrics.inputRms
            << ",\"outputRms\":" << metrics.outputRms
            << ",\"processedFrames\":" << metrics.processedFrames
            << ",\"droppedSpectrumFrames\":" << metrics.droppedSpectrumFrames
            << ",\"limitedSamples\":" << metrics.limitedSamples
            << ",\"callbackProcessingTimeUs\":" << metrics.callbackProcessingTimeUs
            << ",\"maxCallbackProcessingTimeUs\":" << metrics.maxCallbackProcessingTimeUs
            << ",\"callbackBudgetOverruns\":" << metrics.callbackBudgetOverruns
            << ",\"spectrumAvailable\":" << (metrics.spectrumAvailable ? "true" : "false")
            << ",\"spectrumPeakFrequencyHz\":" << metrics.spectrumPeakFrequencyHz
            << ",\"spectrumRms\":" << metrics.spectrumRms
            << ",\"sampleRateHz\":" << metrics.sampleRateHz
            << ",\"spectrumMagnitude\":[";
  for (std::size_t i = 0; i < metrics.spectrumMagnitude.size(); ++i) {
    if (i != 0) std::cout << ",";
    std::cout << metrics.spectrumMagnitude[i];
  }
  std::cout << "]}}\n";
}

bool handleServerCommand(AudioDeviceHost& host, const std::string& line) {
  std::istringstream input(line);
  std::string action;
  input >> action;
  if (action == "devices") {
    const auto capture = host.enumerate(DeviceDirection::Capture);
    const auto playback = host.enumerate(DeviceDirection::Playback);
    std::cout << "{\"status\":\"SUCCESS\",\"data\":{\"capture\":";
    writeDeviceArray(capture);
    std::cout << ",\"playback\":";
    writeDeviceArray(playback);
    std::cout << "}}\n";
    return true;
  }
  if (action == "status") {
    writeMetrics(host.metrics());
    return true;
  }
  if (action == "stop") {
    host.stop();
    writeMetrics(host.metrics());
    return true;
  }
  if (action != "start") {
    std::cout << "{\"status\":\"ERROR\",\"message\":\"unknown audio command\"}\n";
    return true;
  }

  // Refresh both endpoint maps in this process before resolving the supplied indices.
  (void)host.enumerate(DeviceDirection::Capture);
  (void)host.enumerate(DeviceDirection::Playback);
  long long captureIndex = -1;
  long long playbackIndex = -1;
  int monitor = 0;
  ProcessorConfig config;
  int gateEnabled = 0, compressorEnabled = 0, highPassEnabled = 0, limiterEnabled = 1;
  if (!(input >> captureIndex >> playbackIndex >> monitor
        >> config.inputGainDb >> config.gateThresholdDb
        >> config.compressorThresholdDb >> config.compressorRatio
        >> config.compressorAttackMs >> config.compressorReleaseMs
        >> config.compressorKneeDb >> config.highPassFrequencyHz
        >> config.limiterCeilingDb >> gateEnabled >> compressorEnabled
        >> highPassEnabled >> limiterEnabled
        >> config.eq[0].frequencyHz >> config.eq[0].gainDb
        >> config.eq[1].frequencyHz >> config.eq[1].gainDb
        >> config.eq[2].frequencyHz >> config.eq[2].gainDb)
      || captureIndex < 0 || playbackIndex < 0 || monitor < 0 || monitor > 1
      || gateEnabled < 0 || gateEnabled > 1 || compressorEnabled < 0 || compressorEnabled > 1
      || highPassEnabled < 0 || highPassEnabled > 1 || limiterEnabled < 0 || limiterEnabled > 1) {
    std::cout << "{\"status\":\"ERROR\",\"message\":\"invalid audio start request\"}\n";
    return true;
  }
  const float values[] = {config.inputGainDb, config.gateThresholdDb,
    config.compressorThresholdDb, config.compressorRatio, config.compressorAttackMs,
    config.compressorReleaseMs, config.compressorKneeDb, config.highPassFrequencyHz,
    config.limiterCeilingDb, config.eq[0].frequencyHz, config.eq[0].gainDb,
    config.eq[1].frequencyHz, config.eq[1].gainDb, config.eq[2].frequencyHz, config.eq[2].gainDb};
  for (float value : values) {
    if (!std::isfinite(value)) {
      std::cout << "{\"status\":\"ERROR\",\"message\":\"non-finite audio parameter rejected\"}\n";
      return true;
    }
  }
  config.noiseGateEnabled = gateEnabled != 0;
  config.compressorEnabled = compressorEnabled != 0;
  config.highPassEnabled = highPassEnabled != 0;
  config.limiterEnabled = limiterEnabled != 0;
  for (std::size_t i = 0; i < config.eq.size(); ++i) {
    config.eqEnabled[i] = std::abs(config.eq[i].gainDb) > 0.001F;
  }
  std::string error;
  if (!host.start(static_cast<std::size_t>(captureIndex),
                  static_cast<std::size_t>(playbackIndex), config, monitor != 0, error)) {
    std::cout << "{\"status\":\"ERROR\",\"messageHex\":\"" << hexEncode(error) << "\"}\n";
    return true;
  }
  writeMetrics(host.metrics());
  return true;
}

int main(int argc, char** argv) {
  using hwcontrol::audio::AudioDeviceHost;
  using hwcontrol::audio::DeviceDirection;
  using hwcontrol::audio::ProcessorConfig;

  AudioDeviceHost host;
  if (argc >= 2 && std::string(argv[1]) == "--server") {
    std::string line;
    while (std::getline(std::cin, line)) {
      if (line.size() > 4096) {
        std::cout << "{\"status\":\"ERROR\",\"message\":\"command too large\"}\n";
        std::cout.flush();
        continue;
      }
      handleServerCommand(host, line);
      std::cout.flush();
    }
    host.stop();
    return 0;
  }
  const auto capture = host.enumerate(DeviceDirection::Capture);
  const auto playback = host.enumerate(DeviceDirection::Playback);

  if (argc >= 2 && std::string(argv[1]) == "--json") {
    std::cout << "{\"capture\":";
    writeDeviceArray(capture);
    std::cout << ",\"playback\":";
    writeDeviceArray(playback);
    std::cout << "}\n";
    return 0;
  }

  std::cout << "Capture devices (" << capture.size() << "):\n";
  for (const auto& device : capture) {
    std::cout << "  [" << device.index << "] " << device.name
              << (device.isDefault ? " (default)" : "") << '\n';
  }
  std::cout << "Playback devices (" << playback.size() << "):\n";
  for (const auto& device : playback) {
    std::cout << "  [" << device.index << "] " << device.name
              << (device.isDefault ? " (default)" : "") << '\n';
  }

  if (argc < 2 || std::string(argv[1]) != "--test-stream") {
    std::cout << "Enumeration only. Use --test-stream [seconds] to test live capture.\n";
    return 0;
  }

  const auto* captureDevice = findDefault(capture);
  const auto* playbackDevice = findDefault(playback);
  if (captureDevice == nullptr || playbackDevice == nullptr) {
    std::cerr << "No capture/playback pair is available on this system.\n";
    return 2;
  }

  int seconds = 5;
  if (argc >= 3) {
    char* end = nullptr;
    const long parsed = std::strtol(argv[2], &end, 10);
    if (end == argv[2] || *end != '\0' || parsed < 1 || parsed > 30) {
      std::cerr << "Duration must be an integer from 1 to 30 seconds.\n";
      return 2;
    }
    seconds = static_cast<int>(parsed);
  }

  ProcessorConfig config;
  config.limiterEnabled = true;
  std::string error;
  if (!host.start(captureDevice->index, playbackDevice->index, config, false, error)) {
    std::cerr << "Could not start capture test: " << error << '\n';
    return 3;
  }

  std::cout << "Capturing for " << seconds
            << " seconds. Audio is processed locally, not recorded or played back.\n";
  for (int elapsed = 0; elapsed < seconds; ++elapsed) {
    std::this_thread::sleep_for(std::chrono::seconds(1));
    const auto metrics = host.metrics();
    std::cout << "input peak=" << metrics.inputPeak
              << " rms=" << metrics.inputRms
              << " processed frames=" << metrics.processedFrames
              << " FFT peak=" << metrics.spectrumPeakFrequencyHz << " Hz\n";
  }
  host.stop();
  return 0;
}
