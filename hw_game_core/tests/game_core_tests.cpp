#include "hw_game_core/graphics/backend_selection.hpp"
#include "hw_game_core/graphics/device.hpp"
#include "hw_game_core/graphics/gpu_types.hpp"
#include "hw_game_core/graphics/render_graph.hpp"

#include <cstdlib>
#include <iostream>
#include <vector>

namespace {

int failures = 0;

#define CHECK(condition)                                                              \
    do {                                                                              \
        if (!(condition)) {                                                           \
            std::cerr << "FAIL: " << __FILE__ << ':' << __LINE__                      \
                      << ": " << #condition << '\n';                                \
            ++failures;                                                              \
        }                                                                             \
    } while (false)

using namespace hwcontrol::game::graphics;

BackendCandidate ready(GraphicsApi api, bool compute = false) {
    return BackendCandidate{
        api, BackendProbeStatus::ready, BackendCapabilities{true, true, compute}
    };
}

void test_gpu_contracts() {
    const BufferDesc valid_buffer{4096, BufferUsage::vertex | BufferUsage::transfer_destination,
                                  true, "vertex-buffer"};
    CHECK(is_valid(valid_buffer));
    CHECK(has_flag(valid_buffer.usage, BufferUsage::vertex));
    CHECK(!is_valid(BufferDesc{}));

    const TextureDesc valid_texture{1920, 1080, 1, 1, 1,
                                    TextureFormat::rgba8_unorm,
                                    TextureUsage::sampled | TextureUsage::color_attachment,
                                    "scene-color"};
    CHECK(is_valid(valid_texture));
    CHECK(has_flag(valid_texture.usage, TextureUsage::sampled));
    CHECK(!is_valid(TextureDesc{}));

    CHECK(ResourceHandle{}.valid() == false);
    CHECK((ResourceHandle{7, 1}.valid()));
    CHECK(!(ResourceHandle{7, 1} == ResourceHandle{7, 2}));

    const auto success = GraphicsResult<int>::success(42);
    CHECK(success.ok());
    CHECK(success.value.has_value());
    CHECK(*success.value == 42);
    const auto failure = GraphicsResult<int>::failure(
        GraphicsStatus::device_lost, "device removed");
    CHECK(!failure.ok());
    CHECK(!failure.value.has_value());
    CHECK(failure.status == GraphicsStatus::device_lost);
}

void test_backend_selection() {
    {
        BackendSelectionRequest request;
        request.platform = Platform::windows;
        const auto selected = select_graphics_backend(
            request, {ready(GraphicsApi::vulkan), ready(GraphicsApi::direct3d12)});
        CHECK(selected.selected());
        CHECK(selected.api == GraphicsApi::direct3d12);
        CHECK(selected.reason == BackendSelectionReason::platform_default);
    }
    {
        BackendSelectionRequest request;
        request.platform = Platform::windows;
        request.preferred_api = GraphicsApi::direct3d12;
        request.allow_fallback = true;
        const auto selected = select_graphics_backend(request, {
            BackendCandidate{GraphicsApi::direct3d12,
                             BackendProbeStatus::no_compatible_device, {}},
            ready(GraphicsApi::vulkan)
        });
        CHECK(selected.selected());
        CHECK(selected.api == GraphicsApi::vulkan);
        CHECK(selected.reason == BackendSelectionReason::fallback);
    }
    {
        BackendSelectionRequest request;
        request.platform = Platform::windows;
        request.preferred_api = GraphicsApi::direct3d12;
        const auto selected = select_graphics_backend(request, {ready(GraphicsApi::vulkan)});
        CHECK(selected.status == BackendSelectionStatus::preferred_backend_unavailable);
        CHECK(selected.reason == BackendSelectionReason::backend_not_registered);
    }
    {
        BackendSelectionRequest request;
        request.platform = Platform::linux;
        request.preferred_api = GraphicsApi::direct3d12;
        request.allow_fallback = true;
        const auto selected = select_graphics_backend(request, {ready(GraphicsApi::vulkan)});
        CHECK(selected.selected());
        CHECK(selected.api == GraphicsApi::vulkan);
    }
    {
        BackendSelectionRequest request;
        request.platform = Platform::linux;
        request.preferred_api = GraphicsApi::direct3d12;
        const auto selected = select_graphics_backend(
            request, {ready(GraphicsApi::direct3d12)});
        CHECK(selected.status == BackendSelectionStatus::preferred_backend_unavailable);
        CHECK(selected.reason == BackendSelectionReason::unsupported_platform);
    }
    {
        BackendSelectionRequest request;
        request.platform = Platform::macos;
        const auto selected = select_graphics_backend(
            request, {ready(GraphicsApi::vulkan), ready(GraphicsApi::metal)});
        CHECK(selected.selected());
        CHECK(selected.api == GraphicsApi::metal);
    }
    {
        BackendSelectionRequest request;
        request.platform = Platform::macos;
        request.preferred_api = GraphicsApi::vulkan;
        const auto selected = select_graphics_backend(request, {ready(GraphicsApi::vulkan)});
        CHECK(selected.selected());
        CHECK(selected.api == GraphicsApi::vulkan);
    }
    {
        BackendSelectionRequest request;
        request.platform = Platform::windows;
        request.required_capabilities.compute = true;
        const auto selected = select_graphics_backend(request, {ready(GraphicsApi::direct3d12)});
        CHECK(!selected.selected());
        CHECK(selected.reason == BackendSelectionReason::missing_capabilities);
    }
    {
        BackendSelectionRequest request;
        request.platform = Platform::windows;
        const auto selected = select_graphics_backend(request, {
            ready(GraphicsApi::direct3d12), ready(GraphicsApi::direct3d12)
        });
        CHECK(selected.status == BackendSelectionStatus::invalid_request);
        CHECK(selected.reason == BackendSelectionReason::duplicate_backend_registration);
    }
    {
        BackendSelectionRequest request;
        request.platform = Platform::unknown;
        const auto selected = select_graphics_backend(request, {});
        CHECK(selected.status == BackendSelectionStatus::invalid_request);
        CHECK(selected.reason == BackendSelectionReason::unknown_platform);
    }
    CHECK(build_platform() != Platform::unknown);
}

void test_render_graph_hazards_and_order() {
    RenderGraph graph;
    const auto scene_color = graph.create_resource("scene-color", true);
    const auto post_process = graph.create_resource("post-process");
    const auto present = graph.create_resource("present-target", true);

    const auto geometry = graph.add_pass("geometry");
    const auto post = graph.add_pass("post-process");
    const auto composite = graph.add_pass("composite");

    CHECK(graph.use(geometry, scene_color, ResourceAccess::write));
    CHECK(graph.use(post, scene_color, ResourceAccess::read));
    CHECK(graph.use(post, post_process, ResourceAccess::write));
    CHECK(graph.use(composite, post_process, ResourceAccess::read));
    CHECK(graph.use(composite, present, ResourceAccess::write));

    const auto plan = graph.compile();
    CHECK(plan.valid);
    CHECK(plan.execution_order.size() == 3);
    CHECK(plan.execution_order[0] == geometry);
    CHECK(plan.execution_order[1] == post);
    CHECK(plan.execution_order[2] == composite);
    CHECK(plan.dependency_count >= 2);
}

void test_render_graph_determinism_and_write_after_read() {
    RenderGraph graph;
    const auto shared = graph.create_resource("shared", true);
    const auto reader_a = graph.add_pass("reader-a");
    const auto reader_b = graph.add_pass("reader-b");
    const auto writer = graph.add_pass("writer");
    const auto independent = graph.add_pass("independent");

    CHECK(graph.use(reader_a, shared, ResourceAccess::read));
    CHECK(graph.use(reader_b, shared, ResourceAccess::read));
    CHECK(graph.use(writer, shared, ResourceAccess::write));

    const auto plan = graph.compile();
    CHECK(plan.valid);
    CHECK(plan.execution_order.size() == 4);
    CHECK(plan.execution_order[0] == reader_a);
    CHECK(plan.execution_order[1] == reader_b);
    CHECK(plan.execution_order[2] == writer);
    CHECK(plan.execution_order[3] == independent);
}


void test_render_graph_write_after_write() {
    RenderGraph graph;
    const auto shared = graph.create_resource("shared", true);
    const auto write_a = graph.add_pass("write-a");
    const auto read_after_a = graph.add_pass("read-after-a");
    const auto write_b = graph.add_pass("write-b");
    CHECK(graph.use(write_a, shared, ResourceAccess::write));
    CHECK(graph.use(read_after_a, shared, ResourceAccess::read));
    CHECK(graph.use(write_b, shared, ResourceAccess::write));

    const auto plan = graph.compile();
    CHECK(plan.valid);
    CHECK(plan.execution_order.size() == 3);
    CHECK(plan.execution_order[0] == write_a);
    CHECK(plan.execution_order[1] == read_after_a);
    CHECK(plan.execution_order[2] == write_b);
}

void test_render_graph_rejects_invalid_patterns() {
    {
        RenderGraph graph;
        const auto transient = graph.create_resource("transient");
        const auto pass = graph.add_pass("read-before-write");
        CHECK(graph.use(pass, transient, ResourceAccess::read));
        const auto plan = graph.compile();
        CHECK(!plan.valid);
        CHECK(plan.diagnostics.front().code ==
              RenderGraphDiagnostic::Code::read_before_write);
    }
    {
        RenderGraph graph;
        const auto imported = graph.create_resource("imported", true);
        const auto pass = graph.add_pass("invalid-access");
        CHECK(graph.use(pass, imported, static_cast<ResourceAccess>(255)));
        const auto plan = graph.compile();
        CHECK(!plan.valid);
        CHECK(plan.diagnostics.front().code ==
              RenderGraphDiagnostic::Code::invalid_resource_access);
    }
    {
        RenderGraph graph;
        const auto resource = graph.create_resource("resource", true);
        const auto pass = graph.add_pass("duplicate-use");
        CHECK(graph.use(pass, resource, ResourceAccess::read));
        CHECK(graph.use(pass, resource, ResourceAccess::write));
        const auto plan = graph.compile();
        CHECK(!plan.valid);
        CHECK(plan.diagnostics.front().code ==
              RenderGraphDiagnostic::Code::duplicate_resource_use);
    }
    {
        RenderGraph graph;
        const auto resource = graph.create_resource("resource", true);
        const auto pass = graph.add_pass("pass");
        CHECK(!graph.use(PassId{999}, resource, ResourceAccess::read));
        CHECK(!graph.use(pass, ResourceId{999}, ResourceAccess::read));
        CHECK(!graph.depends_on(PassId{999}, pass));
    }
    {
        RenderGraph graph;
        const auto pass_a = graph.add_pass("a");
        const auto pass_b = graph.add_pass("b");
        CHECK(graph.depends_on(pass_a, pass_b));
        CHECK(graph.depends_on(pass_b, pass_a));
        const auto plan = graph.compile();
        CHECK(!plan.valid);
        CHECK(plan.diagnostics.back().code ==
              RenderGraphDiagnostic::Code::dependency_cycle);
    }
    {
        RenderGraph graph;
        const auto pass = graph.add_pass("self-dependent");
        CHECK(graph.depends_on(pass, pass));
        const auto plan = graph.compile();
        CHECK(!plan.valid);
        CHECK(plan.diagnostics.front().code ==
              RenderGraphDiagnostic::Code::self_dependency);
    }
    {
        RenderGraph graph;
        const auto empty = graph.compile();
        CHECK(empty.valid);
        CHECK(empty.execution_order.empty());
    }
}

}  // namespace

int main() {
    test_gpu_contracts();
    test_backend_selection();
    test_render_graph_hazards_and_order();
    test_render_graph_determinism_and_write_after_read();
    test_render_graph_write_after_write();
    test_render_graph_rejects_invalid_patterns();

    if (failures != 0) {
        std::cerr << failures << " Game Core test(s) failed\n";
        return EXIT_FAILURE;
    }
    std::cout << "All Game Core foundation tests passed\n";
    return EXIT_SUCCESS;
}
