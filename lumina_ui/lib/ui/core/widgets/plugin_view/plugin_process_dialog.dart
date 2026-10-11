import 'package:flutter/services.dart' show HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/services/plugin_process/plugin_dialog_queue.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_view_renderer.dart';

/// Shows the modal dialogs plugin processes open ([PluginDialogQueue]) over
/// [child], one at a time: a shadcn [AlertDialog] whose body is the spec's
/// controls (the declarative panel renderer) and whose buttons are its
/// actions. A button answers its action with the body's values; Escape or a
/// click outside answers dismissed when the dialog is dismissible. The
/// layer only listens to the queue: nothing waits on a dialog, so the
/// editor keeps drawing while one is open.
class PluginDialogLayer extends StatelessWidget {
  const PluginDialogLayer({super.key, required this.queue, required this.child, this.projectDir});

  final PluginDialogQueue queue;
  final Widget child;

  /// Lets asset fields in a dialog resolve project paths.
  final String? projectDir;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          child,
          ListenableBuilder(
            listenable: queue,
            builder: (context, _) {
              final current = queue.current;
              if (current == null) return const SizedBox.shrink();
              // Its own overlay: text fields in the dialog need one, and
              // the layer may sit above the app's navigator.
              return Overlay(
                key: ValueKey('plugin_dialog_overlay_${current.serial}'),
                initialEntries: [
                  OverlayEntry(
                    builder: (_) => _PluginDialogView(queue: queue, dialog: current, projectDir: projectDir),
                  ),
                ],
              );
            },
          ),
        ],
      );
}

class _PluginDialogView extends StatefulWidget {
  const _PluginDialogView({required this.queue, required this.dialog, this.projectDir});

  final PluginDialogQueue queue;
  final PendingPluginDialog dialog;
  final String? projectDir;

  @override
  State<_PluginDialogView> createState() => _PluginDialogViewState();
}

class _PluginDialogViewState extends State<_PluginDialogView> {
  PluginDialogSpec get spec => widget.dialog.spec;

  @override
  void initState() {
    super.initState();
    // Escape reaches the dialog wherever focus is (a field in it, or the
    // editor behind it).
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return false;
    _dismiss();
    return true;
  }

  void _dismiss() {
    if (spec.dismissible) widget.queue.answer(widget.dialog, null);
  }

  Future<void> _press(String action) async {
    // A text field commits what was typed when it loses focus. Focus
    // changes apply in a microtask; the commit follows in the next.
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.microtask(() {});
    await Future<void>.microtask(() {});
    widget.queue.answer(widget.dialog, action);
  }

  Widget _button(PluginDialogAction a) {
    final key = ValueKey('plugin_dialog_action_${a.id}');
    final label = Text(a.label);
    void onPressed() => _press(a.id);
    return switch (a.tone) {
      PluginDialogTone.primary => PrimaryButton(key: key, onPressed: onPressed, child: label),
      PluginDialogTone.destructive => DestructiveButton(key: key, onPressed: onPressed, child: label),
      _ => OutlineButton(key: key, onPressed: onPressed, child: label),
    };
  }

  @override
  Widget build(BuildContext context) {
    final actions = spec.actions.isEmpty ? const [PluginDialogAction(id: 'close', label: 'Close')] : spec.actions;
    final dialog = widget.dialog;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          key: const ValueKey('plugin_dialog_barrier'),
          behavior: HitTestBehavior.opaque,
          onTap: _dismiss,
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
        ),
        Center(
          child: AlertDialog(
            key: ValueKey('plugin_dialog_${dialog.plugin}_${spec.id}'),
            title: Text(spec.title),
            content: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 320, maxWidth: 520, maxHeight: 420),
              child: SingleChildScrollView(
                child: PluginViewRenderer(
                  key: ValueKey('plugin_dialog_body_${dialog.serial}'),
                  spec: PluginViewSpec(id: 'dialog:${spec.id}', children: spec.body),
                  projectDir: widget.projectDir,
                  onEvent: (e) {
                    if (e.kind == 'changed' || e.kind == 'picked') widget.queue.setValue(dialog, e.controlId, e.value);
                  },
                ),
              ),
            ),
            actions: [for (final a in actions) _button(a)],
          ),
        ),
      ],
    );
  }
}
