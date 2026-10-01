with Ada.Text_IO; use Ada.Text_IO;
with HWControl_Security; use HWControl_Security;

procedure Security_Core_Test
  with SPARK_Mode => On
is
begin
   pragma Assert
     (Validate_Fan_Command
        (Fan               => 50,
         Telemetry_Valid   => True,
         Temperature_C     => 60,
         Integrity_Healthy => True,
         Authorized        => True) = Allow);

   pragma Assert
     (Validate_Fan_Command
        (Fan               => 50,
         Telemetry_Valid   => False,
         Temperature_C     => 60,
         Integrity_Healthy => True,
         Authorized        => True) = Deny);

   pragma Assert
     (Validate_Fan_Command
        (Fan               => 50,
         Telemetry_Valid   => True,
         Temperature_C     => 95,
         Integrity_Healthy => True,
         Authorized        => True) = Deny);

   pragma Assert
     (Validate_Fan_Command
        (Fan               => 50,
         Telemetry_Valid   => True,
         Temperature_C     => 60,
         Integrity_Healthy => False,
         Authorized        => True) = Deny);

   pragma Assert
     (Validate_Fan_Command
        (Fan               => 50,
         Telemetry_Valid   => True,
         Temperature_C     => 60,
         Integrity_Healthy => True,
         Authorized        => False) = Deny);

   pragma Assert (Is_Temperature_Safe (True, 94));
   pragma Assert (not Is_Temperature_Safe (True, 95));
   pragma Assert (not Is_Temperature_Safe (False, 60));

   Put_Line ("HWcontrol SPARK security core: PASS");
end Security_Core_Test;
