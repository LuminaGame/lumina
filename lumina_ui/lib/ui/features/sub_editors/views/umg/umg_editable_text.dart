import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The runtime Editable Text: shows the element's current `text` (what a
/// graph's Set Text or a plugin process's panel patch wrote) unless the user
/// is typing in it, and commits on Enter (`OnEnter`) or when it loses focus
/// after an edit (`OnUserMovedFocus`).
class UmgEditableText extends StatefulWidget {
  const UmgEditableText({
    super.key,
    required this.text,
    required this.placeholder,
    required this.style,
    required this.onChanged,
    required this.onCommitted,
  });

  /// The element's text now.
  final String text;
  final String placeholder;
  final TextStyle style;
  final ValueChanged<String> onChanged;

  /// The text and the commit method (`OnEnter`, `OnUserMovedFocus`).
  final void Function(String text, String method) onCommitted;

  @override
  State<UmgEditableText> createState() => _UmgEditableTextState();
}

class _UmgEditableTextState extends State<UmgEditableText> {
  late final TextEditingController _controller = TextEditingController(text: widget.text);
  final FocusNode _focus = FocusNode();
  bool _edited = false;

  /// True while the text is set from outside: the field reports that as a
  /// change too, which is not the user's.
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(UmgEditableText old) {
    super.didUpdateWidget(old);
    // An outside change shows at once unless the user is typing.
    if (widget.text != _controller.text && !(_focus.hasFocus && _edited)) {
      _syncing = true;
      _controller.value = TextEditingValue(text: widget.text, selection: TextSelection.collapsed(offset: widget.text.length));
      _syncing = false;
    }
  }

  void _focusChanged() {
    if (!_focus.hasFocus && _edited) {
      _edited = false;
      widget.onCommitted(_controller.text, 'OnUserMovedFocus');
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        focusNode: _focus,
        placeholder: Text(widget.placeholder),
        style: widget.style,
        onChanged: (v) {
          if (_syncing) return;
          _edited = true;
          widget.onChanged(v);
        },
        onSubmitted: (v) {
          _edited = false;
          widget.onCommitted(v, 'OnEnter');
        },
      );
}
