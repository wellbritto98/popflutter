# F1 initial login-route validation

Root cause: live read-only GET returned200 and correct post form/action path, but generic _requirePage rejected the expected ucLogin controls. Foundation synthetic form omitted those markers. Production now permits login form only on the initial login GET; all post-authentication route guards remain strict.

Red: f1-red.log records routeMismatch at _login. Green: f1-green.log342 passed, no tests removed; dart analyze exit0/no issues.

Coverage/reverse mapping: test/game_actions_login_route_test.dart assertions catalog.characters.first.id==3327035, fields username/password==synthetic values, loginPost.url.path==/Default.aspx, closed==true prove SGA-03/04 authentication of an observed login shape without weakening subsequent routes. Whitelist trace in test_live is explicit opt-in; no authenticated HTML, cookies, query or form values retained. All assertions necessary; no spec deviation.
