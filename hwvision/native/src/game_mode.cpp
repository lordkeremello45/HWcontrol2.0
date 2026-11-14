#include "hwvision/game_mode.hpp"
#include <cmath>
namespace hwvision {
namespace {
bool valid_percentage(bool valid,double value) noexcept { return !valid||(std::isfinite(value)&&value>=0.0&&value<=100.0); }
bool valid_temperature(bool valid,double value) noexcept { return !valid||(std::isfinite(value)&&value>=-20.0&&value<=150.0); }
bool valid_telemetry(const Telemetry& t) noexcept {
 return valid_percentage(t.cpu_usage_valid,t.cpu_usage_percent)&&valid_percentage(t.gpu_usage_valid,t.gpu_usage_percent)&&
 valid_temperature(t.cpu_temperature_valid,t.cpu_temperature_c)&&valid_temperature(t.gpu_temperature_valid,t.gpu_temperature_c);
}
bool valid_input_enums(const GameModeInput& i) noexcept {
 return static_cast<unsigned int>(i.detection)<=static_cast<unsigned int>(GameDetection::detected)&&
 static_cast<unsigned int>(i.power_source)<=static_cast<unsigned int>(PowerSource::battery)&&
 static_cast<unsigned int>(i.thermal_state)<=static_cast<unsigned int>(ThermalState::critical);
}
double hottest_valid_temperature(const Telemetry& t) noexcept {
 double hottest=-1000.0;
 if(t.cpu_temperature_valid) hottest=t.cpu_temperature_c;
 if(t.gpu_temperature_valid&&t.gpu_temperature_c>hottest) hottest=t.gpu_temperature_c;
 return hottest;
}
GameModePlan base_plan(GameProfile profile) noexcept {
 GameModePlan p; p.effective_profile=profile;
 p.mutate_game_process_priority=false; p.mutate_system_services=false;
 p.allow_background_ai_inference=false; p.allow_optional_gpu_compute=false;
 return p;
}
}
bool is_valid_game_mode_config(const GameModeConfig& c) noexcept {
 return static_cast<unsigned int>(c.profile)<=static_cast<unsigned int>(GameProfile::quiet)&&
  std::isfinite(c.thermal_limit_c)&&c.thermal_limit_c>=50.0&&c.thermal_limit_c<=100.0;
}
GameModePlan evaluate_game_mode(const GameModeConfig& config,const GameModeInput& input) {
 if(!is_valid_game_mode_config(config)||!valid_input_enums(input)) {
  auto p=base_plan(GameProfile::balanced); p.status=GameModeStatus::invalid_input;
  p.reason=GameModeReason::telemetry_invalid;
  p.diagnostics.emplace_back("Invalid configuration or enum value; no optimization actions permitted."); return p;
 }
 auto plan=base_plan(config.profile);
 if(!valid_telemetry(input.telemetry)) {
  plan.status=GameModeStatus::invalid_input; plan.reason=GameModeReason::telemetry_invalid;
  plan.diagnostics.emplace_back("Telemetry outside validated bounds; all optional actions remain disabled."); return plan;
 }
 if(!config.enabled) { plan.status=GameModeStatus::disabled; plan.reason=GameModeReason::mode_disabled; return plan; }
 if(!config.auto_detection||input.detection==GameDetection::unknown) {
  plan.status=GameModeStatus::monitoring_only; plan.reason=GameModeReason::detection_unknown;
  plan.diagnostics.emplace_back("Game detection is not authoritative; no game-specific policy applied."); return plan;
 }
 if(input.detection==GameDetection::not_detected) {
  plan.status=GameModeStatus::monitoring_only; plan.reason=GameModeReason::no_game_detected; return plan;
 }
 if(!input.game_is_foreground) {
  plan.status=GameModeStatus::monitoring_only; plan.reason=GameModeReason::game_not_foreground;
  plan.diagnostics.emplace_back("Detected game is not foreground; gaming policy remains inactive."); return plan;
 }
 if(!input.telemetry_fresh) {
  plan.status=GameModeStatus::monitoring_only; plan.reason=GameModeReason::telemetry_stale;
  plan.diagnostics.emplace_back("Telemetry is stale or unverified; performance policy is not activated."); return plan;
 }
 if(input.power_source==PowerSource::battery&&!config.allow_on_battery) {
  plan.status=GameModeStatus::battery_restricted; plan.reason=GameModeReason::battery_policy_restricted;
  plan.effective_profile=GameProfile::balanced;
  plan.diagnostics.emplace_back("Battery policy prevents performance profile activation."); return plan;
 }
 const double hottest=hottest_valid_temperature(input.telemetry);
 if(input.thermal_state==ThermalState::critical||hottest>=config.thermal_limit_c) {
  plan.status=GameModeStatus::thermal_safe_mode; plan.reason=GameModeReason::thermal_limit_reached;
  plan.effective_profile=GameProfile::quiet; plan.reduce_hwvision_background_work=true;
  plan.recommend_performance_fan_profile=false; plan.telemetry_interval_ms=500;
  plan.diagnostics.emplace_back("Thermal safety gate forced Quiet policy; optional GPU work is disabled."); return plan;
 }
 if(input.thermal_state==ThermalState::unknown ||
    (!input.telemetry.cpu_temperature_valid && !input.telemetry.gpu_temperature_valid)) {
  plan.status=GameModeStatus::monitoring_only; plan.reason=GameModeReason::telemetry_invalid;
  plan.diagnostics.emplace_back("No trusted thermal measurement is available; performance actions fail closed."); return plan;
 }
 plan.status=GameModeStatus::active; plan.reduce_hwvision_background_work=true;
 plan.recommend_performance_fan_profile=config.profile==GameProfile::performance;
 plan.telemetry_interval_ms=1000;
 if(input.thermal_state==ThermalState::warm && plan.effective_profile==GameProfile::performance) {
  plan.effective_profile=GameProfile::balanced; plan.recommend_performance_fan_profile=false;
  plan.diagnostics.emplace_back("Warm thermal state reduced the requested Performance profile to Balanced.");
 }
 if(input.power_source==PowerSource::unknown&&plan.effective_profile==GameProfile::performance) {
  plan.effective_profile=GameProfile::balanced; plan.recommend_performance_fan_profile=false;
  plan.diagnostics.emplace_back("Power source unknown; Performance downgraded to Balanced.");
 }
 switch(plan.effective_profile) {
 case GameProfile::performance: plan.reason=GameModeReason::active_performance; break;
 case GameProfile::balanced: plan.reason=GameModeReason::active_balanced; break;
 case GameProfile::quiet: plan.reason=GameModeReason::active_quiet; break;
 }
 return plan;
}
} // namespace hwvision
