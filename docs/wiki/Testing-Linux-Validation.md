# Linux Validation

The Linux validation workflow uses Ubuntu 24.04 hosted runners. Its result applies to that runner and the commands executed in the specific run.

It validates:

- CMake native build;
- CTest;
- Go tests/build;
- Flutter analyze/test/build;
- DEB generation;
- package installation;
- presence of the packaged AI helper, bridge and dashboard executables;
- package removal.

Additional release integrity checks validate published checksums and optional Linux package assets. These CI checks do not validate physical sensors, PWM fan response or power-profile behavior on a user's Linux host.
