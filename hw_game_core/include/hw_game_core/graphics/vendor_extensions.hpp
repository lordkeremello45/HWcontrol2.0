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

inline constexpr std::uint32_t known_vendor_feature_mask =
    feature_bit(VendorRuntimeFeature::upscaling) |
    feature_bit(VendorRuntimeFeature::frame_generation) |
    feature_bit(VendorRuntimeFeature::low_latency) |
    feature_bit(VendorRuntimeFeature::ray_tracing) |
    feature_bit(VendorRuntimeFeature::gpu_debug_markers);

struct VendorExtensionInfo {
    GpuVendor vendor = GpuVendor::unknown;
    VendorExtensionState state = VendorExtensionState::not_probed;
    std::uint32_t available_features = 0;
    std::string diagnostic;

    [[nodiscard]] constexpr bool supports(
        VendorRuntimeFeature feature) const noexcept {
        const auto bit = feature_bit(feature);
        return vendor != GpuVendor::unknown &&
               state == VendorExtensionState::ready &&
               bit != 0U && (bit & known_vendor_feature_mask) == bit &&
               (available_features & bit) != 0U &&
               (available_features & ~known_vendor_feature_mask) == 0U;
    }
};

// Validation is performed at the trust boundary after an optional adapter's
// probe. SDK adapters are native in-process code and must be built into a
// trusted application package; this contract is not a sandbox for plugins.
enum class VendorExtensionValidation : std::uint8_t {
    valid,
    vendor_mismatch,
    invalid_state,
    unknown_feature_bits,
    empty_ready_features,
    features_without_ready_state,
    diagnostic_too_large
};

inline constexpr std::size_t max_vendor_diagnostic_bytes = 4096;

[[nodiscard]] inline VendorExtensionValidation validate_vendor_extension_info(
    GpuVendor expected_vendor,
    const GraphicsDeviceInfo& device,
    const VendorExtensionInfo& info) noexcept {
    if (expected_vendor == GpuVendor::unknown ||
        info.vendor != expected_vendor ||
        identify_gpu_vendor(device.adapter.vendor_id) != expected_vendor) {
        return VendorExtensionValidation::vendor_mismatch;
    }

    if (info.diagnostic.size() > max_vendor_diagnostic_bytes) {
        return VendorExtensionValidation::diagnostic_too_large;
    }

    if ((info.available_features & ~known_vendor_feature_mask) != 0U) {
        return VendorExtensionValidation::unknown_feature_bits;
    }

    switch (info.state) {
        case VendorExtensionState::not_probed:
        case VendorExtensionState::unavailable:
        case VendorExtensionState::failed:
            return info.available_features == 0U
                ? VendorExtensionValidation::valid
                : VendorExtensionValidation::features_without_ready_state;
        case VendorExtensionState::ready:
            return info.available_features != 0U
                ? VendorExtensionValidation::valid
                : VendorExtensionValidation::empty_ready_features;
    }

    return VendorExtensionValidation::invalid_state;
}

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
