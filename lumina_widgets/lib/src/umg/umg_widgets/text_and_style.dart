part of 'package:lumina_widgets/src/umg/umg_widgets.dart';

// UMG text with shadow and outline, gradients, the designer style JSON and the container.

/// The drop shadow of a text-bearing UMG element (Shadow Offset / Shadow
/// Color): stored under `shadowEnabled`,
/// `shadowColor` (`#RRGGBBAA`, or the `[r, g, b, a]` the Blueprint nodes
/// write), `shadowOffsetX` / `shadowOffsetY` and `shadowBlur` (design px).
@immutable
class LuminaUmgTextShadow {
  const LuminaUmgTextShadow({
    this.enabled = false,
    this.color = const Color(0xB3000000),
    this.offsetX = 1.0,
    this.offsetY = 1.0,
    this.blur = 0.0,
  });

  /// The designer's defaults: off, 70 % black, (1, 1), sharp.
  static const LuminaUmgTextShadow defaults = LuminaUmgTextShadow();

  final bool enabled;
  final Color color;
  final double offsetX;
  final double offsetY;
  final double blur;

  /// The shadows a [TextStyle] draws: none while disabled or fully transparent.
  List<Shadow> get shadows => enabled && color.a > 0
      ? [Shadow(color: color, offset: Offset(offsetX, offsetY), blurRadius: blur < 0 ? 0 : blur)]
      : const <Shadow>[];

  @override
  bool operator ==(Object other) =>
      other is LuminaUmgTextShadow &&
      other.enabled == enabled &&
      other.color == color &&
      other.offsetX == offsetX &&
      other.offsetY == offsetY &&
      other.blur == blur;

  @override
  int get hashCode => Object.hash(enabled, color, offsetX, offsetY, blur);

  @override
  String toString() => 'LuminaUmgTextShadow(enabled: $enabled, color: $color, offset: ($offsetX, $offsetY), blur: $blur)';
}

/// The outline of a text-bearing UMG element (Font Outline Settings): `outlineSize` in design px (0 = off) and
/// `outlineColor`.
@immutable
class LuminaUmgTextOutline {
  const LuminaUmgTextOutline({this.size = 0.0, this.color = const Color(0xFF000000)});

  /// The designer's defaults: no outline, opaque black.
  static const LuminaUmgTextOutline defaults = LuminaUmgTextOutline();

  final double size;
  final Color color;

  bool get isVisible => size > 0 && color.a > 0;

  /// The stroke painted under the fill: a centred stroke of twice [size]
  /// shows [size] px outside the glyph.
  Paint get strokePaint => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = size * 2
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  /// The outline as eight sharp shadows around the glyphs, for text a second
  /// layer cannot sit under (an editable field).
  List<Shadow> get ringShadows {
    if (!isVisible) return const <Shadow>[];
    const d = 0.7071067811865476;
    return [
      for (final (x, y) in const [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0), (d, d), (-d, d), (d, -d), (-d, -d)])
        Shadow(color: color, offset: Offset(x * size, y * size)),
    ];
  }

  @override
  bool operator ==(Object other) => other is LuminaUmgTextOutline && other.size == size && other.color == color;

  @override
  int get hashCode => Object.hash(size, color);

  @override
  String toString() => 'LuminaUmgTextOutline(size: $size, color: $color)';
}

/// A UMG text with an optional [outline]: Flutter has no text outline, so the
/// outline is a second [Text] painted with a stroke under the fill, laid out
/// identically (same style, lines and overflow) so the glyphs align. The
/// drop shadow of [style] is drawn by the stroked layer, under both.
class LuminaUmgText extends StatelessWidget {
  const LuminaUmgText(
    this.data, {
    super.key,
    this.style,
    this.outline = LuminaUmgTextOutline.defaults,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String data;
  final TextStyle? style;
  final LuminaUmgTextOutline outline;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    if (!outline.isVisible) {
      return Text(data, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign);
    }
    final fill = DefaultTextStyle.of(context).style.merge(style);
    return Stack(
      children: [
        Text(
          data,
          // copyWith drops the fill colour when a foreground paint is given.
          style: fill.copyWith(foreground: outline.strokePaint),
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
        ),
        Text(
          data,
          style: fill.copyWith(shadows: const <Shadow>[]),
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
        ),
      ],
    );
  }
}

/// The background gradient of a UMG Container: Flutter's
/// linear ([begin] → [end]) or radial ([center], [radius]) gradient.
@immutable
class LuminaUmgGradient {
  const LuminaUmgGradient({
    this.type = 'linear',
    required this.colors,
    this.stops,
    this.begin = Alignment.centerLeft,
    this.end = Alignment.centerRight,
    this.center = Alignment.center,
    this.radius = 0.5,
  });

  /// `linear` or `radial`.
  final String type;
  final List<Color> colors;
  final List<double>? stops;
  final Alignment begin;
  final Alignment end;
  final Alignment center;
  final double radius;

  /// The Flutter gradient; null with fewer than two colours.
  Gradient? toGradient() {
    if (colors.length < 2) return null;
    final s = stops != null && stops!.length == colors.length ? stops : null;
    return type == 'radial'
        ? RadialGradient(colors: colors, stops: s, center: center, radius: radius)
        : LinearGradient(colors: colors, stops: s, begin: begin, end: end);
  }

  /// Reads the designer / element JSON: `{type, colors: [hex | [r,g,b,a]],
  /// stops, begin: [x, y], end: [x, y], center: [x, y], radius}`.
  static LuminaUmgGradient? fromJson(Object? v) {
    if (v is! Map) return null;
    final colors = <Color>[
      for (final c in (v['colors'] is List ? v['colors'] as List : const []))
        if (LuminaUmgStyleJson.color(c) case final Color color) color,
    ];
    if (colors.length < 2) return null;
    final stops = v['stops'] is List ? [for (final s in v['stops'] as List) if (s is num) s.toDouble()] : null;
    return LuminaUmgGradient(
      type: v['type'] == 'radial' ? 'radial' : 'linear',
      colors: colors,
      stops: stops,
      begin: LuminaUmgStyleJson.alignment(v['begin']) ?? Alignment.centerLeft,
      end: LuminaUmgStyleJson.alignment(v['end']) ?? Alignment.centerRight,
      center: LuminaUmgStyleJson.alignment(v['center']) ?? Alignment.center,
      radius: v['radius'] is num ? (v['radius'] as num).toDouble() : 0.5,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LuminaUmgGradient &&
      other.type == type &&
      listEquals(other.colors, colors) &&
      listEquals(other.stops, stops) &&
      other.begin == begin &&
      other.end == end &&
      other.center == center &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(type, Object.hashAll(colors), stops == null ? null : Object.hashAll(stops!), begin, end, center, radius);
}

/// JSON-plain readers for the UMG style props (designer values and element
/// state alike).
abstract final class LuminaUmgStyleJson {
  /// `#RRGGBB` / `#RRGGBBAA` or `[r, g, b, a]` (0–1).
  static Color? color(Object? v) {
    if (v is List && v.length >= 3) {
      double c(int i) => i < v.length && v[i] is num ? (v[i] as num).toDouble().clamp(0.0, 1.0) : 1.0;
      return Color.fromARGB((c(3) * 255).round(), (c(0) * 255).round(), (c(1) * 255).round(), (c(2) * 255).round());
    }
    if (v is String) {
      var h = v.trim().replaceAll('#', '');
      if (h.length == 6) h = '${h}FF';
      if (h.length != 8) return null;
      final value = int.tryParse(h, radix: 16);
      return value == null ? null : Color(((value & 0xFF) << 24) | (value >> 8));
    }
    return null;
  }

  static double? number(Object? v) => v is num ? v.toDouble() : null;

  /// A number (all sides) or `[left, top, right, bottom]`.
  static EdgeInsets? edgeInsets(Object? v) {
    if (v is num) return EdgeInsets.all(v.toDouble());
    if (v is List && v.length >= 4 && v.every((e) => e is num)) {
      return EdgeInsets.fromLTRB((v[0] as num).toDouble(), (v[1] as num).toDouble(), (v[2] as num).toDouble(), (v[3] as num).toDouble());
    }
    return null;
  }

  /// A number (every corner) or `[topLeft, topRight, bottomRight, bottomLeft]`.
  static BorderRadius? borderRadius(Object? v) {
    if (v is num) return BorderRadius.circular(v.toDouble());
    if (v is List && v.length >= 4 && v.every((e) => e is num)) {
      Radius r(int i) => Radius.circular((v[i] as num).toDouble());
      return BorderRadius.only(topLeft: r(0), topRight: r(1), bottomRight: r(2), bottomLeft: r(3));
    }
    return null;
  }

  /// `[x, y]` in -1..1, or one of the nine names (`topLeft` … `bottomRight`).
  static Alignment? alignment(Object? v) {
    if (v is List && v.length >= 2 && v[0] is num && v[1] is num) return Alignment((v[0] as num).toDouble(), (v[1] as num).toDouble());
    if (v is String) return alignments[v];
    return null;
  }

  /// The Container's nine child alignments.
  static const Map<String, Alignment> alignments = {
    'topLeft': Alignment.topLeft,
    'topCenter': Alignment.topCenter,
    'topRight': Alignment.topRight,
    'centerLeft': Alignment.centerLeft,
    'center': Alignment.center,
    'centerRight': Alignment.centerRight,
    'bottomLeft': Alignment.bottomLeft,
    'bottomCenter': Alignment.bottomCenter,
    'bottomRight': Alignment.bottomRight,
  };

  /// `[{color, offsetX, offsetY, blur, spread}]`.
  static List<BoxShadow>? boxShadows(Object? v) {
    if (v is! List) return null;
    return [
      for (final s in v)
        if (s is Map)
          BoxShadow(
            color: color(s['color']) ?? const Color(0x66000000),
            offset: Offset(number(s['offsetX']) ?? 0, number(s['offsetY']) ?? 0),
            blurRadius: number(s['blur']) ?? 0,
            spreadRadius: number(s['spread']) ?? 0,
          ),
    ];
  }

  static BoxFit? fit(Object? v) => v is String ? BoxFit.values.where((f) => f.name == v).firstOrNull : null;

  /// The keys of a shortcut label such as `Ctrl+Shift+S` (the shadcn Kbd
  /// component); unknown names are skipped.
  static List<LogicalKeyboardKey> keyboardKeys(String text) {
    const named = <String, LogicalKeyboardKey>{
      'ctrl': LogicalKeyboardKey.control,
      'control': LogicalKeyboardKey.control,
      'shift': LogicalKeyboardKey.shift,
      'alt': LogicalKeyboardKey.alt,
      'option': LogicalKeyboardKey.alt,
      'meta': LogicalKeyboardKey.meta,
      'cmd': LogicalKeyboardKey.meta,
      'super': LogicalKeyboardKey.meta,
      'enter': LogicalKeyboardKey.enter,
      'return': LogicalKeyboardKey.enter,
      'esc': LogicalKeyboardKey.escape,
      'escape': LogicalKeyboardKey.escape,
      'space': LogicalKeyboardKey.space,
      'tab': LogicalKeyboardKey.tab,
      'backspace': LogicalKeyboardKey.backspace,
      'delete': LogicalKeyboardKey.delete,
      'del': LogicalKeyboardKey.delete,
      'up': LogicalKeyboardKey.arrowUp,
      'down': LogicalKeyboardKey.arrowDown,
      'left': LogicalKeyboardKey.arrowLeft,
      'right': LogicalKeyboardKey.arrowRight,
    };
    final keys = <LogicalKeyboardKey>[];
    for (final raw in text.split('+')) {
      final token = raw.trim();
      if (token.isEmpty) continue;
      final key = named[token.toLowerCase()] ??
          LogicalKeyboardKey.knownLogicalKeys.where((k) => k.keyLabel.toLowerCase() == token.toLowerCase()).firstOrNull;
      if (key != null) keys.add(key);
    }
    return keys;
  }
}

/// The look of a UMG Container, Flutter `Container`'s
/// styling: background colour / gradient / image, border (colour, width,
/// sides), corner radius, padding, margin, box shadows, size limits and the
/// child's alignment. The designer stores it as JSON-plain props
/// ([fromProps]); `LuminaUmgElementBinding.containerStyle` lays the
/// Blueprint-written element state over the designer style.
@immutable
class LuminaUmgContainerStyle {
  const LuminaUmgContainerStyle({
    this.backgroundColor = const Color(0x00000000),
    this.gradient,
    this.backgroundFit = BoxFit.cover,
    this.borderColor = const Color(0x00000000),
    this.borderWidth = 0.0,
    this.borderTop = true,
    this.borderRight = true,
    this.borderBottom = true,
    this.borderLeft = true,
    this.cornerRadius = BorderRadius.zero,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.shadows = const <BoxShadow>[],
    this.width,
    this.height,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.alignment,
  });

  final Color backgroundColor;
  final LuminaUmgGradient? gradient;
  final BoxFit backgroundFit;
  final Color borderColor;
  final double borderWidth;
  final bool borderTop;
  final bool borderRight;
  final bool borderBottom;
  final bool borderLeft;
  final BorderRadius cornerRadius;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final List<BoxShadow> shadows;
  final double? width;
  final double? height;
  final double? minWidth;
  final double? maxWidth;
  final double? minHeight;
  final double? maxHeight;

  /// Where the child sits; null lets it fill the padded box.
  final Alignment? alignment;

  /// The style [props] describe (designer props or an element's state), each
  /// missing or unreadable key keeping [fallback]'s value.
  static LuminaUmgContainerStyle fromProps(Map<String, Object?>? props, [LuminaUmgContainerStyle fallback = const LuminaUmgContainerStyle()]) {
    if (props == null) return fallback;
    final sides = props['borderSides'];
    bool side(int i, bool d) => sides is List && sides.length > i && sides[i] is bool ? sides[i] as bool : d;
    double? size(String key, double? d) => props.containsKey(key) ? LuminaUmgStyleJson.number(props[key]) : d;
    return LuminaUmgContainerStyle(
      backgroundColor: LuminaUmgStyleJson.color(props['backgroundColor']) ?? fallback.backgroundColor,
      gradient: props.containsKey('gradient') ? LuminaUmgGradient.fromJson(props['gradient']) : fallback.gradient,
      backgroundFit: LuminaUmgStyleJson.fit(props['backgroundFit']) ?? fallback.backgroundFit,
      borderColor: LuminaUmgStyleJson.color(props['borderColor']) ?? fallback.borderColor,
      borderWidth: LuminaUmgStyleJson.number(props['borderWidth']) ?? fallback.borderWidth,
      borderTop: side(0, fallback.borderTop),
      borderRight: side(1, fallback.borderRight),
      borderBottom: side(2, fallback.borderBottom),
      borderLeft: side(3, fallback.borderLeft),
      cornerRadius: LuminaUmgStyleJson.borderRadius(props['cornerRadius']) ?? fallback.cornerRadius,
      padding: LuminaUmgStyleJson.edgeInsets(props['padding']) ?? fallback.padding,
      margin: LuminaUmgStyleJson.edgeInsets(props['margin']) ?? fallback.margin,
      shadows: LuminaUmgStyleJson.boxShadows(props['shadows']) ?? fallback.shadows,
      width: size('width', fallback.width),
      height: size('height', fallback.height),
      minWidth: size('minWidth', fallback.minWidth),
      maxWidth: size('maxWidth', fallback.maxWidth),
      minHeight: size('minHeight', fallback.minHeight),
      maxHeight: size('maxHeight', fallback.maxHeight),
      alignment: props.containsKey('alignment') ? LuminaUmgStyleJson.alignment(props['alignment']) : fallback.alignment,
    );
  }

  /// The border: each enabled side at [borderWidth] in [borderColor]; null
  /// when nothing shows.
  Border? get border {
    if (borderWidth <= 0 || borderColor.a == 0) return null;
    final s = BorderSide(color: borderColor, width: borderWidth);
    return Border(
      top: borderTop ? s : BorderSide.none,
      right: borderRight ? s : BorderSide.none,
      bottom: borderBottom ? s : BorderSide.none,
      left: borderLeft ? s : BorderSide.none,
    );
  }

  /// A border with differing sides cannot take rounded corners in Flutter.
  bool get _uniformSides => borderTop == borderRight && borderRight == borderBottom && borderBottom == borderLeft;

  /// The `BoxDecoration` a Flutter `Container` paints; [image] is the loaded
  /// background texture, if any.
  BoxDecoration decoration({ImageProvider? image}) => BoxDecoration(
        color: backgroundColor.a == 0 ? null : backgroundColor,
        gradient: gradient?.toGradient(),
        image: image == null ? null : DecorationImage(image: image, fit: backgroundFit),
        border: border,
        borderRadius: cornerRadius == BorderRadius.zero || (border != null && !_uniformSides) ? null : cornerRadius,
        boxShadow: shadows.isEmpty ? null : shadows,
      );

  /// The min/max limits, or null when none is set.
  BoxConstraints? get constraints {
    if (minWidth == null && maxWidth == null && minHeight == null && maxHeight == null) return null;
    return BoxConstraints(
      minWidth: minWidth ?? 0,
      maxWidth: maxWidth ?? double.infinity,
      minHeight: minHeight ?? 0,
      maxHeight: maxHeight ?? double.infinity,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LuminaUmgContainerStyle &&
      other.backgroundColor == backgroundColor &&
      other.gradient == gradient &&
      other.backgroundFit == backgroundFit &&
      other.borderColor == borderColor &&
      other.borderWidth == borderWidth &&
      other.borderTop == borderTop &&
      other.borderRight == borderRight &&
      other.borderBottom == borderBottom &&
      other.borderLeft == borderLeft &&
      other.cornerRadius == cornerRadius &&
      other.padding == padding &&
      other.margin == margin &&
      listEquals(other.shadows, shadows) &&
      other.width == width &&
      other.height == height &&
      other.minWidth == minWidth &&
      other.maxWidth == maxWidth &&
      other.minHeight == minHeight &&
      other.maxHeight == maxHeight &&
      other.alignment == alignment;

  @override
  int get hashCode => Object.hashAll([
        backgroundColor, gradient, backgroundFit, borderColor, borderWidth, borderTop, borderRight, borderBottom, borderLeft,
        cornerRadius, padding, margin, Object.hashAll(shadows), width, height, minWidth, maxWidth, minHeight, maxHeight, alignment,
      ]);
}

/// A UMG Container: a Flutter [Container] painting
/// [style] (with the loaded background [image]) around one [child]. The
/// designer, the PIE view and the generated widget all build this, so the
/// styling is identical everywhere and whichever widget library the game
/// uses.
class LuminaUmgContainer extends StatelessWidget {
  const LuminaUmgContainer({super.key, this.style = const LuminaUmgContainerStyle(), this.image, this.child});

  final LuminaUmgContainerStyle style;
  final ImageProvider? image;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: style.width,
      height: style.height,
      constraints: style.constraints,
      margin: style.margin == EdgeInsets.zero ? null : style.margin,
      padding: style.padding == EdgeInsets.zero ? null : style.padding,
      alignment: style.alignment,
      decoration: style.decoration(image: image),
      clipBehavior: style.cornerRadius == BorderRadius.zero ? Clip.none : Clip.antiAlias,
      child: child,
    );
  }
}
