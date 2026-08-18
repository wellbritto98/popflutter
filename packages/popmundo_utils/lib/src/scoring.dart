import 'popmundo_runtime.dart';

class Scoring {
  Scoring(this.runtime);

  final PopmundoRuntime runtime;

  /// Scoring must not run on page load unless the developer calls it.
  static const bool autoApplyOnLoad = false;

  Future<void> applyScoringNumbers() async {
    await runtime.evaluate('window.__popmundo.applyScoringNumbers()');
  }

  Future<void> applyBarPercentage() async {
    await runtime.evaluate('window.__popmundo.applyBarPercentage()');
  }
}
