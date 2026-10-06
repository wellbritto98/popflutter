import 'dart:async';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;

import '../autologin/aspnet_form.dart';
import '../autologin/auto_login_requests.dart';
import '../autologin/auth_http.dart';
import '../scheduler/scheduler_models.dart';
import 'game_action_contracts.dart';
import 'game_forms.dart';
import 'game_transaction.dart';

/// Sole independent-session gateway for discovery and scheduled game actions.
/// No renderer, visible cookie ports or HostTracker can enter this boundary.
class GameActionsService {
  GameActionsService({
    required this.readCredentials,
    GameHttpTransport Function()? createTransport,
    this.limits = const GameActionLimits(),
    DateTime Function()? now,
    Future<void> Function(Duration)? sleep,
  }) : createTransport =
           createTransport ?? (() => IoGameHttpTransport(limits: limits)),
       now = now ?? DateTime.now,
       sleep = sleep ?? Future<void>.delayed;
  final Future<GameCredentials> Function() readCredentials;
  final GameHttpTransport Function() createTransport;
  final GameActionLimits limits;
  final DateTime Function() now;
  final Future<void> Function(Duration) sleep;
  Future<void> _tail = Future.value();
  GameTransaction? _active;
  bool _disposed = false;
  DateTime? _lastFinished;
  GameHttpTransport _transport() {
    try {
      return createTransport();
    } catch (_) {
      throw const GameActionException('networkError');
    }
  }

  Future<T> _transaction<T>(
    String? account,
    Future<T> Function(GameTransaction, GameCredentials) operation,
  ) {
    final result = _tail.then((_) async {
      if (_disposed) throw const GameActionException('serviceUnavailable');
      final context = GameTransaction(
        transport: _transport(),
        lastFinished: _lastFinished,
        onRequestFinished: (time) => _lastFinished = time,
        limits: limits,
        now: now,
        sleep: sleep,
      );
      _active = context;
      try {
        GameCredentials credentials;
        try {
          credentials = await context.wait(readCredentials());
        } on GameActionException {
          rethrow;
        } catch (_) {
          throw const GameActionException('credentialsUnavailable');
        }
        context.check();
        if (credentials.username.trim().isEmpty ||
            credentials.password.isEmpty) {
          throw const GameActionException('credentialsMissing');
        }
        if (account != null && credentials.username.trim() != account) {
          throw const GameActionException('accountChanged');
        }
        return await operation(context, credentials);
      } on GameActionException {
        rethrow;
      } catch (_) {
        throw const GameActionException('networkError');
      } finally {
        context.close();
        _active = null;
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object e, StackTrace s) {});
    return result;
  }

  Future<_Login> _login(
    GameTransaction context,
    GameCredentials credentials,
  ) async {
    final page = await context.session.get(
      Uri.parse('https://www.popmundo.com/Default.aspx'),
    );
    _requirePage(page, '/Default.aspx');
    final doc = parser.parse(page.body);
    freshForm(doc, page.finalUrl);
    final form = AutoLoginRequests.loginBody(
      doc,
      username: credentials.username,
      password: credentials.password,
      status: credentials.status,
      strictDisabledControls: true,
    );
    final landed = await context.session.postForm(page.finalUrl, form.encode());
    if (AspNetForm.looksLikeLoginForm(landed.body) ||
        AspNetForm.isLoginPath(landed.finalUrl.path)) {
      throw const GameActionException('invalidCredentials');
    }
    _requirePage(landed, '/World/Popmundo.aspx/ChooseCharacter');
    return _Login(landed, ownedChoices(parser.parse(landed.body)));
  }

  Future<Uri> _select(
    GameTransaction context,
    _Login login,
    GameCharacter character,
  ) async {
    final matches = login.choices
        .where((c) => c.character.id == character.id)
        .toList();
    if (matches.length != 1) {
      throw const GameActionException('characterUnavailable');
    }
    final choice = matches.single;
    final form = freshForm(parser.parse(login.page.body), login.page.finalUrl);
    form.set(choice.buttonName, choice.buttonValue);
    final chosen = await context.session.postForm(
      login.page.finalUrl,
      form.encode(),
    );
    _requirePage(chosen, '/World/Popmundo.aspx');
    final origin = Uri.parse(chosen.finalUrl.origin);
    final profile = await context.session.get(
      origin.replace(path: '/World/Popmundo.aspx/Character'),
    );
    _requirePage(profile, '/World/Popmundo.aspx/Character');
    verifyCharacter(parser.parse(profile.body), character.id);
    return origin;
  }

  static void _requirePage(AuthExchange page, String path) {
    GameTransaction.validateUrl(page.finalUrl);
    if (page.status != 200 ||
        page.finalUrl.path != path ||
        AspNetForm.looksLikeLoginForm(page.body)) {
      throw const GameActionException('routeMismatch');
    }
  }

  Future<GameCharacterCatalog> discoverCharacters() =>
      _transaction(null, (context, credentials) async {
        final login = await _login(context, credentials);
        return GameCharacterCatalog(
          username: credentials.username.trim(),
          characters: login.choices.map((c) => c.character).toList(),
        );
      });
  Future<List<GameItemChoice>> discoverItems({
    required String boundUsername,
    required GameCharacter character,
  }) => _discover(
    boundUsername,
    character,
    '/World/Popmundo.aspx/Character/Items/',
    (doc) {
      final names = itemCandidates(doc).map((c) => c.name).toSet();
      return names.map((name) => GameItemChoice(name: name)).toList();
    },
  );
  Future<GameCrewOptions> discoverCrew({
    required String boundUsername,
    required GameCharacter character,
  }) => _discover(
    boundUsername,
    character,
    '/World/Popmundo.aspx/Artist/Crew/',
    crewOptions,
  );
  Future<T> _discover<T>(
    String username,
    GameCharacter character,
    String path,
    T Function(Document) parse,
  ) => _transaction(username, (context, credentials) async {
    final login = await _login(context, credentials);
    final origin = await _select(context, login, character);
    final page = await context.session.get(origin.replace(path: path));
    _requirePage(page, path);
    freshForm(parser.parse(page.body), page.finalUrl);
    return parse(parser.parse(page.body));
  });

  /// Endpoint implementation is added by the item/crew tasks.
  Future<GameActionOutcome> execute(GameScheduledAction action) async =>
      const GameActionOutcome(
        status: GameActionStatus.failed,
        errorCode: 'executorUnavailable',
      );
  void cancel() => _active?.cancel('serviceUnavailable');
  Future<void> dispose() async {
    _disposed = true;
    cancel();
    await _tail;
  }
}

class _Login {
  const _Login(this.page, this.choices);
  final AuthExchange page;
  final List<OwnedCharacterChoice> choices;
}
