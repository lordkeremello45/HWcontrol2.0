import 'dart:io';

/// Checks the bounded installation layout for the companion Go bridge.
///
/// Linux places the bridge beside the dashboard's parent directory. macOS
/// places it outside the .app bundle, above Contents/MacOS. Windows places it
/// beside the dashboard executable.
Future<bool> hasBridgeServiceBinary({
  required String executablePath,
  required bool isWindows,
  int maxParentDirectories = 3,
}) async {
  if (maxParentDirectories < 0) {
    throw ArgumentError.value(
      maxParentDirectories,
      'maxParentDirectories',
      'must not be negative',
    );
  }

  final binaryNames = isWindows
      ? const <String>['bridge-service.exe', 'bridge-service']
      : const <String>['bridge-service'];
  var directory = File(executablePath).parent;

  for (var depth = 0; depth <= maxParentDirectories; depth++) {
    for (final binaryName in binaryNames) {
      final candidate = File(
        '${directory.path}${Platform.pathSeparator}$binaryName',
      );
      if (await candidate.exists()) return true;
    }

    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }

  return false;
}
