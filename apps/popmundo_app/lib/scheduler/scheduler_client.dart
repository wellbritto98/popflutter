import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'game_actions_api.dart';
export 'game_actions_api.dart';

abstract class SchedulerApi {
  Future<SchedulerSnapshot> list();
  Future<SchedulerSnapshot> create(ScheduleDraft draft, {required String id});
  Future<SchedulerSnapshot> update(ScheduledRule rule, ScheduleDraft draft);
  Future<SchedulerSnapshot> toggle(ScheduledRule rule, bool enabled);
  Future<SchedulerSnapshot> delete(ScheduledRule rule);
}
/// Main-isolate transport; no local coordinator or preferences writer.
class SchedulerClient implements SchedulerApi, GameActionsApi {
  SchedulerClient({required this.send, required this.addListener, required this.removeListener, required this.ensureRunning, this.timeout = const Duration(seconds: 15), this.discoveryTimeout = const Duration(seconds: 150)}) { addListener(_receive); }
  final void Function(Map<String, Object?> data) send;
  final void Function(void Function(Object)) addListener;
  final void Function(void Function(Object)) removeListener;
  final Future<void> Function() ensureRunning;
  final Duration timeout, discoveryTimeout;
  final _pending = <String, Completer<Map>>{};
  final _nonce = Random.secure().nextInt(1 << 32).toRadixString(16);
  int _sequence = 0;
  bool _disposed = false;
  static String newRuleId() => ['rule', DateTime.now().microsecondsSinceEpoch.toString(), Random.secure().nextInt(1 << 32).toString()].join('-');
  Future<Map> _message(String command, Map<String, Object?> fields, Duration budget) async {
    if (_disposed) throw const SchedulerException('serviceUnavailable');
    try { await ensureRunning().timeout(timeout); } on TimeoutException { throw const SchedulerException('requestTimeout'); }
    if (_disposed) throw const SchedulerException('serviceUnavailable');
    final id = [_nonce, (++_sequence).toString()].join('-');
    final completer = Completer<Map>(); _pending[id] = completer;
    try {
      send({'type': 'scheduler.request', 'requestId': id, 'command': command, ...fields});
      return await completer.future.timeout(budget);
    } on TimeoutException { throw const SchedulerException('requestTimeout'); }
    finally { _pending.remove(id); }
  }
  Future<SchedulerSnapshot> _request(String command, [Map<String, Object?> fields = const {}]) async {
    final response = await _message(command, fields, timeout);
    try { return SchedulerSnapshot.decode(jsonEncode(response['snapshot'])); }
    catch (_) { throw const SchedulerException('invalidResponse'); }
  }
  Future<T> _discover<T>(String command, Map<String, Object?> fields, T Function(Object?) decode) async {
    final response = await _message(command, fields, discoveryTimeout);
    try { return decode(response['data']); }
    catch (_) { throw const SchedulerException('invalidResponse'); }
  }
  void _receive(Object data) {
    if (data is! Map || data['type'] != 'scheduler.response') return;
    final pending = _pending[data['requestId']];
    if (pending == null || pending.isCompleted) return;
    final error = data['error'];
    if (error != null) { pending.completeError(SchedulerException(error is String ? error : 'invalidResponse')); return; }
    pending.complete(data);
  }
  @override
  Future<GameCharacterCatalog> discoverCharacters() => _discover('discoverCharacters', {}, (data) => GameCharacterCatalog.fromJson(data as Map));
  Map<String, Object?> _target(String username, GameCharacter character) => {'boundUsername': username, 'character': character.toJson()};
  @override
  Future<List<GameItemChoice>> discoverItems({required String boundUsername, required GameCharacter character}) => _discover('discoverItems', _target(boundUsername, character), (data) => (data as List).map((v) => GameItemChoice.fromJson(v as Map)).toList());
  @override
  Future<GameCrewOptions> discoverCrew({required String boundUsername, required GameCharacter character}) => _discover('discoverCrew', _target(boundUsername, character), (data) => GameCrewOptions.fromJson(data as Map));
  @override
  Future<SchedulerSnapshot> list() => _request('list');
  Map<String, Object?> _draft(ScheduleDraft draft) => {'name': draft.name, 'enabled': draft.enabled, 'recurrence': draft.recurrence.toJson(), 'action': draft.action.toJson()};
  @override
  Future<SchedulerSnapshot> create(ScheduleDraft draft, {required String id}) => _request('create', {'id': id, 'draft': _draft(draft)});
  @override
  Future<SchedulerSnapshot> update(ScheduledRule rule, ScheduleDraft draft) => _request('update', {'id': rule.id, 'revision': rule.revision, 'draft': _draft(draft)});
  @override
  Future<SchedulerSnapshot> toggle(ScheduledRule rule, bool enabled) => _request('toggle', {'id': rule.id, 'revision': rule.revision, 'enabled': enabled});
  @override
  Future<SchedulerSnapshot> delete(ScheduledRule rule) => _request('delete', {'id': rule.id, 'revision': rule.revision});
  void dispose() {
    if (_disposed) return;
    _disposed = true; removeListener(_receive);
    for (final request in _pending.values) { if (!request.isCompleted) request.completeError(const SchedulerException('serviceUnavailable')); }
    _pending.clear();
  }
}
