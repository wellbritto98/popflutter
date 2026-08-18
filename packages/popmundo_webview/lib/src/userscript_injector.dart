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
  static UserScript toUserScript(InstalledUserScript script) {
    return UserScript(
      groupName: script.groupName,
      source: script.source,
      injectionTime: script.runAt == UserScriptRunAt.documentStart
          ? UserScriptInjectionTime.AT_DOCUMENT_START
          : UserScriptInjectionTime.AT_DOCUMENT_END,
      forMainFrameOnly: script.forMainFrameOnly,
      contentWorld: ContentWorld.PAGE,
    );
  }

  /// Built-in scripts first, then enabled catalog entries (USM-11).
  static UnmodifiableListView<UserScript> mergeInitial({
    required Iterable<UserScript> builtin,
    required Iterable<InstalledUserScript> enabled,
  }) {
    return UnmodifiableListView([
      ...builtin,
      for (final script in enabled) toUserScript(script),
    ]);
  }

  /// Syncs runtime UserScripts to match [nextCatalog] enabled set, then reloads.
  ///
  /// Adds newly enabled scripts, removes newly disabled/deleted groups.
  /// Built-in scripts are preserved by only touching `userscript:<id>` groups.
  static Future<void> sync({
    required UserScriptWebViewPort port,
    required Iterable<String> previouslyEnabledIds,
    required Iterable<InstalledUserScript> nextCatalog,
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
        await port.addUserScript(toUserScript(entry.value));
      }
    }

    await port.reload();
  }
}
