/// Pure helpers for per-game profile lookup and safe fan-target resolution.
library;

String normalizeGameProcessName(String name) {
  final normalized = name.trim().toLowerCase().replaceAll('\\', '/');
  final separator = normalized.lastIndexOf('/');
  return separator >= 0 ? normalized.substring(separator + 1) : normalized;
}

String? assignedGameProfileName({
  required String processName,
  required Map<String, String> assignments,
}) {
  final process = normalizeGameProcessName(processName);
  if (process.isEmpty) return null;
  for (final entry in assignments.entries) {
    if (normalizeGameProcessName(entry.key) == process &&
        entry.value.trim().isNotEmpty) {
      return entry.value.trim();
    }
  }
  return null;
}

double resolveGameProfileFanTarget({
  required String processName,
  required Map<String, String> assignments,
  required Map<String, Map<String, double>> profiles,
  double defaultFanTarget = 75,
}) {
  final profileName = assignedGameProfileName(
    processName: processName,
    assignments: assignments,
  );
  final savedTarget = profileName == null ? null : profiles[profileName]?['fan'];
  final target = savedTarget != null && savedTarget.isFinite
      ? savedTarget
      : defaultFanTarget;
  final safeTarget = target.isFinite ? target : 75;
  return safeTarget.clamp(0, 100).toDouble();
}
