import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A text field that follows its value when it changes elsewhere (MCP tools,
/// undo, a reload) and keeps what the user is typing
/// while it has focus. Use it instead of `TextField(initialValue: …)` for a
/// field that shows view-model state: `initialValue` is read once.
class SyncedTextField extends StatefulWidget {
  const SyncedTextField({super.key, required this.text, this.onChanged, this.onSubmitted, this.placeholder, this.enabled = true});

  final String text;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? placeholder;
  final bool enabled;

  @override
  State<SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<SyncedTextField> {
  late final TextEditingController _controller = TextEditingController(text: widget.text);
  final FocusNode _focus = FocusNode();

  /// A value written here, not typed: it is not reported back.
  bool _syncing = false;

  @override
  void didUpdateWidget(SyncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text && !_focus.hasFocus && _controller.text != widget.text) {
      _syncing = true;
      _controller.text = widget.text;
      _syncing = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        focusNode: _focus,
        placeholder: widget.placeholder,
        enabled: widget.enabled,
        onChanged: widget.onChanged == null ? null : (v) {
          if (!_syncing) widget.onChanged!(v);
        },
        onSubmitted: widget.onSubmitted,
      );
}
