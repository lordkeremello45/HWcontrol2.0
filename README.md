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

Releases
--------

Releases use Semantic Versioning. Create and push a tag such as `v0.1.0`:

	git tag -a v0.1.0 -m "Release v0.1.0"
	git push origin v0.1.0

The release workflow creates clearly named platform packages automatically:

- `HWControl-vX.Y.Z-Windows-x64.tar.gz` = Windows 64-bit
- `HWControl-vX.Y.Z-Linux-x64.tar.gz` = Linux 64-bit
- `HWControl-vX.Y.Z-macOS-Intel-x64.tar.gz` = macOS Intel
- `HWControl-vX.Y.Z-macOS-AppleSilicon-arm64.tar.gz` = macOS Apple Silicon

Merge changes to `main` through pull requests and publish only `vMAJOR.MINOR.PATCH` tags.
