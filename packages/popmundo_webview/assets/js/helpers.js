(function () {
  window.__popmundo = window.__popmundo || {};

  function nodeInfo(el) {
    if (!el || !el.tagName) return null;
    var text = (el.textContent || '').trim();
    return {
      tag: el.tagName.toLowerCase(),
      id: el.id || '',
      className: el.className || '',
      text: text.length > 60 ? text.slice(0, 60) + '\u2026' : text
    };
  }

  window.__popmundo.getMyID = function () {
    var el = document.querySelector('div.idHolder');
    if (!el) return 0;
    var n = parseInt(el.textContent, 10);
    return isNaN(n) ? 0 : n;
  };

  window.__popmundo.getMyName = function () {
    var el = document.querySelector('#ppm-content > div.box.ofauto.charPresBox > h2');
    return el ? (el.textContent || '') : '';
  };

  window.__popmundo.createNotification = function (level, id, textContent) {
    var container = document.getElementById('notifications');
    if (!container) return null;
    var div = document.createElement('div');
    var cls = 'notification-real notification-normal';
    if (level === 'success') cls = 'notification-real notification-success';
    else if (level === 'error') cls = 'notification-real notification-error';
    div.setAttribute('class', cls);
    if (id) div.setAttribute('id', id);
    if (textContent) div.textContent = textContent;
    container.appendChild(div);
    return nodeInfo(div);
  };

  window.__popmundo.querySingle = function (selector) {
    return nodeInfo(document.querySelector(selector));
  };

  window.__popmundo.queryAll = function (selector) {
    return Array.prototype.slice.call(document.querySelectorAll(selector)).map(nodeInfo);
  };

  window.__popmundo.xpathSingle = function (expr) {
    var r = document.evaluate(expr, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
    return nodeInfo(r.singleNodeValue);
  };

  window.__popmundo.applyScoringNumbers = function () {
    var nodes = document.querySelectorAll('a[href*="Scoring"]');
    return nodes.length;
  };

  window.__popmundo.applyBarPercentage = function () {
    var nodes = document.querySelectorAll('div[class*="rogressBar"]');
    return nodes.length;
  };
})();
