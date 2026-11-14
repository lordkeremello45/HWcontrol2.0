#pragma once
#include "hw_game_core/graphics/device.hpp"
#include "hw_game_core/graphics/vendor_extensions.hpp"
#include <cstddef>
#include <cstdint>
#include <string>
namespace hwcontrol::game::graphics {
enum class VendorSdk : std::uint8_t { nvidia_streamline, amd_fsr, nvidia_nsight_graphics, amd_radeon_gpu_profiler, hwvision_cuda_tensorrt, hwvision_rocm };
enum class VendorSdkFeature : std::uint32_t {
 none=0, dlss_upscaling=1U<<0U, dlss_frame_generation=1U<<1U, reflex_low_latency=1U<<2U,
 fsr_upscaling=1U<<3U, fsr_frame_generation=1U<<4U, nsight_capture=1U<<5U,
 radeon_gpu_profile_capture=1U<<6U, cuda_compute=1U<<7U, tensorrt_inference=1U<<8U, rocm_compute=1U<<9U
};
[[nodiscard]] constexpr std::uint32_t sdk_feature_bit(VendorSdkFeature f) noexcept { return static_cast<std::uint32_t>(f); }
inline constexpr std::uint32_t known_vendor_sdk_feature_mask =
 sdk_feature_bit(VendorSdkFeature::dlss_upscaling)|sdk_feature_bit(VendorSdkFeature::dlss_frame_generation)|
 sdk_feature_bit(VendorSdkFeature::reflex_low_latency)|sdk_feature_bit(VendorSdkFeature::fsr_upscaling)|
 sdk_feature_bit(VendorSdkFeature::fsr_frame_generation)|sdk_feature_bit(VendorSdkFeature::nsight_capture)|
 sdk_feature_bit(VendorSdkFeature::radeon_gpu_profile_capture)|sdk_feature_bit(VendorSdkFeature::cuda_compute)|
 sdk_feature_bit(VendorSdkFeature::tensorrt_inference)|sdk_feature_bit(VendorSdkFeature::rocm_compute);
enum class VendorSdkState : std::uint8_t { not_configured, unavailable, ready, failed };
struct VendorSdkProbe {
 VendorSdk sdk=VendorSdk::nvidia_streamline; VendorSdkState state=VendorSdkState::not_configured;
 GraphicsApi api=GraphicsApi::automatic; std::uint32_t features=0; std::string sdk_version; std::string diagnostic;
 [[nodiscard]] constexpr bool supports(VendorSdkFeature f) const noexcept {
  const auto bit=sdk_feature_bit(f);
  return state==VendorSdkState::ready && bit!=0U && (bit&known_vendor_sdk_feature_mask)==bit &&
   (features&bit)!=0U && (features&~known_vendor_sdk_feature_mask)==0U;
 }
};
enum class VendorSdkValidation : std::uint8_t {
 valid,vendor_mismatch,unsupported_api,invalid_state,unknown_features,feature_sdk_mismatch,
 empty_ready_features,features_without_ready_state,sdk_version_too_large,diagnostic_too_large
};
inline constexpr std::size_t max_vendor_sdk_version_bytes=64;
inline constexpr std::size_t max_vendor_sdk_diagnostic_bytes=4096;
[[nodiscard]] constexpr GpuVendor vendor_for_sdk(VendorSdk sdk) noexcept {
 switch(sdk) {
 case VendorSdk::nvidia_streamline: case VendorSdk::nvidia_nsight_graphics: case VendorSdk::hwvision_cuda_tensorrt:return GpuVendor::nvidia;
 case VendorSdk::amd_fsr: case VendorSdk::amd_radeon_gpu_profiler: case VendorSdk::hwvision_rocm:return GpuVendor::amd;
 }
 return GpuVendor::unknown;
}
[[nodiscard]] constexpr std::uint32_t allowed_features_for_sdk(VendorSdk sdk) noexcept {
 switch(sdk) {
 case VendorSdk::nvidia_streamline:return sdk_feature_bit(VendorSdkFeature::dlss_upscaling)|sdk_feature_bit(VendorSdkFeature::dlss_frame_generation)|sdk_feature_bit(VendorSdkFeature::reflex_low_latency);
 case VendorSdk::amd_fsr:return sdk_feature_bit(VendorSdkFeature::fsr_upscaling)|sdk_feature_bit(VendorSdkFeature::fsr_frame_generation);
 case VendorSdk::nvidia_nsight_graphics:return sdk_feature_bit(VendorSdkFeature::nsight_capture);
 case VendorSdk::amd_radeon_gpu_profiler:return sdk_feature_bit(VendorSdkFeature::radeon_gpu_profile_capture);
 case VendorSdk::hwvision_cuda_tensorrt:return sdk_feature_bit(VendorSdkFeature::cuda_compute)|sdk_feature_bit(VendorSdkFeature::tensorrt_inference);
 case VendorSdk::hwvision_rocm:return sdk_feature_bit(VendorSdkFeature::rocm_compute);
 }
 return 0U;
}
[[nodiscard]] constexpr bool sdk_supports_api(VendorSdk sdk,GraphicsApi api) noexcept {
 switch(sdk) {
 case VendorSdk::nvidia_streamline: case VendorSdk::amd_fsr: case VendorSdk::nvidia_nsight_graphics: case VendorSdk::amd_radeon_gpu_profiler:
  return api==GraphicsApi::direct3d12||api==GraphicsApi::vulkan;
 case VendorSdk::hwvision_cuda_tensorrt: case VendorSdk::hwvision_rocm:return api==GraphicsApi::automatic;
 }
 return false;
}
[[nodiscard]] inline VendorSdkValidation validate_vendor_sdk_probe(const GraphicsDeviceInfo& device,const VendorSdkProbe& probe) noexcept {
 const auto vendor=vendor_for_sdk(probe.sdk);
 if(vendor==GpuVendor::unknown||identify_gpu_vendor(device.adapter.vendor_id)!=vendor)return VendorSdkValidation::vendor_mismatch;
 if(!sdk_supports_api(probe.sdk,probe.api))return VendorSdkValidation::unsupported_api;
 if(probe.sdk_version.size()>max_vendor_sdk_version_bytes)return VendorSdkValidation::sdk_version_too_large;
 if(probe.diagnostic.size()>max_vendor_sdk_diagnostic_bytes)return VendorSdkValidation::diagnostic_too_large;
 if((probe.features&~known_vendor_sdk_feature_mask)!=0U)return VendorSdkValidation::unknown_features;
 if((probe.features&~allowed_features_for_sdk(probe.sdk))!=0U)return VendorSdkValidation::feature_sdk_mismatch;
 switch(probe.state) {
 case VendorSdkState::not_configured: case VendorSdkState::unavailable: case VendorSdkState::failed:
  return probe.features==0U?VendorSdkValidation::valid:VendorSdkValidation::features_without_ready_state;
 case VendorSdkState::ready:return probe.features!=0U?VendorSdkValidation::valid:VendorSdkValidation::empty_ready_features;
 }
 return VendorSdkValidation::invalid_state;
}
} // namespace hwcontrol::game::graphics
