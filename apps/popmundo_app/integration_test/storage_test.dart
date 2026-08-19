// Device-real assertions for storage (STO-01..STO-05).
//
// Exercises the REAL Android Keystore / EncryptedSharedPreferences via
// FlutterSecureSecretStore, and the REAL SharedPreferences platform channel
// via SharedPreferencesStore. The fake tier uses MemoryKeyValueStore, which
// cannot catch a platform-channel or Keystore problem.
//
// ONE patrolTest PER FILE — DO NOT ADD A SECOND ONE. See the header of
// keepalive_test.dart for why (upstream Patrol limitation, issues 2005/2380).
//
// See .specs/features/mobile-e2e-tests/spec.md (P2: Storage real).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:popmundo_app/autologin/secure_secret_store.dart';
import 'package:popmundo_app/prefs_store.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

void main() {
  patrolTest('storage: real keystore and prefs round-trip, password stays out '
      'of plain prefs', ($) async {
    await pumpHarness($, const Text('storage harness'));

    const secretKey = 'e2e.storage.secret';
    const secretValue = 'keystore-round-trip-value';
    const prefsKey = 'e2e.storage.prefs';
    const password = 'e2e-p4ssw0rd-not-in-prefs';

    final secrets = FlutterSecureSecretStore();
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesStore(prefs);

    // Own our cleanup: these keys must not leak into a later run even if
    // clearPackageData is ever turned off.
    addTearDown(() async {
      await secrets.delete(secretKey);
      await secrets.delete(AutoLoginSettingsStore.passwordSecretKey);
      await store.remove(prefsKey);
      await store.remove(AutoLoginSettingsStore.defaultStorageKey);
    });

    // STO-01: real Keystore / EncryptedSharedPreferences round-trip.
    await secrets.write(secretKey, secretValue);
    expect(
      await secrets.read(secretKey),
      secretValue,
      reason: 'STO-01: secure storage did not return the exact value written',
    );

    // STO-02: delete actually clears.
    await secrets.delete(secretKey);
    expect(
      await secrets.read(secretKey),
      isNull,
      reason: 'STO-02: value survived delete in secure storage',
    );

    // STO-04: JSON round-trip through the real platform channel. Read back
    // through a FRESHLY constructed store so an in-memory cache cannot be
    // mistaken for real persistence.
    await store.set(prefsKey, {
      'enabled': true,
      'count': 42,
      'name': 'popmundo',
    });
    final freshStore = SharedPreferencesStore(
      await SharedPreferences.getInstance(),
    );
    expect(
      await freshStore.get(prefsKey),
      {'enabled': true, 'count': 42, 'name': 'popmundo'},
      reason: 'STO-04: structured value did not survive the platform channel',
    );

    // STO-05: remove actually clears.
    await store.remove(prefsKey);
    expect(
      await freshStore.get(prefsKey),
      isNull,
      reason: 'STO-05: value survived remove in shared preferences',
    );

    // STO-03: the Auto Login password must live ONLY in the secret store.
    // Save through the same split the app uses: settings via KeyValueStore,
    // password via SecretStore.
    final settingsStore = AutoLoginSettingsStore(store);
    await settingsStore.save(
      const AutoLoginSettings(
        enabled: true,
        username: 'e2e-user',
        characterName: 'e2e-character',
        status: 2,
      ),
    );
    await secrets.write(AutoLoginSettingsStore.passwordSecretKey, password);

    final reread = await SharedPreferences.getInstance();
    await reread.reload();
    final leaked = <String>[];
    for (final key in reread.getKeys()) {
      final value = reread.get(key);
      if (value != null && value.toString().contains(password)) {
        leaked.add(key);
      }
    }
    expect(
      leaked,
      isEmpty,
      reason:
          'STO-03: the Auto Login password was found in plain SharedPreferences '
          'under $leaked — it must exist only in SecretStore (AD-011)',
    );

    // …and prove the assertion above is not passing merely because nothing was
    // stored: the password IS retrievable from the secure store.
    expect(
      await secrets.read(AutoLoginSettingsStore.passwordSecretKey),
      password,
      reason:
          'STO-03: password missing from SecretStore, so the leak check above '
          'proved nothing',
    );
  });
}
