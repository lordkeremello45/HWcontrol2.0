#include "hwvision/ffmpeg_hdr10plus.hpp"
#include <cassert>
#include <iostream>
#if defined(HWVISION_HAS_FFMPEG)
extern "C" {
#include <libavutil/frame.h>
#include <libavutil/hdr_dynamic_metadata.h>
}
#endif
int main() {
#if defined(HWVISION_HAS_FFMPEG)
  using namespace hwvision::hdr10plus;
  AVFrame* frame=av_frame_alloc(); assert(frame);
  auto* d=av_dynamic_hdr_plus_create_side_data(frame); assert(d);
  d->itu_t_t35_country_code=0xB5U; d->application_version=1U; d->num_windows=1U;
  d->targeted_system_display_maximum_luminance=AVRational{1000,1};
  auto& p=d->params[0];
  for (auto& v:p.maxscl) v=AVRational{50000,100000};
  p.average_maxrgb=AVRational{25000,100000};
  constexpr std::uint8_t indexes[9]={1,5,10,25,50,75,90,95,99};
  p.num_distribution_maxrgb_percentiles=9U;
  for (std::size_t i=0;i<9;++i) {
    p.distribution_maxrgb[i].percentage=indexes[i];
    p.distribution_maxrgb[i].percentile=AVRational{static_cast<int>(i+1U)*1000,100000};
  }
  p.fraction_bright_pixels=AVRational{100,1000};
  p.color_saturation_weight=AVRational{8,8};
  Metadata output;
  auto result=ffmpeg::extract_frame_metadata(*frame,output);
  assert(result.is_valid());
  assert(output.application_identifier==4U && output.application_version==1U);
  assert(output.max_scl_1e5[0]==50000U && output.fraction_bright_pixels_1e3==100U);
  d->itu_t_t35_country_code=0U;
  result=ffmpeg::extract_frame_metadata(*frame,output);
  assert(result.error==ffmpeg::ExtractionError::unsupported_country_code);
  assert(output.max_scl_1e5[0]==50000U);
  av_frame_free(&frame);
#else
  std::cout << "FFmpeg adapter disabled: dependency not present\n";
#endif
  return 0;
}
