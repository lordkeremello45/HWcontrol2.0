#include "hw_game_core/graphics/backend_selection.hpp"

#include <array>
#include <cstddef>

namespace hwcontrol::game::graphics {
namespace {

struct AttemptResult {
    bool selected = false;
    BackendSelectionReason reason = BackendSelectionReason::backend_not_registered;
};

[[nodiscard]] bool api_supported_on_platform(GraphicsApi api, Platform platform) noexcept {
    switch (api) {
        case GraphicsApi::direct3d12:
            return platform == Platform::windows;
        case GraphicsApi::vulkan:
            return platform == Platform::windows ||
                   platform == Platform::linux ||
                   platform == Platform::macos;
        case GraphicsApi::metal:
            return platform == Platform::macos;
        case GraphicsApi::automatic:
            return false;
    }
    return false;
}

[[nodiscard]] bool has_required_capabilities(
    const BackendCapabilities& available,
    const BackendRequirements& required) noexcept {
    return (!required.rendering_2d || available.rendering_2d) &&
           (!required.rendering_3d || available.rendering_3d) &&
           (!required.compute || available.compute);
}

[[nodiscard]] AttemptResult attempt_api(
    GraphicsApi api,
    Platform platform,
    const BackendRequirements& required,
    const std::vector<BackendCandidate>& candidates,
    BackendSelectionResult& result) {
    if (!api_supported_on_platform(api, platform)) {
        return {false, BackendSelectionReason::unsupported_platform};
    }

    const BackendCandidate* match = nullptr;
    for (const auto& candidate : candidates) {
        if (candidate.api != api) {
            continue;
        }
        if (match != nullptr) {
            result.status = BackendSelectionStatus::invalid_request;
            result.reason = BackendSelectionReason::duplicate_backend_registration;
            return {false, result.reason};
        }
        match = &candidate;
    }

    if (match == nullptr) {
        return {false, BackendSelectionReason::backend_not_registered};
    }
    if (match->probe_status != BackendProbeStatus::ready) {
        return {false, BackendSelectionReason::backend_not_ready};
    }
    if (!has_required_capabilities(match->capabilities, required)) {
        return {false, BackendSelectionReason::missing_capabilities};
    }

    result.status = BackendSelectionStatus::selected;
    result.api = api;
    return {true, BackendSelectionReason::platform_default};
}

[[nodiscard]] std::array<GraphicsApi, 2> platform_priority(
    Platform platform,
    std::size_t& count) noexcept {
    count = 0;
    switch (platform) {
        case Platform::windows:
            count = 2;
            return {GraphicsApi::direct3d12, GraphicsApi::vulkan};
        case Platform::linux:
            count = 1;
            return {GraphicsApi::vulkan, GraphicsApi::automatic};
        case Platform::macos:
            count = 2;
            return {GraphicsApi::metal, GraphicsApi::vulkan};
        case Platform::unknown:
            return {GraphicsApi::automatic, GraphicsApi::automatic};
    }
    return {GraphicsApi::automatic, GraphicsApi::automatic};
}

}  // namespace

BackendSelectionResult select_graphics_backend(
    const BackendSelectionRequest& request,
    const std::vector<BackendCandidate>& candidates) {
    BackendSelectionResult result;

    if (request.platform == Platform::unknown) {
        result.status = BackendSelectionStatus::invalid_request;
        result.reason = BackendSelectionReason::unknown_platform;
        return result;
    }

    if (request.preferred_api != GraphicsApi::automatic) {
        const auto preferred = attempt_api(
            request.preferred_api, request.platform,
            request.required_capabilities, candidates, result);
        if (result.status == BackendSelectionStatus::invalid_request) {
            return result;
        }
        if (preferred.selected) {
            result.reason = BackendSelectionReason::explicit_preference;
            return result;
        }
        if (!request.allow_fallback) {
            result.status = BackendSelectionStatus::preferred_backend_unavailable;
            result.reason = preferred.reason;
            return result;
        }
        // Preserve the primary preference's failure reason. A later fallback
        // candidate being absent must not hide a more useful probe failure.
        result.reason = preferred.reason;

        std::size_t priority_count = 0;
        const auto priority = platform_priority(request.platform, priority_count);
        for (std::size_t index = 0; index < priority_count; ++index) {
            const auto api = priority[index];
            if (api == request.preferred_api) {
                continue;
            }
            const auto fallback = attempt_api(
                api, request.platform, request.required_capabilities, candidates, result);
            if (result.status == BackendSelectionStatus::invalid_request) {
                return result;
            }
            if (fallback.selected) {
                result.reason = BackendSelectionReason::fallback;
                return result;
            }
        }

        result.status = BackendSelectionStatus::no_compatible_backend;
        return result;
    }

    std::size_t priority_count = 0;
    const auto priority = platform_priority(request.platform, priority_count);
    bool has_primary_failure = false;
    for (std::size_t index = 0; index < priority_count; ++index) {
        const auto attempt = attempt_api(
            priority[index], request.platform,
            request.required_capabilities, candidates, result);
        if (result.status == BackendSelectionStatus::invalid_request) {
            return result;
        }
        if (attempt.selected) {
            result.reason = BackendSelectionReason::platform_default;
            return result;
        }
        if (!has_primary_failure) {
            result.reason = attempt.reason;
            has_primary_failure = true;
        }
    }

    result.status = BackendSelectionStatus::no_compatible_backend;
    return result;
}

Platform build_platform() noexcept {
#if defined(_WIN32)
    return Platform::windows;
#elif defined(__APPLE__) && defined(__MACH__)
    return Platform::macos;
#elif defined(__linux__)
    return Platform::linux;
#else
    return Platform::unknown;
#endif
}

}  // namespace hwcontrol::game::graphics
