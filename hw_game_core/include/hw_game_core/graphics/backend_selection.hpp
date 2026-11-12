#pragma once

#include <cstdint>
#include <vector>

namespace hwcontrol::game::graphics {

enum class Platform : std::uint8_t { unknown, windows, linux, macos };
enum class GraphicsApi : std::uint8_t { automatic, direct3d12, vulkan, metal };

// A real backend probe supplies these states. This policy layer does not load
// drivers, enumerate GPUs, create devices, or infer readiness from SDK headers.
enum class BackendProbeStatus : std::uint8_t {
    ready,
    not_compiled,
    loader_missing,
    no_compatible_device,
    surface_unavailable,
    initialization_failed
};

struct BackendCapabilities {
    bool rendering_2d = false;
    bool rendering_3d = false;
    bool compute = false;
};

struct BackendCandidate {
    GraphicsApi api = GraphicsApi::automatic;
    BackendProbeStatus probe_status = BackendProbeStatus::not_compiled;
    BackendCapabilities capabilities{};
};

struct BackendRequirements {
    bool rendering_2d = true;
    bool rendering_3d = true;
    bool compute = false;
};

struct BackendSelectionRequest {
    Platform platform = Platform::unknown;
    GraphicsApi preferred_api = GraphicsApi::automatic;
    BackendRequirements required_capabilities{};
    // Explicit preferences are strict by default; fallback requires opt-in.
    bool allow_fallback = false;
};

enum class BackendSelectionStatus : std::uint8_t {
    selected,
    no_compatible_backend,
    preferred_backend_unavailable,
    invalid_request
};

enum class BackendSelectionReason : std::uint8_t {
    platform_default,
    explicit_preference,
    fallback,
    backend_not_registered,
    backend_not_ready,
    unsupported_platform,
    missing_capabilities,
    duplicate_backend_registration,
    unknown_platform
};

struct BackendSelectionResult {
    BackendSelectionStatus status = BackendSelectionStatus::no_compatible_backend;
    BackendSelectionReason reason = BackendSelectionReason::backend_not_registered;
    GraphicsApi api = GraphicsApi::automatic;

    [[nodiscard]] bool selected() const noexcept {
        return status == BackendSelectionStatus::selected;
    }
};

// One candidate represents one API backend on the active platform. GPU device
// enumeration and device selection are responsibilities of the backend layer.
[[nodiscard]] BackendSelectionResult select_graphics_backend(
    const BackendSelectionRequest& request,
    const std::vector<BackendCandidate>& candidates);

[[nodiscard]] Platform build_platform() noexcept;

}  // namespace hwcontrol::game::graphics
