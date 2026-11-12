#include "hw_game_core/graphics/render_graph.hpp"

#include <algorithm>
#include <functional>
#include <queue>
#include <utility>

namespace hwcontrol::game::graphics {
namespace {

[[nodiscard]] bool is_read(ResourceAccess access) noexcept {
    return access == ResourceAccess::read || access == ResourceAccess::read_write;
}

[[nodiscard]] bool is_write(ResourceAccess access) noexcept {
    return access == ResourceAccess::write || access == ResourceAccess::read_write;
}

[[nodiscard]] bool is_valid_access(ResourceAccess access) noexcept {
    return access == ResourceAccess::read ||
           access == ResourceAccess::write ||
           access == ResourceAccess::read_write;
}

}  // namespace

ResourceId RenderGraph::create_resource(std::string name, bool imported) {
    if (resources_.size() >= invalid_resource_id.value) {
        return invalid_resource_id;
    }
    const auto id = ResourceId{static_cast<std::uint32_t>(resources_.size())};
    resources_.push_back(Resource{std::move(name), imported});
    return id;
}

PassId RenderGraph::add_pass(std::string name) {
    if (passes_.size() >= invalid_pass_id.value) {
        return invalid_pass_id;
    }
    const auto id = PassId{static_cast<std::uint32_t>(passes_.size())};
    passes_.push_back(Pass{std::move(name), {}, {}});
    return id;
}

bool RenderGraph::use(PassId pass, ResourceId resource, ResourceAccess access) {
    if (pass.value >= passes_.size() || resource.value >= resources_.size()) {
        return false;
    }
    passes_[pass.value].resources.push_back(ResourceUse{resource, access});
    return true;
}

bool RenderGraph::depends_on(PassId pass, PassId prerequisite) {
    if (pass.value >= passes_.size() || prerequisite.value >= passes_.size()) {
        return false;
    }
    passes_[pass.value].prerequisites.push_back(prerequisite);
    return true;
}

RenderGraphPlan RenderGraph::compile() const {
    RenderGraphPlan plan;
    const std::size_t pass_count = passes_.size();
    const std::size_t resource_count = resources_.size();

    std::vector<std::vector<std::size_t>> edges(pass_count);
    std::vector<std::int64_t> last_writer(resource_count, -1);
    std::vector<std::vector<std::size_t>> active_readers(resource_count);
    std::vector<bool> initialized(resource_count, false);

    for (std::size_t resource = 0; resource < resource_count; ++resource) {
        initialized[resource] = resources_[resource].imported;
        if (resources_[resource].name.empty()) {
            plan.diagnostics.push_back({
                RenderGraphDiagnostic::Code::empty_resource_name,
                invalid_pass_id,
                ResourceId{static_cast<std::uint32_t>(resource)}
            });
        }
    }

    const auto add_edge = [&edges](std::size_t from, std::size_t to) {
        if (from < edges.size() && to < edges.size() && from != to) {
            edges[from].push_back(to);
        }
    };

    for (std::size_t pass_index = 0; pass_index < pass_count; ++pass_index) {
        const auto& pass = passes_[pass_index];
        const PassId pass_id{static_cast<std::uint32_t>(pass_index)};

        if (pass.name.empty()) {
            plan.diagnostics.push_back({
                RenderGraphDiagnostic::Code::empty_pass_name, pass_id, invalid_resource_id
            });
        }

        std::vector<bool> seen_resources(resource_count, false);
        for (const auto& usage : pass.resources) {
            if (usage.resource.value >= resource_count) {
                plan.diagnostics.push_back({
                    RenderGraphDiagnostic::Code::invalid_resource, pass_id, usage.resource
                });
                continue;
            }
            if (!is_valid_access(usage.access)) {
                plan.diagnostics.push_back({
                    RenderGraphDiagnostic::Code::invalid_resource_access,
                    pass_id, usage.resource
                });
                continue;
            }
            if (seen_resources[usage.resource.value]) {
                plan.diagnostics.push_back({
                    RenderGraphDiagnostic::Code::duplicate_resource_use,
                    pass_id, usage.resource
                });
                continue;
            }
            seen_resources[usage.resource.value] = true;

            const std::size_t resource_index = usage.resource.value;
            const bool reads = is_read(usage.access);
            const bool writes = is_write(usage.access);

            if (reads && !initialized[resource_index]) {
                plan.diagnostics.push_back({
                    RenderGraphDiagnostic::Code::read_before_write,
                    pass_id, usage.resource
                });
            }

            if (last_writer[resource_index] >= 0) {
                add_edge(static_cast<std::size_t>(last_writer[resource_index]), pass_index);
            }

            if (writes) {
                for (const auto reader : active_readers[resource_index]) {
                    add_edge(reader, pass_index);
                }
                active_readers[resource_index].clear();
                last_writer[resource_index] = static_cast<std::int64_t>(pass_index);
                initialized[resource_index] = true;
            } else if (reads) {
                active_readers[resource_index].push_back(pass_index);
            }
        }

        for (const auto prerequisite : pass.prerequisites) {
            if (prerequisite.value >= pass_count) {
                plan.diagnostics.push_back({
                    RenderGraphDiagnostic::Code::invalid_pass, pass_id, invalid_resource_id
                });
                continue;
            }
            if (prerequisite.value == pass_index) {
                plan.diagnostics.push_back({
                    RenderGraphDiagnostic::Code::self_dependency, pass_id, invalid_resource_id
                });
                continue;
            }
            add_edge(prerequisite.value, pass_index);
        }
    }

    std::vector<std::size_t> indegree(pass_count, 0);
    for (auto& outgoing : edges) {
        std::sort(outgoing.begin(), outgoing.end());
        outgoing.erase(std::unique(outgoing.begin(), outgoing.end()), outgoing.end());
        plan.dependency_count += outgoing.size();
        for (const auto destination : outgoing) {
            ++indegree[destination];
        }
    }

    // A min-heap keeps output stable when several passes are ready together.
    std::priority_queue<std::size_t, std::vector<std::size_t>, std::greater<std::size_t>> ready;
    for (std::size_t pass = 0; pass < pass_count; ++pass) {
        if (indegree[pass] == 0) {
            ready.push(pass);
        }
    }

    std::vector<PassId> order;
    order.reserve(pass_count);
    while (!ready.empty()) {
        const auto pass = ready.top();
        ready.pop();
        order.push_back(PassId{static_cast<std::uint32_t>(pass)});
        for (const auto destination : edges[pass]) {
            --indegree[destination];
            if (indegree[destination] == 0) {
                ready.push(destination);
            }
        }
    }

    if (order.size() != pass_count) {
        plan.diagnostics.push_back({
            RenderGraphDiagnostic::Code::dependency_cycle,
            invalid_pass_id,
            invalid_resource_id
        });
    }

    if (plan.diagnostics.empty()) {
        plan.valid = true;
        plan.execution_order = std::move(order);
    }
    return plan;
}

}  // namespace hwcontrol::game::graphics
