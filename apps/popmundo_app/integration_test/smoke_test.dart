// Proves the Patrol device-real tier runs end-to-end (build, install,
// execute, report) without importing anything from lib/ or constructing
// any runtime. See .specs/features/mobile-e2e-tests/spec.md (P1: Tier de
// teste em device real).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('smoke: pumps a trivial widget and asserts it', ($) async {
    await $.pumpWidgetAndSettle(
      const MaterialApp(
        home: Scaffold(body: Text('patrol smoke test')),
      ),
    );

    expect($('patrol smoke test'), findsOneWidget);
  });
}
