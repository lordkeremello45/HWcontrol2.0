#pragma once

#include <cstdint>
#include <limits>
#include <string>

namespace hwcontrol::game::graphics {

enum class GraphicsStatus : std::uint8_t {
    success,
    invalid_argument,
    unsupported,
    out_of_memory,
    device_lost,
    timeout,
    backend_error
};

enum class QueueType : std::uint8_t { graphics, compute, copy };
enum class BufferUsage : std::uint32_t {
    none = 0,
    vertex = 1U << 0U,
    index = 1U << 1U,
    uniform = 1U << 2U,
    storage = 1U << 3U,
    transfer_source = 1U << 4U,
    transfer_destination = 1U << 5U
};

enum class TextureFormat : std::uint8_t {
    rgba8_unorm,
    bgra8_unorm,
    rgba16_float,
    depth24_stencil8,
    depth32_float
};

enum class TextureUsage : std::uint32_t {
    none = 0,
    sampled = 1U << 0U,
    storage = 1U << 1U,
    color_attachment = 1U << 2U,
    depth_stencil_attachment = 1U << 3U,
    transfer_source = 1U << 4U,
    transfer_destination = 1U << 5U
};

template <typename Enum>
[[nodiscard]] constexpr Enum operator|(Enum lhs, Enum rhs) noexcept
    requires requires { static_cast<std::uint32_t>(lhs); }
{
    return static_cast<Enum>(
        static_cast<std::uint32_t>(lhs) | static_cast<std::uint32_t>(rhs));
}

template <typename Enum>
[[nodiscard]] constexpr bool has_flag(Enum value, Enum flag) noexcept
    requires requires { static_cast<std::uint32_t>(value); }
{
    return (static_cast<std::uint32_t>(value) &
            static_cast<std::uint32_t>(flag)) ==
           static_cast<std::uint32_t>(flag);
}

struct BufferDesc {
    std::uint64_t size = 0;
    BufferUsage usage = BufferUsage::none;
    bool host_visible = false;
    std::string debug_name;
};

struct TextureDesc {
    std::uint32_t width = 0;
    std::uint32_t height = 0;
    std::uint32_t mip_levels = 1;
    std::uint32_t array_layers = 1;
    std::uint32_t sample_count = 1;
    TextureFormat format = TextureFormat::rgba8_unorm;
    TextureUsage usage = TextureUsage::none;
    std::string debug_name;
};

struct ResourceHandle {
    std::uint32_t index = std::numeric_limits<std::uint32_t>::max();
    std::uint32_t generation = 0;

    [[nodiscard]] constexpr bool valid() const noexcept {
        return index != std::numeric_limits<std::uint32_t>::max() &&
               generation != 0;
    }

    friend constexpr bool operator==(ResourceHandle, ResourceHandle) = default;
};

struct AdapterInfo {
    std::string name;
    std::uint32_t vendor_id = 0;
    std::uint32_t device_id = 0;
    std::uint64_t dedicated_video_memory = 0;
    bool software = false;
};

[[nodiscard]] constexpr bool is_valid(const BufferDesc& desc) noexcept {
    return desc.size > 0 && desc.usage != BufferUsage::none;
}

[[nodiscard]] constexpr bool is_valid(const TextureDesc& desc) noexcept {
    return desc.width > 0 && desc.height > 0 &&
           desc.mip_levels > 0 && desc.array_layers > 0 &&
           desc.sample_count > 0 && desc.usage != TextureUsage::none;
}

}  // namespace hwcontrol::game::graphics
