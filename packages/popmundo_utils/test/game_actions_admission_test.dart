import 'dart:async';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'game_actions_item_test.dart' show ActionTransport, itemAction;

void main() => serviceAdmissionTests();
void serviceAdmissionTests() {
  gameplayCooldownAdmissionTest();
  test(
    'SGA-07 start callback precedes fresh credentials and every HTTP send',
    () async {
      final order = <String>[];
      final transport = _OrderTransport(order);
      final service = GameActionsService(
        createTransport: () => transport,
        readCredentials: () async {
          order.add('credentials');
          return const GameCredentials(
            username: 'account',
            password: 'synthetic',
          );
        },
        limits: const GameActionLimits(cooldown: Duration.zero),
      );
      final result = await service.execute(
        itemAction(),
        beforeHttp: () async {
          order.add('start');
        },
      );
      expect(result.status, GameActionStatus.confirmed);
      expect(order.take(3).toList(), ['start', 'credentials', 'HTTP']);
      await service.dispose();
    },
  );
  test(
    'SGA-07 missing credentials still sends start before failed outcome',
    () async {
      var started = false;
      final transport = ActionTransport();
      final service = GameActionsService(
        createTransport: () => transport,
        readCredentials: () async {
          expect(started, true);
          return const GameCredentials(username: 'account', password: '');
        },
      );
      final result = await service.execute(
        itemAction(),
        beforeHttp: () async {
          started = true;
        },
      );
      expect(result.status, GameActionStatus.failed);
      expect(result.errorCode, 'credentialsMissing');
      expect(transport.requests, isEmpty);
      await service.dispose();
    },
  );
  test('SGA-07 failed start callback stops credentials and HTTP', () async {
    var reads = 0;
    final transport = ActionTransport();
    final service = GameActionsService(
      createTransport: () => transport,
      readCredentials: () async {
        reads++;
        return const GameCredentials(
          username: 'account',
          password: 'synthetic',
        );
      },
    );
    final result = await service.execute(
      itemAction(),
      beforeHttp: () async {
        throw StateError('synthetic-secret');
      },
    );
    expect(result.status, GameActionStatus.failed);
    expect(result.errorCode, 'notificationFailed');
    expect(reads, 0);
    expect(transport.requests, isEmpty);
    await service.dispose();
  });
  test(
    'SGA-09 cancellation while notifying prevents late credentials/HTTP',
    () async {
      final notifier = Completer<void>();
      final transport = ActionTransport();
      var reads = 0;
      final service = GameActionsService(
        createTransport: () => transport,
        readCredentials: () async {
          reads++;
          return const GameCredentials(
            username: 'account',
            password: 'synthetic',
          );
        },
        limits: const GameActionLimits(
          transactionTimeout: Duration(milliseconds: 20),
        ),
      );
      final result = await service.execute(
        itemAction(),
        beforeHttp: () => notifier.future,
      );
      expect(result.status, GameActionStatus.failed);
      expect(result.errorCode, 'transactionTimeout');
      expect(transport.closed, true);
      notifier.complete();
      await Future<void>.delayed(Duration.zero);
      expect(reads, 0);
      expect(transport.requests, isEmpty);
      await service.dispose();
    },
  );
}

class _OrderTransport extends ActionTransport {
  _OrderTransport(this.order);
  final List<String> order;
  @override
  Future<AuthHttpResponse> send(AuthHttpRequest request) {
    order.add('HTTP');
    return super.send(request);
  }
}

void gameplayCooldownAdmissionTest() {
  test('SGA-09 cancellation during gameplay cooldown is failed before actual transmission', () async {
    final transport = ActionTransport();
    var time = DateTime.utc(2026);
    late GameActionsService service;
    service = GameActionsService(
      createTransport: () => transport,
      readCredentials: () async =>
          const GameCredentials(username: 'account', password: 'synthetic'),
      now: () => time,
      sleep: (delay) async {
        if (transport.notificationReads == 1 && transport.gameplay.isEmpty) {
          service.cancel();
        }
        time = time.add(delay);
      },
    );
    final outcome = await service.execute(itemAction());
    expect(outcome.status, GameActionStatus.failed);
    expect(outcome.errorCode, 'serviceUnavailable');
    expect(transport.gameplay, isEmpty);
    expect(transport.notificationReads, 1);
    expect(transport.closed, true);
    await service.dispose();
  });
}
