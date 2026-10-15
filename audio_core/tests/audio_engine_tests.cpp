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
  const auto limitedSamples = engine.process(samples.data(), 4);
  require(limitedSamples == 2, "limiter engagement count incorrect");
  require(engine.metrics().clippedSamples == 2, "cumulative limiter engagement count incorrect");
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
  config.compressorAttackMs = 0.1F;
  config.compressorKneeDb = 0.0F;
  require(engine.configure(config, 48000.0), "compressor configuration rejected");
  std::array<float, 1024> samples{};
  samples.fill(0.8F);
  engine.process(samples.data(), samples.size() / 2);
  require(std::abs(samples[800]) < 0.5F,
          "compressor did not reduce a signal above threshold");
}

void testHighPassAttenuatesLowFrequencyTone() {
  hwcontrol::audio::AudioEngine engine;
  hwcontrol::audio::ProcessorConfig config;
  config.limiterEnabled = false;
  config.highPassEnabled = true;
  config.highPassFrequencyHz = 500.0F;
  require(engine.configure(config, 48000.0), "high-pass configuration rejected");
  constexpr std::size_t frames = 4800;
  std::array<float, frames * 2> samples{};
  for (std::size_t frame = 0; frame < frames; ++frame) {
    const float value = 0.25F * std::sin(static_cast<float>(
        2.0 * 3.14159265358979323846 * 100.0 *
        static_cast<double>(frame) / 48000.0));
    samples[frame * 2] = value;
    samples[frame * 2 + 1] = value;
  }
  engine.process(samples.data(), frames);
  require(engine.metrics().outputRms < engine.metrics().inputRms * 0.25F,
          "high-pass did not attenuate the low-frequency tone");
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

void testSpectrumAnalyzerReportsStereoLevelsAndCorrelation() {
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
    samples[frame * 2 + 1] = -value;
  }
  require(analyzer.analyze(samples.data(), hwcontrol::audio::kFftSize,
                           sampleRate, spectrum),
          "stereo analysis rejected a valid frame");
  require(spectrum.leftRms > 0.15F && spectrum.leftRms < 0.2F,
          "left-channel RMS incorrect");
  require(spectrum.rightRms > 0.15F && spectrum.rightRms < 0.2F,
          "right-channel RMS incorrect");
  require(spectrum.stereoCorrelation < -0.999F,
          "inverted stereo channels were not identified as negatively correlated");

  samples.fill(0.0F);
  require(analyzer.analyze(samples.data(), hwcontrol::audio::kFftSize,
                           sampleRate, spectrum),
          "stereo analysis rejected silence");
  require(spectrum.leftRms == 0.0F && spectrum.rightRms == 0.0F,
          "silence produced nonzero channel RMS");
  require(spectrum.stereoCorrelation == 0.0F,
          "silence should have neutral correlation rather than NaN");
}

void testSpectrumAnalyzerRejectsInvalidRatesAndContainsBadSamples() {
  hwcontrol::audio::AudioAnalyzer analyzer;
  hwcontrol::audio::SpectrumFrame spectrum;
  std::array<float, hwcontrol::audio::kFftSize * 2> samples{};

  require(!analyzer.analyze(samples.data(), hwcontrol::audio::kFftSize,
                            std::numeric_limits<double>::quiet_NaN(), spectrum),
          "FFT accepted a NaN sample rate");
  require(!analyzer.analyze(samples.data(), hwcontrol::audio::kFftSize,
                            500000.0, spectrum),
          "FFT accepted a sample rate outside its supported range");

  samples[0] = std::numeric_limits<float>::quiet_NaN();
  samples[1] = std::numeric_limits<float>::infinity();
  require(analyzer.analyze(samples.data(), hwcontrol::audio::kFftSize,
                           48000.0, spectrum),
          "FFT rejected a correctly sized frame containing bad samples");
  require(std::isfinite(spectrum.rms) && spectrum.rms == 0.0F,
          "FFT RMS is not safely zero for sanitized silence");
  require(std::isfinite(spectrum.peakFrequencyHz),
          "FFT peak frequency is non-finite");
  for (float magnitude : spectrum.magnitude) {
    require(std::isfinite(magnitude) && magnitude >= 0.0F,
            "FFT produced an invalid magnitude");
  }
}

void testSpectrumAnalyzerHandlesLargestFiniteSamples() {
  hwcontrol::audio::AudioAnalyzer analyzer;
  hwcontrol::audio::SpectrumFrame spectrum;
  std::array<float, hwcontrol::audio::kFftSize * 2> samples{};
  samples.fill(std::numeric_limits<float>::max());
  require(analyzer.analyze(samples.data(), hwcontrol::audio::kFftSize,
                           48000.0, spectrum),
          "FFT rejected finite extreme input");
  require(std::isfinite(spectrum.rms),
          "FFT RMS overflowed on finite extreme input");
  require(std::isfinite(spectrum.peakFrequencyHz),
          "FFT peak frequency overflowed on finite extreme input");
  for (float magnitude : spectrum.magnitude) {
    require(std::isfinite(magnitude),
            "FFT magnitude overflowed on finite extreme input");
  }
}

void testAudioDeviceHostLifecycleWithoutAssumingHardware() {
  hwcontrol::audio::AudioDeviceHost host;
  (void)host.enumerate(hwcontrol::audio::DeviceDirection::Capture);
  (void)host.enumerate(hwcontrol::audio::DeviceDirection::Playback);
  require(!host.running(), "device host should not start implicitly");
  const auto metrics = host.metrics();
  require(!metrics.running, "stopped host reports running");
  require(!metrics.spectrumAvailable, "spectrum must not be reported before analysis");
  require(metrics.spectrumMagnitude[0] == 0.0F, "spectrum metrics must start deterministically at zero");
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
  testHighPassAttenuatesLowFrequencyTone();
  testSpectrumAnalyzerFindsTone();
  testSpectrumAnalyzerReportsStereoLevelsAndCorrelation();
  testSpectrumAnalyzerRejectsInvalidRatesAndContainsBadSamples();
  testSpectrumAnalyzerHandlesLargestFiniteSamples();
  testAudioDeviceHostLifecycleWithoutAssumingHardware();
  testInvalidSampleRateFallsBack();
  std::cout << "Audio core tests passed\n";
  return 0;
}
