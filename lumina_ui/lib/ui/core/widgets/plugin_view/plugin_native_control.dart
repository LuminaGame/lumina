import 'dart:async';

import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/editor_panels/widgets/interaction/editor_interaction.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_view_scope.dart';

/// Builds a native widget (timeline, table, canvas) over [state] with the
/// adapter's event and state sinks.
typedef PluginNativeBuilder = Widget Function(
    BuildContext context, Map<String, Object?> state, EditorWidgetEventSink onEvent, EditorWidgetStateSink onState);

/// The JSON spec side of a native editor widget: the same widget an editor
/// panel places, over the control's props. Events go to the plugin process
/// as [PluginViewEvent]s with their phase. What the user changed shows at
/// once (an overlay over the props); an edit (clips, keys, rows, items)
/// waits for the process's patch: any new props for the control count as
/// the answer, and with none within [answerTimeout] the edit reverts with a
/// toast. View state (playhead, zoom, sort, selection) stays until the
/// process sets it.
class PluginNativeControl extends StatefulWidget {
  const PluginNativeControl({super.key, required this.control, required this.defaultHeight, required this.builder});

  final PluginControl control;
  final double defaultHeight;
  final PluginNativeBuilder builder;

  /// How long an edit waits for the plugin's patch.
  static Duration answerTimeout = const Duration(seconds: 10);

  @override
  State<PluginNativeControl> createState() => _PluginNativeControlState();
}

class _PluginNativeControlState extends State<PluginNativeControl> {
  final Map<String, Object?> _overlay = {};
  final Set<String> _edited = {};
  Timer? _waiting;
  Map<String, Object?>? _merged;

  Map<String, Object?> get _state => _merged ??= {...widget.control.props, ..._overlay};

  @override
  void didUpdateWidget(PluginNativeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (pluginControlEquals(oldWidget.control, widget.control)) return;
    // The process answered: its props win.
    final before = oldWidget.control.props;
    for (final k in widget.control.props.keys) {
      if (!pluginValueEquals(before[k], widget.control.props[k])) _overlay.remove(k);
    }
    for (final k in _edited) {
      _overlay.remove(k);
    }
    _edited.clear();
    _waiting?.cancel();
    _waiting = null;
    _merged = null;
  }

  @override
  void dispose() {
    _waiting?.cancel();
    super.dispose();
  }

  void _onEvent(EditorWidgetEvent e) => PluginViewScope.of(context).emit(widget.control.id, e.kind, e.args, e.phase);

  void _onState(Map<String, Object?> changes, {required bool edit}) {
    setState(() {
      _overlay.addAll(changes);
      _merged = null;
      if (edit) {
        _edited.addAll(changes.keys);
        _waiting?.cancel();
        _waiting = Timer(PluginNativeControl.answerTimeout, _revert);
      }
    });
  }

  void _revert() {
    if (!mounted) return;
    setState(() {
      for (final k in _edited) {
        _overlay.remove(k);
      }
      _edited.clear();
      _waiting = null;
      _merged = null;
    });
    final name = widget.control.label ?? widget.control.id;
    showToast(
      context: context,
      location: ToastLocation.bottomRight,
      builder: (_, overlay) => SurfaceCard(
        key: ValueKey('plugin_native_control_reverted_${widget.control.id}'),
        child: Basic(
          title: Text('$name: change reverted', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditorColors.logWarning)),
          content: Text('The plugin did not answer within ${PluginNativeControl.answerTimeout.inSeconds} s.',
              style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.control.number('height')?.toDouble() ?? widget.defaultHeight;
    final label = widget.control.label;
    final body = SizedBox(height: height, child: widget.builder(context, _state, _onEvent, _onState));
    final framed = DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: EditorColors.border)),
      child: body,
    );
    return withPluginTooltip(
      widget.control.tooltip,
      label == null
          ? framed
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(label, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
              ),
              framed,
            ]),
    );
  }
}
