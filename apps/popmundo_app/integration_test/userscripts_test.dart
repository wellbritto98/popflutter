// Device-real assertions for userscript download + import (US-01..US-04).
//
// Exercises the REAL dart:io HttpClient over REAL sockets against a loopback
// HttpServer started inside the test, and the REAL SharedPreferences-backed
// catalog. Hermetic by construction: port 0 means the OS assigns a free port,
// and nothing leaves the device — in particular nothing touches popmundo.com.
//
// ONE patrolTest PER FILE — DO NOT ADD A SECOND ONE. See the header of
// keepalive_test.dart for why (upstream Patrol limitation, issues 2005/2380).
//
// See .specs/features/mobile-e2e-tests/spec.md (P2: Import de userscript real).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:popmundo_app/prefs_store.dart';
import 'package:popmundo_app/userscripts/userscript_http.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/harness.dart';

const _validUserScript = '''
// ==UserScript==
// @name         E2E Fixture
// @namespace    popflutter.e2e
// @version      1.0.0
// @description  Served from an in-test loopback server.
// @match        https://*.popmundo.com/*
// ==/UserScript==

console.log('e2e fixture loaded');
''';

void main() {
  patrolTest('userscripts: real socket download, catalog persistence, and '
      'failure paths', ($) async {
    await pumpHarness($, const Text('userscripts harness'));

    const catalogKey = 'e2e.userscripts.v1';
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesStore(prefs);
    addTearDown(() => store.remove(catalogKey));

    // ---- US-01: real HTTP GET over a loopback socket -----------------------
    final okServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => okServer.close(force: true));
    okServer.listen((request) async {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType('text', 'javascript');
      request.response.write(_validUserScript);
      await request.response.close();
    });
    final okUrl = Uri.parse(
      'http://${okServer.address.address}:${okServer.port}/fixture.user.js',
    );

    expect(
      await fetchUserScriptUrl(okUrl),
      _validUserScript,
      reason: 'US-01: body returned over the real socket did not match',
    );

    // ---- US-02: import persists through the real prefs channel -------------
    final catalog = UserScriptCatalog(store, storageKey: catalogKey);
    final importer = UserScriptImporter(
      catalog: catalog,
      httpGet: fetchUserScriptUrl,
    );
    final installed = await importer.importFromUrl(okUrl.toString());

    // Fresh catalog over a fresh SharedPreferences handle, so this proves
    // persistence rather than in-memory state.
    final freshCatalog = UserScriptCatalog(
      SharedPreferencesStore(await SharedPreferences.getInstance()),
      storageKey: catalogKey,
    );
    expect(
      (await freshCatalog.list()).map((s) => s.id),
      contains(installed.id),
      reason: 'US-02: imported script was not persisted to the real catalog',
    );

    // ---- US-03: non-2xx surfaces a typed error naming the status ----------
    final notFoundServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => notFoundServer.close(force: true));
    notFoundServer.listen((request) async {
      request.response.statusCode = 404;
      await request.response.close();
    });
    final notFoundUrl = Uri.parse(
      'http://${notFoundServer.address.address}:'
      '${notFoundServer.port}/missing.user.js',
    );

    await expectLater(
      fetchUserScriptUrl(notFoundUrl),
      throwsA(
        isA<UserScriptImportException>().having(
          (e) => e.toString(),
          'message',
          contains('404'),
        ),
      ),
      reason: 'US-03: a 404 did not surface as UserScriptImportException(404)',
    );

    // ---- US-04: a server that accepts but never answers must time out ------
    final silentServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => silentServer.close(force: true));
    // Deliberately never respond: hold the request open.
    silentServer.listen((_) {});
    final silentUrl = Uri.parse(
      'http://${silentServer.address.address}:'
      '${silentServer.port}/hangs.user.js',
    );

    await expectLater(
      fetchUserScriptUrl(silentUrl, timeout: const Duration(seconds: 2)),
      throwsA(
        isA<UserScriptImportException>().having(
          (e) => e.toString().toLowerCase(),
          'message',
          contains('timed out'),
        ),
      ),
      reason: 'US-04: an unanswered request did not surface as a timeout',
    );
  });
}
