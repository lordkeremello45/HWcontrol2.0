#include "hw_game_core/graphics/vendor_sdk_contracts.hpp"
#include <cstdlib>
#include <iostream>
using namespace hwcontrol::game::graphics;
int main(){
 int failures=0;
 #define CHECK(x) do{if(!(x)){std::cerr<<"FAIL "<<__LINE__<<": "<<#x; ++failures;}}while(false)
 GraphicsDeviceInfo nvidia; nvidia.adapter.vendor_id=0x10DEU;
 GraphicsDeviceInfo amd; amd.adapter.vendor_id=0x1002U;
 VendorSdkProbe dlss; dlss.sdk=VendorSdk::nvidia_streamline; dlss.state=VendorSdkState::ready;
 dlss.api=GraphicsApi::direct3d12; dlss.features=sdk_feature_bit(VendorSdkFeature::dlss_upscaling)|sdk_feature_bit(VendorSdkFeature::reflex_low_latency); dlss.sdk_version="2.x";
 CHECK(validate_vendor_sdk_probe(nvidia,dlss)==VendorSdkValidation::valid);
 CHECK(dlss.supports(VendorSdkFeature::dlss_upscaling)); CHECK(!dlss.supports(VendorSdkFeature::fsr_upscaling));
 auto bad_vendor=dlss; CHECK(validate_vendor_sdk_probe(amd,bad_vendor)==VendorSdkValidation::vendor_mismatch);
 auto bad_api=dlss; bad_api.api=GraphicsApi::metal; CHECK(validate_vendor_sdk_probe(nvidia,bad_api)==VendorSdkValidation::unsupported_api);
 auto bad_feature=dlss; bad_feature.features=sdk_feature_bit(VendorSdkFeature::fsr_upscaling); CHECK(validate_vendor_sdk_probe(nvidia,bad_feature)==VendorSdkValidation::feature_sdk_mismatch);
 auto unknown=dlss; unknown.features|=(1U<<31U); CHECK(validate_vendor_sdk_probe(nvidia,unknown)==VendorSdkValidation::unknown_features);
 auto empty=dlss; empty.features=0U; CHECK(validate_vendor_sdk_probe(nvidia,empty)==VendorSdkValidation::empty_ready_features);
 auto unavailable=dlss; unavailable.state=VendorSdkState::unavailable; CHECK(validate_vendor_sdk_probe(nvidia,unavailable)==VendorSdkValidation::features_without_ready_state);
 VendorSdkProbe fsr; fsr.sdk=VendorSdk::amd_fsr; fsr.state=VendorSdkState::ready; fsr.api=GraphicsApi::vulkan; fsr.features=sdk_feature_bit(VendorSdkFeature::fsr_upscaling);
 CHECK(validate_vendor_sdk_probe(amd,fsr)==VendorSdkValidation::valid);
 VendorSdkProbe nsight; nsight.sdk=VendorSdk::nvidia_nsight_graphics; nsight.state=VendorSdkState::ready; nsight.api=GraphicsApi::direct3d12; nsight.features=sdk_feature_bit(VendorSdkFeature::nsight_capture);
 CHECK(validate_vendor_sdk_probe(nvidia,nsight)==VendorSdkValidation::valid);
 VendorSdkProbe rgp; rgp.sdk=VendorSdk::amd_radeon_gpu_profiler; rgp.state=VendorSdkState::ready; rgp.api=GraphicsApi::vulkan; rgp.features=sdk_feature_bit(VendorSdkFeature::radeon_gpu_profile_capture);
 CHECK(validate_vendor_sdk_probe(amd,rgp)==VendorSdkValidation::valid);
 VendorSdkProbe cuda; cuda.sdk=VendorSdk::hwvision_cuda_tensorrt; cuda.state=VendorSdkState::ready; cuda.api=GraphicsApi::automatic; cuda.features=sdk_feature_bit(VendorSdkFeature::cuda_compute)|sdk_feature_bit(VendorSdkFeature::tensorrt_inference);
 CHECK(validate_vendor_sdk_probe(nvidia,cuda)==VendorSdkValidation::valid);
 VendorSdkProbe rocm; rocm.sdk=VendorSdk::hwvision_rocm; rocm.state=VendorSdkState::ready; rocm.api=GraphicsApi::automatic; rocm.features=sdk_feature_bit(VendorSdkFeature::rocm_compute);
 CHECK(validate_vendor_sdk_probe(amd,rocm)==VendorSdkValidation::valid);
 auto huge_version=cuda; huge_version.sdk_version.assign(max_vendor_sdk_version_bytes+1U,'v'); CHECK(validate_vendor_sdk_probe(nvidia,huge_version)==VendorSdkValidation::sdk_version_too_large);
 auto huge_diag=cuda; huge_diag.diagnostic.assign(max_vendor_sdk_diagnostic_bytes+1U,'x'); CHECK(validate_vendor_sdk_probe(nvidia,huge_diag)==VendorSdkValidation::diagnostic_too_large);
 auto invalid=cuda; invalid.state=static_cast<VendorSdkState>(255); CHECK(validate_vendor_sdk_probe(nvidia,invalid)==VendorSdkValidation::invalid_state);
 #undef CHECK
 return failures==0?EXIT_SUCCESS:EXIT_FAILURE;
}
