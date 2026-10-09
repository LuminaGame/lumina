part of '../particle_sub_editor.dart';

/// Numeric field committing on Enter / focus loss — `maxParticles` re-allocates
/// the pool, so per-keystroke commits are exactly what we must avoid.
class _NumField extends StatefulWidget {
  final ValueKey<String> fieldKey;
  final double value;
  final bool isInt;
  final void Function(double) onCommit;

  const _NumField({
    required this.fieldKey,
    required this.value,
    required this.onCommit,
    this.isInt = false,
  });

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  String get _formatted => widget.isInt ? widget.value.round().toString() : _trim(widget.value);

  static String _trim(double v) => v == v.roundToDouble() ? v.toStringAsFixed(1) : v.toString();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatted);
    _focus = FocusNode()
      ..addListener(() {
        if (!_focus.hasFocus) _commit(_controller.text);
      });
  }

  @override
  void didUpdateWidget(covariant _NumField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_focus.hasFocus) {
      _controller.text = _formatted;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final parsed = double.tryParse(raw.trim());
    if (parsed == null) {
      _controller.text = _formatted;
      return;
    }
    widget.onCommit(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: TextField(
        key: widget.fieldKey,
        controller: _controller,
        focusNode: _focus,
        style: const TextStyle(fontSize: 9.5),
        onSubmitted: _commit,
      ),
    );
  }
}

/// Default engine config, re-exported for callers building a fresh document.
LuminaParticleEmitterConfig particleEmitterDefaults() => LuminaParticleEmitterConfig();
