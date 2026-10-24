# The Aurora design language

Lumina Studio is painted in **Aurora**, the design language approved on the design canvas ("Lumina Studio UI
Concepts", artboard 3 · Aurora). It lands in four stages that each ship on their own:

| Stage | What it covers | State |
|---|---|---|
| 1 · Tokens, type and chrome | the Obsidian ramp and amber accent, Manrope + JetBrains Mono, the 48 px menu bar with the Prism L lockup and the editor's own window controls, the typed workspace tabs | shipped |
| 2 · Islands and the Content Drawer | every docked panel as an island (fill, 1 px border, 12 px radius, 8 px gutters, 36 px uppercase header), splitter grips, selection rows that start at their indent, the slide-up Content Drawer | shipped |
| 3 · Viewport chrome | the pill row (Perspective, view mode, snap, angle snap, World, Show), the vertical tool column, stats pills, the MiniAI prompt pill | shipped (without the MiniAI prompt pill) |
| 4 · Sub-editors | Material, Blueprint, Sequencer, Static Mesh, Skeletal Mesh, Animation, Landscape, UMG, Plugins, Project Settings and Build Manager on the stage 1–3 components | shipped (the toolbar rows stay) |

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

## Islands (stage 2)

`EditorIsland` (`lib/ui/core/widgets/editor_island.dart`) is a docked panel: the island fill (`sidebar`), a 1 px
`border` and a 12 px radius, its content clipped to the corners, with an optional `EditorIslandHeader` on top (36 px,
the title in upper case at 11 px bold with a little tracking, an optional mono `trailingInfo` and `actions` at the right
end, over a 1 px border). `EditorIslandStyle` holds the measurements (`radius` 12, `gap` 8, `gripGap` 10,
`headerHeight` 36, `rowHeight` 24, `rowRadius` 6).

The level workspace lays its islands on the window's ground (`background`) with an 8 px gutter round them: the Outliner
island over the Details island in the left column, the viewport island (`viewportBackdrop` fill) in the centre and,
while pinned, the bottom panel island under it. The panes are still `ResizablePanel`s: `EditorIslandDividers.gap` is the
8 px gutter beside islands and `EditorIslandDividers.grip` the 10 px gutter with a 28 × 3 px grip bar between stacked
ones; the panel's own resize handle sits over either, so every island stays resizable and its size persists.

## Tree rows

`EditorTreeRowStyle` is how a tree row inside an island shows its state. The row is indented by a **margin**
(`margin(depth)`: the inner gutter plus one indent step per level), not by padding, so the selection fill starts at the
row's own indent rather than at the panel edge; the selected fill is the amber `primary` with `primaryForeground` text
and icons on it (`foreground(selected:)`), 6 px rounded; a drag over the row tints it and outlines it in amber. The
World Outliner and the Content Browser's folder tree use it.

## The Content Drawer

While the bottom panel is not pinned, the viewport island carries the Content Drawer (`ContentDrawer`,
`lib/ui/features/main_editor/views/content_drawer.dart`): a 36 px `ContentDrawerBar` along its bottom and, above it,
the bottom panel (Content Browser, Output Log, Blueprint, plugin tabs) sliding up 322 px over the viewport in 180 ms.
The viewport keeps its size and its input outside the panel; closed, the panel is not built at all. The bar holds the
**Content Drawer** toggle (opens on the Content Browser, or brings it forward; again closes), the pin (docks the panel
into the layout as an island), the selected folder as a breadcrumb (`Content / Props / Barrels`), the **Output Log**
button (opens or closes the drawer on the log) and the editor's state (`Ready · MCP on/off`). The open and pinned states
persist with the layout (`.lumina/editor_layout.json`); the pin in the panel's tab bar unpins it again.

## Viewport chrome (stage 3)

`lib/ui/core/widgets/viewport_pills.dart` holds the pieces every 3D view shares: `ViewportPill` (28 px on the HUD
surface, 10 px radius, an icon, a label — in mono for numbers — and a chevron when it opens a menu), `ViewportSnapPill`
(a snap toggle and its step value in one pill, the step menu on the value), `ViewportToolColumn` (the vertical pill of
30 px tool buttons, the active one amber with dark icon, a divider, then actions such as Focus), `ViewportShowItem` and
`ViewportPillStyle`.

**Level viewport** (`LevelViewportPills`, `lib/ui/features/main_editor/views/level_viewport_chrome.dart`): top-left the
pill row — camera projection, view mode (Lit, Unlit, Wireframe, Buffer Visualization), the translate, rotate and scale
snaps, the grid with its step, World ⇄ Local, and `Show · n` with the overlays (Grid, Transform Gizmo, Selection
Bounds, Collision, Actor Icons & Labels, Ground Drop Shadows) — with the tool column under it (Select, Move, Rotate,
Scale, then Focus; Q/W/E/R/F still switch them). Top-right: the stats pill (`182k tris · 120 fps`) beside the camera
speed, DLSS, FSR3 and RTX pills, zoom and reset. The level toolbar above the viewport keeps Play and its modes, the
Blueprints menu, the plugin slots, the full frame stats and Quality; the tools, snaps, view mode, Show and camera
projection moved into the viewport.

**Sub-editor viewports** (`SubEditor3DViewport`): the same pill row (view mode with Wireframe, the projection, Scene
Lights where the scene has lights, the preview shape, `Show · n` from `showItems`, then World ⇄ Local and the snap
pills of `TransformGizmoToolbar` with their inline step fields) and, while a gizmo is active, `TransformGizmoToolColumn`
under it; Reset View sits top-right. The Static Mesh editor passes Show · Collision (its collision view) and Show ·
Bounds (a cyan box from the mesh's own bounds, `StaticMeshEditorViewModel.boundsLineSet`); static meshes carry no
sockets, so its Show menu lists none.

Not yet in the chrome: the MiniAI prompt pill. MiniAI's ✦ AI button in the toolbar's plugin slot opens its panel; a
prompt field in the viewport needs a plugin slot that hands typed text to a plugin.

## Sub-editors (stage 4)

Every sub-editor lays its panes out as islands on the ground, with the stage 1–3 components only:
`EditorIslandGround` (the `background` fill with the 8 px gutter), `EditorIsland` per pane, `EditorIslandDividers.gap`
beside islands and `.grip` between stacked ones, so every pane keeps resizing. Three more pieces live in
`lib/ui/core/widgets/editor_island.dart`: `EditorIslandTabHeader` (an island header whose tabs switch the island's view:
the active tab bold on a `muted` chip; a narrow island shortens the labels instead of scrolling one away;
`tabKeys`/`keyPrefix` key the tabs), `EditorIslandSectionLabel` (an upper-case 10 px section label inside an island, with
an optional trailing widget) and `editorIslandGroundGrip` (the grip under a pane that brings its own gutter).

| Editor | Islands |
|---|---|
| Static Mesh | LODs / Hierarchy over Mesh stats · viewport · Details |
| Skeletal Mesh | Skeleton tree (bone and socket counts, + socket) over Morphs / RigLogic · viewport (Show · Bones, Weights, Sockets) · Details |
| Animation | Properties / Bone Tracks / Notifies · viewport with the frame card and the transport bar along its bottom, over the Dope sheet · Key details / Curves / BlendSpace / Pose |
| Material | Preview over Parameters & uniforms · GLSL Source / Node Graph over the Compiler log · Details (the material's header settings) |
| Blueprint | Components over My Blueprint · the graph tabs and canvas over the compiler results · Details |
| Sequencer | Track outliner · 3D Viewport / Curves · Key details; the transport over the timeline below |
| UMG | Palette over Hierarchy · designer · Details |
| Landscape | Manage / Sculpt / Foliage tabs heading the tool island · viewport · Foliage |
| Texture, Particle, Physics Asset, Blend Space, Anim Blueprint, Blueprint Interface, Pose Search, Cloth, Garment | each pane an island |
| Plugins | categories · plugin list · details |
| Project Settings | category list (resizable now, was a fixed 220 px) · the category's settings with the save footer |
| Build Manager | Build steps · Build log · Packaging (resizable now, were fixed widths) |

The Skeletal Mesh editor's Show Bones, Display Sockets and Skin Weight Heatmap toolbar buttons moved into the viewport's
`Show` menu (Bones, Weights, Sockets). The overlay boxes of the Static Mesh, Skeletal Mesh and Physics Asset viewports
sit bottom-left on the pill surface (the pill row and the tool column own the top-left); the Animation frame card sits
under the pill row beside the tool column and the root motion toggle is a pill under Reset View. The Material editor
follows its artboard: the parameters under the preview, the material's settings in the Details island at the right.

The sub-editor shell docks the Content Browser as an island under the workspace (the grip between) and floats the
unpinned drawer as an island over the workspace's bottom. The plugin right dock is an island too, and a plugin's tab or
asset editor is framed on one island on the ground by the host.

Not in stage 4: the sub-editors keep their toolbar row (the artboards put the actions at the right of the tab bar);
plugins get no island widgets of their own through `lumina_editor_api` yet (the host frames their panels and tabs).

## Verification

`test/ui/theme_aurora_tokens_test.dart`, `test/ui/menu_bar_aurora_test.dart` and `test/ui/typed_tab_bar_test.dart`
cover stage 1, `test/ui/editor_island_test.dart` and `test/ui/content_drawer_test.dart` stage 2, `test/ui/viewport_pills_test.dart` and `test/ui/sub_viewport_pills_test.dart` stage 3, and each sub-editor's own widget test finds its islands and headers (`test/helpers/island_expectations.dart`) for stage 4; the smoke scenario "Design System Smoke: aurora design language"
(`integration_test/smoke/design_system_smoke_test.dart`) imports a barrel and the mannequin into a real project, opens
the Static Mesh and Skeletal Mesh editors as typed tabs, measures the rail, the command field, the chip and the tab
underlines in screenshots, and records the tab switches with the viewport orbiting. "Design System Smoke: aurora islands
and content drawer" places a barrel, an AC unit and a banana bunch, measures the ground, the island fill, border, grip
and rounded corner, the Outliner selection at its indent and the drawer bar, opens the drawer over the viewport (322 px,
the viewport island unchanged), opens the Output Log from the bar, and pins the panel, on video. "Design System Smoke:
aurora sub-editors" imports a barrel, the mannequin and an idle clip, opens the eleven editors as tabs, checks their
islands, measures the island fill and the ground beside it in each, and orbits the 3D viewports on video.
