import 'package:flutter/material.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

const _statusOptions = <({int value, String label})>[
  (value: 0, label: 'Normal'),
  (value: 1, label: 'Busy'),
  (value: 2, label: 'Mobile'),
  (value: 4, label: 'Away'),
  (value: 3, label: 'Drunk'),
];

/// Settings UI for Auto Login (password via [SecretStore] only).
class AutoLoginScreen extends StatefulWidget {
  const AutoLoginScreen({
    super.key,
    required this.settingsStore,
    required this.secretStore,
  });

  final AutoLoginSettingsStore settingsStore;
  final SecretStore secretStore;

  @override
  State<AutoLoginScreen> createState() => _AutoLoginScreenState();
}

class _AutoLoginScreenState extends State<AutoLoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _character = TextEditingController();

  var _loading = true;
  var _saving = false;
  var _enabled = false;
  var _status = 0;
  var _hasStoredPassword = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _character.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await widget.settingsStore.load();
    final existing = await widget.secretStore.read(
      AutoLoginSettingsStore.passwordSecretKey,
    );
    if (!mounted) return;
    setState(() {
      _enabled = settings.enabled;
      _username.text = settings.username;
      _character.text = settings.characterName;
      _status = settings.status;
      _hasStoredPassword = existing != null && existing.isNotEmpty;
      _password.clear();
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final next = AutoLoginSettings(
        enabled: _enabled,
        username: _username.text.trim(),
        characterName: _character.text.trim(),
        status: _status,
      );
      await widget.settingsStore.save(next);
      final typed = _password.text;
      if (typed.isNotEmpty) {
        await widget.secretStore.write(
          AutoLoginSettingsStore.passwordSecretKey,
          typed,
        );
        _hasStoredPassword = true;
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _password.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          key: Key('autologin-snackbar'),
          content: Text('Auto Login settings saved'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('autologin-snackbar-error'),
          content: Text('Save failed: $e'),
        ),
      );
    }
  }

  Future<void> _clearPassword() async {
    await widget.secretStore.delete(AutoLoginSettingsStore.passwordSecretKey);
    if (!mounted) return;
    setState(() {
      _hasStoredPassword = false;
      _password.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('autologin-screen'),
      appBar: AppBar(title: const Text('Auto Login')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  key: const Key('autologin-enabled'),
                  title: const Text('Enabled'),
                  subtitle: const Text(
                    'POST login via TimedFetch when the login page appears',
                  ),
                  value: _enabled,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _enabled = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('autologin-username'),
                  controller: _username,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('autologin-password'),
                  controller: _password,
                  enabled: !_saving,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText: _hasStoredPassword
                        ? 'Leave blank to keep the stored password'
                        : 'Required for Auto Login',
                    border: const OutlineInputBorder(),
                    suffixIcon: _hasStoredPassword
                        ? IconButton(
                            key: const Key('autologin-clear-password'),
                            tooltip: 'Clear stored password',
                            onPressed: _saving ? null : _clearPassword,
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('autologin-character'),
                  controller: _character,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Character name',
                    helperText: 'Must match Choose / Escolher button label',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      key: const Key('autologin-status'),
                      isExpanded: true,
                      value: _status,
                      items: [
                        for (final opt in _statusOptions)
                          DropdownMenuItem(
                            key: Key('autologin-status-${opt.value}'),
                            value: opt.value,
                            child: Text(opt.label),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) {
                              if (v != null) setState(() => _status = v);
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('autologin-save'),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
    );
  }
}
