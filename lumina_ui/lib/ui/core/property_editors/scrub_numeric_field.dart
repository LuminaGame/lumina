import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

class ScrubNumericField extends StatefulWidget {
  final bool isMixed;
  final double value;
  final double defaultValue;
  final String? unit;
  final String label;
  final double? min;
  final double? max;
  final int fractionDigits;

  /// Width of the label column. The default fits a single-letter axis label
  /// (`X`/`Y`/`Z`); panels with worded labels ("Position X") pass their own.
  final double labelWidth;

  /// The colour of the label column. The design prototype paints a vector
  /// field's `X`/`Y`/`Z` in the transform axis colours, so a caller that knows
  /// it is editing an axis passes them; everything else keeps the muted
  /// foreground it shares with the other property labels.
  final Color labelColor;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onCommit;
  final VoidCallback onReset;

  /// When set, a scrub reports how far it has moved the value since the
  /// gesture began (live, then once more with `end: true` on release) instead
  /// of absolute values through [onChanged] / [onCommit]. The Details
  /// multi-select rows add it to each actor's own value (a scrub
  /// is relative), so a mixed field is never seeded from one actor.
  /// Typed entry still reaches [onCommit].
  final void Function(double delta, bool end)? onScrubDelta;
  final Key? textFieldKey;
  final String? initialValue;

  const ScrubNumericField({
    this.isMixed = false,
    super.key,
    required this.value,
    required this.defaultValue,
    required this.label,
    required this.onChanged,
    required this.onCommit,
    required this.onReset,
    this.unit,
    this.min,
    this.max,
    this.fractionDigits = 2,
    this.labelWidth = 12,
    this.labelColor = EditorColors.mutedForeground,
    this.onScrubDelta,
    this.textFieldKey,
    this.initialValue,
  });

  @override
  State<ScrubNumericField> createState() => _ScrubNumericFieldState();

  /// [full] (the field's text for [value]) as the field shows it in
  /// [maxWidth]: whole when it fits, else with fewer decimals, else in
  /// thousands / millions (`12.8k`, `-1.3M`), else the shortest of those.
  static String fitValueText(
    String full,
    double value, {
    required int fractionDigits,
    required String? unit,
    required double maxWidth,
    required TextStyle style,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    String withUnit(String s) => unit != null ? '$s $unit' : s;
    final candidates = <String>[
      full,
      for (var d = fractionDigits - 1; d >= 0; d--) withUnit(value.toStringAsFixed(d)),
      if (value.abs() >= 1e6) ...[
        withUnit('${(value / 1e6).toStringAsFixed(1)}M'),
        withUnit('${(value / 1e6).toStringAsFixed(0)}M'),
      ] else if (value.abs() >= 1e3) ...[
        withUnit('${(value / 1e3).toStringAsFixed(1)}k'),
        withUnit('${(value / 1e3).toStringAsFixed(0)}k'),
      ],
    ];
    var shortest = full;
    for (final c in candidates) {
      final painter = TextPainter(
        text: TextSpan(text: c, style: style),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      if (w <= maxWidth) return c;
      if (c.length < shortest.length) shortest = c;
    }
    return shortest;
  }
}

/// The field's controller: [text] is always the whole value (what editing,
/// committing and tests read); while [display] is set the field draws that
/// shortened text instead.
class _FittingTextController extends TextEditingController {
  _FittingTextController({super.text});

  String? display;

  /// A new text (typed, scrubbed, committed) shows whole until the field
  /// lays out again and decides whether it fits.
  @override
  set value(TextEditingValue newValue) {
    if (newValue.text != text) display = null;
    super.value = newValue;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final d = display;
    if (d != null) return TextSpan(text: d, style: style);
    return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
  }
}

class _ScrubNumericFieldState extends State<ScrubNumericField> {
  late _FittingTextController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isDragging = false;
  double _dragValue = 0;

  /// Where the current scrub started, and whether it has moved yet.
  double _dragStart = 0;
  bool _scrubMoved = false;

  /// The text the field showed when it took focus. Losing focus commits only
  /// what was typed since, so a click in and out writes nothing.
  String? _textAtFocus;

  @override
  void initState() {
    super.initState();
    _controller = _FittingTextController(text: widget.isMixed ? '—' : _format(widget.value));
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(ScrubNumericField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.value != widget.value || oldWidget.isMixed != widget.isMixed) && !_focusNode.hasFocus && !_isDragging) {
      _controller.text = widget.isMixed ? '—' : _format(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Editing shows the whole value; leaving the field may shorten it again.
    if (mounted) setState(() {});
    if (!_focusNode.hasFocus) {
      if (_controller.text != _textAtFocus) {
        _commitText(_controller.text);
      } else {
        // Nothing typed: show the value (with its unit, or the dash) again.
        _controller.text = widget.isMixed ? '—' : _format(widget.value);
      }
    } else {
      // Remove unit when editing
      _controller.text = widget.isMixed ? '' : widget.value.toStringAsFixed(widget.fractionDigits);
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
      _textAtFocus = _controller.text;
    }
  }

  void _commitText(String text) {
    final parsed = double.tryParse(text);
    if (parsed != null) {
      final clamped = _clamp(parsed);
      widget.onCommit(clamped);
      _controller.text = _format(clamped);
    } else {
      _controller.text = widget.isMixed ? '—' : _format(widget.value);
    }
  }

  double _clamp(double val) {
    if (widget.min != null && val < widget.min!) return widget.min!;
    if (widget.max != null && val > widget.max!) return widget.max!;
    return val;
  }

  String _format(double val) {
    final str = val.toStringAsFixed(widget.fractionDigits);
    return widget.unit != null ? '$str ${widget.unit}' : str;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    bool isShift = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) || 
                   HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);
    bool isCtrl = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft) || 
                  HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlRight);
    
    double sensitivity = 0.5;
    if (isShift) sensitivity = 0.05;
    if (isCtrl) sensitivity = 5.0;

    _dragValue += details.delta.dx * sensitivity;
    if (widget.onScrubDelta != null) {
      _scrubMoved = true;
      _controller.text = _format(_dragValue);
      widget.onScrubDelta!(_dragValue - _dragStart, false);
      return;
    }
    final clamped = _clamp(_dragValue);
    _controller.text = _format(clamped);
    widget.onChanged(clamped);
  }

  void _endScrub() {
    _isDragging = false;
    if (widget.onScrubDelta != null) {
      if (_scrubMoved) widget.onScrubDelta!(_dragValue - _dragStart, true);
      return;
    }
    widget.onCommit(_clamp(_dragValue));
  }

  @override
  Widget build(BuildContext context) {
    final bool isModified = (widget.value - widget.defaultValue).abs() > 0.001;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
          decoration: BoxDecoration(
            color: widget.labelColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontFamily: EditorTypography.monoFamily,
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: widget.labelColor,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              onHorizontalDragStart: (details) {
                _focusNode.unfocus();
                _isDragging = true;
                // A mixed field has no one value to scrub from: it scrubs an
                // offset from an empty baseline.
                _dragStart = widget.isMixed && widget.onScrubDelta != null ? 0.0 : widget.value;
                _dragValue = _dragStart;
                _scrubMoved = false;
              },
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: (details) => _endScrub(),
              // Flutter also cancels a pointer that never became a drag, such
              // as the click that focuses the field: only a scrub that started
              // has a value to commit.
              onHorizontalDragCancel: () {
                if (_isDragging) _endScrub();
              },
              child: LayoutBuilder(builder: (context, constraints) {
                // A value wider than the field is shown shortened (fewer
                // decimals, then `12.8k`) while the field is not being
                // edited; the tooltip and the editing text keep it whole.
                final full = _controller.text;
                final shown = _focusNode.hasFocus || widget.isMixed || _isDragging
                    ? full
                    : ScrubNumericField.fitValueText(
                        full,
                        widget.value,
                        fractionDigits: widget.fractionDigits,
                        unit: widget.unit,
                        maxWidth: constraints.maxWidth - 2 * _textPadding - _textFieldChrome,
                        style: _effectiveValueStyle(context),
                        textScaler: MediaQuery.textScalerOf(context),
                      );
                _controller.display = shown == full ? null : shown;
                if (widget.initialValue != null) {
                  return TextField(
                    key: widget.textFieldKey,
                    initialValue: widget.initialValue,
                    focusNode: _focusNode,
                    style: _valueStyle,
                    onChanged: (val) {
                      final v = double.tryParse(val) ?? 0.0;
                      widget.onChanged(v);
                    },
                    onSubmitted: (val) {
                      final v = double.tryParse(val) ?? 0.0;
                      widget.onCommit(v);
                      _focusNode.unfocus();
                    },
                    padding: const EdgeInsets.symmetric(horizontal: _textPadding, vertical: 2),
                  );
                }
                final field = TextField(
                  key: widget.textFieldKey,
                  controller: _controller,
                  focusNode: _focusNode,
                  // `text-[11px] font-mono` in the prototype's VecInput.
                  style: _valueStyle,
                  // Enter leaves the field, and leaving it commits: one commit
                  // per edit, not one for Enter and another for the focus loss
                  // that follows it.
                  onSubmitted: (_) => _focusNode.unfocus(),
                  padding: const EdgeInsets.symmetric(horizontal: _textPadding, vertical: 2),
                );
                if (_controller.display == null) return field;
                return Tooltip(
                  tooltip: (context) => TooltipContainer(child: Text(full)),
                  child: field,
                );
              }),
            ),
          ),
        ),
        // Its own slot after the value, as wide as the icon: with shadcn's
        // default button padding it was drawn over the next field's letter.
        if (isModified)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: SizedBox(
              width: _resetSize,
              height: _resetSize,
              child: GhostButton(
                density: ButtonDensity.compact,
                alignment: Alignment.center,
                onPressed: widget.onReset,
                child: const Icon(LucideIcons.rotateCcw, size: 10),
              ),
            ),
          ),
      ],
    );
  }

  static const double _textPadding = 3;
  static const double _resetSize = 12;

  /// The text field's border and caret room around the padded text.
  static const double _textFieldChrome = 4;

  /// The style shadcn's `TextField` draws [_valueStyle] in (its own merge
  /// of the default text style and the theme's typography), so the value is
  /// measured in the font it is drawn in.
  static TextStyle _effectiveValueStyle(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTextStyle.of(context)
        .style
        .merge(theme.typography.small)
        .merge(theme.typography.normal)
        .merge(_valueStyle);
  }

  static const TextStyle _valueStyle = TextStyle(
    fontFamily: EditorTypography.monoFamily,
    fontSize: EditorTypography.bodySize,
  );
}
