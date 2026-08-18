import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  test('popmundo URIs stay in the WebView', () {
    expect(
      ObservePolicy.decideNavigation(Uri.parse('https://73.popmundo.com/x')),
      NavDecision.allowInWebView,
    );
  });

  test('other http(s) URIs open externally', () {
    expect(
      ObservePolicy.decideNavigation(Uri.parse('https://wiki.example.com')),
      NavDecision.openExternal,
    );
  });

  test('observe-only resource policy never returns a replacement', () {
    expect(ObservePolicy.observeOnlyResourceResponse(), isNull);
  });
}
