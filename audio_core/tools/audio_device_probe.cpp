#include "hwcontrol_audio/audio_device_host.hpp"

#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <iostream>
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
int main(int argc, char** argv) {
  using hwcontrol::audio::AudioDeviceHost;
  using hwcontrol::audio::DeviceDirection;
  using hwcontrol::audio::ProcessorConfig;

  AudioDeviceHost host;
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
              << " processed frames=" << metrics.processedFrames << '\n';
  }
  host.stop();
  return 0;
}
