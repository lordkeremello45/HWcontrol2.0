package HWControl_Security
  with SPARK_Mode => On
is
   Critical_Temperature : constant := 95;

   subtype Fan_Percent is Integer range 0 .. 100;

   type Security_Decision is (Allow, Deny);

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
          or else Temperature_C >= Critical_Temperature
          then Validate_Fan_Command'Result = Deny
          else Validate_Fan_Command'Result = Allow);

   function Is_Temperature_Safe
     (Telemetry_Valid   : Boolean;
      Temperature_C     : Integer) return Boolean
     with
       Global => null,
       Post =>
         Is_Temperature_Safe'Result =
           (Telemetry_Valid and then Temperature_C < Critical_Temperature);

end HWControl_Security;
