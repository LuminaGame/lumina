import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../theme/editor_theme.dart';

class ColorField extends StatefulWidget {
  final bool isMixed;
  final String value;
  final String defaultValue;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCommit;
  final VoidCallback onReset;

  /// Edits the alpha too: accepts `#RRGGBB` or `#RRGGBBAA`, writes
  /// `#RRGGBBAA` (alpha last), and the picker shows an alpha slider.
  final bool showAlpha;

  const ColorField({
    this.isMixed = false,
    super.key,
    required this.value,
    this.defaultValue = '#FFFFFF',
    required this.onChanged,
    required this.onCommit,
    required this.onReset,
    this.showAlpha = false,
  });

  @override
  State<ColorField> createState() => _ColorFieldState();
}

class _ColorFieldState extends State<ColorField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(ColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = widget.value;
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
      _commitText(_controller.text);
    }
  }

  void _commitText(String text) {
    final trimmed = text.trim();
    if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(trimmed)) {
      widget.onCommit(widget.showAlpha ? '${trimmed.toUpperCase()}FF' : trimmed.toUpperCase());
    } else if (widget.showAlpha && RegExp(r'^#[0-9A-Fa-f]{8}$').hasMatch(trimmed)) {
      widget.onCommit(trimmed.toUpperCase());
    } else {
      _controller.text = widget.value;
    }
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (widget.showAlpha) {
      // #RRGGBBAA: alpha last.
      if (hex.length == 6) hex = '${hex}FF';
      final v = int.tryParse(hex, radix: 16) ?? 0xFFFFFFFF;
      return Color(((v & 0xFF) << 24) | (v >> 8));
    }
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  String _toHex(Color color) {
    String c(double v) => (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${c(color.r)}${c(color.g)}${c(color.b)}${widget.showAlpha ? c(color.a) : ''}'.toUpperCase();
  }

  void _showColorPicker() {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (context) {
        return AlertDialog(
          content: ColorPicker(
            value: ColorDerivative.fromColor(_parseColor(widget.value)),
            showAlpha: widget.showAlpha,
            onChanged: (ColorDerivative color) {
              widget.onChanged(_toHex(color.toColor()));
            },
          ),
        );
      },
    ).then((_) {
      widget.onCommit(widget.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isModified = widget.value != widget.defaultValue;

    return Row(
      children: [
        GestureDetector(
          onTap: _showColorPicker,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _parseColor(widget.value),
              border: Border.all(color: EditorColors.border),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onSubmitted: _commitText,
            style: const TextStyle(fontSize: 10),
          ),
        ),
        if (isModified)
          SizedBox(
            width: 16,
            child: GhostButton(
              onPressed: widget.onReset,
              child: const Icon(LucideIcons.rotateCcw, size: 10),
            ),
          ),
      ],
    );
  }
}
