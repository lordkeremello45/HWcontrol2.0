#include "hwvision/game_mode.hpp"
#include <cstdlib>
#include <iostream>
#include <limits>
using namespace hwvision;
namespace {
int failures=0;
void check(bool ok,int line,const char* expr){if(!ok){std::cerr<<"FAIL line "<<line<<": "<<expr<<'\n';++failures;}}
#define CHECK(x) check((x),__LINE__,#x)
GameModeInput active_input(){GameModeInput i;i.detection=GameDetection::detected;i.game_is_foreground=true;i.power_source=PowerSource::ac;i.thermal_state=ThermalState::normal;i.telemetry_fresh=true;i.telemetry.cpu_temperature_valid=true;i.telemetry.cpu_temperature_c=65.0;i.telemetry.gpu_temperature_valid=true;i.telemetry.gpu_temperature_c=70.0;return i;}
}
int main(){
 GameModeConfig c;c.enabled=true;c.profile=GameProfile::performance;
 auto i=active_input();auto p=evaluate_game_mode(c,i);
 CHECK(p.status==GameModeStatus::active);CHECK(p.effective_profile==GameProfile::performance);
 CHECK(p.reduce_hwvision_background_work);CHECK(!p.allow_background_ai_inference);CHECK(!p.allow_optional_gpu_compute);
 CHECK(p.recommend_performance_fan_profile);CHECK(!p.mutate_game_process_priority);CHECK(!p.mutate_system_services);CHECK(p.telemetry_interval_ms==1000U);
 c.enabled=false;p=evaluate_game_mode(c,i);CHECK(p.status==GameModeStatus::disabled);CHECK(!p.reduce_hwvision_background_work);
 c.enabled=true;i.detection=GameDetection::unknown;p=evaluate_game_mode(c,i);CHECK(p.status==GameModeStatus::monitoring_only);
 i=active_input();i.game_is_foreground=false;p=evaluate_game_mode(c,i);CHECK(p.status==GameModeStatus::monitoring_only);
 i=active_input();i.telemetry_fresh=false;p=evaluate_game_mode(c,i);CHECK(p.status==GameModeStatus::monitoring_only);CHECK(p.reason==GameModeReason::telemetry_stale);
 i=active_input();i.power_source=PowerSource::battery;p=evaluate_game_mode(c,i);CHECK(p.status==GameModeStatus::battery_restricted);CHECK(p.effective_profile==GameProfile::balanced);
 i=active_input();i.telemetry.gpu_temperature_c=95.0;p=evaluate_game_mode(c,i);CHECK(p.status==GameModeStatus::thermal_safe_mode);CHECK(p.effective_profile==GameProfile::quiet);CHECK(!p.recommend_performance_fan_profile);CHECK(p.telemetry_interval_ms==500U);
 i=active_input();i.thermal_state=ThermalState::unknown;p=evaluate_game_mode(c,i);CHECK(p.status==GameModeStatus::monitoring_only);
 i=active_input();i.thermal_state=ThermalState::warm;p=evaluate_game_mode(c,i);CHECK(p.effective_profile==GameProfile::balanced);CHECK(!p.recommend_performance_fan_profile);
 i=active_input();i.power_source=PowerSource::unknown;p=evaluate_game_mode(c,i);CHECK(p.effective_profile==GameProfile::balanced);CHECK(!p.recommend_performance_fan_profile);
 i=active_input();i.telemetry.cpu_usage_valid=true;i.telemetry.cpu_usage_percent=std::numeric_limits<double>::quiet_NaN();p=evaluate_game_mode(c,i);CHECK(p.status==GameModeStatus::invalid_input);CHECK(!p.reduce_hwvision_background_work);
 i=active_input();i.detection=static_cast<GameDetection>(255);p=evaluate_game_mode(c,i);CHECK(p.status==GameModeStatus::invalid_input);
 c.thermal_limit_c=1000.0;CHECK(!is_valid_game_mode_config(c));p=evaluate_game_mode(c,active_input());CHECK(p.status==GameModeStatus::invalid_input);
 c.thermal_limit_c=85.0;c.profile=static_cast<GameProfile>(255);CHECK(!is_valid_game_mode_config(c));
 return failures==0?EXIT_SUCCESS:EXIT_FAILURE;
}
