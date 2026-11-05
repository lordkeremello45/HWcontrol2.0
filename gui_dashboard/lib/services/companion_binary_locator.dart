import 'dart:io';

/// Finds a packaged companion binary beside the dashboard or in one of its
/// bounded installation ancestors.
Future<File?> findCompanionBinary({
  required String executablePath,
  required List<String> binaryNames,
  int maxParentDirectories = 3,
}) async {
  if (maxParentDirectories < 0) {
    throw ArgumentError.value(
      maxParentDirectories,
      'maxParentDirectories',
      'must not be negative',
    );
  }
  if (binaryNames.any((name) =>
      name.isEmpty ||
      name == '.' ||
      name == '..' ||
      name.contains('/') ||
      name.contains(Platform.pathSeparator))) {
    throw ArgumentError.value(
      binaryNames,
      'binaryNames',
      'must contain file names only',
    );
  }

  var directory = File(executablePath).parent;
  for (var depth = 0; depth <= maxParentDirectories; depth++) {
    for (final binaryName in binaryNames) {
      final candidate = File(
        '${directory.path}${Platform.pathSeparator}$binaryName',
      );
      if (await candidate.exists()) return candidate;
    }

    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  return null;
}

/// Checks the platform-specific installed name of the Go bridge.
Future<bool> hasBridgeServiceBinary({
  required String executablePath,
  required bool isWindows,
  int maxParentDirectories = 3,
}) async {
  final binaryNames = isWindows
      ? const <String>['bridge-service.exe', 'bridge-service']
      : const <String>['bridge-service'];
  return await findCompanionBinary(
        executablePath: executablePath,
        binaryNames: binaryNames,
        maxParentDirectories: maxParentDirectories,
      ) !=
      null;
}
