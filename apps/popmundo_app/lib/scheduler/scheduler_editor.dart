import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'scheduler_client.dart';
import 'scheduler_game_fields.dart';
import 'scheduler_labels.dart';
import 'scheduler_recurrence_fields.dart';

enum _Service { notification, item, crew }

class SchedulerEditor extends StatefulWidget {
  const SchedulerEditor({
    super.key,
    required this.api,
    required this.ensurePermission,
    this.discovery,
    this.rule,
    this.onSaved,
  });
  final SchedulerApi api;
  final GameActionsApi? discovery;
  final Future<bool> Function() ensurePermission;
  final ScheduledRule? rule;
  final void Function(SchedulerSnapshot)? onSaved;
  @override
  State<SchedulerEditor> createState() => _SchedulerEditorState();
}

class _SchedulerEditorState extends State<SchedulerEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _title = TextEditingController(),
      _body = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  late final String _id = widget.rule?.id ?? SchedulerClient.newRuleId();
  ScheduledRule? _rule;
  bool _enabled = true, _weekly = false, _pending = false, _needsRead = false;
  bool _loadingChoices = false, _targetLocked = false;
  _Service _service = _Service.notification;
  GameCharacterCatalog? _catalog;
  GameCharacter? _character;
  List<GameItemChoice> _items = const [];
  GameCrewOptions? _crew;
  String? _itemName;
  int? _bonusLevel;
  int _ticket = 0;
  IntervalUnit _unit = IntervalUnit.minutes;
  Set<int> _days = {};
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  String? _error;
  @override
  void initState() {
    super.initState();
    _rule = widget.rule;
    final rule = _rule;
    if (rule == null) return;
    _name.text = rule.name;
    final action = rule.action;
    if (action is LocalNotificationAction) {
      _title.text = action.title;
      _body.text = action.body;
    }
    _enabled = rule.enabled;
    final game = rule.action;
    if (game is GameScheduledAction) _restoreSaved(game);
    final recurrence = rule.recurrence;
    if (recurrence is IntervalRecurrence) {
      _quantity.text = recurrence.quantity.toString();
      _unit = recurrence.unit;
    }
    if (recurrence is WeeklyRecurrence) {
      _weekly = true;
      _days = Set.of(recurrence.weekdays);
      _time = TimeOfDay(hour: recurrence.hour, minute: recurrence.minute);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _body.dispose();
    _quantity.dispose();
    super.dispose();
  }

  String? _text(String? value, int max) {
    final length = (value ?? '').trim().length;
    return length < 1 || length > max
        ? 'scheduler.textError'.tr(args: [max.toString()])
        : null;
  }

  Future<void> _read() async {
    final snapshot = await widget.api.list();
    final matches = snapshot.rules.where((rule) => rule.id == _id);
    if (matches.isNotEmpty) {
      _rule = matches.single;
    } else if (_rule != null) {
      throw const SchedulerException('ruleNotFound');
    }
    _needsRead = false;
  }

  Future<void> _reread() async {
    setState(() => _pending = true);
    try {
      await _read();
    } catch (error) {
      _error = schedulerError(error);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  void _restoreSaved(GameScheduledAction action) {
    _targetLocked = true;
    _character = action.character;
    _service = action is PayCrewAction ? _Service.crew : _Service.item;
    _itemName = action is UseItemAction ? action.itemName : null;
    _bonusLevel = action is PayCrewAction ? action.bonusLevel : null;
  }

  Future<void> _selectService(_Service service) async {
    final saved = _rule?.action;
    final sameSaved =
        (service == _Service.item && saved is UseItemAction) ||
        (service == _Service.crew && saved is PayCrewAction);
    setState(() {
      _service = service;
      _error = null;
      if (sameSaved) {
        _restoreSaved(saved as GameScheduledAction);
      } else if (service != _Service.notification) {
        _targetLocked = false;
        _character = null;
        _itemName = null;
        _bonusLevel = null;
        _items = const [];
        _crew = null;
        _catalog = null;
      }
    });
    if (service != _Service.notification && !sameSaved) {
      await _loadCharacters();
    }
  }

  Future<void> _loadCharacters() async {
    final ticket = ++_ticket;
    final discovery = widget.discovery;
    if (discovery == null) {
      setState(() => _error = 'scheduler.credentialsMissing'.tr());
      return;
    }
    setState(() => _loadingChoices = true);
    try {
      final catalog = await discovery.discoverCharacters();
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _catalog = catalog;
        _loadingChoices = false;
      });
    } catch (error) {
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _loadingChoices = false;
        _error = _discoveryMessage(error);
      });
    }
  }

  Future<void> _selectCharacter(GameCharacter character) async {
    final ticket = ++_ticket;
    final discovery = widget.discovery;
    final catalog = _catalog;
    if (discovery == null || catalog == null) return;
    setState(() {
      _character = character;
      _itemName = null;
      _bonusLevel = null;
      _items = const [];
      _crew = null;
      _loadingChoices = true;
      _error = null;
    });
    try {
      if (_service == _Service.item) {
        final items = await discovery.discoverItems(
          boundUsername: catalog.username,
          character: character,
        );
        if (!mounted || ticket != _ticket) return;
        setState(() {
          _items = items;
          _loadingChoices = false;
        });
      } else {
        final crew = await discovery.discoverCrew(
          boundUsername: catalog.username,
          character: character,
        );
        if (!mounted || ticket != _ticket) return;
        setState(() {
          _crew = crew;
          _loadingChoices = false;
        });
      }
    } catch (error) {
      if (!mounted || ticket != _ticket) return;
      setState(() {
        _loadingChoices = false;
        _error = _discoveryMessage(error);
      });
    }
  }

  String _discoveryMessage(Object error) {
    final code = error is SchedulerException ? error.code : '';
    if (code == 'credentialsMissing' || code == 'credentialsUnavailable') {
      return 'scheduler.credentialsMissing'.tr();
    }
    return 'scheduler.discoveryFailed'.tr();
  }

  String? get _effect {
    if (_service == _Service.item && _character != null && _itemName != null) {
      return 'scheduler.effectItem'.tr(args: [_itemName!, _character!.name]);
    }
    if (_service != _Service.crew || _bonusLevel == null) return null;
    final saved = _rule?.action;
    final artist =
        _crew?.artistName ??
        (saved is PayCrewAction ? saved.artistName : null);
    final quoted = _crew?.bonuses.where((bonus) => bonus.level == _bonusLevel);
    final cost = quoted != null && quoted.isNotEmpty
        ? quoted.single.costMinor
        : saved is PayCrewAction && saved.bonusLevel == _bonusLevel
        ? saved.maxCostMinor
        : null;
    if (artist == null || cost == null) return null;
    return 'scheduler.effectCrew'.tr(
      args: [_bonusLevel.toString(), cost.toString(), artist],
    );
  }

  ScheduledAction? _action() {
    if (_service == _Service.notification) {
      return LocalNotificationAction(title: _title.text, body: _body.text);
    }
    final saved = _rule?.action;
    if (_targetLocked && saved is GameScheduledAction) return saved;
    final character = _character;
    final catalog = _catalog;
    if (character == null || catalog == null) return null;
    if (_service == _Service.item) {
      final item = _itemName;
      if (item == null || !_items.any((choice) => choice.name == item)) {
        return null;
      }
      return UseItemAction(
        boundUsername: catalog.username,
        character: character,
        itemName: item,
      );
    }
    final crew = _crew;
    final level = _bonusLevel;
    if (crew == null || level == null) return null;
    final matches = crew.bonuses.where((bonus) => bonus.level == level);
    if (matches.length != 1) return null;
    return PayCrewAction(
      boundUsername: catalog.username,
      character: character,
      artistId: crew.artistId,
      artistName: crew.artistName,
      bonusLevel: level,
      maxCostMinor: matches.single.costMinor,
    );
  }

  Future<void> _save() async {
    if (_pending ||
        _needsRead ||
        _loadingChoices ||
        !_form.currentState!.validate()) {
      return;
    }
    final action = _action();
    if (action == null) {
      setState(() => _error = 'scheduler.choiceRequired'.tr());
      return;
    }
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      if (_enabled && !await widget.ensurePermission()) {
        throw const SchedulerException('permissionDenied');
      }
      final draft = ScheduleDraft(
        name: _name.text,
        enabled: _enabled,
        recurrence: _weekly
            ? WeeklyRecurrence(
                weekdays: _days,
                hour: _time.hour,
                minute: _time.minute,
              )
            : IntervalRecurrence(
                quantity: int.parse(_quantity.text.trim()),
                unit: _unit,
                anchorUtc: DateTime.now().toUtc(),
              ),
        action: action,
      );
      final snapshot = _rule == null
          ? await widget.api.create(draft, id: _id)
          : await widget.api.update(_rule!, draft);
      _rule = snapshot.rules.singleWhere((rule) => rule.id == _id);
      if (!mounted) return;
      widget.onSaved?.call(snapshot);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(snapshot);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('scheduler.saved'.tr())));
      }
    } catch (error) {
      _error = schedulerError(error);
      _needsRead = true;
      try {
        await _read();
      } catch (_) {
        /* Saving stays disabled until authoritative refresh. */
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Widget _field(
    String key,
    String label,
    TextEditingController controller,
    int max, {
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: Key(key),
      controller: controller,
      enabled: !_pending,
      maxLines: lines,
      validator: (value) => _text(value, max),
      decoration: InputDecoration(
        labelText: ['scheduler', label].join('.').tr(),
        border: const OutlineInputBorder(),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('schedule-editor'),
    appBar: AppBar(
      title: Text((_rule == null ? 'scheduler.create' : 'scheduler.edit').tr()),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  key: const Key('schedule-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_needsRead)
              TextButton(
                key: const Key('schedule-reread'),
                onPressed: _pending ? null : _reread,
                child: Text('scheduler.reread'.tr()),
              ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const Key('schedule-cancel'),
                    onPressed: _pending
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    child: Text('scheduler.cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('schedule-save'),
                    onPressed: _pending || _needsRead || _loadingChoices
                        ? null
                        : _save,
                    child: Text(
                      (_pending ? 'scheduler.saving' : 'scheduler.save').tr(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    body: Form(
      key: _form,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field('schedule-name', 'name', _name, 80),
            SwitchListTile(
              key: const Key('schedule-enabled'),
              title: Text('scheduler.enabled'.tr()),
              value: _enabled,
              onChanged: _pending
                  ? null
                  : (value) => setState(() => _enabled = value),
            ),
            Text(
              'scheduler.recurrence'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('schedule-interval'),
                  label: Text('scheduler.interval'.tr()),
                  selected: !_weekly,
                  onSelected: _pending
                      ? null
                      : (_) => setState(() => _weekly = false),
                ),
                ChoiceChip(
                  key: const Key('schedule-weekly'),
                  label: Text('scheduler.weekly'.tr()),
                  selected: _weekly,
                  onSelected: _pending
                      ? null
                      : (_) => setState(() => _weekly = true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SchedulerRecurrenceFields(
              weekly: _weekly,
              pending: _pending,
              quantity: _quantity,
              unit: _unit,
              days: _days,
              time: _time,
              onUnit: (value) => setState(() => _unit = value),
              onDays: (value) => setState(() => _days = value),
              onTime: (value) => setState(() => _time = value),
            ),
            const SizedBox(height: 20),
            Text(
              'scheduler.action'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('schedule-service-local'),
                  label: Text('scheduler.localNotification'.tr()),
                  selected: _service == _Service.notification,
                  onSelected: _pending || _loadingChoices
                      ? null
                      : (_) => unawaited(_selectService(_Service.notification)),
                ),
                ChoiceChip(
                  key: const Key('schedule-service-item'),
                  label: Text('scheduler.useItem'.tr()),
                  selected: _service == _Service.item,
                  onSelected: _pending || _loadingChoices
                      ? null
                      : (_) => unawaited(_selectService(_Service.item)),
                ),
                ChoiceChip(
                  key: const Key('schedule-service-crew'),
                  label: Text('scheduler.payCrew'.tr()),
                  selected: _service == _Service.crew,
                  onSelected: _pending || _loadingChoices
                      ? null
                      : (_) => unawaited(_selectService(_Service.crew)),
                ),
              ],
            ),
            if (_service == _Service.notification) ...[
              _field('schedule-title', 'notificationTitle', _title, 120),
              _field(
                'schedule-body',
                'notificationBody',
                _body,
                1000,
                lines: 3,
              ),
            ] else
              SchedulerGameFields(
                crew: _service == _Service.crew,
                pending: _pending || _loadingChoices,
                locked: _targetLocked,
                catalog: _catalog,
                character: _character,
                items: _items,
                itemName: _itemName,
                crewOptions: _crew,
                bonusLevel: _bonusLevel,
                effect: _effect,
                onCharacter: (value) => unawaited(_selectCharacter(value)),
                onItem: (value) => setState(() => _itemName = value),
                onBonus: (value) => setState(() => _bonusLevel = value),
                onChangeTarget: () {
                  setState(() {
                    _targetLocked = false;
                    _character = null;
                    _itemName = null;
                    _bonusLevel = null;
                    _items = const [];
                    _crew = null;
                    _catalog = null;
                    _error = null;
                  });
                  unawaited(_loadCharacters());
                },
              ),
          ],
        ),
      ),
    ),
  );
}
