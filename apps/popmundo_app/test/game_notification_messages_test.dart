import 'package:flutter_test/flutter_test.dart';
import 'package:popmundo_app/scheduler/game_notification_messages.dart';
import 'package:popmundo_app/scheduler/scheduled_game_notifications.dart';
import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final locale in ["en", "pt"]) {
    test(
      [
        locale,
        " tuning start and result notices name the authorized operation",
      ].join(),
      () async {
        SharedPreferences.setMockInitialValues({"locale": locale});
        final prefs = await SharedPreferences.getInstance();
        final action = UseItemAction(
          boundUsername: "bound",
          character: GameCharacter(id: 42, name: "Saved Character"),
          itemName: "Violino",
          operation: GameItemOperation.tune,
        );
        final titles = <String>[], bodies = <String>[];
        final ids = <int>[];
        final notices = NativeScheduledGameNotifications(
          loadMessages: () => GameNotificationMessages.load(prefs),
          show:
              ({
                required int id,
                required String title,
                required String body,
              }) async {
                ids.add(id);
                titles.add(title);
                bodies.add(body);
              },
        );
        await notices.showStart(action: action, notificationId: -42);
        await notices.showResult(
          action: action,
          notificationId: -42,
          outcome: const GameActionOutcome(status: GameActionStatus.confirmed),
        );
        expect(ids, [-42, -42]);
        expect(
          titles,
          locale == "pt"
              ? [
                  "Executando Afinar instrumento",
                  "Afinar instrumento: ação confirmada",
                ]
              : [
                  "Executing Tune instrument",
                  "Tune instrument: action confirmed",
                ],
        );
        expect(
          bodies,
          List.filled(
            2,
            locale == "pt"
                ? "Personagem: Saved Character"
                : "Character: Saved Character",
          ),
        );
      },
    );
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  test('service engine loads fresh EN/PT assets and retains saved character in notice', () async {
    SharedPreferences.setMockInitialValues({'locale': 'pt'});
    final prefs = await SharedPreferences.getInstance();
    final action = UseItemAction(
      boundUsername: 'bound',
      character: GameCharacter(id: 42, name: 'Saved Character'),
      itemName: 'Exact Item',
    );
    final pt = await GameNotificationMessages.load(prefs);
    expect(pt.start(action).title, 'Executando Usar item');
    expect(pt.start(action).body, 'Personagem: Saved Character');
    expect(
      pt
          .result(
            action,
            const GameActionOutcome(status: GameActionStatus.confirmed),
          )
          .title,
      'Usar item: ação confirmada',
    );
    await prefs.setString('locale', 'en');
    final en = await GameNotificationMessages.load(prefs);
    expect(en.start(action).title, 'Executing Use item');
    expect(
      en
          .result(
            action,
            const GameActionOutcome(status: GameActionStatus.uncertain),
          )
          .title,
      'Use item: result uncertain',
    );
    final ids = <int>[];
    final titles = <String>[];
    final bodies = <String>[];
    final notices = NativeScheduledGameNotifications(
      loadMessages: () => GameNotificationMessages.load(prefs),
      show:
          ({
            required int id,
            required String title,
            required String body,
          }) async {
            ids.add(id);
            titles.add(title);
            bodies.add(body);
          },
    );
    await notices.showStart(action: action, notificationId: -42);
    await notices.showResult(
      action: action,
      notificationId: -42,
      outcome: const GameActionOutcome(status: GameActionStatus.unavailable),
    );
    expect(ids, [-42, -42]);
    expect(titles, ['Executing Use item', 'Use item: unavailable']);
    expect(bodies, [
      'Character: Saved Character',
      'Character: Saved Character',
    ]);
    final denied = NativeScheduledGameNotifications(
      loadMessages: () => GameNotificationMessages.load(prefs),
      show: ({
        required int id,
        required String title,
        required String body,
      }) async => throw const SchedulerException('permissionDenied'),
    );
    await expectLater(
      denied.showStart(action: action, notificationId: -42),
      throwsA(
        isA<SchedulerException>().having(
          (e) => e.code,
          'code',
          'permissionDenied',
        ),
      ),
    );
  });
}
