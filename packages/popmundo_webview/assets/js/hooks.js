(function () {
  var MAX = 32768;
  var queue = [];
  var ready = false;

  function post(msg) {
    if (!ready || !window.flutter_inappwebview || !window.flutter_inappwebview.callHandler) {
      queue.push(msg);
      return;
    }
    window.flutter_inappwebview.callHandler('popmundo', msg);
  }

  function flush() {
    ready = true;
    while (queue.length) {
      window.flutter_inappwebview.callHandler('popmundo', queue.shift());
    }
    post({ type: 'ready', payload: {} });
  }

  window.addEventListener('flutterInAppWebViewPlatformReady', flush);

  function captureBody(text, binary) {
    if (binary) return { body: null, bodyTruncated: false, bodyOmitted: true };
    if (text == null) return { body: null, bodyTruncated: false, bodyOmitted: false };
    var encoded = typeof TextEncoder !== 'undefined' ? new TextEncoder().encode(String(text)) : null;
    var len = encoded ? encoded.length : String(text).length;
    if (len <= MAX) return { body: String(text), bodyTruncated: false, bodyOmitted: false };
    var cut = encoded
      ? new TextDecoder().decode(encoded.slice(0, MAX))
      : String(text).slice(0, MAX);
    return { body: cut, bodyTruncated: true, bodyOmitted: false };
  }

  var originalFetch = window.fetch ? window.fetch.bind(window) : null;
  window.__popmundoOriginalFetch = originalFetch;
  if (originalFetch) {
    window.fetch = function (resource, config) {
      var url = typeof resource === 'string' ? resource : (resource && resource.url) || String(resource);
      var method = (config && config.method) || (resource && resource.method) || 'GET';
      return originalFetch(resource, config).then(function (res) {
        var ct = (res.headers && res.headers.get && res.headers.get('content-type')) || '';
        var binary = /image|octet-stream|video|audio|font|wasm/i.test(ct);
        var done = binary
          ? Promise.resolve(captureBody(null, true))
          : res.clone().text().then(function (t) { return captureBody(t, false); }).catch(function () {
            return { body: null, bodyTruncated: false, bodyOmitted: true };
          });
        return done.then(function (bodyInfo) {
          post({
            type: 'network',
            payload: {
              method: String(method).toUpperCase(),
              url: String(url),
              status: res.status,
              source: 'fetch',
              body: bodyInfo.body,
              bodyTruncated: bodyInfo.bodyTruncated,
              bodyOmitted: bodyInfo.bodyOmitted
            }
          });
          return res;
        });
      });
    };
  }

  if (window.XMLHttpRequest && window.XMLHttpRequest.prototype) {
    var origOpen = XMLHttpRequest.prototype.open;
    var origSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open = function (method, url) {
      this.__pmMethod = method;
      this.__pmUrl = url;
      return origOpen.apply(this, arguments);
    };
    XMLHttpRequest.prototype.send = function () {
      var xhr = this;
      xhr.addEventListener('loadend', function () {
        var ct = '';
        try { ct = xhr.getResponseHeader('content-type') || ''; } catch (e) {}
        var binary = /image|octet-stream|video|audio/i.test(ct);
        var bodyInfo = binary ? captureBody(null, true) : captureBody(xhr.responseText, false);
        post({
          type: 'network',
          payload: {
            method: String(xhr.__pmMethod || 'GET').toUpperCase(),
            url: String(xhr.__pmUrl || ''),
            status: xhr.status,
            source: 'xhr',
            body: bodyInfo.body,
            bodyTruncated: bodyInfo.bodyTruncated,
            bodyOmitted: bodyInfo.bodyOmitted
          }
        });
      });
      return origSend.apply(this, arguments);
    };
  }

  ['log', 'warn', 'error', 'info', 'debug'].forEach(function (level) {
    var orig = console[level] ? console[level].bind(console) : console.log.bind(console);
    console[level] = function () {
      var message = Array.prototype.slice.call(arguments).map(String).join(' ');
      post({ type: 'console', payload: { level: level, message: message } });
      return orig.apply(console, arguments);
    };
  });

  window.__popmundo = window.__popmundo || {};
  window.__popmundo.post = post;
  window.__popmundo.fetch = function (url, options) {
    if (!originalFetch) return Promise.reject(new Error('fetch unavailable'));
    return originalFetch(url, options || {}).then(function (res) {
      return res.text().then(function (text) {
        return JSON.stringify({ ok: res.ok, status: res.status, text: text });
      });
    });
  };
})();
