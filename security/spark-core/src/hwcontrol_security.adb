package body HWControl_Security
  with SPARK_Mode => On
is
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
        or else Temperature_C >= Critical_Temperature
      then
         return Deny;
      end if;

      return Allow;
   end Validate_Fan_Command;

   function Is_Temperature_Safe
     (Telemetry_Valid   : Boolean;
      Temperature_C     : Integer) return Boolean
   is
   begin
      return Telemetry_Valid and then Temperature_C < Critical_Temperature;
   end Is_Temperature_Safe;

end HWControl_Security;
