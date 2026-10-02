import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Startup trust gate for packaged release builds.
///
/// The compile-time value is supplied only by the release build pipeline.
/// Debug/profile development builds are intentionally allowed to run without
/// the release marker. This is a UX/startup gate; OS code signing remains the
/// actual publisher-authenticity root of trust.
class HWControlAuthenticityGuard {
  static const String releaseTrust = String.fromEnvironment(
    'HWCONTROL_RELEASE_TRUST',
    defaultValue: 'unverified',
  );

  static bool get requiresBlock =>
      kReleaseMode && releaseTrust != 'official';
}

class UnofficialBuildScreen extends StatelessWidget {
  const UnofficialBuildScreen({super.key});

  void _close() {
    exit(1);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.gpp_bad_rounded,
                      size: 72,
                      color: scheme.error,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'THIS CODE IS UNOFFICIAL AND UNSAFE',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: scheme.error,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This release could not be verified as an official '
                      'HWcontrol2.0 build. The application has been blocked '
                      'for your security.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Do not use this build for hardware control. '
                      'Obtain HWcontrol2.0 from the official release channel.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _close,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Close application'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
