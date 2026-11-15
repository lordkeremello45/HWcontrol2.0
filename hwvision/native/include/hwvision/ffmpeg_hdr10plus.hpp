#pragma once
#include "hwvision/hdr10plus.hpp"
#include <cstdint>
#if defined(HWVISION_HAS_FFMPEG)
extern "C" {
#include <libavutil/frame.h>
}
#endif
namespace hwvision::hdr10plus::ffmpeg {
enum class ExtractionError : std::uint8_t {
  none, ffmpeg_not_enabled, frame_has_no_dynamic_metadata, invalid_side_data,
  unsupported_country_code, unsupported_application_version, invalid_metadata
};
struct ExtractionResult {
  ExtractionError error = ExtractionError::none;
  [[nodiscard]] constexpr bool is_valid() const noexcept { return error == ExtractionError::none; }
};
[[nodiscard]] ExtractionResult extract_frame_metadata(
#if defined(HWVISION_HAS_FFMPEG)
    const AVFrame& frame,
#else
    const void* frame,
#endif
    Metadata& output) noexcept;
}  // namespace hwvision::hdr10plus::ffmpeg
