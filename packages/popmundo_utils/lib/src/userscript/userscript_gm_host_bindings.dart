/// JS prelude fragments for GM "Host" grants (`GM.xmlHttpRequest`, etc.).
///
/// Kept separate from [UserScriptGmShim] to avoid a single oversized file.
class UserScriptGmHostBindings {
  UserScriptGmHostBindings._();

  /// Shared helpers for round-trip host APIs (clipboard is fire-and-forget).
  static String sharedHelpers() {
    return '''
  var __gmCallSeq = 0;
  function __gmNextCallId() { return __gmScriptId + ':' + (++__gmCallSeq); }
  function __gmRegisterCallback(callId, fn, persistent) {
    window.__popmundo.__gmCallbacks = window.__popmundo.__gmCallbacks || {};
    window.__popmundo.__gmCallbacks[callId] = { fn: fn, persistent: !!persistent };
  }
  function __gmPost(action, data) {
    try {
      if (window.__popmundo && window.__popmundo.post) {
        var payload = { scriptId: __gmScriptId, action: action };
        if (data) {
          for (var k in data) {
            if (Object.prototype.hasOwnProperty.call(data, k)) payload[k] = data[k];
          }
        }
        window.__popmundo.post({ type: 'gm', payload: payload });
      }
    } catch (e) {}
  }''';
  }

  static String setClipboardLegacy() {
    return '''
  var GM_setClipboard = function(text) {
    __gmPost('setClipboard', { text: String(text) });
  };''';
  }

  static String setClipboardModern() {
    return '''
  GM.setClipboard = function(text) {
    __gmPost('setClipboard', { text: String(text) });
    return Promise.resolve();
  };''';
  }

  static String openInTabLegacy() {
    return '''
  var GM_openInTab = function(url, openInBackground) {
    var objURL;
    try { objURL = new URL(url, location.href); } catch (e) { throw new Error('GM_openInTab: bad URL ' + url); }
    __gmPost('openInTab', { url: objURL.href, active: openInBackground === false });
  };''';
  }

  static String openInTabModern() {
    return '''
  GM.openInTab = function(url, openInBackground) {
    var objURL;
    try { objURL = new URL(url, location.href); } catch (e) { return Promise.reject(new Error('GM.openInTab: bad URL ' + url)); }
    __gmPost('openInTab', { url: objURL.href, active: openInBackground === false });
    return Promise.resolve();
  };''';
  }

  static String notificationLegacy() {
    return '''
  var GM_notification = function(text, title, image, onclick) {
    var opt;
    if (typeof text === 'object') {
      opt = text;
      if (typeof title === 'function') opt.onclick = title;
    } else {
      opt = { title: title, text: text, image: image, onclick: onclick };
    }
    if (typeof opt.text !== 'string') throw new Error('GM_notification: text must be a string');
    if (typeof opt.title !== 'string') opt.title = 'Popmundo';
    var callId = __gmNextCallId();
    if (typeof opt.onclick === 'function') {
      window.__popmundo.__gmNotifCallbacks = window.__popmundo.__gmNotifCallbacks || {};
      window.__popmundo.__gmNotifCallbacks[callId] = opt.onclick;
    }
    __gmPost('notification', { callId: callId, title: opt.title, text: opt.text, image: opt.image || '' });
  };''';
  }

  static String notificationModern() {
    return '''
  GM.notification = function(text, title, image, onclick) {
    GM_notification(text, title, image, onclick);
    return Promise.resolve();
  };''';
  }

  static String registerMenuCommandLegacy() {
    return '''
  var GM_registerMenuCommand = function(caption, commandFunc, accessKey) {
    if (typeof commandFunc !== 'function') throw new Error('GM_registerMenuCommand: commandFunc must be a function');
    var commandId = __gmNextCallId();
    window.__popmundo.__gmMenuCommands = window.__popmundo.__gmMenuCommands || {};
    window.__popmundo.__gmMenuCommands[commandId] = commandFunc;
    __gmPost('registerMenuCommand', { commandId: commandId, caption: String(caption) });
    return commandId;
  };''';
  }

  static String registerMenuCommandModern() {
    return '''
  GM.registerMenuCommand = function(caption, commandFunc, accessKey) {
    return Promise.resolve(GM_registerMenuCommand(caption, commandFunc, accessKey));
  };''';
  }

  static String getResourceUrlModern() {
    return '''
  GM.getResourceUrl = function(name, type) {
    return new Promise(function(resolve, reject) {
      var callId = __gmNextCallId();
      __gmRegisterCallback(callId, function(msg) {
        if (msg.error) reject(msg.error);
        else resolve(msg.objectUrl);
      });
      __gmPost('getResourceUrl', { callId: callId, name: String(name), type: type || '' });
    });
  };''';
  }

  static String xmlHttpRequestLegacy() {
    return '''
  var GM_xmlhttpRequest = function(d) {
    if (!d) throw new Error('GM_xmlhttpRequest: details required');
    if (!d.url) throw new Error('GM_xmlhttpRequest: url required');
    var url;
    try { url = new URL(d.url, location.href); } catch (e) { throw new Error('GM_xmlhttpRequest: bad url ' + d.url); }
    if (url.protocol !== 'http:' && url.protocol !== 'https:') {
      throw new Error('GM_xmlhttpRequest: bad url scheme ' + d.url);
    }
    var callId = __gmNextCallId();
    var handlers = {};
    ['onload','onerror','onloadend','ontimeout','onreadystatechange'].forEach(function(k) {
      if (typeof d[k] === 'function') handlers[k] = d[k];
    });
    __gmRegisterCallback(callId, function(msg) {
      var evt = msg.eventType || 'load';
      var cb = handlers['on' + evt];
      if (cb && msg.responseState) {
        if (msg.responseState.responseXML && typeof msg.responseState.responseText === 'string') {
          try {
            msg.responseState.responseXML = (new DOMParser()).parseFromString(
              msg.responseState.responseText, 'application/xml');
          } catch (e) { msg.responseState.responseXML = null; }
        }
        msg.responseState.context = d.context;
        cb(msg.responseState);
      }
    }, true);
    function sanitizer(k, v) {
      if (k === 'context') return undefined;
      if (k === 'url') return url.href;
      if (typeof v === 'function') return true;
      return v;
    }
    var details = JSON.parse(JSON.stringify(d, sanitizer));
    if (!details.upload) details.upload = {};
    __gmPost('xmlHttpRequest', { callId: callId, details: details });
  };''';
  }

  static String xmlHttpRequestModern() {
    return '''
  GM.xmlHttpRequest = function(d) {
    GM_xmlhttpRequest(d);
    return Promise.resolve();
  };''';
  }
}
