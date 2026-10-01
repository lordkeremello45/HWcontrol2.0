#ifndef HWCONTROL_SECURITY_SUPPORT_H
#define HWCONTROL_SECURITY_SUPPORT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * SPARK is authoritative for the decision. Rust only preserves the decision
 * across the ABI and fails closed for unknown values.
 */
uint8_t hwcontrol_security_decision_from_ffi(uint8_t decision);
uint8_t hwcontrol_security_can_execute(uint8_t decision);

#ifdef __cplusplus
}
#endif

#endif
