import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

/// Material list UI for managing installed userscripts (theme unchanged).
class UserScriptsScreen extends StatefulWidget {
  const UserScriptsScreen({
    super.key,
    required this.catalog,
    required this.importer,
    required this.onApply,
    this.onScriptDeleted,
  });

  final UserScriptCatalog catalog;
  final UserScriptImporter importer;

  /// Called after a successful catalog mutation with the full catalog snapshot.
  /// Host should sync WebView UserScripts and reload.
  final Future<void> Function(List<InstalledUserScript> catalog) onApply;

  /// Called with the deleted script's id after removal, so the host can clear
  /// any orphaned per-script data (e.g. GM_setValue storage).
  final Future<void> Function(String id)? onScriptDeleted;

  @override
  State<UserScriptsScreen> createState() => _UserScriptsScreenState();
}

class _UserScriptsScreenState extends State<UserScriptsScreen> {
  var _scripts = <InstalledUserScript>[];
  var _loading = true;
  var _importing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await widget.catalog.list();
    if (!mounted) return;
    setState(() {
      _scripts = list;
      _loading = false;
    });
  }

  Future<void> _showAddDialog() async {
    final url = await showDialog<String>(
      context: context,
      builder: (context) => const _AddUserScriptDialog(),
    );
    if (url == null || url.isEmpty || !mounted) return;
    await _import(url);
  }

  Future<void> _import(String url) async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final installed = await widget.importer.importFromUrl(url);
      final next = await widget.catalog.list();
      await widget.onApply(next);
      if (!mounted) return;
      setState(() {
        _scripts = next;
        _importing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('userscript-snackbar'),
          content: Text('userscripts.imported'.tr(args: [installed.name])),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      final message = e is UserScriptImportException
          ? e.message
          : e is UserScriptParseException
              ? e.message
              : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('userscript-snackbar'),
          content: Text(message),
        ),
      );
    }
  }

  Future<void> _toggle(InstalledUserScript script) async {
    await widget.catalog.toggleEnabled(script.id);
    final next = await widget.catalog.list();
    await widget.onApply(next);
    if (!mounted) return;
    setState(() => _scripts = next);
  }

  Future<void> _confirmDelete(InstalledUserScript script) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: const Key('userscript-delete-dialog'),
          title: Text('userscripts.deleteTitle'.tr()),
          content: Text('userscripts.deleteConfirm'.tr(args: [script.name])),
          actions: [
            TextButton(
              key: const Key('userscript-delete-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('common.cancel'.tr()),
            ),
            TextButton(
              key: const Key('userscript-delete-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('common.delete'.tr()),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    await widget.catalog.remove(script.id);
    await widget.onScriptDeleted?.call(script.id);
    final next = await widget.catalog.list();
    await widget.onApply(next);
    if (!mounted) return;
    setState(() => _scripts = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('userscripts-screen'),
      appBar: AppBar(
        title: Text('userscripts.title'.tr()),
        actions: [
          IconButton(
            key: const Key('userscript-add'),
            tooltip: 'userscripts.add'.tr(),
            onPressed: _importing ? null : _showAddDialog,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _scripts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'userscripts.empty'.tr(),
                        key: const Key('userscripts-empty'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const Key('userscripts-empty-add'),
                        onPressed: _importing ? null : _showAddDialog,
                        icon: const Icon(Icons.add),
                        label: Text('userscripts.add'.tr()),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  key: const Key('userscripts-list'),
                  itemCount: _scripts.length,
                  itemBuilder: (context, index) {
                    final script = _scripts[index];
                    return SwitchListTile(
                      key: Key('userscript-item-${script.id}'),
                      title: Text(script.name),
                      subtitle: script.version != null
                          ? Text(script.version!)
                          : (script.description != null
                              ? Text(script.description!)
                              : null),
                      value: script.enabled,
                      onChanged: _importing
                          ? null
                          : (_) => _toggle(script),
                      secondary: IconButton(
                        key: Key('userscript-delete-${script.id}'),
                        tooltip: 'common.delete'.tr(),
                        icon: const Icon(Icons.delete_outline),
                        onPressed:
                            _importing ? null : () => _confirmDelete(script),
                      ),
                    );
                  },
                ),
    );
  }
}

class _AddUserScriptDialog extends StatefulWidget {
  const _AddUserScriptDialog();

  @override
  State<_AddUserScriptDialog> createState() => _AddUserScriptDialogState();
}

class _AddUserScriptDialogState extends State<_AddUserScriptDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('userscript-add-dialog'),
      title: Text('userscripts.add'.tr()),
      content: TextField(
        key: const Key('userscript-url-field'),
        controller: _controller,
        decoration: InputDecoration(
          labelText: 'common.url'.tr(),
          hintText: 'https://example.com/script.user.js',
        ),
        keyboardType: TextInputType.url,
        autofocus: true,
      ),
      actions: [
        TextButton(
          key: const Key('userscript-add-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        TextButton(
          key: const Key('userscript-add-confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text('common.import'.tr()),
        ),
      ],
    );
  }
}
