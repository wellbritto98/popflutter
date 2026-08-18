import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest declares INTERNET', () {
    final manifest = _open([
      'android/app/src/main/AndroidManifest.xml',
      'apps/popmundo_app/android/app/src/main/AndroidManifest.xml',
    ]);
    expect(manifest.contains('android.permission.INTERNET'), isTrue);
  });

  test('Android manifest declares FGS keepalive permissions and service', () {
    final manifest = _open([
      'android/app/src/main/AndroidManifest.xml',
      'apps/popmundo_app/android/app/src/main/AndroidManifest.xml',
    ]);
    expect(manifest.contains('android.permission.FOREGROUND_SERVICE'), isTrue);
    expect(
      manifest.contains('android.permission.FOREGROUND_SERVICE_DATA_SYNC'),
      isTrue,
    );
    expect(manifest.contains('android.permission.POST_NOTIFICATIONS'), isTrue);
    expect(
      manifest.contains(
        'android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
      ),
      isTrue,
    );
    expect(manifest.contains('android.permission.WAKE_LOCK'), isTrue);
    expect(
      manifest.contains(
        'com.pravera.flutter_foreground_task.service.ForegroundService',
      ),
      isTrue,
    );
    expect(manifest.contains('android:foregroundServiceType="dataSync"'), isTrue);
  });

  test('iOS ATS includes popmundo.com subdomains', () {
    final plist = _open([
      'ios/Runner/Info.plist',
      'apps/popmundo_app/ios/Runner/Info.plist',
    ]);
    expect(plist.contains('popmundo.com'), isTrue);
    expect(plist.contains('NSIncludesSubdomains'), isTrue);
  });

  test('iOS Info.plist declares background fetch for foreground_task', () {
    final plist = _open([
      'ios/Runner/Info.plist',
      'apps/popmundo_app/ios/Runner/Info.plist',
    ]);
    expect(plist.contains('UIBackgroundModes'), isTrue);
    expect(plist.contains('<string>fetch</string>'), isTrue);
    expect(plist.contains('BGTaskSchedulerPermittedIdentifiers'), isTrue);
    expect(
      plist.contains('com.pravera.flutter_foreground_task.refresh'),
      isTrue,
    );
  });
}

String _open(List<String> candidates) {
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError('Missing ${candidates.first}');
}
