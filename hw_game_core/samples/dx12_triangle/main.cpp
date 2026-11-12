#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>

#include <d3d12.h>
#include <d3dcompiler.h>
#include <dxgi1_6.h>
#include <wrl/client.h>

#include <array>
#include <climits>
#include <cstdint>
#include <cstring>
#include <exception>
#include <iomanip>
#include <sstream>
#include <stdexcept>
#include <string>

using Microsoft::WRL::ComPtr;

namespace {

constexpr UINT kFrameCount = 2;
constexpr UINT kWindowWidth = 1280;
constexpr UINT kWindowHeight = 720;
constexpr DXGI_FORMAT kColorFormat = DXGI_FORMAT_R8G8B8A8_UNORM;

[[noreturn]] void throw_hresult(const char* operation, HRESULT hr) {
    std::ostringstream message;
    message << operation << " failed (HRESULT 0x" << std::hex
            << static_cast<unsigned long>(hr) << ')';
    throw std::runtime_error(message.str());
}

void check_hresult(HRESULT hr, const char* operation) {
    if (FAILED(hr)) {
        throw_hresult(operation, hr);
    }
}

struct Vertex {
    float position[3];
    float color[4];
};

constexpr std::array<Vertex, 3> kVertices{{
    {{0.0F, 0.55F, 0.0F}, {0.15F, 0.75F, 1.0F, 1.0F}},
    {{0.55F, -0.45F, 0.0F}, {0.15F, 0.75F, 1.0F, 1.0F}},
    {{-0.55F, -0.45F, 0.0F}, {0.15F, 0.75F, 1.0F, 1.0F}},
}};

constexpr char kShaderSource[] = R"(
struct VertexInput {
    float3 position : POSITION;
    float4 color : COLOR;
};
struct VertexOutput {
    float4 position : SV_POSITION;
    float4 color : COLOR;
};
VertexOutput VSMain(VertexInput input) {
    VertexOutput output;
    output.position = float4(input.position, 1.0);
    output.color = input.color;
    return output;
}
float4 PSMain(VertexOutput input) : SV_TARGET {
    return input.color;
}
)";

LRESULT CALLBACK window_proc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
    if (message == WM_DESTROY) {
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(window, message, wparam, lparam);
}

class Dx12Triangle final {
public:
    explicit Dx12Triangle(HWND window) : window_(window) {
        create_device();
        create_swap_chain();
        create_render_targets();
        create_command_objects();
        create_pipeline();
        create_vertex_buffer();
        viewport_ = {0.0F, 0.0F, static_cast<float>(kWindowWidth),
                     static_cast<float>(kWindowHeight), 0.0F, 1.0F};
        scissor_ = {0, 0, static_cast<LONG>(kWindowWidth),
                    static_cast<LONG>(kWindowHeight)};
    }

    ~Dx12Triangle() {
        if (queue_ && fence_) {
            wait_for_gpu();
        }
        if (fence_event_ != nullptr) {
            CloseHandle(fence_event_);
        }
    }

    Dx12Triangle(const Dx12Triangle&) = delete;
    Dx12Triangle& operator=(const Dx12Triangle&) = delete;

    void render() {
        const UINT frame_index = swap_chain_->GetCurrentBackBufferIndex();
        wait_for_frame(frame_index);

        check_hresult(allocators_[frame_index]->Reset(), "CommandAllocator::Reset");
        check_hresult(command_list_->Reset(allocators_[frame_index].Get(), pipeline_.Get()),
                      "GraphicsCommandList::Reset");

        D3D12_RESOURCE_BARRIER to_target{};
        to_target.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        to_target.Transition.pResource = render_targets_[frame_index].Get();
        to_target.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        to_target.Transition.StateBefore = D3D12_RESOURCE_STATE_PRESENT;
        to_target.Transition.StateAfter = D3D12_RESOURCE_STATE_RENDER_TARGET;
        command_list_->ResourceBarrier(1, &to_target);

        const D3D12_CPU_DESCRIPTOR_HANDLE target =
            rtv_heap_->GetCPUDescriptorHandleForHeapStart();
        D3D12_CPU_DESCRIPTOR_HANDLE current_target = target;
        current_target.ptr += static_cast<SIZE_T>(frame_index) * rtv_descriptor_size_;

        constexpr float clear_color[4]{0.025F, 0.035F, 0.065F, 1.0F};
        command_list_->OMSetRenderTargets(1, &current_target, FALSE, nullptr);
        command_list_->ClearRenderTargetView(current_target, clear_color, 0, nullptr);
        command_list_->RSSetViewports(1, &viewport_);
        command_list_->RSSetScissorRects(1, &scissor_);
        command_list_->IASetPrimitiveTopology(D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
        command_list_->IASetVertexBuffers(0, 1, &vertex_view_);
        command_list_->DrawInstanced(3, 1, 0, 0);

        D3D12_RESOURCE_BARRIER to_present{};
        to_present.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
        to_present.Transition.pResource = render_targets_[frame_index].Get();
        to_present.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        to_present.Transition.StateBefore = D3D12_RESOURCE_STATE_RENDER_TARGET;
        to_present.Transition.StateAfter = D3D12_RESOURCE_STATE_PRESENT;
        command_list_->ResourceBarrier(1, &to_present);
        check_hresult(command_list_->Close(), "GraphicsCommandList::Close");

        ID3D12CommandList* lists[]{command_list_.Get()};
        queue_->ExecuteCommandLists(1, lists);
        check_hresult(swap_chain_->Present(1, 0), "SwapChain::Present");

        const UINT64 signal_value = ++fence_value_;
        check_hresult(queue_->Signal(fence_.Get(), signal_value), "CommandQueue::Signal");
        frame_fence_values_[frame_index] = signal_value;
    }

    void wait_for_gpu() noexcept {
        if (!queue_ || !fence_ || fence_event_ == nullptr) {
            return;
        }
        const UINT64 value = ++fence_value_;
        if (SUCCEEDED(queue_->Signal(fence_.Get(), value)) &&
            fence_->GetCompletedValue() < value &&
            SUCCEEDED(fence_->SetEventOnCompletion(value, fence_event_))) {
            WaitForSingleObject(fence_event_, INFINITE);
        }
    }

private:
    void create_device() {
#if defined(_DEBUG)
        ComPtr<ID3D12Debug> debug;
        if (SUCCEEDED(D3D12GetDebugInterface(IID_PPV_ARGS(&debug)))) {
            debug->EnableDebugLayer();
        }
#endif
        // IDXGIFactory1 keeps the sample compatible with older Windows 10
        // releases; adapter preference APIs are not required for this MVP.
        ComPtr<IDXGIFactory1> factory;
        check_hresult(CreateDXGIFactory1(IID_PPV_ARGS(&factory)), "CreateDXGIFactory1");

        HRESULT device_result = E_FAIL;
        for (UINT index = 0;; ++index) {
            ComPtr<IDXGIAdapter1> adapter;
            if (factory->EnumAdapters1(index, &adapter) == DXGI_ERROR_NOT_FOUND) {
                break;
            }
            DXGI_ADAPTER_DESC1 description{};
            if (FAILED(adapter->GetDesc1(&description)) ||
                (description.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) != 0) {
                continue;
            }
            device_result = D3D12CreateDevice(
                adapter.Get(), D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(&device_));
            if (SUCCEEDED(device_result)) {
                break;
            }
        }
        if (!device_) {
            check_hresult(D3D12CreateDevice(
                nullptr, D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(&device_)),
                "D3D12CreateDevice (default adapter)");
        }
        D3D12_COMMAND_QUEUE_DESC queue_description{};
        queue_description.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
        queue_description.Priority = D3D12_COMMAND_QUEUE_PRIORITY_NORMAL;
        queue_description.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;
        queue_description.NodeMask = 0;
        check_hresult(device_->CreateCommandQueue(
            &queue_description, IID_PPV_ARGS(&queue_)), "CreateCommandQueue");
    }

    void create_swap_chain() {
        ComPtr<IDXGIFactory4> factory;
        check_hresult(CreateDXGIFactory1(IID_PPV_ARGS(&factory)), "CreateDXGIFactory1");
        DXGI_SWAP_CHAIN_DESC1 description{};
        description.Width = kWindowWidth;
        description.Height = kWindowHeight;
        description.Format = kColorFormat;
        description.SampleDesc.Count = 1;
        description.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
        description.BufferCount = kFrameCount;
        description.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
        ComPtr<IDXGISwapChain1> base_swap_chain;
        check_hresult(factory->CreateSwapChainForHwnd(
            queue_.Get(), window_, &description, nullptr, nullptr, &base_swap_chain),
            "CreateSwapChainForHwnd");
        check_hresult(base_swap_chain.As(&swap_chain_), "Query IDXGISwapChain3");
        check_hresult(factory->MakeWindowAssociation(window_, DXGI_MWA_NO_ALT_ENTER),
                      "MakeWindowAssociation");
    }

    void create_render_targets() {
        D3D12_DESCRIPTOR_HEAP_DESC heap_description{};
        heap_description.NumDescriptors = kFrameCount;
        heap_description.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
        check_hresult(device_->CreateDescriptorHeap(
            &heap_description, IID_PPV_ARGS(&rtv_heap_)), "CreateDescriptorHeap(RTV)");
        rtv_descriptor_size_ = device_->GetDescriptorHandleIncrementSize(
            D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
        auto handle = rtv_heap_->GetCPUDescriptorHandleForHeapStart();
        for (UINT index = 0; index < kFrameCount; ++index) {
            check_hresult(swap_chain_->GetBuffer(
                index, IID_PPV_ARGS(&render_targets_[index])), "SwapChain::GetBuffer");
            device_->CreateRenderTargetView(render_targets_[index].Get(), nullptr, handle);
            handle.ptr += rtv_descriptor_size_;
        }
    }

    void create_command_objects() {
        for (auto& allocator : allocators_) {
            check_hresult(device_->CreateCommandAllocator(
                D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(&allocator)),
                "CreateCommandAllocator");
        }
        check_hresult(device_->CreateCommandList(
            0, D3D12_COMMAND_LIST_TYPE_DIRECT, allocators_[0].Get(), nullptr,
            IID_PPV_ARGS(&command_list_)), "CreateCommandList");
        check_hresult(command_list_->Close(), "Initial CommandList::Close");
        check_hresult(device_->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&fence_)),
                      "CreateFence");
        fence_event_ = CreateEventW(nullptr, FALSE, FALSE, nullptr);
        if (fence_event_ == nullptr) {
            throw std::runtime_error("CreateEventW failed");
        }
    }

    void create_pipeline() {
        ComPtr<ID3DBlob> vertex_shader;
        ComPtr<ID3DBlob> pixel_shader;
        ComPtr<ID3DBlob> errors;
        const UINT compile_flags =
#if defined(_DEBUG)
            D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION;
#else
            D3DCOMPILE_OPTIMIZATION_LEVEL3;
#endif
        check_hresult(D3DCompile(kShaderSource, sizeof(kShaderSource) - 1,
                                 nullptr, nullptr, nullptr, "VSMain", "vs_5_0",
                                 compile_flags, 0, &vertex_shader, &errors),
                      "Compile vertex shader");
        check_hresult(D3DCompile(kShaderSource, sizeof(kShaderSource) - 1,
                                 nullptr, nullptr, nullptr, "PSMain", "ps_5_0",
                                 compile_flags, 0, &pixel_shader, &errors),
                      "Compile pixel shader");

        D3D12_ROOT_SIGNATURE_DESC root_description{};
        root_description.Flags = D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT;
        ComPtr<ID3DBlob> serialized_root;
        check_hresult(D3D12SerializeRootSignature(
            &root_description, D3D_ROOT_SIGNATURE_VERSION_1,
            &serialized_root, &errors), "Serialize root signature");
        check_hresult(device_->CreateRootSignature(
            0, serialized_root->GetBufferPointer(), serialized_root->GetBufferSize(),
            IID_PPV_ARGS(&root_signature_)), "CreateRootSignature");

        const D3D12_INPUT_ELEMENT_DESC input_layout[]{
            {"POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0,
             D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
            {"COLOR", 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0,
             D3D12_APPEND_ALIGNED_ELEMENT,
             D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0}};
        D3D12_GRAPHICS_PIPELINE_STATE_DESC pipeline_description{};
        pipeline_description.InputLayout = {input_layout, 2};
        pipeline_description.pRootSignature = root_signature_.Get();
        pipeline_description.VS = {vertex_shader->GetBufferPointer(),
                                   vertex_shader->GetBufferSize()};
        pipeline_description.PS = {pixel_shader->GetBufferPointer(),
                                   pixel_shader->GetBufferSize()};
        auto& rasterizer = pipeline_description.RasterizerState;
        rasterizer.FillMode = D3D12_FILL_MODE_SOLID;
        rasterizer.CullMode = D3D12_CULL_MODE_NONE;
        rasterizer.FrontCounterClockwise = FALSE;
        rasterizer.DepthBias = D3D12_DEFAULT_DEPTH_BIAS;
        rasterizer.DepthBiasClamp = D3D12_DEFAULT_DEPTH_BIAS_CLAMP;
        rasterizer.SlopeScaledDepthBias = D3D12_DEFAULT_SLOPE_SCALED_DEPTH_BIAS;
        rasterizer.DepthClipEnable = TRUE;
        rasterizer.MultisampleEnable = FALSE;
        rasterizer.AntialiasedLineEnable = FALSE;
        rasterizer.ForcedSampleCount = 0;
        rasterizer.ConservativeRaster = D3D12_CONSERVATIVE_RASTERIZATION_MODE_OFF;

        auto& blend = pipeline_description.BlendState.RenderTarget[0];
        blend.BlendEnable = FALSE;
        blend.LogicOpEnable = FALSE;
        blend.SrcBlend = D3D12_BLEND_ONE;
        blend.DestBlend = D3D12_BLEND_ZERO;
        blend.BlendOp = D3D12_BLEND_OP_ADD;
        blend.SrcBlendAlpha = D3D12_BLEND_ONE;
        blend.DestBlendAlpha = D3D12_BLEND_ZERO;
        blend.BlendOpAlpha = D3D12_BLEND_OP_ADD;
        blend.LogicOp = D3D12_LOGIC_OP_NOOP;
        blend.RenderTargetWriteMask = D3D12_COLOR_WRITE_ENABLE_ALL;

        pipeline_description.DepthStencilState.DepthEnable = FALSE;
        pipeline_description.DepthStencilState.DepthWriteMask = D3D12_DEPTH_WRITE_MASK_ZERO;
        pipeline_description.DepthStencilState.DepthFunc = D3D12_COMPARISON_FUNC_ALWAYS;
        pipeline_description.DepthStencilState.StencilEnable = FALSE;
        pipeline_description.SampleMask = UINT_MAX;
        pipeline_description.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
        pipeline_description.NumRenderTargets = 1;
        pipeline_description.RTVFormats[0] = kColorFormat;
        pipeline_description.SampleDesc.Count = 1;
        check_hresult(device_->CreateGraphicsPipelineState(
            &pipeline_description, IID_PPV_ARGS(&pipeline_)),
            "CreateGraphicsPipelineState");
    }

    void create_vertex_buffer() {
        const UINT64 buffer_size = sizeof(kVertices);
        D3D12_HEAP_PROPERTIES heap_properties{};
        heap_properties.Type = D3D12_HEAP_TYPE_UPLOAD;
        heap_properties.CPUPageProperty = D3D12_CPU_PAGE_PROPERTY_UNKNOWN;
        heap_properties.MemoryPoolPreference = D3D12_MEMORY_POOL_UNKNOWN;
        heap_properties.CreationNodeMask = 1;
        heap_properties.VisibleNodeMask = 1;
        D3D12_RESOURCE_DESC buffer_description{};
        buffer_description.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
        buffer_description.Width = buffer_size;
        buffer_description.Height = 1;
        buffer_description.DepthOrArraySize = 1;
        buffer_description.MipLevels = 1;
        buffer_description.SampleDesc.Count = 1;
        buffer_description.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
        buffer_description.Flags = D3D12_RESOURCE_FLAG_NONE;
        check_hresult(device_->CreateCommittedResource(
            &heap_properties, D3D12_HEAP_FLAG_NONE, &buffer_description,
            D3D12_RESOURCE_STATE_GENERIC_READ, nullptr,
            IID_PPV_ARGS(&vertex_buffer_)), "Create vertex buffer");
        void* mapped = nullptr;
        const D3D12_RANGE no_read{0, 0};
        check_hresult(vertex_buffer_->Map(0, &no_read, &mapped), "Map vertex buffer");
        std::memcpy(mapped, kVertices.data(), sizeof(kVertices));
        vertex_buffer_->Unmap(0, nullptr);
        vertex_view_ = {vertex_buffer_->GetGPUVirtualAddress(),
                        static_cast<UINT>(buffer_size), sizeof(Vertex)};
    }

    void wait_for_frame(UINT frame_index) {
        const UINT64 value = frame_fence_values_[frame_index];
        if (value == 0 || fence_->GetCompletedValue() >= value) {
            return;
        }
        check_hresult(fence_->SetEventOnCompletion(value, fence_event_),
                      "Fence::SetEventOnCompletion");
        WaitForSingleObject(fence_event_, INFINITE);
    }

    HWND window_ = nullptr;
    ComPtr<ID3D12Device> device_;
    ComPtr<ID3D12CommandQueue> queue_;
    ComPtr<IDXGISwapChain3> swap_chain_;
    ComPtr<ID3D12DescriptorHeap> rtv_heap_;
    std::array<ComPtr<ID3D12Resource>, kFrameCount> render_targets_;
    std::array<ComPtr<ID3D12CommandAllocator>, kFrameCount> allocators_;
    ComPtr<ID3D12GraphicsCommandList> command_list_;
    ComPtr<ID3D12RootSignature> root_signature_;
    ComPtr<ID3D12PipelineState> pipeline_;
    ComPtr<ID3D12Resource> vertex_buffer_;
    D3D12_VERTEX_BUFFER_VIEW vertex_view_{};
    D3D12_VIEWPORT viewport_{};
    D3D12_RECT scissor_{};
    ComPtr<ID3D12Fence> fence_;
    HANDLE fence_event_ = nullptr;
    UINT rtv_descriptor_size_ = 0;
    UINT64 fence_value_ = 0;
    std::array<UINT64, kFrameCount> frame_fence_values_{};
};

}  // namespace

int main() {
    try {
        const HINSTANCE instance = GetModuleHandleW(nullptr);
        constexpr wchar_t class_name[] = L"HWControlGameCoreDx12Triangle";
        WNDCLASSEXW window_class{};
        window_class.cbSize = sizeof(window_class);
        window_class.lpfnWndProc = window_proc;
        window_class.hInstance = instance;
        window_class.lpszClassName = class_name;
        window_class.hCursor = LoadCursorW(nullptr, MAKEINTRESOURCEW(32512));
        if (RegisterClassExW(&window_class) == 0) {
            throw std::runtime_error("RegisterClassExW failed");
        }

        RECT bounds{0, 0, static_cast<LONG>(kWindowWidth),
                    static_cast<LONG>(kWindowHeight)};
        if (!AdjustWindowRect(&bounds, WS_OVERLAPPEDWINDOW, FALSE)) {
            throw std::runtime_error("AdjustWindowRect failed");
        }
        HWND window = CreateWindowExW(
            0, class_name, L"HWcontrol Game Core — Direct3D 12 Triangle",
            WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
            bounds.right - bounds.left, bounds.bottom - bounds.top,
            nullptr, nullptr, instance, nullptr);
        if (window == nullptr) {
            throw std::runtime_error("CreateWindowExW failed");
        }

        Dx12Triangle renderer(window);
        ShowWindow(window, SW_SHOW);
        UpdateWindow(window);

        MSG message{};
        bool running = true;
        while (running) {
            while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) {
                if (message.message == WM_QUIT) {
                    running = false;
                    break;
                }
                TranslateMessage(&message);
                DispatchMessageW(&message);
            }
            if (running && !IsIconic(window)) {
                renderer.render();
            } else if (running) {
                WaitMessage();
            }
        }
        renderer.wait_for_gpu();
        return 0;
    } catch (const std::exception& error) {
        const std::string message = error.what();
        const int wide_length = MultiByteToWideChar(
            CP_UTF8, 0, message.c_str(), -1, nullptr, 0);
        std::wstring wide_message(static_cast<std::size_t>(wide_length), L'\0');
        if (wide_length > 0) {
            MultiByteToWideChar(CP_UTF8, 0, message.c_str(), -1,
                                wide_message.data(), wide_length);
        }
        MessageBoxW(nullptr, wide_message.c_str(),
                    L"HWcontrol Game Core — Direct3D 12 error",
                    MB_OK | MB_ICONERROR);
        return 1;
    }
}
