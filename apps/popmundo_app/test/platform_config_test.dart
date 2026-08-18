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

  test('iOS ATS includes popmundo.com subdomains', () {
    final plist = _open([
      'ios/Runner/Info.plist',
      'apps/popmundo_app/ios/Runner/Info.plist',
    ]);
    expect(plist.contains('popmundo.com'), isTrue);
    expect(plist.contains('NSIncludesSubdomains'), isTrue);
  });
}

String _open(List<String> candidates) {
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError('Missing ${candidates.first}');
}
