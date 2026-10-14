import 'package:flutter/material.dart';

import 'profile_document.dart';
import 'user_data_store.dart';

/// CRUD interface for saved, versioned profiles.
///
/// Profiles are stored as user preferences only. This screen deliberately does
/// not send commands to the hardware bridge or apply a profile to a device.
class HWControlProfileManagerScreen extends StatefulWidget {
  HWControlProfileManagerScreen({
    super.key,
    HWControlUserDataStore? store,
  }) : store = store ?? _defaultStore;

  static final HWControlUserDataStore _defaultStore = HWControlUserDataStore();

  final HWControlUserDataStore store;

  @override
  State<HWControlProfileManagerScreen> createState() =>
      _HWControlProfileManagerScreenState();
}

class _HWControlProfileManagerScreenState
    extends State<HWControlProfileManagerScreen> {
  List<HWControlProfile> _profiles = const <HWControlProfile>[];
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final collection = await widget.store.readValidatedProfiles();
      if (!mounted) return;
      setState(() {
        _profiles = collection.profiles;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Saved profiles could not be read. The original file was preserved.';
      });
    }
  }

  Future<void> _persist(List<HWControlProfile> next) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final collection = HWControlProfileCollection(next);
      await widget.store.writeValidatedProfiles(collection);
      if (!mounted) return;
      setState(() {
        _profiles = collection.profiles;
        _saving = false;
        _loadError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved.')),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile was not saved: ${error.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save profile. Existing data was not intentionally replaced.')),
      );
    }
  }

  Future<void> _createProfile() async {
    if (_profiles.length >= HWControlProfile.maxProfiles) {
      _message('You have reached the 100-profile limit.');
      return;
    }
    final draft = await _editProfile();
    if (draft == null || !mounted) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final profile = HWControlProfile(
      id: 'profile_${DateTime.now().toUtc().microsecondsSinceEpoch}',
      name: draft.name,
      mode: draft.mode,
      createdAt: now,
      updatedAt: now,
      gameModeEnabled: draft.gameModeEnabled,
      fanCurve: const <HWControlFanPoint>[
        HWControlFanPoint(temperatureCelsius: 35, fanPercent: 25),
        HWControlFanPoint(temperatureCelsius: 70, fanPercent: 60),
      ],
    );
    await _persist(<HWControlProfile>[..._profiles, profile]);
  }

  Future<void> _editExisting(HWControlProfile profile) async {
    final draft = await _editProfile(profile: profile);
    if (draft == null || !mounted) return;
    final updated = HWControlProfile(
      id: profile.id,
      name: draft.name,
      mode: draft.mode,
      createdAt: profile.createdAt,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      gameModeEnabled: draft.gameModeEnabled,
      fanCurve: profile.fanCurve,
    );
    await _persist(<HWControlProfile>[
      for (final current in _profiles)
        if (current.id == profile.id) updated else current,
    ]);
  }

  Future<_ProfileDraft?> _editProfile({HWControlProfile? profile}) async {
    final nameController = TextEditingController(text: profile?.name ?? '');
    var mode = profile?.mode ?? 'balanced';
    var gameModeEnabled = profile?.gameModeEnabled ?? false;
    try {
      return await showDialog<_ProfileDraft>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(profile == null ? 'Create profile' : 'Edit profile'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      maxLength: HWControlProfile.maxNameLength,
                      decoration: const InputDecoration(
                        labelText: 'Profile name',
                        hintText: 'e.g. Quiet gaming',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: mode,
                      decoration: const InputDecoration(labelText: 'Mode'),
                      items: const [
                        DropdownMenuItem(value: 'quiet', child: Text('Quiet')),
                        DropdownMenuItem(value: 'balanced', child: Text('Balanced')),
                        DropdownMenuItem(value: 'performance', child: Text('Performance')),
                        DropdownMenuItem(value: 'custom', child: Text('Custom')),
                      ],
                      onChanged: (value) {
                        if (value != null) setDialogState(() => mode = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Game Mode preference'),
                      subtitle: const Text('Saved as a preference only; does not launch or prioritize games.'),
                      value: gameModeEnabled,
                      onChanged: (value) =>
                          setDialogState(() => gameModeEnabled = value),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The default fan curve is retained for new profiles. Saving a profile does not change hardware settings.',
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty || name.length > HWControlProfile.maxNameLength) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a profile name from 1 to 64 characters.')),
                    );
                    return;
                  }
                  Navigator.pop(
                    dialogContext,
                    _ProfileDraft(
                      name: name,
                      mode: mode,
                      gameModeEnabled: gameModeEnabled,
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _duplicate(HWControlProfile profile) async {
    if (_profiles.length >= HWControlProfile.maxProfiles) {
      _message('You have reached the 100-profile limit.');
      return;
    }
    final draft = await _editProfile(
      profile: profile.rename(
        newName: '${profile.name} copy',
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
    if (draft == null || !mounted) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final copy = profile.duplicate(
      newId: 'profile_${DateTime.now().toUtc().microsecondsSinceEpoch}',
      newName: draft.name,
      createdAt: now,
      updatedAt: now,
    ).rename(newName: draft.name, updatedAt: now);
    final withPreferences = HWControlProfile(
      id: copy.id,
      name: copy.name,
      mode: draft.mode,
      createdAt: copy.createdAt,
      updatedAt: copy.updatedAt,
      gameModeEnabled: draft.gameModeEnabled,
      fanCurve: profile.fanCurve,
    );
    await _persist(<HWControlProfile>[..._profiles, withPreferences]);
  }

  Future<void> _delete(HWControlProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete profile?'),
        content: Text('Delete "${profile.name}"? This only removes the saved profile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _persist(_profiles.where((item) => item.id != profile.id).toList());
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile manager'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _saving ? null : _loadProfiles,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading || _saving ? null : _createProfile,
        icon: const Icon(Icons.add),
        label: const Text('Create profile'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 40),
                        const SizedBox(height: 12),
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _loadProfiles,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _profiles.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No saved profiles yet. Create one to store a named mode and fan-curve preference.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      children: [
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Profiles are saved preferences. Applying them to hardware is not available from this screen.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        for (final profile in _profiles)
                          Card(
                            child: ListTile(
                              leading: Icon(
                                profile.gameModeEnabled
                                    ? Icons.sports_esports_outlined
                                    : Icons.tune,
                              ),
                              title: Text(profile.name),
                              subtitle: Text(
                                '${profile.mode[0].toUpperCase()}${profile.mode.substring(1)}'
                                ' • ${profile.fanCurve.length} fan-curve points'
                                '${profile.gameModeEnabled ? ' • Game Mode preference' : ''}',
                              ),
                              isThreeLine: false,
                              trailing: PopupMenuButton<String>(
                                enabled: !_saving,
                                onSelected: (action) {
                                  switch (action) {
                                    case 'edit':
                                      _editExisting(profile);
                                      break;
                                    case 'duplicate':
                                      _duplicate(profile);
                                      break;
                                    case 'delete':
                                      _delete(profile);
                                      break;
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
    );
  }
}

class _ProfileDraft {
  const _ProfileDraft({
    required this.name,
    required this.mode,
    required this.gameModeEnabled,
  });

  final String name;
  final String mode;
  final bool gameModeEnabled;
}
