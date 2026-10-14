#include "hwcontrol_audio/audio_engine.hpp"
#include "hwcontrol_audio/audio_analyzer.hpp"
#include "hwcontrol_audio/audio_device_host.hpp"

#include <array>
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <limits>

namespace {
void require(bool condition, const char* message) {
  if (!condition) {
    std::cerr << "FAIL: " << message << '\n';
    std::exit(1);
  }
}

void testLimiterAndMetrics() {
  hwcontrol::audio::AudioEngine engine;
  hwcontrol::audio::ProcessorConfig config;
  config.limiterEnabled = true;
  config.limiterCeilingDb = -1.0F;
  require(engine.configure(config, 48000.0), "valid configuration rejected");
  std::array<float, 8> samples{{0.0F, 0.0F, 0.5F, -0.5F, 2.0F, -2.0F, 0.25F, -0.25F}};
  engine.process(samples.data(), 4);
  const float ceiling = std::pow(10.0F, -1.0F / 20.0F);
  for (float sample : samples) {
    require(std::isfinite(sample), "output contains non-finite sample");
    require(std::abs(sample) <= ceiling + 1.0e-5F, "limiter ceiling exceeded");
  }
  require(engine.metrics().processedFrames == 4, "frame counter incorrect");
  require(engine.metrics().inputPeak == 2.0F, "input peak incorrect");
  require(engine.metrics().outputPeak <= ceiling + 1.0e-5F, "output peak incorrect");
}

void testGainAndGate() {
  hwcontrol::audio::AudioEngine engine;
  hwcontrol::audio::ProcessorConfig config;
  config.inputGainDb = 6.0F;
  config.limiterEnabled = false;
  require(engine.configure(config, 48000.0), "valid configuration rejected");
  std::array<float, 4> samples{{0.1F, -0.1F, 0.2F, -0.2F}};
  engine.process(samples.data(), 2);
  require(samples[0] > 0.19F && samples[0] < 0.21F, "input gain not applied");

  config.inputGainDb = 0.0F;
  config.noiseGateEnabled = true;
  config.gateThresholdDb = -30.0F;
  require(engine.configure(config, 48000.0), "gate configuration rejected");
  samples = {{0.01F, -0.01F, 0.5F, -0.5F}};
  engine.process(samples.data(), 2);
  require(samples[0] == 0.0F && samples[1] == 0.0F, "gate did not suppress quiet signal");
  require(samples[2] == 0.5F && samples[3] == -0.5F, "gate altered loud signal");
}

void testNonFiniteSamplesAreContained() {
  hwcontrol::audio::AudioEngine engine;
  hwcontrol::audio::ProcessorConfig config;
  require(engine.configure(config, 48000.0), "valid configuration rejected");
  std::array<float, 4> samples{{std::numeric_limits<float>::quiet_NaN(),
      std::numeric_limits<float>::infinity(), -0.25F, 0.25F}};
  engine.process(samples.data(), 2);
  require(samples[0] == 0.0F && samples[1] == 0.0F, "non-finite input not sanitized");
  for (float sample : samples) require(std::isfinite(sample), "non-finite output remains");
}

void testEqualizerBoostsConfiguredBand() {
  hwcontrol::audio::AudioEngine engine;
  hwcontrol::audio::ProcessorConfig config;
  config.limiterEnabled = false;
  config.eq[1] = {1000.0F, 12.0F, 1.0F};
  config.eqEnabled[1] = true;
  require(engine.configure(config, 48000.0), "EQ configuration rejected");

  constexpr std::size_t frames = 4800;
  std::array<float, frames * 2> samples{};
  for (std::size_t frame = 0; frame < frames; ++frame) {
    const float value = 0.1F * std::sin(2.0F * 3.14159265F *
        1000.0F * static_cast<float>(frame) / 48000.0F);
    samples[frame * 2] = value;
    samples[frame * 2 + 1] = value;
  }
  engine.process(samples.data(), frames);
  require(engine.metrics().outputRms > engine.metrics().inputRms * 1.5F,
          "enabled peaking EQ did not boost its configured frequency");
}

void testCompressorReducesAboveThresholdLevel() {
  hwcontrol::audio::AudioEngine engine;
  hwcontrol::audio::ProcessorConfig config;
  config.limiterEnabled = false;
  config.compressorEnabled = true;
  config.compressorThresholdDb = -12.0F;
  config.compressorRatio = 4.0F;
  require(engine.configure(config, 48000.0), "compressor configuration rejected");
  std::array<float, 4> samples{{0.8F, -0.8F, 0.8F, -0.8F}};
  engine.process(samples.data(), 2);
  require(std::abs(samples[0]) < 0.5F,
          "compressor did not reduce a signal above threshold");
}

void testSpectrumAnalyzerFindsTone() {
  hwcontrol::audio::AudioAnalyzer analyzer;
  hwcontrol::audio::SpectrumFrame spectrum;
  std::array<float, hwcontrol::audio::kFftSize * 2> samples{};
  constexpr double sampleRate = 48000.0;
  constexpr double frequency = 1500.0;
  for (std::size_t frame = 0; frame < hwcontrol::audio::kFftSize; ++frame) {
    const float value = 0.25F * std::sin(static_cast<float>(
        2.0 * 3.14159265358979323846 * frequency *
        static_cast<double>(frame) / sampleRate));
    samples[frame * 2] = value;
    samples[frame * 2 + 1] = value;
  }
  require(analyzer.analyze(samples.data(), hwcontrol::audio::kFftSize,
                           sampleRate, spectrum),
          "valid FFT frame rejected");
  require(std::abs(spectrum.peakFrequencyHz - 1500.0F) < 1.0F,
          "FFT peak frequency incorrect");
  require(spectrum.magnitude[32] > 0.2F, "FFT peak magnitude too small");
  require(spectrum.rms > 0.15F && spectrum.rms < 0.2F, "FFT RMS incorrect");
  require(!analyzer.analyze(samples.data(), 64, sampleRate, spectrum),
          "wrong FFT frame size accepted");
}

void testAudioDeviceHostLifecycleWithoutAssumingHardware() {
  hwcontrol::audio::AudioDeviceHost host;
  (void)host.enumerate(hwcontrol::audio::DeviceDirection::Capture);
  (void)host.enumerate(hwcontrol::audio::DeviceDirection::Playback);
  require(!host.running(), "device host should not start implicitly");
  const auto metrics = host.metrics();
  require(!metrics.running, "stopped host reports running");
  host.stop();
  require(!host.running(), "stop should be idempotent");
}

void testInvalidSampleRateFallsBack() {
  hwcontrol::audio::AudioEngine engine;
  hwcontrol::audio::ProcessorConfig config;
  require(!engine.configure(config, 0.0), "invalid sample rate accepted");
  std::array<float, 2> samples{{0.2F, -0.2F}};
  engine.process(samples.data(), 1);
  require(std::isfinite(samples[0]) && std::isfinite(samples[1]), "fallback failed");
}
}  // namespace

int main() {
  testLimiterAndMetrics();
  testGainAndGate();
  testNonFiniteSamplesAreContained();
  testEqualizerBoostsConfiguredBand();
  testCompressorReducesAboveThresholdLevel();
  testSpectrumAnalyzerFindsTone();
  testAudioDeviceHostLifecycleWithoutAssumingHardware();
  testInvalidSampleRateFallsBack();
  std::cout << "Audio core tests passed\n";
  return 0;
}
