with Interfaces.C;

package HWControl_Security
  with SPARK_Mode => On
is
   Critical_Temperature : constant := 95;
   Minimum_Sensor_Temperature : constant := -40;
   Maximum_Sensor_Temperature : constant := 125;

   subtype Fan_Percent is Integer range 0 .. 100;
   type Security_Decision is (Allow, Deny);

   function Is_Sensor_Temperature_Valid
     (Temperature_C : Integer) return Boolean
     with
       Global => null,
       Post =>
         Is_Sensor_Temperature_Valid'Result =
           (Temperature_C >= Minimum_Sensor_Temperature
            and then Temperature_C <= Maximum_Sensor_Temperature);

   function Is_Temperature_Safe
     (Telemetry_Valid : Boolean;
      Temperature_C   : Integer) return Boolean
     with
       Global => null,
       Post =>
         Is_Temperature_Safe'Result =
           (Telemetry_Valid
            and then Is_Sensor_Temperature_Valid (Temperature_C)
            and then Temperature_C < Critical_Temperature);

   function Validate_Fan_Command
     (Fan                 : Fan_Percent;
      Telemetry_Valid     : Boolean;
      Temperature_C       : Integer;
      Integrity_Healthy   : Boolean;
      Authorized          : Boolean) return Security_Decision
     with
       Global => null,
       Post =>
         (if not Authorized
          or else not Integrity_Healthy
          or else not Telemetry_Valid
          or else not Is_Sensor_Temperature_Valid (Temperature_C)
          or else Temperature_C >= Critical_Temperature
          then Validate_Fan_Command'Result = Deny
          else Validate_Fan_Command'Result = Allow);

   function Validate_Raw_Fan_Command
     (Fan_Percent_Value  : Integer;
      Telemetry_Valid    : Boolean;
      Temperature_C      : Integer;
      Integrity_Healthy  : Boolean;
      Authorized         : Boolean) return Security_Decision
     with
       Global => null,
       Post =>
         (if Fan_Percent_Value < Fan_Percent'First
          or else Fan_Percent_Value > Fan_Percent'Last
          or else not Authorized
          or else not Integrity_Healthy
          or else not Telemetry_Valid
          or else not Is_Sensor_Temperature_Valid (Temperature_C)
          or else Temperature_C >= Critical_Temperature
          then Validate_Raw_Fan_Command'Result = Deny
          else Validate_Raw_Fan_Command'Result = Allow);

   -- C ABI boundary for the Rust support layer. The policy remains in SPARK;
   -- the exported function only exposes the already-formally-specified gate.
   function Validate_Raw_Fan_Command_C
     (Fan_Percent_Value : Interfaces.C.int;
      Telemetry_Valid   : Interfaces.C.unsigned_char;
      Temperature_C     : Interfaces.C.int;
      Integrity_Healthy : Interfaces.C.unsigned_char;
      Authorized        : Interfaces.C.unsigned_char)
      return Interfaces.C.unsigned_char
     with
       Global => null,
       Export,
       Convention => C,
       External_Name => "hwcontrol_security_validate_fan_command";

end HWControl_Security;
