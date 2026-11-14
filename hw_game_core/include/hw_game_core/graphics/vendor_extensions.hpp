#pragma once

#include "hw_game_core/graphics/device.hpp"

#include <cstdint>
#include <string>

namespace hwcontrol::game::graphics {

// PCI vendor IDs are identification hints only. They never prove that a
// vendor SDK, driver extension, or optional runtime feature is installed.
enum class GpuVendor : std::uint8_t {
    unknown,
    nvidia,
    amd,
    intel,
    apple
};

[[nodiscard]] constexpr GpuVendor identify_gpu_vendor(
    std::uint32_t pci_vendor_id) noexcept {
    switch (pci_vendor_id) {
        case 0x10DEU: return GpuVendor::nvidia;
        case 0x1002U: return GpuVendor::amd;
        case 0x8086U: return GpuVendor::intel;
        case 0x106BU: return GpuVendor::apple;
        default: return GpuVendor::unknown;
    }
}

enum class VendorExtensionState : std::uint8_t {
    not_probed,
    unavailable,
    ready,
    failed
};

// These are optional runtime capabilities reported by a real SDK/backend
// probe. They must not be inferred from the adapter's vendor ID.
enum class VendorRuntimeFeature : std::uint32_t {
    none = 0,
    upscaling = 1U << 0U,
    frame_generation = 1U << 1U,
    low_latency = 1U << 2U,
    ray_tracing = 1U << 3U,
    gpu_debug_markers = 1U << 4U
};

[[nodiscard]] constexpr std::uint32_t feature_bit(
    VendorRuntimeFeature feature) noexcept {
    return static_cast<std::uint32_t>(feature);
}

struct VendorExtensionInfo {
    GpuVendor vendor = GpuVendor::unknown;
    VendorExtensionState state = VendorExtensionState::not_probed;
    std::uint32_t available_features = 0;
    std::string diagnostic;

    [[nodiscard]] constexpr bool supports(
        VendorRuntimeFeature feature) const noexcept {
        return vendor != GpuVendor::unknown &&
               state == VendorExtensionState::ready &&
               feature != VendorRuntimeFeature::none &&
               (available_features & feature_bit(feature)) != 0U;
    }
};

// Implementations live in optional vendor-specific modules. The portable
// Game Core target must not link NVIDIA or AMD SDKs to use the core API.
class IVendorGraphicsExtension {
public:
    virtual ~IVendorGraphicsExtension() = default;

    [[nodiscard]] virtual GpuVendor vendor() const noexcept = 0;
    [[nodiscard]] virtual VendorExtensionInfo probe(
        const GraphicsDeviceInfo& device) = 0;
};

}  // namespace hwcontrol::game::graphics
