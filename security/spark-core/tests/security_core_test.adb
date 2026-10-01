with Ada.Text_IO; use Ada.Text_IO;
with Interfaces.C;
use type Interfaces.C.unsigned_char;
with HWControl_Security; use HWControl_Security;

procedure Security_Core_Test
  with SPARK_Mode => On
is
begin
   pragma Assert (Is_Sensor_Temperature_Valid (-40));
   pragma Assert (Is_Sensor_Temperature_Valid (125));
   pragma Assert (not Is_Sensor_Temperature_Valid (-41));
   pragma Assert (not Is_Sensor_Temperature_Valid (126));

   pragma Assert
     (Validate_Fan_Command
        (Fan => 50, Telemetry_Valid => True, Temperature_C => 60,
         Integrity_Healthy => True, Authorized => True) = Allow);

   pragma Assert
     (Validate_Fan_Command
        (Fan => 0, Telemetry_Valid => True, Temperature_C => 60,
         Integrity_Healthy => True, Authorized => True) = Allow);

   pragma Assert
     (Validate_Fan_Command
        (Fan => 100, Telemetry_Valid => True, Temperature_C => 60,
         Integrity_Healthy => True, Authorized => True) = Allow);

   pragma Assert
     (Validate_Fan_Command
        (Fan => 50, Telemetry_Valid => False, Temperature_C => 60,
         Integrity_Healthy => True, Authorized => True) = Deny);

   pragma Assert
     (Validate_Fan_Command
        (Fan => 50, Telemetry_Valid => True, Temperature_C => 95,
         Integrity_Healthy => True, Authorized => True) = Deny);

   pragma Assert
     (Validate_Fan_Command
        (Fan => 50, Telemetry_Valid => True, Temperature_C => 60,
         Integrity_Healthy => False, Authorized => True) = Deny);

   pragma Assert
     (Validate_Fan_Command
        (Fan => 50, Telemetry_Valid => True, Temperature_C => 60,
         Integrity_Healthy => True, Authorized => False) = Deny);

   pragma Assert
     (Validate_Fan_Command
        (Fan => 50, Telemetry_Valid => True, Temperature_C => -41,
         Integrity_Healthy => True, Authorized => True) = Deny);

   pragma Assert
     (Validate_Fan_Command
        (Fan => 50, Telemetry_Valid => True, Temperature_C => 126,
         Integrity_Healthy => True, Authorized => True) = Deny);

   pragma Assert
     (Validate_Raw_Fan_Command
        (Fan_Percent_Value => -1, Telemetry_Valid => True, Temperature_C => 60,
         Integrity_Healthy => True, Authorized => True) = Deny);

   pragma Assert
     (Validate_Raw_Fan_Command
        (Fan_Percent_Value => 101, Telemetry_Valid => True, Temperature_C => 60,
         Integrity_Healthy => True, Authorized => True) = Deny);

   pragma Assert
     (Validate_Raw_Fan_Command
        (Fan_Percent_Value => 50, Telemetry_Valid => True, Temperature_C => 60,
         Integrity_Healthy => True, Authorized => True) = Allow);

   pragma Assert (Is_Temperature_Safe (True, 94));
   pragma Assert (not Is_Temperature_Safe (True, 95));
   pragma Assert (not Is_Temperature_Safe (False, 60));
   pragma Assert (not Is_Temperature_Safe (True, -41));
   pragma Assert (not Is_Temperature_Safe (True, 126));

   pragma Assert
     (Validate_Raw_Fan_Command_C
        (Fan_Percent_Value => 50,
         Telemetry_Valid => 1,
         Temperature_C => 60,
         Integrity_Healthy => 1,
         Authorized => 1) = 1);

   pragma Assert
     (Validate_Raw_Fan_Command_C
        (Fan_Percent_Value => 101,
         Telemetry_Valid => 1,
         Temperature_C => 60,
         Integrity_Healthy => 1,
         Authorized => 1) = 0);

   pragma Assert
     (Validate_Raw_Fan_Command_C
        (Fan_Percent_Value => 50,
         Telemetry_Valid => 0,
         Temperature_C => 60,
         Integrity_Healthy => 1,
         Authorized => 1) = 0);


   Put_Line ("HWcontrol SPARK security core: PASS");
end Security_Core_Test;
