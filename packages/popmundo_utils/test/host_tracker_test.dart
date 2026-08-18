import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  test('starts at www.popmundo.com', () {
    final host = HostTracker();
    expect(host.currentOrigin.toString(), 'https://www.popmundo.com');
  });

  test('numeric host redirect updates origin', () {
    final host = HostTracker();
    host.onNavigation(Uri.parse('https://73.popmundo.com/Default.aspx'));
    expect(host.currentOrigin.host, '73.popmundo.com');
    expect(host.resolve('/World/Popmundo.aspx/Character/1').toString(),
        'https://73.popmundo.com/World/Popmundo.aspx/Character/1/');
  });

  test('external host does not update origin', () {
    final host = HostTracker();
    host.onNavigation(Uri.parse('https://example.com/x'));
    expect(host.currentOrigin.host, 'www.popmundo.com');
  });

  test('resolve adds leading and trailing slashes', () {
    final host = HostTracker();
    expect(host.resolve('foo').toString(), 'https://www.popmundo.com/foo/');
    expect(host.resolve('/foo').toString(), 'https://www.popmundo.com/foo/');
    expect(host.resolve('/foo/').toString(), 'https://www.popmundo.com/foo/');
  });

  test('isPopmundoHost allows apex and subdomains', () {
    expect(HostTracker.isPopmundoHost('popmundo.com'), isTrue);
    expect(HostTracker.isPopmundoHost('www.popmundo.com'), isTrue);
    expect(HostTracker.isPopmundoHost('apps.popmundo.com'), isTrue);
    expect(HostTracker.isPopmundoHost('evil.com'), isFalse);
    expect(HostTracker.isPopmundoHost('popmundo.com.evil'), isFalse);
  });
}
