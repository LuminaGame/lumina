import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'editor_theme_data.dart';
import 'editor_theme_store.dart';

/// Lumina Studio's palette.
///
/// The accents, text colours, radius and type scale are the Figma Make design
/// prototype's (`Design Lumina Game Engine UI/src/index.css`), converted from
/// its OKLCH to sRGB and keeping its token names so the two can be compared.
///
/// The **surfaces** are a deliberate departure: the
/// prototype's near-black ramp (`oklch(0.086…0.155 0 0)`, `#020202`–`#0C0C0C`)
/// made the panels read as one black sheet, so they were lifted onto a
/// hueless grey ramp whose neighbours differ by at least 4 L* and on which
/// [foreground] keeps 7:1 and [mutedForeground] 4.5:1 (see
/// `test/ui/theme_surface_contrast_test.dart`):
///
/// | token        | value     | L*   | used for                                  |
/// |--------------|-----------|------|-------------------------------------------|
/// | [rail]       | `#131313` |  5.9 | filter strips, sources column, toolbars   |
/// | [background] | `#1C1C1C` | 10.3 | the window, panel bodies                  |
/// | [sidebar]    | `#252525` | 14.7 | tab strips (workspace, bottom panel)      |
/// | [cardHeader] | `#2E2E2E` | 18.9 | menu bar, main toolbar, panel headers     |
/// | [card]       | `#373737` | 23.1 | Details sections, asset tiles, cards      |
/// | [popover]    | `#414141` | 27.5 | menus, popovers, [muted]                  |
///
/// [viewportBackdrop] stays below the ramp (`#0E0E0E`) so the 3D view reads as
/// recessed, and the neutrals still carry no hue.
///
/// `tool/design_tokens.dart` regenerates the prototype-derived values from the
/// prototype's CSS.
///
/// **Themes.** Every colour token below except the
/// transform axes is an [EditorThemeColor]: a `const` colour whose value is
/// the active editor theme's (`EditorTheme.current`, loaded from the theme
/// JSON), with the values written here — Lumina Dark's — as its fallback. So
/// `const TextStyle(color: EditorColors.foreground)` stays valid everywhere
/// and still follows a theme switch; `EditorTheme.apply` rebuilds, repaints
/// and re-lays out the running editor when the theme changes.
class EditorColors {
  const EditorColors._();

  // --- Surfaces (grey ramp) --------------------------------

  /// The window behind everything and the body of most panels (World
  /// Outliner, Details). Was the prototype's `--background` `#020202`.
  static const Color background = EditorThemeColor('background', 0xFF1C1C1C);

  /// The tab strips: the workspace tabs under the menu bar and the bottom
  /// panel's Content Browser / Output Log / Blueprint row. Was `--sidebar`
  /// `#050505`.
  static const Color sidebar = EditorThemeColor('sidebar', 0xFF252525);

  /// Panels and cards that sit on the background (Details sections, asset
  /// tiles). Was `--card` `#070707`.
  static const Color card = EditorThemeColor('card', 0xFF373737);

  /// Menus and popovers (`--popover` / `--muted`). Was `#0C0C0C`.
  static const Color popover = EditorThemeColor('popover', 0xFF414141);
  static const Color muted = EditorThemeColor('muted', 0xFF414141);

  /// A panel's header strip, the menu bar and the main toolbar. Still darker
  /// than the [card] under it, as in the prototype. Was `#040404`.
  static const Color cardHeader = EditorThemeColor('cardHeader', 0xFF2E2E2E);

  /// The header strip under the pointer.
  static const Color cardHeaderHover = EditorThemeColor('cardHeaderHover', 0xFF353535);

  /// The rails and filter strips that frame a panel — the outliner's filter
  /// row, the Content Browser's sources column and its toolbar. The darkest
  /// step of the ramp. Was `#030303`.
  static const Color rail = EditorThemeColor('rail', 0xFF131313);

  /// The colour behind the native 3D surface, visible only until the viewport
  /// produces its first frame. Deliberately below the whole panel ramp, so the
  /// 3D view reads as recessed.
  static const Color viewportBackdrop = EditorThemeColor('viewportBackdrop', 0xFF0E0E0E);

  /// A HUD chip floating over the 3D render: [background] at the opacity the
  /// viewport's overlays use, so the render shows through.
  static const Color hudSurface = EditorThemeColor('hudSurface', 0xCC1C1C1C);

  /// The same chip where the text on it has to stay readable over a bright
  /// render.
  static const Color hudSurfaceStrong = EditorThemeColor('hudSurfaceStrong', 0xEE1C1C1C);

  /// The Blueprint / Anim Graph canvas backdrop (graph grey), and so
  /// the fill of the selected graph tab above it.
  static const Color graphCanvas = EditorThemeColor('graphCanvas', 0xFF16171A);

  /// The scrollbar thumb, well above [popover].
  static const Color scrollbar = EditorThemeColor('scrollbar', 0xFF5E5E5E);

  /// Pressed/secondary button faces (`--secondary`), a step above [popover].
  static const Color secondary = EditorThemeColor('secondary', 0xFF4A4A4A);

  // --- Text -----------------------------------------------------------------

  /// `--foreground`, `oklch(0.875 0 0)`.
  static const Color foreground = EditorThemeColor('foreground', 0xFFD6D6D6);

  /// Text on [secondary] faces. Lifted from the prototype's `oklch(0.78 0 0)`
  /// `#B7B7B7` so it stays above [mutedForeground].
  static const Color secondaryForeground = EditorThemeColor('secondaryForeground', 0xFFC4C4C4);

  /// Labels, units, inactive tabs. Lifted from the prototype's
  /// `oklch(0.52 0 0)` `#696969`: on the grey ramp it must
  /// still reach 4.5:1 on the lightest surface, [popover].
  static const Color mutedForeground = EditorThemeColor('mutedForeground', 0xFFAEAEAE);

  /// `--primary-foreground`, `oklch(0.1 0 0)`: text on top of [primary].
  static const Color primaryForeground = EditorThemeColor('primaryForeground', 0xFF030303);

  /// `--accent-foreground`, `oklch(0.96 0 0)`.
  static const Color accentForeground = EditorThemeColor('accentForeground', 0xFFF2F2F2);

  // --- Accents --------------------------------------------------------------

  /// `--primary` / `--ring`, `oklch(0.72 0.185 52)`: Lumina's orange.
  static const Color primary = EditorThemeColor('primary', 0xFFFB7C01);

  /// `--accent`, `oklch(0.62 0.16 220)`: the secondary, cyan-blue accent.
  static const Color accent = EditorThemeColor('accent', 0xFF0099C8);

  /// `--destructive`, `oklch(0.62 0.22 27)`.
  static const Color destructive = EditorThemeColor('destructive', 0xFFEE3533);

  /// A selected row's fill: [primary] at the prototype's selection opacity
  /// (`bg-primary/20`).
  static const Color selectionBg = EditorThemeColor('selectionBg', 0x33FB7C01);

  /// A row under the pointer, `hover:bg-white/4`.
  static const Color rowHover = EditorThemeColor('rowHover', 0x0AFFFFFF);

  // --- Chart ramp -----------------------------------------------------------
  // `--chart-1` … `--chart-5`. This is the prototype's only set of categorical
  // hues, so anything in the editor that needs to tell categories apart — log
  // levels, actor types, source-control states, blueprint node families — draws
  // from here rather than inventing a colour.

  /// `--chart-1`, the same orange as [primary].
  static const Color chart1 = EditorThemeColor('chart1', 0xFFFB7C01);

  /// `--chart-2`, the same blue as [accent].
  static const Color chart2 = EditorThemeColor('chart2', 0xFF0099C8);

  /// `--chart-3`, `oklch(0.65 0.15 140)`: green.
  static const Color chart3 = EditorThemeColor('chart3', 0xFF58A547);

  /// `--chart-4`, `oklch(0.68 0.17 280)`: violet.
  static const Color chart4 = EditorThemeColor('chart4', 0xFF8688FE);

  /// `--chart-5`, the same red as [destructive].
  static const Color chart5 = EditorThemeColor('chart5', 0xFFEE3533);

  /// Amber. The prototype's ramp has no yellow, but a warning that reads as a
  /// selection is worse than a sixth hue, so the log and the "modified"/locked
  /// states keep one. Tailwind `amber-400`, which is what the prototype's own
  /// `text-yellow-400` folder icon uses.
  static const Color warning = EditorThemeColor('warning', 0xFFFBBF24);

  // --- Lines ----------------------------------------------------------------

  /// White at 12% (the prototype's `--border` is 9%, raised with the lifted
  /// surfaces so panel edges stay visible), not a solid grey, so it keeps its
  /// weight over any surface it is drawn on.
  static const Color border = EditorThemeColor('border', 0x1FFFFFFF);

  /// Input outlines, white at 15% (prototype `--input`: 11%).
  static const Color input = EditorThemeColor('input', 0x26FFFFFF);

  /// [border] composited over [background], as a solid colour for the places
  /// that need one (native painters and anything drawn without a backdrop to
  /// blend with).
  static const Color borderSolid = EditorThemeColor('borderSolid', 0xFF383838);

  // --- Output log -----------------------------------------------------------
  // The log keeps its own hues: these are states, not surfaces, and the
  // prototype's chart ramp is what it uses for them.

  /// `--chart-2`, the accent blue.
  static const Color logInfo = EditorThemeColor('logInfo', 0xFF0099C8);

  /// [warning]; kept distinct from [primary] so a warning does not read as a
  /// selection.
  static const Color logWarning = EditorThemeColor('logWarning', 0xFFFBBF24);

  /// `--chart-5` / `--destructive`.
  static const Color logError = EditorThemeColor('logError', 0xFFEE3533);

  /// `--chart-3`.
  static const Color logSuccess = EditorThemeColor('logSuccess', 0xFF58A547);

  // --- Graph taxonomies ----------------------------------------------------
  // Colours that name a kind of value in a graph editor rather than a piece of
  // editor chrome; they live here so no widget spells a raw literal.

  /// Blueprint graph pins by type (white exec, red
  /// boolean, green numbers, violet vectors, …), themeable like the rest.
  static const Color pinExec = EditorThemeColor('pinExec', 0xFFFFFFFF);
  static const Color pinBoolean = EditorThemeColor('pinBoolean', 0xFFEE3533);
  static const Color pinInteger = EditorThemeColor('pinInteger', 0xFF43A047);
  static const Color pinFloat = EditorThemeColor('pinFloat', 0xFF58A547);
  static const Color pinString = EditorThemeColor('pinString', 0xFFFF5252);
  static const Color pinName = EditorThemeColor('pinName', 0xFFF48FB1);
  static const Color pinVector = EditorThemeColor('pinVector', 0xFF8688FE);
  static const Color pinVector2D = EditorThemeColor('pinVector2D', 0xFF1DE9B6);
  static const Color pinRotator = EditorThemeColor('pinRotator', 0xFFB39DDB);
  static const Color pinObject = EditorThemeColor('pinObject', 0xFF0099C8);
  static const Color pinTransform = EditorThemeColor('pinTransform', 0xFF26C6DA);
  static const Color pinStruct = EditorThemeColor('pinStruct', 0xFFFBBF24);
  static const Color pinColor = EditorThemeColor('pinColor', 0xFF1E88E5);
  static const Color pinArray = EditorThemeColor('pinArray', 0xFF0099C8);
  static const Color pinHitResult = EditorThemeColor('pinHitResult', 0xFF26C6DA);
  static const Color pinWildcard = EditorThemeColor('pinWildcard', 0xFF9E9E9E);
  static const Color pinEnum = EditorThemeColor('pinEnum', 0xFF2E7D32);
  static const Color pinDelegate = EditorThemeColor('pinDelegate', 0xFFE53935);
  static const Color pinTimerHandle = EditorThemeColor('pinTimerHandle', 0xFF26C6DA);
  static const Color pinUnknown = EditorThemeColor('pinUnknown', 0xFFEE3533);

  /// Material graph pins by component count (float1…float4, texture, and an
  /// unresolved type).
  static const Color materialPinFloat1 = EditorThemeColor('materialPinFloat1', 0xFFB0BEC5);
  static const Color materialPinFloat2 = EditorThemeColor('materialPinFloat2', 0xFF4DB6AC);
  static const Color materialPinFloat3 = EditorThemeColor('materialPinFloat3', 0xFFFFD54F);
  static const Color materialPinFloat4 = EditorThemeColor('materialPinFloat4', 0xFFF06292);
  static const Color materialPinTexture = EditorThemeColor('materialPinTexture', 0xFFBA68C8);
  static const Color materialPinUnknown = EditorThemeColor('materialPinUnknown', 0xFF78909C);

  /// A Blend Space reference in the Anim Blueprint editor: Tailwind
  /// `purple-400`, the text colour for the purple Blend Space icon.
  static const Color blendSpaceLabel = EditorThemeColor('blendSpaceLabel', 0xFFC084FC);

  /// The fill of an empty image slot in the UMG designer: white at 7%, so it
  /// reads as a placeholder over any backdrop.
  static const Color placeholderFill = EditorThemeColor('placeholderFill', 0x11FFFFFF);

  // --- Asset types ----------------------------------------------------------
  // The Content Browser's type strip under each thumbnail and the type swatch
  // in tooltips, filter chips and asset pickers.
  // `AssetTypeStyle` maps an `AssetType` to its token.

  /// An Animation Sequence (`AssetType.animation`): green.
  static const Color assetTypeAnimation = EditorThemeColor('assetTypeAnimation', 0xFF3FA33A);

  /// A Skeletal Mesh (`filameshSk`): magenta.
  static const Color assetTypeSkeletalMesh = EditorThemeColor('assetTypeSkeletalMesh', 0xFFE040E0);

  /// A Static Mesh (`filamesh`): cyan.
  static const Color assetTypeStaticMesh = EditorThemeColor('assetTypeStaticMesh', 0xFF00C8C8);

  /// A Material (`filamat`): light green.
  static const Color assetTypeMaterial = EditorThemeColor('assetTypeMaterial', 0xFF8BD867);

  /// A Blueprint Class (`actor`): blue.
  static const Color assetTypeBlueprint = EditorThemeColor('assetTypeBlueprint', 0xFF3F7EFF);

  /// An Animation Blueprint: orange-red.
  static const Color assetTypeAnimBlueprint = EditorThemeColor('assetTypeAnimBlueprint', 0xFFF05A28);

  /// A Blend Space: yellow-orange.
  static const Color assetTypeBlendSpace = EditorThemeColor('assetTypeBlendSpace', 0xFFF5B324);

  /// A Physics Asset: peach.
  static const Color assetTypePhysicsAsset = EditorThemeColor('assetTypePhysicsAsset', 0xFFFFC08A);

  /// A Level: orange.
  static const Color assetTypeLevel = EditorThemeColor('assetTypeLevel', 0xFFFF9C00);

  /// A Texture: red.
  static const Color assetTypeTexture = EditorThemeColor('assetTypeTexture', 0xFFD64545);

  /// A Sound: blue-grey.
  static const Color assetTypeAudio = EditorThemeColor('assetTypeAudio', 0xFF7C93B0);

  /// A Widget Blueprint: dark blue.
  static const Color assetTypeWidget = EditorThemeColor('assetTypeWidget', 0xFF2C59B4);

  /// A Particle System: violet.
  static const Color assetTypeParticle = EditorThemeColor('assetTypeParticle', 0xFFB06CFF);

  /// A Landscape: earth brown.
  static const Color assetTypeLandscape = EditorThemeColor('assetTypeLandscape', 0xFFB08D57);

  /// A Level Sequence: rose.
  static const Color assetTypeSequencer = EditorThemeColor('assetTypeSequencer', 0xFFE0607E);

  // --- Transform axes -------------------------------------------------------
  // These must match `FilamentTransformGizmo.defaultHandleColor`, which paints
  // the manipulator in the 3D scene, or the Details panel and the viewport
  // disagree about which axis is which colour.

  static const Color axisX = Color(0xFFFF3333);
  static const Color axisY = Color(0xFF33FF33);
  static const Color axisZ = Color(0xFF3333FF);

  /// The corner radius the prototype uses, `--radius: 0.1875rem` = 3 px.
  /// shadcn_flutter takes this as a multiplier of its own base radius. The
  /// active theme's `radius` is what the app runs on.
  static const double radius = 0.1875;

  /// Every themed token by its JSON key.
  static const Map<String, Color> all = {
    'background': background,
    'sidebar': sidebar,
    'card': card,
    'cardHeader': cardHeader,
    'cardHeaderHover': cardHeaderHover,
    'rail': rail,
    'popover': popover,
    'muted': muted,
    'secondary': secondary,
    'viewportBackdrop': viewportBackdrop,
    'hudSurface': hudSurface,
    'hudSurfaceStrong': hudSurfaceStrong,
    'scrollbar': scrollbar,
    'border': border,
    'input': input,
    'borderSolid': borderSolid,
    'rowHover': rowHover,
    'placeholderFill': placeholderFill,
    'foreground': foreground,
    'secondaryForeground': secondaryForeground,
    'mutedForeground': mutedForeground,
    'primaryForeground': primaryForeground,
    'accentForeground': accentForeground,
    'primary': primary,
    'accent': accent,
    'selectionBg': selectionBg,
    'destructive': destructive,
    'warning': warning,
    'logInfo': logInfo,
    'logWarning': logWarning,
    'logError': logError,
    'logSuccess': logSuccess,
    'graphCanvas': graphCanvas,
    'pinExec': pinExec,
    'pinBoolean': pinBoolean,
    'pinInteger': pinInteger,
    'pinFloat': pinFloat,
    'pinString': pinString,
    'pinName': pinName,
    'pinVector': pinVector,
    'pinVector2D': pinVector2D,
    'pinRotator': pinRotator,
    'pinObject': pinObject,
    'pinTransform': pinTransform,
    'pinStruct': pinStruct,
    'pinColor': pinColor,
    'pinArray': pinArray,
    'pinHitResult': pinHitResult,
    'pinWildcard': pinWildcard,
    'pinEnum': pinEnum,
    'pinDelegate': pinDelegate,
    'pinTimerHandle': pinTimerHandle,
    'pinUnknown': pinUnknown,
    'materialPinFloat1': materialPinFloat1,
    'materialPinFloat2': materialPinFloat2,
    'materialPinFloat3': materialPinFloat3,
    'materialPinFloat4': materialPinFloat4,
    'materialPinTexture': materialPinTexture,
    'materialPinUnknown': materialPinUnknown,
    'blendSpaceLabel': blendSpaceLabel,
    'assetTypeAnimation': assetTypeAnimation,
    'assetTypeSkeletalMesh': assetTypeSkeletalMesh,
    'assetTypeStaticMesh': assetTypeStaticMesh,
    'assetTypeMaterial': assetTypeMaterial,
    'assetTypeBlueprint': assetTypeBlueprint,
    'assetTypeAnimBlueprint': assetTypeAnimBlueprint,
    'assetTypeBlendSpace': assetTypeBlendSpace,
    'assetTypePhysicsAsset': assetTypePhysicsAsset,
    'assetTypeLevel': assetTypeLevel,
    'assetTypeTexture': assetTypeTexture,
    'assetTypeAudio': assetTypeAudio,
    'assetTypeWidget': assetTypeWidget,
    'assetTypeParticle': assetTypeParticle,
    'assetTypeLandscape': assetTypeLandscape,
    'assetTypeSequencer': assetTypeSequencer,
    'chart1': chart1,
    'chart2': chart2,
    'chart3': chart3,
    'chart4': chart4,
    'chart5': chart5,
  };

  /// The token called [key] in the theme JSON.
  static Color token(String key) => all[key] ?? (throw ArgumentError.value(key, 'key', 'not an editor theme token'));
}

/// The shadcn_flutter colour scheme built from [EditorColors], so the widgets
/// that theme themselves (buttons, menus, popovers, inputs) land on the same
/// palette as the ones that read [EditorColors] directly.
///
/// This replaces `ColorSchemes.darkNeutral`, whose surfaces and accent are not
/// the prototype's.
const ColorScheme luminaDarkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  background: EditorColors.background,
  foreground: EditorColors.foreground,
  card: EditorColors.card,
  cardForeground: EditorColors.foreground,
  popover: EditorColors.popover,
  popoverForeground: EditorColors.foreground,
  primary: EditorColors.primary,
  primaryForeground: EditorColors.primaryForeground,
  secondary: EditorColors.secondary,
  secondaryForeground: EditorColors.secondaryForeground,
  muted: EditorColors.muted,
  mutedForeground: EditorColors.mutedForeground,
  accent: EditorColors.accent,
  accentForeground: EditorColors.accentForeground,
  destructive: EditorColors.destructive,
  destructiveForeground: EditorColors.accentForeground,
  border: EditorColors.border,
  input: EditorColors.input,
  ring: EditorColors.primary,
  // The prototype's chart ramp: orange, blue, green, violet, red.
  chart1: EditorColors.chart1,
  chart2: EditorColors.chart2,
  chart3: EditorColors.chart3,
  chart4: EditorColors.chart4,
  chart5: EditorColors.chart5,
);

/// The sidebar surface is not part of this shadcn_flutter version's
/// [ColorScheme]; the panels that need it read [EditorColors.sidebar].

/// The prototype's type scale.
///
/// Every size here was read off `Design Lumina Game Engine UI/src/App.tsx`
/// rather than judged: the prototype writes its sizes as explicit
/// `text-[Npx]` utilities, so there is nothing to interpret.
class EditorTypography {
  const EditorTypography._();

  /// `--font-sans: 'Geist Variable'`. shadcn_flutter already bundles the whole
  /// Geist family under this name, so nothing is shipped for it here. The
  /// prototype loads the variable cut and this is the static one, which means
  /// the weights are the designed instances rather than interpolations — the
  /// shapes are the same at 400/500/600/700, which is all the editor uses.
  static const String sansFamily = 'GeistSans';
  static const String sansPackage = 'shadcn_flutter';

  /// `--font-mono: 'JetBrains Mono', monospace`, bundled under
  /// `assets/fonts/` (SIL OFL).
  static const String monoFamily = 'JetBrains Mono';

  /// `text-[10px] font-semibold uppercase tracking-widest` — panel headings.
  static const double panelTitleSize = 10;
  static const FontWeight panelTitleWeight = FontWeight.w600;

  /// `text-[11px]` — outliner rows, actor names, property labels, field text.
  static const double bodySize = 11;

  /// `text-[10px]` — section labels, units, filter chips.
  static const double labelSize = 10;

  /// `text-[9px]` — badges, asset names, the status bar.
  static const double captionSize = 9;

  /// `text-[8px]` — asset sizes, viewport axis gizmo letters.
  static const double microSize = 8;

  /// Tailwind `tracking-widest` is `0.1em`; Flutter's `letterSpacing` is in
  /// logical pixels, so at [panelTitleSize] that is 1.0.
  static const double trackingWidest = panelTitleSize * 0.1;

  /// Tailwind `tracking-wider` is `0.05em`.
  static const double trackingWider = labelSize * 0.05;

  /// The heading strip of every panel: World Outliner, Details, Sources.
  static const TextStyle panelHeading = TextStyle(
    fontSize: panelTitleSize,
    fontWeight: panelTitleWeight,
    letterSpacing: trackingWidest,
    color: EditorColors.mutedForeground,
  );

  /// A section label inside the Details panel (`LOCATION`, `ROTATION`, …).
  static const TextStyle sectionLabel = TextStyle(
    fontSize: labelSize,
    letterSpacing: trackingWider,
    color: EditorColors.mutedForeground,
  );

  /// Numbers, paths and counters, which the prototype always sets in mono.
  static TextStyle mono({
    double fontSize = bodySize,
    FontWeight? fontWeight,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: monoFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
}

/// The prototype's density, in logical pixels.
///
/// Tailwind's spacing step is 4 px, so `h-7` is 28, `h-6` is 24, `h-5.5` is 22
/// and `px-2` is an 8 px gutter. These are measurements off the prototype's
/// markup, not preferences.
class EditorDensity {
  const EditorDensity._();

  /// `h-7` — a panel's header strip and the Content Browser toolbar.
  static const double panelHeaderHeight = 28;

  /// `h-6` — an outliner row, and a Details vector field.
  static const double rowHeight = 24;
  static const double fieldHeight = 24;

  /// `h-5.5` — the outliner's filter box and the Content Browser's folder rows.
  static const double compactRowHeight = 22;

  /// `h-5` — filter chips and the asset search box.
  static const double chipHeight = 20;

  /// `px-2` — the horizontal gutter shared by headers, rows and toolbars.
  static const double gutter = 8;

  /// `gap-1` — the gap between a row's icon, name and buttons.
  static const double gap = 4;

  /// `paddingLeft: 8 + depth * 14` — the outliner's indent per tree level.
  static const double indentStep = 14;

  /// `w-36` — the Content Browser's sources column.
  static const double sourcesRailWidth = 144;

  /// `grid-cols-[repeat(auto-fill,minmax(72px,1fr))]` — an asset tile.
  static const double assetTileMinWidth = 72;

  /// `border-l-2` — the accent bar on the selected outliner row.
  static const double selectionBarWidth = 2;
}

/// The shared look of a tab in a tab strip: the workspace
/// tabs, the bottom panel's tabs and the Blueprint editor's graph tabs.
///
/// The active tab is attached to the content under it: its fill
/// is that content's colour ([content]), it keeps a tinted outline on the top
/// (a 2 px [EditorColors.primary] bar) and the sides, and it has **no bottom
/// edge**, so nothing separates it from what it shows. Inactive tabs are flat.
/// A strip using it draws its own bottom line under the inactive tabs only
/// ([stripBottomLine]); the active tab covers it.
class EditorTabStyle {
  const EditorTabStyle._();

  /// The tinted top bar of the active tab.
  static const double activeTopWidth = 2;

  static BoxDecoration decoration({required bool active, required Color content}) {
    if (!active) return const BoxDecoration(color: Color(0x00000000));
    return BoxDecoration(
      color: content,
      border: Border(
        top: const BorderSide(color: EditorColors.primary, width: activeTopWidth),
        left: BorderSide(color: EditorColors.primary.withValues(alpha: 0.5)),
        right: BorderSide(color: EditorColors.primary.withValues(alpha: 0.5)),
      ),
    );
  }

  /// The strip's bottom line, drawn under the inactive tabs; the active tab
  /// paints over it.
  static Widget stripBottomLine() => const Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: 1,
        child: ColoredBox(color: EditorColors.border),
      );
}

/// The shadcn_flutter colour scheme of [theme], in plain
/// resolved colours so a theme switch produces a different `ThemeData` and
/// every shadcn widget rebuilds with it.
ColorScheme luminaColorSchemeFor(EditorThemeData theme) {
  Color c(String token) => theme.color(token);
  return ColorScheme(
    brightness: theme.brightness,
    background: c('background'),
    foreground: c('foreground'),
    card: c('card'),
    cardForeground: c('foreground'),
    popover: c('popover'),
    popoverForeground: c('foreground'),
    primary: c('primary'),
    primaryForeground: c('primaryForeground'),
    secondary: c('secondary'),
    secondaryForeground: c('secondaryForeground'),
    muted: c('muted'),
    mutedForeground: c('mutedForeground'),
    accent: c('accent'),
    accentForeground: c('accentForeground'),
    destructive: c('destructive'),
    destructiveForeground: c('accentForeground'),
    border: c('border'),
    input: c('input'),
    ring: c('primary'),
    chart1: c('chart1'),
    chart2: c('chart2'),
    chart3: c('chart3'),
    chart4: c('chart4'),
    chart5: c('chart5'),
  );
}

/// The one theme Lumina Studio runs on — in the app, in every widget test and
/// in every smoke test, so a screenshot is evidence of what the editor
/// actually looks like.
///
/// It is derived from the active editor theme (`EditorTheme.current`): its colours, radius, density (shadcn's `scaling`) and
/// fonts. [light] asks for Lumina Light's scheme while a dark theme is active
/// (kept for callers that still pass it).
ThemeData luminaEditorTheme({bool light = false}) {
  final active = EditorTheme.current;
  final theme = light && active.brightness == Brightness.dark ? EditorThemeData.luminaLight : active;
  final mono = theme.monoFamily == 'GeistMono'
      ? const TextStyle(fontFamily: 'GeistMono', package: 'shadcn_flutter')
      : TextStyle(fontFamily: theme.monoFamily);
  final sans = theme.sansFamily == EditorTypography.sansFamily
      ? const TextStyle(fontFamily: EditorTypography.sansFamily, package: EditorTypography.sansPackage)
      : TextStyle(fontFamily: theme.sansFamily);
  return ThemeData(
    colorScheme: luminaColorSchemeFor(theme),
    radius: theme.radius,
    scaling: theme.density,
    typography: Typography.geist(
      sans: sans,
      mono: mono,
      inlineCode: mono.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  );
}
