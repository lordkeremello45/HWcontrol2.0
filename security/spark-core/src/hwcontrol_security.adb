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

   function Validate_Raw_Fan_Command_C
     (Fan_Percent_Value : Interfaces.C.int;
      Telemetry_Valid   : Interfaces.C.unsigned_char;
      Temperature_C     : Interfaces.C.int;
      Integrity_Healthy : Interfaces.C.unsigned_char;
      Authorized        : Interfaces.C.unsigned_char)
      return Interfaces.C.unsigned_char
   is
      Decision : constant Security_Decision :=
        Validate_Raw_Fan_Command
          (Integer (Fan_Percent_Value),
           Telemetry_Valid /= 0,
           Integer (Temperature_C),
           Integrity_Healthy /= 0,
           Authorized /= 0);
   begin
      if Decision = Allow then
         return 1;
      else
         return 0;
      end if;
   end Validate_Raw_Fan_Command_C;

end HWControl_Security;
