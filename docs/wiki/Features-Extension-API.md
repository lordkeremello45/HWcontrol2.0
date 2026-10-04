# Extension API

The first extension layer is a validated metadata/capability manifest.

Example capabilities can describe telemetry providers without granting control authority.

Arbitrary native binaries are not loaded from user-writable plugin directories. This is intentional: extension execution must not become a privilege-escalation path around the authenticated bridge.

A future executable extension host should require signed manifests/binaries and explicit capability grants before privileged hardware operations are permitted.
