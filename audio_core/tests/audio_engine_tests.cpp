#include "hwcontrol_audio/audio_engine.hpp"
#include "hwcontrol_audio/audio_analyzer.hpp"
#include "hwcontrol_audio/audio_device_host.hpp"
#include "hwcontrol_audio/loudness_meter.hpp"

#include <algorithm>
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
  require(spectrum.rms < 1.0e-6F,
          "anti-phase stereo channels should cancel in the mono spectrum");

  samples.fill(0.0F);
  require(analyzer.analyze(samples.data(), hwcontrol::audio::kFftSize,
                           sampleRate, spectrum),
          "stereo analysis rejected silence");
  require(spectrum.leftRms == 0.0F && spectrum.rightRms == 0.0F,
          "silence produced nonzero channel RMS");
  require(spectrum.stereoCorrelation == 0.0F,
          "silence should have neutral correlation rather than NaN");

  for (std::size_t frame = 0; frame < hwcontrol::audio::kFftSize; ++frame) {
    const float quiet = 1.0e-10F * std::sin(static_cast<float>(
        2.0 * 3.14159265358979323846 * frequency *
        static_cast<double>(frame) / sampleRate));
    samples[frame * 2] = quiet;
    samples[frame * 2 + 1] = quiet * 0.5F;
  }
  require(analyzer.analyze(samples.data(), hwcontrol::audio::kFftSize,
                           sampleRate, spectrum),
          "stereo analysis rejected a quiet but valid frame");
  require(spectrum.stereoCorrelation > 0.999F,
          "quiet correlated channels lost their correlation");
  require(spectrum.leftRms > spectrum.rightRms * 1.9F,
          "unequal quiet channel levels were not preserved");

  for (std::size_t frame = 0; frame < hwcontrol::audio::kFftSize; ++frame) {
    const float tone = 0.1F * std::sin(static_cast<float>(
        2.0 * 3.14159265358979323846 * frequency *
        static_cast<double>(frame) / sampleRate));
    samples[frame * 2] = tone + 0.3F;
    samples[frame * 2 + 1] = tone * 0.5F - 0.2F;
  }
  require(analyzer.analyze(samples.data(), hwcontrol::audio::kFftSize,
                           sampleRate, spectrum),
          "stereo analysis rejected a DC-offset frame");
  require(spectrum.stereoCorrelation > 0.999F,
          "DC offsets incorrectly dominated stereo correlation");
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
  require(std::isfinite(spectrum.leftRms) &&
              std::isfinite(spectrum.rightRms) &&
              std::isfinite(spectrum.stereoCorrelation),
          "stereo metrics overflowed on finite extreme input");
  require(spectrum.stereoCorrelation >= -1.0F &&
              spectrum.stereoCorrelation <= 1.0F,
          "stereo correlation escaped its normalized range");
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

void testDspOutputIsIndependentOfBlockPartitioning() {
  hwcontrol::audio::ProcessorConfig config;
  config.inputGainDb = 3.0F;
  config.noiseGateEnabled = true;
  config.gateThresholdDb = -48.0F;
  config.highPassEnabled = true;
  config.highPassFrequencyHz = 65.0F;
  config.compressorEnabled = true;
  config.compressorThresholdDb = -18.0F;
  config.compressorRatio = 3.0F;
  config.compressorAttackMs = 2.0F;
  config.compressorReleaseMs = 80.0F;
  config.compressorKneeDb = 4.0F;
  config.limiterEnabled = true;
  config.limiterCeilingDb = -1.0F;
  config.eq[0] = {120.0F, 3.0F, 0.8F};
  config.eqEnabled[0] = true;
  config.eq[1] = {1200.0F, -2.0F, 1.1F};
  config.eqEnabled[1] = true;

  constexpr std::size_t frames = 8192;
  std::array<float, frames * hwcontrol::audio::kChannelCount> whole{};
  std::array<float, frames * hwcontrol::audio::kChannelCount> chunked{};
  for (std::size_t frame = 0; frame < frames; ++frame) {
    const float low = 0.35F * std::sin(static_cast<float>(
        2.0 * 3.14159265358979323846 * 90.0 *
        static_cast<double>(frame) / 48000.0));
    const float high = 0.22F * std::sin(static_cast<float>(
        2.0 * 3.14159265358979323846 * 1700.0 *
        static_cast<double>(frame) / 48000.0));
    const float transient = frame % 997U < 8U ? 0.9F : 0.0F;
    const float sample = low + high + transient;
    whole[frame * 2] = sample;
    whole[frame * 2 + 1] = sample * 0.8F;
  }
  chunked = whole;

  hwcontrol::audio::AudioEngine oneBlock;
  hwcontrol::audio::AudioEngine manyBlocks;
  require(oneBlock.configure(config, 48000.0), "whole-block DSP configuration rejected");
  require(manyBlocks.configure(config, 48000.0), "chunked DSP configuration rejected");
  const auto wholeLimited = oneBlock.process(whole.data(), frames);
  std::uint64_t chunkedLimited = 0;
  constexpr std::size_t blockFrames = 127;
  for (std::size_t offset = 0; offset < frames; offset += blockFrames) {
    const std::size_t count = std::min(blockFrames, frames - offset);
    chunkedLimited += manyBlocks.process(chunked.data() + offset * 2, count);
  }

  require(oneBlock.metrics().processedFrames == frames,
          "whole-block processing frame count incorrect");
  require(manyBlocks.metrics().processedFrames == frames,
          "chunked processing frame count incorrect");
  require(wholeLimited == chunkedLimited,
          "limiter engagement changed with callback block partitioning");
  for (std::size_t i = 0; i < whole.size(); ++i) {
    require(std::isfinite(whole[i]) && std::isfinite(chunked[i]),
            "partitioning test produced non-finite output");
    require(std::abs(whole[i] - chunked[i]) < 2.0e-5F,
            "DSP output changed materially with callback block partitioning");
  }
}

void testLoudnessMeterGatingAndBlockBoundaries() {
  hwcontrol::audio::LoudnessMeter meter;
  require(meter.configure(48000.0), "LUFS meter rejected 48 kHz");
  auto initial = meter.metrics();
  require(!initial.momentaryAvailable && !initial.integratedAvailable,
          "LUFS meter reported values before a complete block");

  constexpr std::size_t frames = 48000;
  std::array<float, frames * 2> tone{};
  for (std::size_t frame = 0; frame < frames; ++frame) {
    const float sample = 0.1F * std::sin(static_cast<float>(
        2.0 * 3.14159265358979323846 * 1000.0 *
        static_cast<double>(frame) / 48000.0));
    tone[frame * 2] = sample;
    tone[frame * 2 + 1] = sample;
  }
  // Split input into irregular chunks to exercise state continuity.
  std::size_t offset = 0;
  while (offset < frames) {
    const std::size_t count = std::min<std::size_t>(733, frames - offset);
    meter.process(tone.data() + offset * 2, count);
    offset += count;
  }
  const auto measured = meter.metrics();
  require(measured.momentaryAvailable && measured.integratedAvailable,
          "LUFS meter did not publish values after complete blocks");
  require(std::isfinite(measured.momentaryLufs) &&
              std::isfinite(measured.integratedLufs),
          "LUFS meter produced non-finite measurements");
  require(measured.momentaryLufs > -30.0 && measured.momentaryLufs < -5.0,
          "LUFS meter result for a full-scale-calibrated 1 kHz tone is implausible");
  require(std::abs(measured.momentaryLufs - measured.integratedLufs) < 0.5,
          "steady tone momentary and integrated loudness should be close");

  meter.reset();
  const auto reset = meter.metrics();
  require(!reset.momentaryAvailable && !reset.integratedAvailable,
          "reset did not clear LUFS history");
  require(!meter.configure(std::numeric_limits<double>::quiet_NaN()),
          "LUFS meter accepted invalid sample rate");
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
  testDspOutputIsIndependentOfBlockPartitioning();
  testLoudnessMeterGatingAndBlockBoundaries();
  testInvalidSampleRateFallsBack();
  std::cout << "Audio core tests passed\n";
  return 0;
}
