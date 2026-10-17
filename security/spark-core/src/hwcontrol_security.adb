with Interfaces.C;
use type Interfaces.C.unsigned_char;

package body HWControl_Security
  with SPARK_Mode => On
is
   function Is_Sensor_Temperature_Valid
     (Temperature_C : Integer) return Boolean
   is
   begin
      return Temperature_C >= Minimum_Sensor_Temperature
        and then Temperature_C <= Maximum_Sensor_Temperature;
   end Is_Sensor_Temperature_Valid;

   function Is_Temperature_Safe
     (Telemetry_Valid : Boolean;
      Temperature_C   : Integer) return Boolean
   is
   begin
      return Telemetry_Valid
        and then Is_Sensor_Temperature_Valid (Temperature_C)
        and then Temperature_C < Critical_Temperature;
   end Is_Temperature_Safe;

   function Validate_Fan_Command
     (Fan                 : Fan_Percent;
      Telemetry_Valid     : Boolean;
      Temperature_C       : Integer;
      Integrity_Healthy   : Boolean;
      Authorized          : Boolean) return Security_Decision
   is
      pragma Unreferenced (Fan);
   begin
      if not Authorized
        or else not Integrity_Healthy
        or else not Telemetry_Valid
        or else not Is_Sensor_Temperature_Valid (Temperature_C)
        or else Temperature_C >= Critical_Temperature
      then
         return Deny;
      end if;

      return Allow;
   end Validate_Fan_Command;

   function Validate_Raw_Fan_Command
     (Fan_Percent_Value  : Integer;
      Telemetry_Valid    : Boolean;
      Temperature_C      : Integer;
      Integrity_Healthy  : Boolean;
      Authorized         : Boolean) return Security_Decision
   is
   begin
      if Fan_Percent_Value < Fan_Percent'First
        or else Fan_Percent_Value > Fan_Percent'Last
        or else not Authorized
        or else not Integrity_Healthy
        or else not Telemetry_Valid
        or else not Is_Sensor_Temperature_Valid (Temperature_C)
        or else Temperature_C >= Critical_Temperature
      then
         return Deny;
      end if;

      return Allow;
   end Validate_Raw_Fan_Command;

   function Validate_Hardware_Identity
     (Schema_Valid    : Boolean;
      Payload_Bounded : Boolean;
      Counts_Valid    : Boolean;
      Status_Valid    : Boolean) return Security_Decision
   is
   begin
      if not Schema_Valid
        or else not Payload_Bounded
        or else not Counts_Valid
        or else not Status_Valid
      then
         return Deny;
      end if;

      return Allow;
   end Validate_Hardware_Identity;

   function Validate_Hardware_Identity_C
     (Schema_Valid    : Interfaces.C.unsigned_char;
      Payload_Bounded : Interfaces.C.unsigned_char;
      Counts_Valid    : Interfaces.C.unsigned_char;
      Status_Valid    : Interfaces.C.unsigned_char)
      return Interfaces.C.unsigned_char
   is
      Decision : constant Security_Decision :=
        Validate_Hardware_Identity
          (Schema_Valid = 1,
           Payload_Bounded = 1,
           Counts_Valid = 1,
           Status_Valid = 1);
   begin
      if Decision = Allow then
         return 1;
      else
         return 0;
      end if;
   end Validate_Hardware_Identity_C;

   function Validate_Raw_Fan_Command_C
     (Fan_Percent_Value : Interfaces.C.int;
      Telemetry_Valid   : Interfaces.C.unsigned_char;
      Temperature_C     : Interfaces.C.int;
      Integrity_Healthy : Interfaces.C.unsigned_char;
      Authorized        : Interfaces.C.unsigned_char)
      return Interfaces.C.unsigned_char
   is
   begin
      -- C callers must pass canonical boolean flags. Treat every value other
      -- than exactly 0 or 1 as malformed and deny rather than interpreting an
      -- arbitrary nonzero byte as authorization or healthy telemetry.
      if Telemetry_Valid > 1
        or else Integrity_Healthy > 1
        or else Authorized > 1
      then
         return 0;
      end if;

      declare
         Decision : constant Security_Decision :=
           Validate_Raw_Fan_Command
             (Integer (Fan_Percent_Value),
              Telemetry_Valid = 1,
              Integer (Temperature_C),
              Integrity_Healthy = 1,
              Authorized = 1);
      begin
         if Decision = Allow then
            return 1;
         else
            return 0;
         end if;
      end;
   end Validate_Raw_Fan_Command_C;

end HWControl_Security;
