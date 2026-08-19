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
    // stopWithTask="true" kills the FGS the moment the app leaves Recents,
    // defeating the whole point of background keepalive — must stay false.
    expect(manifest.contains('android:stopWithTask="false"'), isTrue);
    expect(manifest.contains('android:stopWithTask="true"'), isFalse);
  });

  test('FlutterForegroundTaskPlatform does not stop the service with the task', () {
    final source = _open([
      'lib/background/flutter_foreground_task_platform.dart',
      'apps/popmundo_app/lib/background/flutter_foreground_task_platform.dart',
    ]);
    expect(source.contains('stopWithTask: false'), isTrue);
    expect(source.contains('stopWithTask: true'), isFalse);
  });

  test('FGS isolate does not probe Character or touch AuthSession', () {
    final source = _open([
      'lib/background/keepalive_task_handler.dart',
      'apps/popmundo_app/lib/background/keepalive_task_handler.dart',
    ]);
    expect(source.contains('World/Popmundo.aspx/Character'), isFalse);
    expect(source.contains('AuthSession'), isFalse);
    expect(source.contains('CookieSource'), isFalse);
    expect(source.contains('loadUrl'), isFalse);
    expect(source.contains("'heartbeat'"), isTrue);
  });

  test('iOS ATS includes popmundo.com subdomains', () {
    final plist = _open([
      'ios/Runner/Info.plist',
      'apps/popmundo_app/ios/Runner/Info.plist',
    ]);
    expect(plist.contains('popmundo.com'), isTrue);
    expect(plist.contains('NSIncludesSubdomains'), isTrue);
  });

  test('iOS Info.plist declares the app shell supported localizations', () {
    final plist = _open([
      'ios/Runner/Info.plist',
      'apps/popmundo_app/ios/Runner/Info.plist',
    ]);
    expect(plist.contains('CFBundleLocalizations'), isTrue);
    expect(plist.contains('<string>en</string>'), isTrue);
    expect(plist.contains('<string>pt</string>'), isTrue);
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
