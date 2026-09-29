import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../theme/editor_theme.dart';

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
    this.labelWidth = 16,
    this.labelColor = EditorColors.mutedForeground,
    this.onScrubDelta,
  });

  @override
  State<ScrubNumericField> createState() => _ScrubNumericFieldState();
}

class _ScrubNumericFieldState extends State<ScrubNumericField> {
  late TextEditingController _controller;
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
    _controller = TextEditingController(text: widget.isMixed ? '—' : _format(widget.value));
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
        SizedBox(
          width: widget.labelWidth,
          // `text-[9px] font-mono font-semibold` in the prototype's VecInput.
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: EditorTypography.monoFamily,
              fontSize: EditorTypography.captionSize,
              fontWeight: EditorTypography.panelTitleWeight,
              color: widget.labelColor,
            ),
          ),
        ),
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
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                // `text-[11px] font-mono` in the prototype's VecInput.
                style: const TextStyle(
                  fontFamily: EditorTypography.monoFamily,
                  fontSize: EditorTypography.bodySize,
                ),
                // Enter leaves the field, and leaving it commits: one commit
                // per edit, not one for Enter and another for the focus loss
                // that follows it.
                onSubmitted: (_) => _focusNode.unfocus(),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
            ),
          ),
        ),
        if (isModified)
          SizedBox(
            width: 16,
            child: GhostButton(
              
              child: const Icon(LucideIcons.rotateCcw, size: 10),
              onPressed: widget.onReset,
            ),
          ),
      ],
    );
  }
}
