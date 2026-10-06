import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'plugin_view_scope.dart';

/// [PluginControlKind.textField]: `value`, `placeholder`, `multiline`.
/// Sends `changed` with the text when the user submits it (Enter on a
/// single line; leaving the field commits a multi-line edit, or a single
/// line the user changed without pressing Enter). While the field has focus
/// a new `value` from the plugin does not overwrite what is being typed.
class PluginTextFieldControl extends StatefulWidget {
  const PluginTextFieldControl({super.key, required this.control});

  final PluginControl control;

  @override
  State<PluginTextFieldControl> createState() => _PluginTextFieldControlState();
}

class _PluginTextFieldControlState extends State<PluginTextFieldControl> {
  late final TextEditingController _controller = TextEditingController(text: _value(widget.control));
  final FocusNode _focus = FocusNode();

  /// The last text sent (or received): leaving the field does not send it twice.
  late String _committed;

  static String _value(PluginControl c) => c.string('value') ?? '';

  @override
  void initState() {
    super.initState();
    _committed = _value(widget.control);
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(PluginTextFieldControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _value(widget.control);
    if (next != _value(oldWidget.control)) {
      _committed = next;
      if (!_focus.hasFocus && _controller.text != next) _controller.text = next;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus) _commit(_controller.text);
  }

  void _commit(String text) {
    if (!widget.control.enabled || text == _committed) return;
    _committed = text;
    PluginViewScope.of(context).emit(widget.control.id, 'changed', text);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.control;
    final multiline = c.flag('multiline') ?? false;
    final placeholder = c.string('placeholder');
    final field = TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: c.enabled,
      placeholder: placeholder == null ? null : Text(placeholder),
      maxLines: multiline ? 6 : 1,
      minLines: multiline ? 3 : 1,
      style: const TextStyle(fontSize: 10),
      onSubmitted: multiline ? null : _commit,
    );
    return withPluginTooltip(c.tooltip, PluginFieldRow(label: c.label, alignTop: multiline, child: field));
  }
}
