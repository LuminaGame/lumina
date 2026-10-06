import 'dart:convert';
import 'package:flutter/widgets.dart' show Color;

import 'lumina_asset.dart';

/// Style overrides for a specific UI component in a [LuminaThemeDocument].
class LuminaComponentStyle {
  final int? backgroundColor;
  final int? foregroundColor;
  final int? borderColor;
  final double? borderWidth;
  final double? borderRadius;
  final double? paddingHorizontal;
  final double? paddingVertical;
  final double? fontSize;
  final int? fontWeight;
  final Map<String, dynamic> customProperties;

  const LuminaComponentStyle({
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.paddingHorizontal,
    this.paddingVertical,
    this.fontSize,
    this.fontWeight,
    this.customProperties = const {},
  });

  Color? get bgColor => backgroundColor != null ? Color(backgroundColor!) : null;
  Color? get fgColor => foregroundColor != null ? Color(foregroundColor!) : null;
  Color? get bColor => borderColor != null ? Color(borderColor!) : null;

  LuminaComponentStyle copyWith({
    int? backgroundColor,
    int? foregroundColor,
    int? borderColor,
    double? borderWidth,
    double? borderRadius,
    double? paddingHorizontal,
    double? paddingVertical,
    double? fontSize,
    int? fontWeight,
    Map<String, dynamic>? customProperties,
  }) {
    return LuminaComponentStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      foregroundColor: foregroundColor ?? this.foregroundColor,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      borderRadius: borderRadius ?? this.borderRadius,
      paddingHorizontal: paddingHorizontal ?? this.paddingHorizontal,
      paddingVertical: paddingVertical ?? this.paddingVertical,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      customProperties: customProperties ?? Map.from(this.customProperties),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (backgroundColor != null) 'background_color': backgroundColor,
      if (foregroundColor != null) 'foreground_color': foregroundColor,
      if (borderColor != null) 'border_color': borderColor,
      if (borderWidth != null) 'border_width': borderWidth,
      if (borderRadius != null) 'border_radius': borderRadius,
      if (paddingHorizontal != null) 'padding_horizontal': paddingHorizontal,
      if (paddingVertical != null) 'padding_vertical': paddingVertical,
      if (fontSize != null) 'font_size': fontSize,
      if (fontWeight != null) 'font_weight': fontWeight,
      if (customProperties.isNotEmpty) 'custom_properties': customProperties,
    };
  }

  factory LuminaComponentStyle.fromMap(Map<String, dynamic> map) {
    return LuminaComponentStyle(
      backgroundColor: (map['background_color'] as num?)?.toInt(),
      foregroundColor: (map['foreground_color'] as num?)?.toInt(),
      borderColor: (map['border_color'] as num?)?.toInt(),
      borderWidth: (map['border_width'] as num?)?.toDouble(),
      borderRadius: (map['border_radius'] as num?)?.toDouble(),
      paddingHorizontal: (map['padding_horizontal'] as num?)?.toDouble(),
      paddingVertical: (map['padding_vertical'] as num?)?.toDouble(),
      fontSize: (map['font_size'] as num?)?.toDouble(),
      fontWeight: (map['font_weight'] as num?)?.toInt(),
      customProperties: (map['custom_properties'] as Map<String, dynamic>?) ?? const {},
    );
  }
}

/// A named, custom style that can be assigned to widgets.
class LuminaCustomStyle {
  final String name;
  final String targetComponent;
  final LuminaComponentStyle style;

  const LuminaCustomStyle({
    required this.name,
    required this.targetComponent,
    required this.style,
  });

  LuminaCustomStyle copyWith({
    String? name,
    String? targetComponent,
    LuminaComponentStyle? style,
  }) {
    return LuminaCustomStyle(
      name: name ?? this.name,
      targetComponent: targetComponent ?? this.targetComponent,
      style: style ?? this.style,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'target_component': targetComponent,
    'style': style.toMap(),
  };

  factory LuminaCustomStyle.fromMap(Map<String, dynamic> map) {
    return LuminaCustomStyle(
      name: map['name'] as String? ?? 'CustomStyle',
      targetComponent: map['target_component'] as String? ?? 'button',
      style: LuminaComponentStyle.fromMap((map['style'] as Map<String, dynamic>?) ?? const {}),
    );
  }
}

/// Document representation of a Theme stored in a `.lmas` asset with [AssetType.theme].
class LuminaThemeDocument {
  final String name;
  final String baseTheme;
  final Map<String, int> colors;
  final double radius;
  final String? fontFamily;
  final double baseFontSize;
  final double headlineFontSize;
  final Map<String, LuminaComponentStyle> componentStyles;
  final Map<String, LuminaCustomStyle> customStyles;

  const LuminaThemeDocument({
    this.name = 'DefaultTheme',
    this.baseTheme = 'shadcn_dark',
    this.colors = const {},
    this.radius = 6.0,
    this.fontFamily,
    this.baseFontSize = 14.0,
    this.headlineFontSize = 20.0,
    this.componentStyles = const {},
    this.customStyles = const {},
  });

  Color colorOf(String token, {Color fallback = const Color(0xFF888888)}) {
    final val = colors[token];
    if (val == null) return fallback;
    return Color(val);
  }

  int colorInt(String token, {int fallback = 0xFF888888}) => colors[token] ?? fallback;

  bool hasComponentStyle(String key) => componentStyles.containsKey(key);

  LuminaThemeDocument copyWith({
    String? name,
    String? baseTheme,
    Map<String, int>? colors,
    double? radius,
    String? fontFamily,
    double? baseFontSize,
    double? headlineFontSize,
    Map<String, LuminaComponentStyle>? componentStyles,
    Map<String, LuminaCustomStyle>? customStyles,
  }) {
    return LuminaThemeDocument(
      name: name ?? this.name,
      baseTheme: baseTheme ?? this.baseTheme,
      colors: colors ?? Map.from(this.colors),
      radius: radius ?? this.radius,
      fontFamily: fontFamily ?? this.fontFamily,
      baseFontSize: baseFontSize ?? this.baseFontSize,
      headlineFontSize: headlineFontSize ?? this.headlineFontSize,
      componentStyles: componentStyles ?? Map.from(this.componentStyles),
      customStyles: customStyles ?? Map.from(this.customStyles),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'base_theme': baseTheme,
      'colors': colors,
      'radius': radius,
      if (fontFamily != null) 'font_family': fontFamily,
      'base_font_size': baseFontSize,
      'headline_font_size': headlineFontSize,
      'component_styles': componentStyles.map((k, v) => MapEntry(k, v.toMap())),
      'custom_styles': customStyles.map((k, v) => MapEntry(k, v.toMap())),
    };
  }

  factory LuminaThemeDocument.fromMap(Map<String, dynamic> map) {
    final colorsMap = (map['colors'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ) ??
        {};

    final compMap = (map['component_styles'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, LuminaComponentStyle.fromMap(v as Map<String, dynamic>)),
        ) ??
        {};

    final customMap = (map['custom_styles'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, LuminaCustomStyle.fromMap(v as Map<String, dynamic>)),
        ) ??
        {};

    return LuminaThemeDocument(
      name: map['name'] as String? ?? 'DefaultTheme',
      baseTheme: map['base_theme'] as String? ?? 'shadcn_dark',
      colors: colorsMap,
      radius: (map['radius'] as num?)?.toDouble() ?? 6.0,
      fontFamily: map['font_family'] as String?,
      baseFontSize: (map['base_font_size'] as num?)?.toDouble() ?? 14.0,
      headlineFontSize: (map['headline_font_size'] as num?)?.toDouble() ?? 20.0,
      componentStyles: compMap,
      customStyles: customMap,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory LuminaThemeDocument.fromJson(String source) =>
      LuminaThemeDocument.fromMap(jsonDecode(source) as Map<String, dynamic>);

  /// Creates a default theme matching shadcn dark editor palette.
  factory LuminaThemeDocument.defaultShadcnDark({String name = 'DefaultTheme'}) {
    return LuminaThemeDocument(
      name: name,
      baseTheme: 'shadcn_dark',
      radius: 6.0,
      colors: {
        'background': 0xFF1C1C1C,
        'foreground': 0xFFFAFAFA,
        'card': 0xFF27272A,
        'cardForeground': 0xFFFAFAFA,
        'popover': 0xFF27272A,
        'popoverForeground': 0xFFFAFAFA,
        'primary': 0xFF3B82F6,
        'primaryForeground': 0xFFFFFFFF,
        'secondary': 0xFF3F3F46,
        'secondaryForeground': 0xFFFAFAFA,
        'muted': 0xFF27272A,
        'mutedForeground': 0xFFA1A1AA,
        'accent': 0xFF3F3F46,
        'accentForeground': 0xFFFAFAFA,
        'destructive': 0xFFEF4444,
        'destructiveForeground': 0xFFFFFFFF,
        'border': 0xFF3F3F46,
        'input': 0xFF3F3F46,
        'ring': 0xFF3B82F6,
      },
      componentStyles: {
        'button': const LuminaComponentStyle(
          backgroundColor: 0xFF3B82F6,
          foregroundColor: 0xFFFFFFFF,
          borderRadius: 6.0,
          paddingHorizontal: 16.0,
          paddingVertical: 8.0,
          fontSize: 14.0,
          fontWeight: 600,
        ),
      },
    );
  }

  /// Creates a default theme for game UI.
  factory LuminaThemeDocument.defaultGameTheme({String name = 'GameUITheme'}) {
    return LuminaThemeDocument(
      name: name,
      baseTheme: 'custom',
      radius: 8.0,
      colors: {
        'background': 0xFF0F172A,
        'foreground': 0xFFF8FAFC,
        'card': 0xFF1E293B,
        'cardForeground': 0xFFF8FAFC,
        'popover': 0xFF1E293B,
        'popoverForeground': 0xFFF8FAFC,
        'primary': 0xFF6366F1,
        'primaryForeground': 0xFFFFFFFF,
        'secondary': 0xFF334155,
        'secondaryForeground': 0xFFF8FAFC,
        'muted': 0xFF1E293B,
        'mutedForeground': 0xFF94A3B8,
        'accent': 0xFF38BDF8,
        'accentForeground': 0xFF0F172A,
        'destructive': 0xFFF43F5E,
        'destructiveForeground': 0xFFFFFFFF,
        'border': 0xFF334155,
        'input': 0xFF1E293B,
        'ring': 0xFF6366F1,
      },
      componentStyles: {
        'button': const LuminaComponentStyle(
          backgroundColor: 0xFF6366F1,
          foregroundColor: 0xFFFFFFFF,
          borderRadius: 8.0,
          paddingHorizontal: 16.0,
          paddingVertical: 10.0,
          fontSize: 14.0,
          fontWeight: 600,
        ),
        'card': const LuminaComponentStyle(
          backgroundColor: 0xFF1E293B,
          borderColor: 0xFF334155,
          borderWidth: 1.0,
          borderRadius: 12.0,
          paddingHorizontal: 16.0,
          paddingVertical: 16.0,
        ),
      },
    );
  }

  /// Converts this theme into a [LuminaAsset] for `.lmas` storage.
  LuminaAsset toAsset({String? assetId, String? name}) {
    final assetName = name ?? this.name;
    return LuminaAsset(
      assetId: assetId ?? 'theme_${DateTime.now().millisecondsSinceEpoch}',
      name: assetName,
      type: AssetType.theme,
      rawPayload: utf8.encode(toJson()),
      metadata: {
        'theme_name': assetName,
        'base_theme': baseTheme,
      },
    );
  }

  /// Reads a [LuminaThemeDocument] from a [LuminaAsset].
  factory LuminaThemeDocument.fromAsset(LuminaAsset asset) {
    if (asset.rawPayload != null && asset.rawPayload!.isNotEmpty) {
      final jsonStr = utf8.decode(asset.rawPayload!);
      return LuminaThemeDocument.fromJson(jsonStr);
    }
    return LuminaThemeDocument.defaultShadcnDark(name: asset.name);
  }
}
