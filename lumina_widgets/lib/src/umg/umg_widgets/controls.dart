part of 'package:lumina_widgets/src/umg/umg_widgets.dart';

// Interactive UMG widgets: buttons, slider, check box, text field, combo box.

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

/// A drop-down of option labels (UMG Combo Box). Picking one calls
/// [onChanged] with its label and [onSelected] with its index (labels may
/// repeat; the index does not). The list opens in the nearest [Overlay],
/// which every game app has.
class LuminaUmgComboBox extends StatefulWidget {
  const LuminaUmgComboBox({
    super.key,
    required this.value,
    required this.options,
    this.onChanged,
    this.onSelected,
    this.selectedIndex,
    this.placeholder,
    this.style,
    this.outline = LuminaUmgTextOutline.defaults,
  });

  final String? value;
  final List<String> options;
  final ValueChanged<String>? onChanged;

  /// The index of the picked option.
  final ValueChanged<int>? onSelected;

  /// The selected option's index; null highlights the first option labelled
  /// [value].
  final int? selectedIndex;
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

  void _pick(int index) {
    _portal.hide();
    widget.onChanged?.call(widget.options[index]);
    widget.onSelected?.call(index);
  }

  bool _isSelected(int index) =>
      widget.selectedIndex != null ? widget.selectedIndex == index : (widget.value != null && widget.options.indexOf(widget.value!) == index);

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
                        for (var i = 0; i < widget.options.length; i++)
                          GestureDetector(
                            key: ValueKey('lumina_umg_combo_option_$i'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _pick(i),
                            child: Container(
                              color: _isSelected(i) ? LuminaUmgColors.raised : null,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Text(widget.options[i], style: text),
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
            onTap: widget.onChanged == null && widget.onSelected == null ? null : _portal.toggle,
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
