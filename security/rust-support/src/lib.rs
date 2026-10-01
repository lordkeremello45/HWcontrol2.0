#![forbid(unsafe_op_in_unsafe_fn)]
#![deny(clippy::all)]

#[repr(u8)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum SecurityDecision {
    Deny = 0,
    Allow = 1,
}

impl SecurityDecision {
    pub const fn from_ffi(value: u8) -> Option<Self> {
        match value {
            0 => Some(Self::Deny),
            1 => Some(Self::Allow),
            _ => None,
        }
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct FanCommand {
    pub fan_percent: u8,
    pub telemetry_valid: u8,
    pub temperature_c: i16,
    pub integrity_healthy: u8,
    pub authorized: u8,
}

impl FanCommand {
    pub const fn new(
        fan_percent: u8,
        telemetry_valid: bool,
        temperature_c: i16,
        integrity_healthy: bool,
        authorized: bool,
    ) -> Option<Self> {
        if fan_percent > 100 || temperature_c < -40 || temperature_c > 125 {
            return None;
        }

        Some(Self {
            fan_percent,
            telemetry_valid: telemetry_valid as u8,
            temperature_c,
            integrity_healthy: integrity_healthy as u8,
            authorized: authorized as u8,
        })
    }
}

/// Unknown foreign decision values are always converted to DENY.
#[unsafe(no_mangle)]
pub extern "C" fn hwcontrol_security_decision_from_ffi(value: u8) -> u8 {
    match SecurityDecision::from_ffi(value) {
        Some(SecurityDecision::Allow) => SecurityDecision::Allow as u8,
        Some(SecurityDecision::Deny) | None => SecurityDecision::Deny as u8,
    }
}

/// Return the already-computed security decision without performing I/O.
#[unsafe(no_mangle)]
pub extern "C" fn hwcontrol_security_can_execute(value: u8) -> u8 {
    hwcontrol_security_decision_from_ffi(value)
}

#[cfg(feature = "spark-ffi")]
unsafe extern "C" {
    fn hwcontrol_security_validate_fan_command(
        fan_percent: i32,
        telemetry_valid: u8,
        temperature_c: i32,
        integrity_healthy: u8,
        authorized: u8,
    ) -> u8;
}

/// Call the authoritative SPARK gate when the native SPARK library is linked.
#[cfg(feature = "spark-ffi")]
pub fn validate_fan_command_with_spark(command: FanCommand) -> SecurityDecision {
    let decision = unsafe {
        hwcontrol_security_validate_fan_command(
            i32::from(command.fan_percent),
            command.telemetry_valid,
            i32::from(command.temperature_c),
            command.integrity_healthy,
            command.authorized,
        )
    };
    match SecurityDecision::from_ffi(decision) {
        Some(value) => value,
        None => SecurityDecision::Deny,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fan_command_is_bounded() {
        assert!(FanCommand::new(0, true, 0, true, true).is_some());
        assert!(FanCommand::new(100, true, 125, true, true).is_some());
        assert!(FanCommand::new(101, true, 50, true, true).is_none());
        assert!(FanCommand::new(50, true, -41, true, true).is_none());
        assert!(FanCommand::new(50, true, 126, true, true).is_none());
    }

    #[test]
    fn invalid_ffi_decisions_fail_closed() {
        assert_eq!(hwcontrol_security_decision_from_ffi(0), 0);
        assert_eq!(hwcontrol_security_decision_from_ffi(1), 1);
        assert_eq!(hwcontrol_security_decision_from_ffi(2), 0);
        assert_eq!(hwcontrol_security_decision_from_ffi(255), 0);
    }
}
