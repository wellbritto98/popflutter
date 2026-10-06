import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import '../background/background_platform.dart';
import 'scheduler_client.dart';
import 'scheduler_editor.dart';
import 'scheduler_labels.dart';
import 'scheduler_permissions_card.dart';

class SchedulerScreen extends StatefulWidget {
  const SchedulerScreen({super.key, required this.api, required this.platform});
  final SchedulerApi? api;
  final BackgroundPlatform platform;
  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen>
    with WidgetsBindingObserver {
  SchedulerSnapshot? _snapshot;
  bool _loading = true, _pending = false;
  String? _error;
  Timer? _poll;
  Future<void>? _reading;
  bool _editing = false, _active = true;
  final _permissions = GlobalKey<SchedulerPermissionsCardState>();
  SchedulerApi get _api =>
      widget.api ?? (throw const SchedulerException('serviceUnavailable'));
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.platform.isAndroid) {
      _load();
    }
    if (widget.platform.isAndroid) {
      _poll = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_pending && !_editing && _active) unawaited(_load());
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed &&
        widget.platform.isAndroid &&
        !_pending &&
        !_editing) {
      unawaited(_load());
      unawaited(_permissions.currentState?.refresh());
    }
  }

  Future<void> _load() =>
      _reading ??= _loadOnce().whenComplete(() => _reading = null);
  Future<void> _loadOnce() async {
    try {
      final snapshot = await _api.list();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = schedulerError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _permission() async {
    final granted =
        await widget.platform.isNotificationGranted() ||
        await widget.platform.requestNotificationPermission();
    unawaited(_permissions.currentState?.refresh());
    return granted;
  }

  Future<void> _edit([ScheduledRule? rule]) async {
    _editing = true;
    final snapshot = await Navigator.of(context).push<SchedulerSnapshot>(
      MaterialPageRoute(
        builder: (_) => SchedulerEditor(
          api: _api,
          rule: rule,
          ensurePermission: _permission,
        ),
      ),
    );
    if (!mounted) return;
    _editing = false;
    if (snapshot != null) {
      setState(() => _snapshot = snapshot);
    } else {
      await _load();
    }
  }

  Future<void> _mutate(Future<SchedulerSnapshot> Function() command) async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      final snapshot = await command();
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (error) {
      final message = schedulerError(error);
      await _load();
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _toggle(ScheduledRule rule, bool enabled) => _mutate(() async {
    if (enabled && !await _permission()) {
      throw const SchedulerException('permissionDenied');
    }
    return _api.toggle(rule, enabled);
  });
  Future<void> _delete(ScheduledRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('scheduler.deleteTitle'.tr()),
        content: Text('scheduler.deletePrompt'.tr(args: [rule.name])),
        actions: [
          TextButton(
            key: const Key('schedule-delete-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text('scheduler.cancel'.tr()),
          ),
          FilledButton(
            key: const Key('schedule-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text('scheduler.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) await _mutate(() => _api.delete(rule));
  }

  Widget _rule(ScheduledRule rule) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rule.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Switch(
                key: Key('schedule-toggle-${rule.id}'),
                value: rule.enabled,
                onChanged: _pending ? null : (value) => _toggle(rule, value),
              ),
            ],
          ),
          Text(recurrenceLabel(rule.recurrence)),
          Text(
            !rule.enabled
                ? 'scheduler.paused'.tr()
                : rule.nextDueUtc == null
                ? 'scheduler.noNext'.tr()
                : 'scheduler.next'.tr(
                    args: [
                      DateFormat('yyyy-MM-dd HH:mm:ss')
                          .format(rule.nextDueUtc!.toLocal()),
                    ],
                  ),
          ),
          Text(resultLabel(rule.lastResult)),
          if (rule.lastResult.atUtc != null)
            Text(
              DateFormat('yyyy-MM-dd HH:mm:ss')
                  .format(rule.lastResult.atUtc!.toLocal()),
            ),
          Row(
            children: [
              TextButton.icon(
                key: Key('schedule-edit-${rule.id}'),
                onPressed: _pending ? null : () => _edit(rule),
                icon: const Icon(Icons.edit_outlined),
                label: Text('scheduler.edit'.tr()),
              ),
              TextButton.icon(
                key: Key('schedule-delete-${rule.id}'),
                onPressed: _pending ? null : () => _delete(rule),
                icon: const Icon(Icons.delete_outline),
                label: Text('scheduler.delete'.tr()),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('schedule-screen'),
    appBar: AppBar(
      title: Text('scheduler.title'.tr()),
      actions: [
        if (widget.platform.isAndroid)
          IconButton(
            key: const Key('schedule-refresh'),
            tooltip: 'scheduler.refresh'.tr(),
            onPressed: _pending ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
      ],
    ),
    floatingActionButton: widget.platform.isAndroid && widget.api != null
        ? FloatingActionButton(
            key: const Key('schedule-add'),
            tooltip: 'scheduler.create'.tr(),
            onPressed: _pending ? null : () => _edit(),
            child: const Icon(Icons.add),
          )
        : null,
    body: !widget.platform.isAndroid
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('scheduler.androidOnly'.tr()),
            ),
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              SchedulerPermissionsCard(
                key: _permissions,
                platform: widget.platform,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_snapshot?.rules.isEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('scheduler.empty'.tr()),
                )
              else
                ...?(_snapshot?.rules.map(_rule)),
            ],
          ),
  );
}
