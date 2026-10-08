import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// A text field that commits its value when it loses focus or on Enter.
class PoseSearchTextField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onCommit;
  final String? placeholder;

  const PoseSearchTextField({super.key, required this.value, required this.onCommit, this.placeholder});

  @override
  State<PoseSearchTextField> createState() => _PoseSearchTextFieldState();
}

class _PoseSearchTextFieldState extends State<PoseSearchTextField> {
  late final TextEditingController _c = TextEditingController(text: widget.value);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant PoseSearchTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && widget.value != _c.text) _c.text = widget.value;
  }

  void _commit() {
    if (_c.text != widget.value) widget.onCommit(_c.text);
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        focusNode: _focus,
        placeholder: widget.placeholder == null
            ? null
            : Text(widget.placeholder!, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        style: const TextStyle(fontSize: 11),
        onSubmitted: (_) => _commit(),
      );
}

/// A number field committing on focus loss or Enter (unparsable text is
/// dropped).
class PoseSearchNumberField extends StatelessWidget {
  final double value;
  final ValueChanged<double> onCommit;

  const PoseSearchNumberField({super.key, required this.value, required this.onCommit});

  static String format(double v) => v == v.roundToDouble() ? v.toStringAsFixed(1) : '$v';

  @override
  Widget build(BuildContext context) => PoseSearchTextField(
        value: format(value),
        onCommit: (text) {
          final v = double.tryParse(text.trim());
          if (v != null) onCommit(v);
        },
      );
}

/// A label / editor row of the Details panel (property labels 10 px,
/// muted).
Widget poseSearchField(String label, Widget child, {double labelWidth = 120}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
              width: labelWidth,
              child: Text(label, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground))),
          Expanded(child: child),
        ],
      ),
    );

/// A Details section header (11 px semi-bold).
Widget poseSearchSection(String title) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
    );

/// A shadcn check box with a caption.
Widget poseSearchCheck(String key, String caption, bool value, ValueChanged<bool> onChanged) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          key: ValueKey(key),
          state: value ? CheckboxState.checked : CheckboxState.unchecked,
          onChanged: (s) => onChanged(s == CheckboxState.checked),
        ),
        const SizedBox(width: 4),
        Text(caption, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
      ],
    );
