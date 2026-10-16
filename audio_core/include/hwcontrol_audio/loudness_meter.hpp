#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace hwcontrol::audio {

struct LoudnessMetrics {
  bool momentaryAvailable = false;
  double momentaryLufs = -120.0;
  bool integratedAvailable = false;
  double integratedLufs = -120.0;
};

// ITU-R BS.1770 / EBU R128 stereo loudness meter (K-weighting, 400 ms
// blocks with 100 ms hops, -70 LUFS absolute and -10 LU relative gating).
// Call from a worker/control thread, never from a real-time device callback:
// integrated gating stores block energies and metrics() scans that history.
class LoudnessMeter final {
 public:
  bool configure(double sampleRateHz) noexcept;
  void process(const float* interleavedStereo, std::size_t frameCount) noexcept;
  LoudnessMetrics metrics() const noexcept;
  void reset() noexcept;

 private:
  struct Biquad {
    double b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0;
    std::array<double, 2> z1{{0.0, 0.0}};
    std::array<double, 2> z2{{0.0, 0.0}};
    double tick(double input, std::size_t channel) noexcept;
    void clear() noexcept;
  };

  static constexpr std::size_t kMaxWindowFrames = 76800; // 400 ms at 192 kHz
  static double energyToLufs(double energy) noexcept;

  double sampleRateHz_ = 48000.0;
  std::size_t windowFrames_ = 19200;
  std::size_t hopFrames_ = 4800;
  std::array<Biquad, 2> kWeighting_{};
  std::array<double, kMaxWindowFrames> energyRing_{};
  std::size_t ringWrite_ = 0;
  std::size_t ringCount_ = 0;
  std::size_t framesSinceBlock_ = 0;
  double rollingEnergy_ = 0.0;
  std::vector<double> blockEnergies_;
};

}  // namespace hwcontrol::audio
