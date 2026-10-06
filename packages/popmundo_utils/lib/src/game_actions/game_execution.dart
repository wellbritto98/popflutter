part of 'game_actions_service.dart';

Future<GameActionOutcome> _executeScheduledGame(
  GameActionsService service,
  GameScheduledAction action, {
  bool Function()? isEligible,
  Future<void> Function()? beforeHttp,
}) async {
  try {
    return await service._transaction(
      action.boundUsername,
      (context, credentials) async {
        try {
          final login = await service._login(context, credentials);
          final origin = await service._select(
            context,
            login,
            action.character,
          );
          final path = switch (action) {
            UseItemAction() => '/World/Popmundo.aspx/Character/Items/',
            PayCrewAction() => '/World/Popmundo.aspx/Artist/Crew/',
          };
          final url = origin.replace(path: path);
          final page = await context.session.get(url);
          GameActionsService._requirePage(
            page,
            url.path,
            expectedOrigin: origin,
          );
          final document = parser.parse(page.body);
          final form = switch (action) {
            UseItemAction() => itemPost(document, page.finalUrl, action),
            PayCrewAction() => crewPost(document, page.finalUrl, action),
          };
          await context.establishNeutralBaseline(origin);
          context.check();
          context.gameplayUrl = url;
          final posted = await context.session.postForm(url, form.encode());
          GameActionsService._requirePage(
            posted,
            url.path,
            expectedOrigin: origin,
          );
          return await context.readOutcome(origin);
        } on GameActionException catch (error) {
          if (context.gameplaySent) {
            return const GameActionOutcome(
              status: GameActionStatus.uncertain,
              errorCode: 'outcomeUncertain',
            );
          }
          return GameActionOutcome(
            status:
                [
                  'itemUnavailable',
                  'formUnavailable',
                  'artistUnavailable',
                  'artistMismatch',
                  'bonusUnavailable',
                ].contains(error.code)
                ? GameActionStatus.unavailable
                : GameActionStatus.failed,
            errorCode: error.code,
          );
        }
      },
      isEligible: isEligible,
      beforeHttp: beforeHttp,
    );
  } on GameActionException catch (error) {
    return GameActionOutcome(
      status: GameActionStatus.failed,
      errorCode: error.code,
    );
  }
}
