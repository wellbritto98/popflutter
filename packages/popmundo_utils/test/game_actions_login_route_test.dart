import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

import 'game_actions_transport_test.dart' show FixtureTransport, serviceFor;

void main() {
  test(
    'SGA-03 login GET accepts actual login controls before authentication',
    () async {
      final transport = FixtureTransport();
      var first = true;
      transport.handler = (request) async {
        if (first) {
          first = false;
          return const AuthHttpResponse(
            status: 200,
            body: r'''
<form method="post" id="aspnetForm" action="./Default.aspx">
<input name="__VIEWSTATE" value="synthetic-login">
<input name="ctl00$cphRightColumn$ucLogin$txtUsername">
<input type="password" name="ctl00$cphRightColumn$ucLogin$txtPassword">
</form>''',
          );
        }
        transport.handler = null;
        return transport.send(request);
      };
      final catalog = await serviceFor(transport).discoverCharacters();
      expect(catalog.characters.first.id, 3327035);
      final loginPost = transport.requests.firstWhere(
        (request) => request.method == 'POST',
      );
      final fields = Uri.splitQueryString(loginPost.body!);
      expect(fields[r'ctl00$cphRightColumn$ucLogin$txtUsername'], 'account');
      expect(
        fields[r'ctl00$cphRightColumn$ucLogin$txtPassword'],
        'synthetic-password',
      );
      expect(loginPost.url.path, '/Default.aspx');
      expect(transport.closed, true);
    },
  );
}
