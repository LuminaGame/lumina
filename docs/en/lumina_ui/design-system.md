# The Aurora design language

Lumina Studio is painted in **Aurora**, the design language approved on the design canvas ("Lumina Studio UI
Concepts", artboard 3 · Aurora). It lands in four stages that each ship on their own:

| Stage | What it covers | State |
|---|---|---|
| 1 · Tokens, type and chrome | the Obsidian ramp and amber accent, Manrope + JetBrains Mono, the 48 px menu bar with the Prism L lockup and the editor's own window controls, the typed workspace tabs | shipped |
| 2 · Islands and the Content Drawer | every docked panel as an island (fill, 1 px border, 12 px radius, 8 px gutters, 36 px uppercase header), splitter grips, selection rows that start at their indent, the slide-up Content Drawer | planned |
| 3 · Viewport chrome | the pill row (Perspective, view mode, snap, angle snap, World, Show), the vertical tool column, stats pills, the MiniAI prompt pill | planned |
| 4 · Sub-editors | Material, Blueprint, Sequencer, Static Mesh, Skeletal Mesh, Animation, Landscape, UMG, Plugins, Project Settings and Build Manager on the stage 1–3 components | planned |

Themes stay data: the ramp and accent are the defaults of the Lumina Dark theme (`EditorThemeData.luminaDark`), so a
custom theme JSON still overrides any token (see [Editor themes](core.md)).

## Tokens (stage 1)

Every colour is an `EditorColors` token (`lib/ui/core/theme/editor_theme.dart`), a `const` that resolves through the
active theme. The surfaces form one near-black ramp with a faint cool cast; islands and fields are separated by solid
borders and radii, not by big lightness steps.

| Token | Value | Paints |
|---|---|---|
| `rail` | `#0F1013` | the menu bar, the tab bar, graph canvases (`graphCanvas`) |
| `sidebar` | `#111215` | islands (every docked panel), viewport pills (`hudSurface` at 88 %) |
| `background` | `#141518` | the window behind the islands |
| `cardHeader` | `#15171B` | panel header strips, toolbars |
| `card` | `#1A1B1F` | fields, tiles, popovers |
| `muted` / `secondary` | `#1F2126` / `#24262C` | muted fills, pressed button faces |
| `border` | `#26282E` | island and panel borders (solid) |
| `fieldBorder` (`input`) | `#2C2E34` | input outlines |
| `viewportBackdrop` | `#1B1D22` | behind the 3D view |
| `foreground` / `mutedForeground` | `#E6E6E8` / `#9A9CA3` | text, labels |
| `primary` / `primaryForeground` | `#F2A93B` / `#0B1D22` | the amber accent and the dark text on it |
| `accent` | `#39C6E0` | the second accent (cyan) |
| `success` / `warning` / `destructive` | `#7FE0A4` / `#E3B341` / `#FF7B72` | states |

`test/ui/theme_surface_contrast_test.dart` keeps `foreground` at 7:1 and `mutedForeground` at 4.5:1 on every surface
and the ramp strictly ordered; `test/ui/design_tokens_test.dart` pins the values and scans `lib/ui` for raw colour
literals (a literal survives only with a reason on its line or the line above, or a `// design-token-exempt:` note at
the top of a file that paints things outside the chrome, such as the GLSL syntax palette or a UI Theme preview).

## Type

`EditorTypography.uiFamily` is **Manrope** (400/500/600/700/800, bundled under `assets/fonts/`, SIL OFL) for every
label, menu, tab and heading; `EditorTypography.monoFamily` is **JetBrains Mono** for numbers, paths and stats. The
scale is 9 / 10 / 11 / 12 / 15 px (`captionSize`, `labelSize`, `bodySize`, `titleSize`, `displaySize`);
`EditorTypography.ui(...)` and `EditorTypography.mono(...)` spell a style in each family. The app theme sets
shadcn_flutter's `sans` to Manrope, so widgets that style themselves follow; a theme JSON may still pick `GeistSans`.

## The menu bar

`MenuBarWidget` (`lib/ui/features/main_editor/views/menu_bar_widget.dart`) is the window's title bar: a 48 px row on
`rail` with the Prism L lockup (`LuminaLockup`) at the left, then File · Edit · View · Build · Debug · Tools ·
Plugins · Window · Help (plugin menus slot in before Window or Help), the Ctrl K command field in the middle (it opens
the quick-open palette, as Ctrl K and Ctrl P do), and at the right the source-control button (its dropdown holds the
Source Control entries; a dot marks a level with uncommitted changes), undo, redo, the `Project · Level` chip (an amber
dot while the level is unsaved; click saves) and the editor's own window controls: fullscreen, minimize, maximize ⇄
restore, close. The empty stretch of the row drags the window; double-click maximizes.

## Typed tabs

`EditorTypedTabBar` (`lib/ui/core/widgets/typed_tab_bar.dart`) is the 42 px workspace strip under the menu bar. Each
`EditorTypedTab` carries the icon and colour of what it shows (`AssetTypeStyle` for an asset, the registry's icon in the
muted grey for a document such as Plugins or Project Settings); the active tab sits on the island fill with a 2 px
underline in that colour; an unsaved tab shows an amber dot where the close cross goes, and the cross comes back under
the pointer; a middle click closes; `+` opens New Asset; tabs that do not fit the width collapse into a `+N` menu that
lists and selects them, and the active tab is always kept visible.

## Verification

`test/ui/theme_aurora_tokens_test.dart`, `test/ui/menu_bar_aurora_test.dart` and `test/ui/typed_tab_bar_test.dart`
cover stage 1; the smoke scenario "Design System Smoke: aurora design language"
(`integration_test/smoke/design_system_smoke_test.dart`) imports a barrel and the mannequin into a real project, opens
the Static Mesh and Skeletal Mesh editors as typed tabs, measures the rail, the command field, the chip and the tab
underlines in screenshots, and records the tab switches with the viewport orbiting.
