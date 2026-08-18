import 'dart:convert';

import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'fake_runtime.dart';

void main() {
  test('CssSelectorHelper decodes serialized nodes', () async {
    final runtime = FakePopmundoRuntime();
    runtime.evaluateHandler = (source) {
      if (source.contains('querySingle')) {
        return jsonEncode({'tag': 'div', 'id': 'x', 'className': 'box', 'text': 'hi'});
      }
      return jsonEncode([
        {'tag': 'span', 'id': '', 'className': '', 'text': 'a'},
      ]);
    };
    final helper = CssSelectorHelper(runtime, 'div.box');
    expect((await helper.getSingle())?['id'], 'x');
    expect((await helper.getAll()).single['text'], 'a');
  });

  test('Scoring is not auto-applied and evaluate runs on call', () async {
    expect(Scoring.autoApplyOnLoad, isFalse);
    final runtime = FakePopmundoRuntime();
    runtime.evaluateHandler = (_) => 'ok';
    await Scoring(runtime).applyScoringNumbers();
    expect(
      runtime.evaluateCalls.single,
      contains('applyScoringNumbers'),
    );
  });
}
