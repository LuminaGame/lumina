import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'dart:ui' show Brightness, Color;

/// One colour slot of the editor theme: its JSON key, the group the
/// Appearance page files it under, and a line saying what it paints.
@immutable
class EditorThemeToken {
  const EditorThemeToken(this.key, this.group, this.description);

  final String key;
  final String group;
  final String description;
}

/// An editor theme — every colour the editor paints, plus
/// its corner radius, density and fonts — as a JSON document the user can
/// switch, edit, import and export:
///
/// ```json
/// {
///   "name": "Lumina Dark",
///   "version": 1,
///   "brightness": "dark",
///   "colors": { "background": "#1C1C1C", "border": "#FFFFFF1F", … },
///   "radius": 0.1875,
///   "density": 1.0,
///   "font": { "sans": "GeistSans", "mono": "JetBrains Mono" }
/// }
/// ```
///
/// Colours are CSS hex, `#RRGGBB` or `#RRGGBBAA`. A token that is missing
/// takes the default theme's value; one that does not parse does too, and is
/// reported in [warnings] so the Appearance page can say which.
@immutable
class EditorThemeData {
  const EditorThemeData({
    required this.name,
    required this.brightness,
    required this.colors,
    this.radius = defaultRadius,
    this.density = 1.0,
    this.sansFamily = defaultSans,
    this.monoFamily = defaultMono,
    this.warnings = const [],
  });

  static const int version = 1;
  static const double defaultRadius = 0.1875;
  static const String defaultSans = 'GeistSans';
  static const String defaultMono = 'JetBrains Mono';

  /// The fonts the editor bundles (shadcn_flutter's Geist family and
  /// JetBrains Mono under `assets/fonts/`); a theme may pick among these.
  static const List<String> sansFamilies = ['GeistSans', 'JetBrains Mono'];
  static const List<String> monoFamilies = ['JetBrains Mono', 'GeistMono'];

  /// Density is shadcn_flutter's `ThemeData.scaling`: < 1 is compact.
  static const double minDensity = 0.75;
  static const double maxDensity = 1.25;
  static const double minRadius = 0;
  static const double maxRadius = 1.5;

  final String name;
  final Brightness brightness;

  /// Every token in [tokens], always complete.
  final Map<String, Color> colors;
  final double radius;
  final double density;
  final String sansFamily;
  final String monoFamily;

  /// What was wrong with the JSON this came from (a colour that did not
  /// parse, an out-of-range radius, …) and which default replaced it.
  final List<String> warnings;

  Color color(String token) => colors[token] ?? luminaDark.colors[token]!;

  // --- tokens ----------------------------------------------------------------

  static const String surfaces = 'Surfaces';
  static const String text = 'Text';
  static const String accents = 'Accents';
  static const String status = 'Status';
  static const String graph = 'Graph pins';
  static const String charts = 'Charts';
  static const String assetTypes = 'Asset types';
  static const List<String> groups = [surfaces, text, accents, status, graph, charts, assetTypes];

  /// The theme's colour slots, in the order they are written.
  static const List<EditorThemeToken> tokens = [
    EditorThemeToken('background', surfaces, 'The window and most panel bodies'),
    EditorThemeToken('sidebar', surfaces, 'Tab strips'),
    EditorThemeToken('card', surfaces, 'Cards, Details sections, asset tiles'),
    EditorThemeToken('cardHeader', surfaces, 'Menu bar, toolbar, panel headers'),
    EditorThemeToken('cardHeaderHover', surfaces, 'A header under the pointer'),
    EditorThemeToken('rail', surfaces, 'Filter strips, sources column, toolbars'),
    EditorThemeToken('popover', surfaces, 'Menus and popovers'),
    EditorThemeToken('muted', surfaces, 'Muted fills'),
    EditorThemeToken('secondary', surfaces, 'Secondary button faces'),
    EditorThemeToken('viewportBackdrop', surfaces, 'Behind the 3D viewport'),
    EditorThemeToken('hudSurface', surfaces, 'Viewport HUD chips'),
    EditorThemeToken('hudSurfaceStrong', surfaces, 'Viewport HUD chips over bright renders'),
    EditorThemeToken('scrollbar', surfaces, 'Scrollbar thumb'),
    EditorThemeToken('border', surfaces, 'Borders (translucent)'),
    EditorThemeToken('input', surfaces, 'Input outlines (translucent)'),
    EditorThemeToken('borderSolid', surfaces, 'Borders where nothing blends'),
    EditorThemeToken('rowHover', surfaces, 'A row under the pointer'),
    EditorThemeToken('placeholderFill', surfaces, 'Empty image slots'),
    EditorThemeToken('foreground', text, 'Text'),
    EditorThemeToken('secondaryForeground', text, 'Text on secondary faces'),
    EditorThemeToken('mutedForeground', text, 'Labels, units, inactive tabs'),
    EditorThemeToken('primaryForeground', text, 'Text on the primary colour'),
    EditorThemeToken('accentForeground', text, 'Text on the accent colour'),
    EditorThemeToken('primary', accents, 'Lumina orange: selection, active tabs'),
    EditorThemeToken('accent', accents, 'The second accent'),
    EditorThemeToken('selectionBg', accents, 'A selected row'),
    EditorThemeToken('destructive', status, 'Errors, delete, close hover'),
    EditorThemeToken('warning', status, 'Warnings, modified state'),
    EditorThemeToken('logInfo', status, 'Output Log info'),
    EditorThemeToken('logWarning', status, 'Output Log warning'),
    EditorThemeToken('logError', status, 'Output Log error'),
    EditorThemeToken('logSuccess', status, 'Output Log success'),
    EditorThemeToken('graphCanvas', graph, 'Blueprint / Anim Graph canvas'),
    EditorThemeToken('pinExec', graph, 'Blueprint pin: exec'),
    EditorThemeToken('pinBoolean', graph, 'Blueprint pin: boolean'),
    EditorThemeToken('pinInteger', graph, 'Blueprint pin: integer'),
    EditorThemeToken('pinFloat', graph, 'Blueprint pin: float'),
    EditorThemeToken('pinString', graph, 'Blueprint pin: string'),
    EditorThemeToken('pinName', graph, 'Blueprint pin: name'),
    EditorThemeToken('pinVector', graph, 'Blueprint pin: vector'),
    EditorThemeToken('pinVector2D', graph, 'Blueprint pin: Vector2D'),
    EditorThemeToken('pinRotator', graph, 'Blueprint pin: rotator'),
    EditorThemeToken('pinObject', graph, 'Blueprint pin: object'),
    EditorThemeToken('pinTransform', graph, 'Blueprint pin: transform'),
    EditorThemeToken('pinStruct', graph, 'Blueprint pin: struct / enum byte'),
    EditorThemeToken('pinColor', graph, 'Blueprint pin: colour'),
    EditorThemeToken('pinArray', graph, 'Blueprint pin: array'),
    EditorThemeToken('pinHitResult', graph, 'Blueprint pin: hit result'),
    EditorThemeToken('pinWildcard', graph, 'Blueprint pin: wildcard'),
    EditorThemeToken('pinEnum', graph, 'Blueprint pin: enumeration'),
    EditorThemeToken('pinDelegate', graph, 'Blueprint pin: delegate'),
    EditorThemeToken('pinTimerHandle', graph, 'Blueprint pin: timer handle'),
    EditorThemeToken('pinUnknown', graph, 'Blueprint pin: unresolved type'),
    EditorThemeToken('materialPinFloat1', graph, 'Material pin: float'),
    EditorThemeToken('materialPinFloat2', graph, 'Material pin: float2'),
    EditorThemeToken('materialPinFloat3', graph, 'Material pin: float3'),
    EditorThemeToken('materialPinFloat4', graph, 'Material pin: float4'),
    EditorThemeToken('materialPinTexture', graph, 'Material pin: texture'),
    EditorThemeToken('materialPinUnknown', graph, 'Material pin: unresolved'),
    EditorThemeToken('blendSpaceLabel', graph, 'Blend Space references'),
    EditorThemeToken('chart1', charts, 'Chart 1'),
    EditorThemeToken('chart2', charts, 'Chart 2'),
    EditorThemeToken('chart3', charts, 'Chart 3'),
    EditorThemeToken('chart4', charts, 'Chart 4'),
    EditorThemeToken('chart5', charts, 'Chart 5'),
    EditorThemeToken('assetTypeAnimation', assetTypes, 'Asset type strip: Animation Sequence'),
    EditorThemeToken('assetTypeSkeletalMesh', assetTypes, 'Asset type strip: Skeletal Mesh'),
    EditorThemeToken('assetTypeStaticMesh', assetTypes, 'Asset type strip: Static Mesh'),
    EditorThemeToken('assetTypeMaterial', assetTypes, 'Asset type strip: Material'),
    EditorThemeToken('assetTypeBlueprint', assetTypes, 'Asset type strip: Blueprint Class'),
    EditorThemeToken('assetTypeAnimBlueprint', assetTypes, 'Asset type strip: Animation Blueprint'),
    EditorThemeToken('assetTypeBlendSpace', assetTypes, 'Asset type strip: Blend Space'),
    EditorThemeToken('assetTypePhysicsAsset', assetTypes, 'Asset type strip: Physics Asset'),
    EditorThemeToken('assetTypeLevel', assetTypes, 'Asset type strip: Level'),
    EditorThemeToken('assetTypeTexture', assetTypes, 'Asset type strip: Texture'),
    EditorThemeToken('assetTypeAudio', assetTypes, 'Asset type strip: Sound'),
    EditorThemeToken('assetTypeWidget', assetTypes, 'Asset type strip: Widget Blueprint'),
    EditorThemeToken('assetTypeParticle', assetTypes, 'Asset type strip: Particle System'),
    EditorThemeToken('assetTypeLandscape', assetTypes, 'Asset type strip: Landscape'),
    EditorThemeToken('assetTypeSequencer', assetTypes, 'Asset type strip: Level Sequence'),
  ];

  static final Set<String> tokenKeys = {for (final t in tokens) t.key};

  // --- built-ins -------------------------------------------------------------

  /// The lifted grey ramp — the default.
  static final EditorThemeData luminaDark = EditorThemeData(
    name: 'Lumina Dark',
    brightness: Brightness.dark,
    colors: _hex(const {
      'background': 0xFF1C1C1C,
      'sidebar': 0xFF252525,
      'card': 0xFF373737,
      'cardHeader': 0xFF2E2E2E,
      'cardHeaderHover': 0xFF353535,
      'rail': 0xFF131313,
      'popover': 0xFF414141,
      'muted': 0xFF414141,
      'secondary': 0xFF4A4A4A,
      'viewportBackdrop': 0xFF0E0E0E,
      'hudSurface': 0xCC1C1C1C,
      'hudSurfaceStrong': 0xEE1C1C1C,
      'scrollbar': 0xFF5E5E5E,
      'border': 0x1FFFFFFF,
      'input': 0x26FFFFFF,
      'borderSolid': 0xFF383838,
      'rowHover': 0x0AFFFFFF,
      'placeholderFill': 0x11FFFFFF,
      'foreground': 0xFFD6D6D6,
      'secondaryForeground': 0xFFC4C4C4,
      'mutedForeground': 0xFFAEAEAE,
      'primaryForeground': 0xFF030303,
      'accentForeground': 0xFFF2F2F2,
      'primary': 0xFFFB7C01,
      'accent': 0xFF0099C8,
      'selectionBg': 0x33FB7C01,
      'destructive': 0xFFEE3533,
      'warning': 0xFFFBBF24,
      'logInfo': 0xFF0099C8,
      'logWarning': 0xFFFBBF24,
      'logError': 0xFFEE3533,
      'logSuccess': 0xFF58A547,
      'graphCanvas': 0xFF16171A,
      'pinExec': 0xFFFFFFFF,
      'pinBoolean': 0xFFEE3533,
      'pinInteger': 0xFF43A047,
      'pinFloat': 0xFF58A547,
      'pinString': 0xFFFF5252,
      'pinName': 0xFFF48FB1,
      'pinVector': 0xFF8688FE,
      'pinVector2D': 0xFF1DE9B6,
      'pinRotator': 0xFFB39DDB,
      'pinObject': 0xFF0099C8,
      'pinTransform': 0xFF26C6DA,
      'pinStruct': 0xFFFBBF24,
      'pinColor': 0xFF1E88E5,
      'pinArray': 0xFF0099C8,
      'pinHitResult': 0xFF26C6DA,
      'pinWildcard': 0xFF9E9E9E,
      'pinEnum': 0xFF2E7D32,
      'pinDelegate': 0xFFE53935,
      'pinTimerHandle': 0xFF26C6DA,
      'pinUnknown': 0xFFEE3533,
      'materialPinFloat1': 0xFFB0BEC5,
      'materialPinFloat2': 0xFF4DB6AC,
      'materialPinFloat3': 0xFFFFD54F,
      'materialPinFloat4': 0xFFF06292,
      'materialPinTexture': 0xFFBA68C8,
      'materialPinUnknown': 0xFF78909C,
      'blendSpaceLabel': 0xFFC084FC,
      'chart1': 0xFFFB7C01,
      'chart2': 0xFF0099C8,
      'chart3': 0xFF58A547,
      'chart4': 0xFF8688FE,
      'chart5': 0xFFEE3533,
      'assetTypeAnimation': 0xFF3FA33A,
      'assetTypeSkeletalMesh': 0xFFE040E0,
      'assetTypeStaticMesh': 0xFF00C8C8,
      'assetTypeMaterial': 0xFF8BD867,
      'assetTypeBlueprint': 0xFF3F7EFF,
      'assetTypeAnimBlueprint': 0xFFF05A28,
      'assetTypeBlendSpace': 0xFFF5B324,
      'assetTypePhysicsAsset': 0xFFFFC08A,
      'assetTypeLevel': 0xFFFF9C00,
      'assetTypeTexture': 0xFFD64545,
      'assetTypeAudio': 0xFF7C93B0,
      'assetTypeWidget': 0xFF2C59B4,
      'assetTypeParticle': 0xFFB06CFF,
      'assetTypeLandscape': 0xFFB08D57,
      'assetTypeSequencer': 0xFFE0607E,
    }),
  );

  /// The Figma Make prototype's near-black palette, as the
  /// editor looked before the lifted grey ramp.
  static final EditorThemeData luminaClassic = EditorThemeData(
    name: 'Lumina Classic',
    brightness: Brightness.dark,
    colors: {
      ...luminaDark.colors,
      ..._hex(const {
        'background': 0xFF020202,
        'sidebar': 0xFF050505,
        'card': 0xFF070707,
        'cardHeader': 0xFF040404,
        'cardHeaderHover': 0xFF060606,
        'rail': 0xFF030303,
        'popover': 0xFF0C0C0C,
        'muted': 0xFF0C0C0C,
        'secondary': 0xFF121212,
        'viewportBackdrop': 0xFF0C0C0C,
        'hudSurface': 0xCC0C0C0C,
        'hudSurfaceStrong': 0xEE0C0C0C,
        'scrollbar': 0xFF292929,
        'border': 0x17FFFFFF,
        'input': 0x1CFFFFFF,
        'borderSolid': 0xFF1C1C1C,
        'secondaryForeground': 0xFFB7B7B7,
        'mutedForeground': 0xFF696969,
      }),
    },
  );

  /// A light counterpart: the same accents on a hueless light ramp.
  static final EditorThemeData luminaLight = EditorThemeData(
    name: 'Lumina Light',
    brightness: Brightness.light,
    colors: {
      ...luminaDark.colors,
      ..._hex(const {
        'background': 0xFFF4F4F4,
        'sidebar': 0xFFE6E6E6,
        'card': 0xFFFFFFFF,
        'cardHeader': 0xFFEBEBEB,
        'cardHeaderHover': 0xFFE0E0E0,
        'rail': 0xFFDADADA,
        'popover': 0xFFFFFFFF,
        'muted': 0xFFEFEFEF,
        'secondary': 0xFFE2E2E2,
        'viewportBackdrop': 0xFF2A2A2A,
        'hudSurface': 0xCCF4F4F4,
        'hudSurfaceStrong': 0xEEF4F4F4,
        'scrollbar': 0xFFB5B5B5,
        'border': 0x24000000,
        'input': 0x2E000000,
        'borderSolid': 0xFFD0D0D0,
        'rowHover': 0x0D000000,
        'placeholderFill': 0x14000000,
        'foreground': 0xFF1F1F1F,
        'secondaryForeground': 0xFF2E2E2E,
        'mutedForeground': 0xFF5C5C5C,
        'primaryForeground': 0xFF111111,
        // shadcn menus draw their item text in accentForeground, so on a
        // light theme it must be dark (it still reads on the cyan accent).
        'accentForeground': 0xFF141414,
        'primary': 0xFFE06E00,
        'selectionBg': 0x33E06E00,
        'warning': 0xFFB45309,
        'logWarning': 0xFFB45309,
        'graphCanvas': 0xFFE9EAEC,
        'pinExec': 0xFF3A3A3A,
        'chart1': 0xFFE06E00,
        // Asset-type strips: darker and more saturated,
        // so a 3 px line still reads on a white tile.
        'assetTypeAnimation': 0xFF2A7A26,
        'assetTypeSkeletalMesh': 0xFFBE1FBE,
        'assetTypeStaticMesh': 0xFF00989B,
        'assetTypeMaterial': 0xFF62B043,
        'assetTypeBlueprint': 0xFF2A62DB,
        'assetTypeAnimBlueprint': 0xFFD04515,
        'assetTypeBlendSpace': 0xFFD08E0A,
        'assetTypePhysicsAsset': 0xFFE39A62,
        'assetTypeLevel': 0xFFD97A00,
        'assetTypeTexture': 0xFFB52F2F,
        'assetTypeAudio': 0xFF566D8C,
        'assetTypeWidget': 0xFF1F4596,
        'assetTypeParticle': 0xFF8445DB,
        'assetTypeLandscape': 0xFF8A6A36,
        'assetTypeSequencer': 0xFFC23F5E,
      }),
    },
  );

  static final List<EditorThemeData> builtIns = [luminaDark, luminaClassic, luminaLight];

  static bool isBuiltInName(String name) => builtIns.any((t) => t.name == name);

  // --- JSON ------------------------------------------------------------------

  static String formatColor(Color c) {
    final argb = c.toARGB32();
    final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
    final a = argb >>> 24;
    return a == 0xFF ? '#$rgb' : '#$rgb${a.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  /// `#RRGGBB` / `#RRGGBBAA` (CSS order), or null.
  static Color? parseColor(Object? value) {
    if (value is! String) return null;
    final m = RegExp(r'^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$').firstMatch(value.trim());
    if (m == null) return null;
    final rgb = int.parse(m.group(1)!, radix: 16);
    final a = m.group(2) == null ? 0xFF : int.parse(m.group(2)!, radix: 16);
    return Color((a << 24) | rgb);
  }

  Map<String, Object> toJson() => {
        'name': name,
        'version': version,
        'brightness': brightness.name,
        'colors': {for (final t in tokens) t.key: formatColor(color(t.key))},
        'radius': radius,
        'density': density,
        'font': {'sans': sansFamily, 'mono': monoFamily},
      };

  /// The canonical text of this theme: two-space indent, tokens in [tokens]
  /// order, a trailing newline. Parsing it and encoding again gives the same
  /// bytes.
  String encode() => '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';

  /// Reads a theme; every invalid or missing value falls back to [fallback]
  /// (Lumina Dark by default), invalid ones with a warning.
  static EditorThemeData fromJson(Object? json, {EditorThemeData? fallback, String? fallbackName}) {
    final base = fallback ?? luminaDark;
    final warnings = <String>[];
    if (json is! Map) {
      return base.copyWith(name: fallbackName ?? base.name, warnings: ['the theme is not a JSON object; using ${base.name}']);
    }
    final rawName = json['name'];
    final name = rawName is String && rawName.trim().isNotEmpty ? rawName.trim() : (fallbackName ?? 'Untitled Theme');
    if (rawName is! String || rawName.trim().isEmpty) warnings.add('name is missing; using "$name"');
    final v = json['version'];
    if (v is int && v > version) warnings.add('version $v is newer than this editor ($version); unknown fields are ignored');
    final brightness = switch (json['brightness']) {
      'light' => Brightness.light,
      'dark' => Brightness.dark,
      null => base.brightness,
      final other => () {
          warnings.add('brightness "$other" is neither "dark" nor "light"; using ${base.brightness.name}');
          return base.brightness;
        }(),
    };
    final colors = <String, Color>{};
    final rawColors = json['colors'];
    for (final t in tokens) {
      final raw = rawColors is Map ? rawColors[t.key] : null;
      if (raw == null) {
        colors[t.key] = base.color(t.key);
        continue;
      }
      final parsed = parseColor(raw);
      if (parsed == null) {
        colors[t.key] = base.color(t.key);
        warnings.add('colors.${t.key}: "$raw" is not a colour (#RRGGBB or #RRGGBBAA); using ${formatColor(base.color(t.key))}');
      } else {
        colors[t.key] = parsed;
      }
    }
    if (rawColors is Map) {
      for (final k in rawColors.keys) {
        if (!tokenKeys.contains(k)) warnings.add('colors.$k is not a theme token; ignored');
      }
    }
    double number(String key, double def, double min, double max) {
      final raw = json[key];
      if (raw == null) return def;
      if (raw is num && raw >= min && raw <= max) return raw.toDouble();
      warnings.add('$key: $raw is not a number between $min and $max; using $def');
      return def;
    }

    final font = json['font'];
    String family(String key, String def, List<String> allowed) {
      final raw = font is Map ? font[key] : null;
      if (raw == null) return def;
      if (raw is String && allowed.contains(raw)) return raw;
      warnings.add('font.$key: "$raw" is not a bundled font (${allowed.join(', ')}); using $def');
      return def;
    }

    return EditorThemeData(
      name: name,
      brightness: brightness,
      colors: colors,
      radius: number('radius', base.radius, minRadius, maxRadius),
      density: number('density', base.density, minDensity, maxDensity),
      sansFamily: family('sans', base.sansFamily, sansFamilies),
      monoFamily: family('mono', base.monoFamily, monoFamilies),
      warnings: List.unmodifiable(warnings),
    );
  }

  /// Parses [source]; text that is not JSON gives the fallback with a warning.
  static EditorThemeData decode(String source, {EditorThemeData? fallback, String? fallbackName}) {
    Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException catch (e) {
      final base = fallback ?? luminaDark;
      return base.copyWith(name: fallbackName ?? base.name, warnings: ['not valid JSON (${e.message}); using ${base.name}']);
    }
    return fromJson(json, fallback: fallback, fallbackName: fallbackName);
  }

  EditorThemeData copyWith({
    String? name,
    Brightness? brightness,
    Map<String, Color>? colors,
    double? radius,
    double? density,
    String? sansFamily,
    String? monoFamily,
    List<String>? warnings,
  }) =>
      EditorThemeData(
        name: name ?? this.name,
        brightness: brightness ?? this.brightness,
        colors: colors ?? this.colors,
        radius: radius ?? this.radius,
        density: density ?? this.density,
        sansFamily: sansFamily ?? this.sansFamily,
        monoFamily: monoFamily ?? this.monoFamily,
        warnings: warnings ?? const [],
      );

  /// This theme with [token] set to [value].
  EditorThemeData withColor(String token, Color value) => copyWith(colors: {...colors, token: value});

  @override
  bool operator ==(Object other) => other is EditorThemeData && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;

  static Map<String, Color> _hex(Map<String, int> values) => {for (final e in values.entries) e.key: Color(e.value)};
}
