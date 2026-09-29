import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

/// The UMG widgets a game uses when its project picks plain Flutter widgets:
/// built from `package:flutter/widgets.dart` alone, so a game needs
/// no Material and no shadcn_flutter, and they compile for the web. The UMG
/// codegen and the designer preview both use them.
///
/// The look follows a dark neutral palette close to shadcn's, so a menu reads
/// the same whichever library the project picked.
abstract final class LuminaUmgColors {
  static const Color foreground = Color(0xFFFAFAFA);
  static const Color muted = Color(0xFFA1A1AA);
  static const Color surface = Color(0xFF18181B);
  static const Color raised = Color(0xFF27272A);
  static const Color border = Color(0xFF3F3F46);
  static const Color destructive = Color(0xFFDC2626);

  /// Primary buttons: saturated enough for the designer's default white label.
  static const Color primary = Color(0xFF2563EB);
}

/// The five button styles the UMG designer offers.
enum LuminaUmgButtonStyle { primary, secondary, outline, ghost, destructive }

/// A clickable button with hover reporting (UMG `OnClicked` / `OnHovered` /
/// `OnUnhovered`). Without [onPressed] it is disabled.
class LuminaUmgButton extends StatefulWidget {
  const LuminaUmgButton({
    super.key,
    this.style = LuminaUmgButtonStyle.primary,
    this.onPressed,
    this.onHovered,
    required this.child,
  });

  final LuminaUmgButtonStyle style;
  final VoidCallback? onPressed;

  /// `true` when the pointer enters, `false` when it leaves.
  final ValueChanged<bool>? onHovered;
  final Widget child;

  @override
  State<LuminaUmgButton> createState() => _LuminaUmgButtonState();
}

class _LuminaUmgButtonState extends State<LuminaUmgButton> {
  bool _hovering = false;

  void _hover(bool hovering) {
    setState(() => _hovering = hovering);
    widget.onHovered?.call(hovering);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final (Color background, Color foreground, Color? border) = switch (widget.style) {
      LuminaUmgButtonStyle.primary => (LuminaUmgColors.primary, LuminaUmgColors.foreground, null),
      LuminaUmgButtonStyle.secondary => (LuminaUmgColors.raised, LuminaUmgColors.foreground, null),
      LuminaUmgButtonStyle.outline => (const Color(0x00000000), LuminaUmgColors.foreground, LuminaUmgColors.border),
      LuminaUmgButtonStyle.ghost => (const Color(0x00000000), LuminaUmgColors.foreground, null),
      LuminaUmgButtonStyle.destructive => (LuminaUmgColors.destructive, LuminaUmgColors.foreground, null),
    };
    final hoverTint = _hovering && enabled;
    final fill = hoverTint
        ? (background.a == 0 ? LuminaUmgColors.raised : Color.lerp(background, const Color(0xFF000000), 0.12)!)
        : background;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => _hover(true),
      onExit: (_) => _hover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(6),
              border: border == null ? null : Border.all(color: border),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: foreground, fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontal slider: tap or drag anywhere on the track (UMG
/// `OnValueChanged`).
class LuminaUmgSlider extends StatelessWidget {
  const LuminaUmgSlider({super.key, required this.value, this.onChanged, this.min = 0, this.max = 1, this.color});

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
      final span = max - min;
      final t = span == 0 ? 0.0 : ((value - min) / span).clamp(0.0, 1.0);
      final accent = color ?? LuminaUmgColors.foreground;
      void update(double dx) => onChanged?.call(min + (dx / width).clamp(0.0, 1.0) * span);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => update(d.localPosition.dx),
        onHorizontalDragUpdate: (d) => update(d.localPosition.dx),
        child: SizedBox(
          width: width,
          height: 20,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(color: LuminaUmgColors.raised, borderRadius: BorderRadius.circular(2)),
              ),
              Container(
                width: width * t,
                height: 4,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
              ),
              Positioned(
                left: width * t - 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: LuminaUmgColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// A check box with an optional label; tapping either toggles it (UMG
/// `OnCheckStateChanged`).
class LuminaUmgCheckbox extends StatelessWidget {
  const LuminaUmgCheckbox({super.key, required this.value, this.onChanged, this.label});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: value ? LuminaUmgColors.foreground : const Color(0x00000000),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: value ? LuminaUmgColors.foreground : LuminaUmgColors.border),
            ),
            child: value ? const CustomPaint(painter: _CheckPainter()) : null,
          ),
          if (label != null) ...[
            const SizedBox(width: 8),
            DefaultTextStyle.merge(style: const TextStyle(color: LuminaUmgColors.foreground, fontSize: 14), child: label!),
          ],
        ],
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LuminaUmgColors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.72)
      ..lineTo(size.width * 0.78, size.height * 0.3);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => false;
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LuminaUmgColors.muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => false;
}

/// A single-line text input with a placeholder (UMG Editable Text,
/// `OnTextChanged`).
class LuminaUmgTextField extends StatefulWidget {
  const LuminaUmgTextField({super.key, this.initialValue, this.placeholder, this.style, this.onChanged, this.onSubmitted});

  final String? initialValue;
  final String? placeholder;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;

  /// Enter pressed (a widget graph's On Text Committed).
  final ValueChanged<String>? onSubmitted;

  @override
  State<LuminaUmgTextField> createState() => _LuminaUmgTextFieldState();
}

class _LuminaUmgTextFieldState extends State<LuminaUmgTextField> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue ?? '');
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(LuminaUmgTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) _controller.text = widget.initialValue ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // EditableText ignores DefaultTextStyle; inherit it so the game's font applies.
    final style = DefaultTextStyle.of(context)
        .style
        .merge(const TextStyle(color: LuminaUmgColors.foreground, fontSize: 14))
        .merge(widget.style);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focus.requestFocus,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: LuminaUmgColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: LuminaUmgColors.border),
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            if (_controller.text.isEmpty && widget.placeholder != null)
              IgnorePointer(child: Text(widget.placeholder!, style: style.copyWith(color: LuminaUmgColors.muted))),
            EditableText(
              controller: _controller,
              focusNode: _focus,
              style: style,
              cursorColor: LuminaUmgColors.foreground,
              backgroundCursorColor: LuminaUmgColors.muted,
              onSubmitted: widget.onSubmitted,
              onChanged: (text) {
                setState(() {});
                widget.onChanged?.call(text);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A drop-down of string options (UMG Combo Box, `OnSelectionChanged`). The
/// list opens in the nearest [Overlay], which every game app has.
class LuminaUmgComboBox extends StatefulWidget {
  const LuminaUmgComboBox({
    super.key,
    required this.value,
    required this.options,
    this.onChanged,
    this.placeholder,
    this.style,
    this.outline = LuminaUmgTextOutline.defaults,
  });

  final String? value;
  final List<String> options;
  final ValueChanged<String>? onChanged;
  final String? placeholder;

  /// Merged over the default label style (font size, colour, shadow).
  final TextStyle? style;

  /// The outline of the selected label.
  final LuminaUmgTextOutline outline;

  @override
  State<LuminaUmgComboBox> createState() => _LuminaUmgComboBoxState();
}

class _LuminaUmgComboBoxState extends State<LuminaUmgComboBox> {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  double _width = 160;

  void _pick(String option) {
    _portal.hide();
    widget.onChanged?.call(option);
  }

  @override
  Widget build(BuildContext context) {
    final text = const TextStyle(color: LuminaUmgColors.foreground, fontSize: 14).merge(widget.style);
    return LayoutBuilder(builder: (context, constraints) {
      _width = constraints.maxWidth.isFinite ? constraints.maxWidth : 160;
      return CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (context) => Stack(
            children: [
              Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _portal.hide)),
              Positioned(
                left: 0,
                top: 0,
                child: CompositedTransformFollower(
                  link: _link,
                  showWhenUnlinked: false,
                  targetAnchor: Alignment.bottomLeft,
                  offset: const Offset(0, 4),
                  child: Container(
                    width: _width,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: LuminaUmgColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: LuminaUmgColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final option in widget.options)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _pick(option),
                            child: Container(
                              color: option == widget.value ? LuminaUmgColors.raised : null,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Text(option, style: text),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onChanged == null ? null : _portal.toggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: LuminaUmgColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: LuminaUmgColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: LuminaUmgText(
                      widget.value ?? widget.placeholder ?? '',
                      style: widget.value == null ? text.copyWith(color: LuminaUmgColors.muted) : text,
                      outline: widget.value == null ? LuminaUmgTextOutline.defaults : widget.outline,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Drawn, not a glyph: a game's font may not have one.
                  const SizedBox(width: 10, height: 6, child: CustomPaint(painter: _ChevronPainter())),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// A horizontal progress bar; [progress] is clamped to 0..1 (UMG Progress
/// Bar `Percent`).
class LuminaUmgProgressBar extends StatelessWidget {
  const LuminaUmgProgressBar({super.key, required this.progress, this.color, this.trackColor});

  /// Key of the filled part, for tests and tools that measure it.
  static const Key fillKey = ValueKey<String>('lumina_umg_progress_fill');

  final double progress;
  final Color? color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
      final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 8.0;
      return ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Container(
          width: width,
          height: height,
          color: trackColor ?? LuminaUmgColors.raised,
          alignment: Alignment.centerLeft,
          child: Container(key: fillKey, width: width * progress.clamp(0.0, 1.0), color: color ?? LuminaUmgColors.foreground),
        ),
      );
    });
  }
}

/// A filled, rounded panel around one child (UMG Border).
class LuminaUmgBorder extends StatelessWidget {
  const LuminaUmgBorder({super.key, this.color, this.padding = EdgeInsets.zero, this.radius = 6, this.child});

  final Color? color;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: color ?? LuminaUmgColors.surface, borderRadius: BorderRadius.circular(radius)),
      child: child,
    );
  }
}

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
