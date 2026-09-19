# Linux Validation

The Linux CI job runs on Ubuntu 24.04.

It validates:

- CMake native build;
- CTest;
- Go tests/build;
- Flutter analyze/test/build;
- DEB generation;
- package installation;
- presence of native engine, bridge and dashboard executables;
- package removal.

Additional release integrity checks validate published checksums and optional Linux package assets.
