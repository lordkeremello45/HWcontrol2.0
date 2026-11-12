#pragma once

#include <cstddef>
#include <cstdint>
#include <limits>
#include <string>
#include <vector>

namespace hwcontrol::game::graphics {

struct ResourceId {
    std::uint32_t value = std::numeric_limits<std::uint32_t>::max();
    friend bool operator==(const ResourceId&, const ResourceId&) = default;
};

struct PassId {
    std::uint32_t value = std::numeric_limits<std::uint32_t>::max();
    friend bool operator==(const PassId&, const PassId&) = default;
};

inline constexpr ResourceId invalid_resource_id{};
inline constexpr PassId invalid_pass_id{};

enum class ResourceAccess : std::uint8_t { read, write, read_write };

struct RenderGraphDiagnostic {
    enum class Code : std::uint8_t {
        empty_resource_name,
        empty_pass_name,
        invalid_resource,
        invalid_pass,
        duplicate_resource_use,
        invalid_resource_access,
        read_before_write,
        self_dependency,
        dependency_cycle
    };

    Code code = Code::invalid_resource;
    PassId pass = invalid_pass_id;
    ResourceId resource = invalid_resource_id;
};

struct RenderGraphPlan {
    bool valid = false;
    std::vector<PassId> execution_order;
    std::vector<RenderGraphDiagnostic> diagnostics;
    std::size_t dependency_count = 0;
};

class RenderGraph final {
public:
    // Imported resources have contents at frame start. Transient resources
    // must be written before their first read.
    [[nodiscard]] ResourceId create_resource(std::string name, bool imported = false);
    [[nodiscard]] PassId add_pass(std::string name);

    // Each pass declares a resource at most once. read_write consumes the
    // previous contents and then produces new contents.
    [[nodiscard]] bool use(PassId pass, ResourceId resource, ResourceAccess access);
    [[nodiscard]] bool depends_on(PassId pass, PassId prerequisite);

    // Compiles explicit dependencies and RAW/WAR/WAW hazards into a
    // deterministic topological execution order.
    [[nodiscard]] RenderGraphPlan compile() const;

private:
    struct Resource {
        std::string name;
        bool imported = false;
    };
    struct ResourceUse {
        ResourceId resource{};
        ResourceAccess access = ResourceAccess::read;
    };
    struct Pass {
        std::string name;
        std::vector<ResourceUse> resources;
        std::vector<PassId> prerequisites;
    };

    std::vector<Resource> resources_;
    std::vector<Pass> passes_;
};

}  // namespace hwcontrol::game::graphics
