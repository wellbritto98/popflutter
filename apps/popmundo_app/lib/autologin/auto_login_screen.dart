import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

const _statusOptions = <({int value, String key})>[
  (value: 0, key: 'autologin.statusNormal'),
  (value: 1, key: 'autologin.statusBusy'),
  (value: 2, key: 'autologin.statusMobile'),
  (value: 4, key: 'autologin.statusAway'),
  (value: 3, key: 'autologin.statusDrunk'),
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
        SnackBar(
          key: const Key('autologin-snackbar'),
          content: Text('autologin.saved'.tr()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('autologin-snackbar-error'),
          content: Text('autologin.saveFailed'.tr(args: ['$e'])),
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
      appBar: AppBar(title: Text('autologin.title'.tr())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  key: const Key('autologin-enabled'),
                  title: Text('autologin.enabled'.tr()),
                  subtitle: Text('autologin.enabledSubtitle'.tr()),
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
                  decoration: InputDecoration(
                    labelText: 'autologin.username'.tr(),
                    border: const OutlineInputBorder(),
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
                    labelText: 'autologin.password'.tr(),
                    helperText: _hasStoredPassword
                        ? 'autologin.passwordKeep'.tr()
                        : 'autologin.passwordRequired'.tr(),
                    border: const OutlineInputBorder(),
                    suffixIcon: _hasStoredPassword
                        ? IconButton(
                            key: const Key('autologin-clear-password'),
                            tooltip: 'autologin.clearPassword'.tr(),
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
                  decoration: InputDecoration(
                    labelText: 'autologin.character'.tr(),
                    helperText: 'autologin.characterHelp'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'autologin.status'.tr(),
                    border: const OutlineInputBorder(),
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
                            child: Text(opt.key.tr()),
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
                      : Text('common.save'.tr()),
                ),
              ],
            ),
    );
  }
}
