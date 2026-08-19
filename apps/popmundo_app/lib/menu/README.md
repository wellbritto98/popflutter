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
| `app_menu_registry.dart` | `buildAppMenuItems`: `auto-login`, `userscripts`, `language`, e `debug` se `includeDebugItem` (default `kDebugMode`) |
| `app_sidebar.dart` | `Drawer`; `menu-empty` se lista fixa vazia **e** sem comandos GM |
| `gm_menu_command_item.dart` | Entrada dinâmica (scriptId, commandId, caption) |

`AppShell` (`lib/app_shell.dart`) hospeda o drawer com `drawerEnableOpenDragGesture: false` (não capturar swipe do jogo).

## Dependências

`easy_localization` nas labels do registro. Callbacks injetados por `PopmundoHome`.

## Relacionados

Telas Auto Login / UserScripts / Language / DebugOverlay. `GmMenuRegistry`.

## Pontos de entrada

Novo item nativo = nova entrada em `buildAppMenuItems` **somente**. Não hardcodar em `AppSidebar`.

## Observações e débitos

- Em release o FAB permanece; os três itens QoL preenchem o drawer (não fica só “No options available” como no AD-009 original).
- Keys: `app-sidebar`, `menu-toggle`, `menu-item-<id>`, `menu-empty`.
