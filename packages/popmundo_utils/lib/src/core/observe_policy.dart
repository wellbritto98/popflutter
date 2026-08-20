import 'host_tracker.dart';

enum NavDecision { allowInWebView, openExternal }

/// Pure navigation / resource policy. Never replaces game responses.
class ObservePolicy {
  static NavDecision decideNavigation(Uri uri) {
    if (HostTracker.isPopmundoUri(uri)) {
      return NavDecision.allowInWebView;
    }
    return NavDecision.openExternal;
  }

  /// Observe-only: callers must not substitute a [WebResourceResponse].
  static Null observeOnlyResourceResponse() => null;
}
