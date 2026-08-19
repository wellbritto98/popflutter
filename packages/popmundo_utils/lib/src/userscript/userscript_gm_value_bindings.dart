/// JS fragments for GM value change listeners (Tampermonkey-compatible).
class UserScriptGmValueBindings {
  UserScriptGmValueBindings._();

  /// Listener registry + notify hook used by [__gmSetValue]/[__gmDeleteValue].
  static String valueChangeListeners() {
    return '''
  var __gmValueListeners = [];
  var __gmValueListenerSeq = 0;
  function __gmNotifyValueChangeListeners(key, oldVal, newVal, remote) {
    if (oldVal === newVal) return;
    for (var i = 0; i < __gmValueListeners.length; i++) {
      var entry = __gmValueListeners[i];
      if (entry && entry.key === key && typeof entry.cb === 'function') {
        try { entry.cb(key, oldVal, newVal, !!remote); } catch (e) {}
      }
    }
  }
  function __gmAddValueChangeListener(key, cb) {
    if (typeof cb !== 'function') throw new Error('GM_addValueChangeListener: callback must be a function');
    var id = ++__gmValueListenerSeq;
    __gmValueListeners.push({ id: id, key: String(key), cb: cb });
    return id;
  }
  function __gmRemoveValueChangeListener(id) {
    for (var i = __gmValueListeners.length - 1; i >= 0; i--) {
      if (__gmValueListeners[i].id === id) {
        __gmValueListeners.splice(i, 1);
        return true;
      }
    }
    return false;
  }''';
  }

  static String addListenerLegacy() {
    return '  var GM_addValueChangeListener = __gmAddValueChangeListener;';
  }

  static String removeListenerLegacy() {
    return '  var GM_removeValueChangeListener = __gmRemoveValueChangeListener;';
  }

  static String addListenerModern() {
    return '''
  GM.addValueChangeListener = function(key, cb) {
    return Promise.resolve(__gmAddValueChangeListener(key, cb));
  };''';
  }

  static String removeListenerModern() {
    return '''
  GM.removeValueChangeListener = function(id) {
    return Promise.resolve(__gmRemoveValueChangeListener(id));
  };''';
  }
}
