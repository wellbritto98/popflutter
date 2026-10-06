import 'dart:convert';
import 'dart:io';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  test(
    'SGA-09 native sender rejects decoded UTF8 bytes over ceiling',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) {
        request.response.add(utf8.encode('😀😀'));
        request.response.close();
      });
      final sender = IoAuthHttpSender(maxDecodedBodyBytes: 7);
      try {
        await expectLater(
          sender.call(
            AuthHttpRequest(
              url: Uri.parse('http://127.0.0.1:${server.port}/'),
              method: 'GET',
            ),
          ),
          throwsA(
            isA<AuthHttpException>().having(
              (e) => e.message,
              'message',
              'Response exceeds decoded body limit',
            ),
          ),
        );
      } finally {
        sender.close();
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
  test('SGA-09 native optional limit accepts exact bytes and legacy default intact', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) {
      request.response.add(utf8.encode('😀😀'));
      request.response.close();
    });
    final bounded = IoAuthHttpSender(maxDecodedBodyBytes: 8);
    final legacy = IoAuthHttpSender();
    try {
      final request = AuthHttpRequest(
        url: Uri.parse('http://127.0.0.1:${server.port}/'),
        method: 'GET',
      );
      expect((await bounded.call(request)).body, '😀😀');
      expect((await legacy.call(request)).body, '😀😀');
      expect(legacy.maxDecodedBodyBytes, isNull);
      expect(legacy.timeout, const Duration(seconds: 20));
      const limits = GameActionLimits();
      expect(limits.transactionTimeout, const Duration(seconds: 120));
      expect(limits.requestTimeout, const Duration(seconds: 20));
      expect(limits.maxDecodedBodyBytes, 2097152);
      expect(limits.cooldown, const Duration(milliseconds: 750));
    } finally {
      bounded.close();
      legacy.close();
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
