# HWcontrol2.0
HWControl 2.0 is a high-performance, kernel-level hardware management and control suite designed for precision and stability. Built with a focus on low-latency communication and secure system interaction, this project provides a robust bridge between user-space applications and kernel-mode operations.

Architecture
The project is built on a multi-layer architecture:

ai_core (C++): The heart of the system, handling kernel-mode drivers and hardware-level operations.

bridge_service (Go): A high-concurrency service that manages the secure communication bridge between the kernel-core and the UI.

gui_dashboard (Dart/Flutter): A responsive and intuitive dashboard for real-time hardware monitoring and configuration.

Key Features
Kernel-Level Control: Direct interaction with hardware drivers for maximum efficiency.

BSOD Shield: Built-in safeguards to prevent system instability and kernel panics.

Secure Communication: Implements SHA-256 verification to ensure the integrity of driver modules.

Cross-Platform Ready: Designed with a modular structure to support future extensions.

Security Policy
We take the security of our users and their systems seriously. Please refer to our SECURITY.md file for information on supported versions and the vulnerability reporting process.

Build and test
--------------

Build the C++ engine without CPU-specific instructions:

	cmake -S . -B build -DGGML_NATIVE=OFF
	cmake --build build --parallel 2

Test and build the Go bridge:

	cd bridge_service
	go test ./...
	go build -o bridge-service ./src

Analyze the Flutter dashboard:

	cd gui_dashboard
	flutter pub get
	flutter analyze
	flutter run --dart-define=HWCONTROL_KEY="replace-with-a-long-random-secret"

Security key
------------

The bridge and dashboard use the same HMAC-SHA-256 key. The bridge refuses to start without `HWCONTROL_KEY`; the dashboard reads it from the runtime environment or a local `--dart-define` and sends only command signatures.

Start the bridge with an environment variable:

	HWCONTROL_KEY="replace-with-a-long-random-secret" ./bridge-service

Run the dashboard with the same key without putting it in source control:

	flutter run --dart-define=HWCONTROL_KEY="replace-with-a-long-random-secret"

Releases
--------

Releases use Semantic Versioning with an operating-system suffix. Create and push one of these tags:

	git tag -a v0.1.4-linux -m "Release v0.1.4 for Linux"
	git push origin v0.1.4-linux

The release workflow creates clearly named platform packages automatically. Each package includes the native engine, Go bridge and Flutter dashboard:

- `vX.Y.Z-windows` -> `HWControl-vX.Y.Z-windows-Windows-x64.zip` = Windows 64-bit + `.exe`
- `vX.Y.Z-linux` -> `HWControl-vX.Y.Z-linux-Linux-x64.tar.gz` and `.deb` = Linux 64-bit
- `vX.Y.Z-macos` -> `HWControl-vX.Y.Z-macos-macOS-AppleSilicon.dmg` + `.app` = macOS Apple Silicon

Packaged desktop apps read `HWCONTROL_KEY` from the environment at runtime. The key is intentionally not included in release files.

The in-app update panel reads `updates/check.json`, checks the official GitHub release API over HTTPS, and displays only releases with a `.sha256` integrity asset. It opens the official release page for a user-confirmed download; it never executes a downloaded file automatically. Verify the checksum before launching any package.

Eski `v0.1.x` tag’leri geriye dönük olarak korunur. Yeni yayınlarda tag sonuna mutlaka `-windows`, `-linux` veya `-macos` eklenmelidir.
