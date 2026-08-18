import 'dart:collection';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

/// Narrow port over the InAppWebView controller methods this feature needs.
///
/// Intentionally omits wipe-all APIs so callers cannot clear built-in scripts.
abstract class UserScriptWebViewPort {
  Future<void> addUserScript(UserScript userScript);
  Future<void> removeUserScriptsByGroupName(String groupName);
  Future<void> reload();
}

class InAppUserScriptWebViewPort implements UserScriptWebViewPort {
  InAppUserScriptWebViewPort(this.controller);

  final InAppWebViewController controller;

  @override
  Future<void> addUserScript(UserScript userScript) {
    return controller.addUserScript(userScript: userScript);
  }

  @override
  Future<void> removeUserScriptsByGroupName(String groupName) {
    return controller.removeUserScriptsByGroupName(groupName: groupName);
  }

  @override
  Future<void> reload() => controller.reload();
}

class UserScriptInjector {
  /// Maps a catalog entry to an InAppWebView [UserScript] (USM-14).
  ///
  /// When the script's `@grant` list requests a Core GM function
  /// (`GM_getValue`/`GM_addStyle`/etc.), the generated source is wrapped in a
  /// per-script GM shim closure seeded with [initialGmValues] so
  /// `GM_getValue`/`GM_setValue` are synchronous in the page (see
  /// [UserScriptGmShim]). Scripts without a Core GM grant are untouched.
  static UserScript toUserScript(
    InstalledUserScript script, {
    Map<String, Object?> initialGmValues = const {},
  }) {
    final shim = UserScriptGmShim.build(script: script, initialValues: initialGmValues);
    final source = shim == null ? script.source : '$shim\n${script.source}\n})();';
    return UserScript(
      groupName: script.groupName,
      source: source,
      injectionTime: script.runAt == UserScriptRunAt.documentStart
          ? UserScriptInjectionTime.AT_DOCUMENT_START
          : UserScriptInjectionTime.AT_DOCUMENT_END,
      forMainFrameOnly: script.forMainFrameOnly,
      contentWorld: ContentWorld.PAGE,
    );
  }

  /// Built-in scripts first, then enabled catalog entries (USM-11).
  static Future<UnmodifiableListView<UserScript>> mergeInitial({
    required Iterable<UserScript> builtin,
    required Iterable<InstalledUserScript> enabled,
    required GmValueStore valueStore,
  }) async {
    final result = <UserScript>[...builtin];
    for (final script in enabled) {
      final values = await valueStore.loadAll(script.id);
      result.add(toUserScript(script, initialGmValues: values));
    }
    return UnmodifiableListView(result);
  }

  /// Syncs runtime UserScripts to match [nextCatalog] enabled set, then reloads.
  ///
  /// Adds newly enabled scripts, removes newly disabled/deleted groups.
  /// Built-in scripts are preserved by only touching `userscript:<id>` groups.
  static Future<void> sync({
    required UserScriptWebViewPort port,
    required Iterable<String> previouslyEnabledIds,
    required Iterable<InstalledUserScript> nextCatalog,
    required GmValueStore valueStore,
  }) async {
    final previous = previouslyEnabledIds.toSet();
    final nextEnabled = {
      for (final s in nextCatalog)
        if (s.enabled) s.id: s,
    };

    for (final id in previous) {
      if (!nextEnabled.containsKey(id)) {
        await port.removeUserScriptsByGroupName(
          InstalledUserScript.groupNameFor(id),
        );
      }
    }

    for (final entry in nextEnabled.entries) {
      if (!previous.contains(entry.key)) {
        final values = await valueStore.loadAll(entry.value.id);
        await port.addUserScript(toUserScript(entry.value, initialGmValues: values));
      }
    }

    await port.reload();
  }

  /// Re-seeds the native `UserScript` of every enabled script that uses a
  /// Core GM value grant with a fresh snapshot from [valueStore].
  ///
  /// A registered `UserScript`'s source is static text: it re-executes
  /// unchanged on every later navigation in the same WebView, so the
  /// `GM_getValue`/`GM_setValue` snapshot baked in at add-time would
  /// otherwise go stale after the very first `GM_setValue` call survives a
  /// page reload. Call this right before allowing a navigation to proceed
  /// (see `shouldOverrideUrlLoading`) so the destination page's
  /// document-start/end injection sees the latest persisted values. Does
  /// *not* reload — the caller's own navigation is what applies the change.
  static Future<void> refreshGmSnapshots({
    required UserScriptWebViewPort port,
    required Iterable<InstalledUserScript> enabledScripts,
    required GmValueStore valueStore,
  }) async {
    for (final script in enabledScripts) {
      if (!UserScriptGmShim.hasValueGrant(script)) continue;
      final values = await valueStore.loadAll(script.id);
      await port.removeUserScriptsByGroupName(script.groupName);
      await port.addUserScript(toUserScript(script, initialGmValues: values));
    }
  }
}
