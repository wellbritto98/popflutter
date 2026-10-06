# Popflutter

Wrapper Flutter (Android + iOS) do [Popmundo](https://www.popmundo.com) com `flutter_inappwebview`. A UI principal é o próprio jogo. O app observa rede/console/navegação, persiste cookies, reloga em silêncio (opcional), injeta UserScripts com polyfill GM, e oferece a lib Dart portada de [Popmundo-Utils `common/`](https://github.com/ilpersi/Popmundo-Utils) (GPL-3).

Documentação oficial: [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md), [`docs/OBJETIVO.md`](docs/OBJETIVO.md). Índice: [`docs/README.md`](docs/README.md). Specs: [`.specs/`](.specs/README.md).

## Packages

| Package | Função | README |
| ------- | ------ | ------ |
| `packages/popmundo_utils` | Dart puro: contrato `PopmundoRuntime`, host sticky, TimedFetch, Auto Login, UserScripts/GM, scheduler, ações HTTP isoladas, storage | [README](packages/popmundo_utils/README.md) |
| `packages/popmundo_webview` | Adapter InAppWebView 6.x, JS bridge `popmundo`, injector de scripts, cookie sink | [README](packages/popmundo_webview/README.md) |
| `apps/popmundo_app` | Shell, composition root, sidebar, i18n, keepalive, telas nativas | [README](apps/popmundo_app/README.md) |

Cadeia de dependência: `popmundo_utils` ← `popmundo_webview` ← `popmundo_app`. Utils **não** depende de Flutter.

## Comandos

Na raiz (`resolution: workspace`):

```bash
flutter pub get
flutter analyze packages/popmundo_utils packages/popmundo_webview apps/popmundo_app
cd packages/popmundo_utils && dart test
cd packages/popmundo_webview && flutter test
cd apps/popmundo_app && flutter test
cd apps/popmundo_app && flutter run
```

Patrol (Android, um arquivo por vez; **não** carrega popmundo.com):

```bash
cd apps/popmundo_app && patrol test --target integration_test/keepalive_test.dart -d <device-id>
```

## Host sticky e TimedFetch

URL inicial: `https://www.popmundo.com`. Redirecionamentos `N.popmundo.com` atualizam a origem. `Utils.getServerLink` e `TimedFetch` usam o hostname atual.

Fila serial, delay **750 ms**, cache in-memory `METHOD:URL`. Fetch auxiliar do jogo roda **no contexto da página**. Os caminhos nativos são explícitos: Auto Login usa HTTP nativo `dart:io` com o mesmo cooldown, depois sync de cookies na WebView. Heartbeat de sessão: GET nativo a cada 60 s em `{N.popmundo.com}/World/Popmundo.aspx/Character`.

Android mantém a sessão por FGS specialUse e auto login HTTP nativo, com notificação local de sucesso/falha em segundo plano. Veja [critérios e limites](.specs/features/background-session-reliability/spec.md) e AD-020.

## Overlay e menu

Um FAB (`menu-toggle`) abre o sidebar. Cada feature define o seu próprio `AppMenuItem` na própria pasta (Auto Login, Userscripts, Agendamentos, Language; Debug só em debug); `buildAppMenuItems` só ordena a lista e anexa o item de debug por último quando o gate permite. Cookies no overlay: **nome@domínio**, nunca o valor.

## Agendamentos Android

O menu Agendamentos configura notificações locais, uso de item e bônus para a equipe por intervalos (segundos, minutos, horas ou dias) ou dias da semana e horário local. As regras ficam persistidas e executam no serviço em segundo plano, com restauração após reboot enquanto houver regras ativas. Ocorrências perdidas são descartadas. Segundos funcionam em melhor esforço; force-stop do Android impede execução até abrir o app novamente. O iOS apresenta a limitação na tela. Ver [spec e critérios](.specs/features/service-scheduler/spec.md).

As ações do jogo guardam conta e personagem (ID e nome) por regra. Usam login HTTP independente, sem tocar a sessão da tela principal. Cada ocorrência avisa antes de iniciar; o item é escolhido e o bônus usa nível máximo por padrão. A banda pode ser agendada durante o bloqueio semanal; com cotação disponível, ela vira teto de custo; sem cotação, o preço é definido pelo jogo na execução. A execução respeita a disponibilidade do formulário atual. Resultados incertos nunca são reenviados. Ver [spec das ações](.specs/features/scheduled-game-actions/spec.md).

## Estender

```dart
final runtime = InAppPopmundoRuntime(); // só no composition root
final timed = TimedFetch(runtime);
final id = await Utils(runtime, timed).getMyID();
```

Scoring **não** roda no load. Storage: `KeyValueStore` (`MemoryKeyValueStore` nos testes, `SharedPreferencesStore` no app). Senha de Auto Login: `SecretStore` / `flutter_secure_storage`.

Novo item de menu nativo = uma função `<feature>MenuItem()` na pasta da feature + uma linha na lista `items:` do único call site em `app.dart`. Nova regra de negócio = `popmundo_utils` + teste fake. Depois de mudar comportamento documentado, atualize `docs/` e o README do módulo (`CLAUDE.md`, Documentation maintenance).

## Licença

GPL-3.0-or-later. Ver `LICENSE` e `NOTICE`.
