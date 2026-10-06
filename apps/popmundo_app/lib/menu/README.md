# menu (`popmundo_app`)

Sidebar nativo. Spec: `app-sidebar-menu`. AD-009 (amendment: Userscripts/Auto Login/Language sempre visíveis).

## Objetivo

Um único FAB abre um `Drawer` cujos itens **fixos** vêm de um registro. Comandos GM são lista à parte.

## Responsabilidade principal

Renderizar `AppMenuItem` e `GmMenuCommandItem`. Agnóstico de `PopmundoRuntime`.

## Funcionalidades existentes

| Arquivo | Função |
| ------- | ------ |
| `app_menu_item.dart` | Value object `id`, `icon`, `label`, `subtitle?`, `onTap` |
| `app_menu_registry.dart` | `buildAppMenuItems({items, debugItem, includeDebugItem = kDebugMode})`: só preserva a ordem de `items` e anexa `debugItem` por último quando o gate permite |
| `debug_menu_item.dart` | `debugMenuItem({required onTap})` — vive em `menu/` porque debug é capacidade da shell, não feature |
| `app_sidebar.dart` | `Drawer`; `menu-empty` se lista fixa vazia **e** sem comandos GM |
| `gm_menu_command_item.dart` | Entrada dinâmica (scriptId, commandId, caption) |

`AppShell` (`lib/app_shell.dart`) hospeda o drawer com `drawerEnableOpenDragGesture: false` (não capturar swipe do jogo).

## Dependências

`easy_localization` nas labels do registro. Callbacks (`onTap`) injetados por `PopmundoHome`, que é quem tem o `Navigator`.

## Relacionados

Telas Auto Login / UserScripts / Language / DebugOverlay. `GmMenuRegistry`.

## Pontos de entrada

Novo item nativo = a própria feature define uma função `AppMenuItem` na sua pasta (ver `autologin/auto_login_menu_item.dart`, `userscripts/userscripts_menu_item.dart`, `language/language_menu_item.dart` como exemplos), e essa função ganha uma linha na lista `items:` passada a `buildAppMenuItems` no único call site, no `build` do `app.dart`. `buildAppMenuItems` em si não conhece nenhuma feature — só ordena `items` e, se o gate permitir, anexa `debugItem` por último. Não hardcodar em `AppSidebar`.

## Observações e débitos

- Em release o FAB permanece; os três itens QoL preenchem o drawer (não fica só “No options available” como no AD-009 original).
- Keys: `app-sidebar`, `menu-toggle`, `menu-item-<id>`, `menu-empty`.
