import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  final www = Uri.parse('https://www.popmundo.com/');
  final n75 = Uri.parse('https://75.popmundo.com/World/Popmundo.aspx/Character');

  GameCookie hostOnly(String name, String value, String host) => GameCookie(
        name: name,
        value: value,
        host: host,
        httpOnly: true,
        secure: true,
        sameSite: 'Lax',
      );

  test('read returns cookies that match the URL', () async {
    final jar = MemoryCookieSink();
    jar.seed([
      hostOnly('popmundo.com', 'AUTH', '75.popmundo.com'),
      hostOnly('ASP.NET_SessionId', 's75', '75.popmundo.com'),
    ]);

    final got = await jar.read(n75);
    expect(got.map((c) => c.name),
        containsAll(['popmundo.com', 'ASP.NET_SessionId']));
    expect(got.singleWhere((c) => c.name == 'popmundo.com').value, 'AUTH');
  });

  test('seed makes cookies readable without write', () async {
    final jar = MemoryCookieSink();
    jar.seed([hostOnly('popmundo.com', 'AUTH', '75.popmundo.com')]);

    expect(jar.written, isEmpty);
    expect(await jar.read(n75), isNotEmpty);
  });

  test('a host-only www cookie is not returned for the numbered host', () async {
    final jar = MemoryCookieSink();
    jar.seed([
      hostOnly('popmundo.com', 'WWW', 'www.popmundo.com'),
      hostOnly('popmundo.com', 'N75', '75.popmundo.com'),
    ]);

    final on75 = await jar.read(n75);
    expect(on75.map((c) => c.value), ['N75']);

    final onWww = await jar.read(www);
    expect(onWww.map((c) => c.value), ['WWW']);
  });
}
