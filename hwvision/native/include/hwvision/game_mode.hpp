#pragma once
#include <cstdint>
#include <string>
#include <vector>
namespace hwvision {
enum class GameDetection : std::uint8_t { unknown, not_detected, detected };
enum class PowerSource : std::uint8_t { unknown, ac, battery };
enum class ThermalState : std::uint8_t { unknown, normal, warm, critical };
enum class GameProfile : std::uint8_t { performance, balanced, quiet };
enum class GameModeStatus : std::uint8_t { disabled, monitoring_only, active, battery_restricted, thermal_safe_mode, invalid_input };
enum class GameModeReason : std::uint8_t { mode_disabled, detection_unknown, no_game_detected, game_not_foreground, battery_policy_restricted, thermal_limit_reached, telemetry_invalid, telemetry_stale, active_performance, active_balanced, active_quiet };
struct Telemetry {
 bool cpu_usage_valid=false, gpu_usage_valid=false, cpu_temperature_valid=false, gpu_temperature_valid=false;
 double cpu_usage_percent=0.0, gpu_usage_percent=0.0, cpu_temperature_c=0.0, gpu_temperature_c=0.0;
};
struct GameModeConfig {
 bool enabled=false, auto_detection=true, allow_on_battery=false;
 GameProfile profile=GameProfile::balanced;
 double thermal_limit_c=85.0;
};
struct GameModeInput {
 GameDetection detection=GameDetection::unknown;
 bool game_is_foreground=false;
 PowerSource power_source=PowerSource::unknown;
 ThermalState thermal_state=ThermalState::unknown;
 bool telemetry_fresh=false;
 Telemetry telemetry{};
};
struct GameModePlan {
 GameModeStatus status=GameModeStatus::disabled;
 GameProfile effective_profile=GameProfile::balanced;
 GameModeReason reason=GameModeReason::mode_disabled;
 bool reduce_hwvision_background_work=false;
 bool allow_background_ai_inference=false;
 bool allow_optional_gpu_compute=false;
 bool recommend_performance_fan_profile=false;
 bool mutate_game_process_priority=false;
 bool mutate_system_services=false;
 std::uint32_t telemetry_interval_ms=3000;
 std::vector<std::string> diagnostics;
};
[[nodiscard]] GameModePlan evaluate_game_mode(const GameModeConfig& config,const GameModeInput& input);
[[nodiscard]] bool is_valid_game_mode_config(const GameModeConfig& config) noexcept;
} // namespace hwvision
