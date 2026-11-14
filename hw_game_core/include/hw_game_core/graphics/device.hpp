#pragma once

#include "hw_game_core/graphics/backend_selection.hpp"
#include "hw_game_core/graphics/gpu_types.hpp"

#include <optional>
#include <string>

namespace hwcontrol::game::graphics {

struct GraphicsDeviceInfo {
    GraphicsApi api = GraphicsApi::automatic;
    AdapterInfo adapter;
    BackendCapabilities capabilities;
    std::uint32_t api_major = 0;
    std::uint32_t api_minor = 0;
    std::uint64_t local_memory_budget = 0;
    std::uint64_t local_memory_usage = 0;
};

template <typename T>
struct GraphicsResult {
    GraphicsStatus status = GraphicsStatus::backend_error;
    std::optional<T> value;
    std::string diagnostic;

    [[nodiscard]] bool ok() const noexcept {
        return status == GraphicsStatus::success && value.has_value();
    }

    [[nodiscard]] static GraphicsResult success(T result) {
        return {GraphicsStatus::success, std::move(result), {}};
    }

    [[nodiscard]] static GraphicsResult failure(
        GraphicsStatus error, std::string message) {
        return {error, std::nullopt, std::move(message)};
    }
};

class IGraphicsDevice {
public:
    virtual ~IGraphicsDevice() = default;

    [[nodiscard]] virtual const GraphicsDeviceInfo& info() const noexcept = 0;
    [[nodiscard]] virtual GraphicsResult<ResourceHandle> create_buffer(
        const BufferDesc& desc) = 0;
    [[nodiscard]] virtual GraphicsResult<ResourceHandle> create_texture(
        const TextureDesc& desc) = 0;
    [[nodiscard]] virtual GraphicsStatus destroy_resource(
        ResourceHandle resource) noexcept = 0;
    [[nodiscard]] virtual GraphicsStatus wait_idle() noexcept = 0;
};

// Backend factories must report failure explicitly. A factory must not return
// a device merely because the corresponding SDK or loader is present.
struct BackendCreateRequest {
    bool enable_debug_validation = false;
    bool prefer_high_performance_adapter = true;
    bool allow_software_adapter = false;
};

class IGraphicsBackend {
public:
    virtual ~IGraphicsBackend() = default;

    [[nodiscard]] virtual GraphicsApi api() const noexcept = 0;
    [[nodiscard]] virtual BackendCandidate probe() const = 0;
    [[nodiscard]] virtual GraphicsResult<std::unique_ptr<IGraphicsDevice>>
    create_device(const BackendCreateRequest& request) = 0;
};

}  // namespace hwcontrol::game::graphics
