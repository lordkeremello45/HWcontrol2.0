/// Stable metadata/capability extension contract.
/// Arbitrary native code is deliberately not loaded from user-writable paths.
class HWControlExtensionManifest {
  const HWControlExtensionManifest({required this.id, required this.name, required this.version, required this.capabilities});
  final String id;
  final String name;
  final String version;
  final List<String> capabilities;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'version': version, 'capabilities': capabilities};

  static HWControlExtensionManifest? fromJson(dynamic value) {
    if (value is! Map) return null;
    final id = value['id']?.toString().trim();
    final name = value['name']?.toString().trim();
    final version = value['version']?.toString().trim();
    final capabilities = (value['capabilities'] as List?)?.map((e) => e.toString()).toList();
    if (id == null || id.isEmpty || name == null || name.isEmpty || version == null || version.isEmpty || capabilities == null) return null;
    if (id.length > 128 || capabilities.any((e) => e.length > 128)) return null;
    return HWControlExtensionManifest(id: id, name: name, version: version, capabilities: List.unmodifiable(capabilities));
  }
}
