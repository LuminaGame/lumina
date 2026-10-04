import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/shortcuts/quick_open_palette.dart';

/// A shortcut that stands down whenever its key belongs to someone else:
/// a focused text field (it types the letter, and owns Delete, Ctrl+Z and
/// Ctrl+D), the viewport's right-mouse fly, or a running Play session (the
/// game has the keyboard). [levelEditing] shortcuts also stand down while a
/// sub-editor tab is showing, so a key pressed there never edits the level
/// hidden behind it.
class ConditionalActivator extends ShortcutActivator {
  final LogicalKeyboardKey key;
  final EditorViewModel viewModel;
  final bool control;
  final bool shift;
  final bool levelEditing;

  ConditionalActivator(
    this.key,
    this.viewModel, {
    this.control = false,
    this.shift = false,
    this.levelEditing = true,
  });

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != key) return false;
    // Exact modifiers, like SingleActivator: Ctrl+W is not W.
    if (state.isControlPressed != control || state.isShiftPressed != shift) return false;
    if (state.isAltPressed || state.isMetaPressed) return false;

    if (viewModel.isFlyNavigating) return false;
    if (viewModel.pieController.acceptsGameInput) return false;
    if (levelEditing && viewModel.activeTabIndex != 0) return false;

    // Check if EditableText is focused
    final focusNode = FocusManager.instance.primaryFocus;
    if (focusNode != null && focusNode.context != null) {
      if (focusNode.context!.findAncestorWidgetOfExactType<EditableText>() != null) {
        return false;
      }

      bool hasEditableText = false;
      focusNode.context!.visitChildElements((element) {
        if (element.widget is EditableText || element.widget is shadcn.TextField) {
          hasEditableText = true;
        }
      });
      if (hasEditableText) return false;

      if (focusNode.context!.widget is EditableText) return false;
    }

    return true;
  }

  @override
  Iterable<LogicalKeyboardKey>? get triggers => [key];

  @override
  String debugDescribeKeys() {
    return key.keyLabel;
  }
}

class DispatchCommandIntent extends Intent {
  final String commandId;
  const DispatchCommandIntent(this.commandId);
}

/// The editor shell's shortcut layer, mounted around the
/// whole editor by `MainEditorView`.
///
/// It is a focus *scope*: when a text field gives up focus (a click
/// elsewhere), focus falls back to this scope rather than out of the editor,
/// so the shortcuts keep working. Widgets below that handle a key themselves
/// (the viewport's fly keys, a sub-editor's own Ctrl+Z) win, being deeper.
class EditorShortcutsScope extends StatefulWidget {
  final Widget child;
  final EditorViewModel viewModel;

  const EditorShortcutsScope({
    super.key,
    required this.child,
    required this.viewModel,
  });

  @override
  State<EditorShortcutsScope> createState() => _EditorShortcutsScopeState();
}

class _EditorShortcutsScopeState extends State<EditorShortcutsScope> {
  final FocusScopeNode _focusNode = FocusScopeNode(debugLabel: 'EditorShortcutsScope');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _showQuickOpen() {
    showQuickOpenPalette(context, widget.viewModel, _focusNode);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        ConditionalActivator(LogicalKeyboardKey.keyQ, vm, levelEditing: false): const DispatchCommandIntent('tool.select'),
        ConditionalActivator(LogicalKeyboardKey.keyW, vm, levelEditing: false): const DispatchCommandIntent('tool.translate'),
        ConditionalActivator(LogicalKeyboardKey.keyE, vm, levelEditing: false): const DispatchCommandIntent('tool.rotate'),
        ConditionalActivator(LogicalKeyboardKey.keyR, vm, levelEditing: false): const DispatchCommandIntent('tool.scale'),
        ConditionalActivator(LogicalKeyboardKey.keyF, vm): const DispatchCommandIntent('view.focusSelected'),
        ConditionalActivator(LogicalKeyboardKey.delete, vm): const DispatchCommandIntent('edit.delete'),
        ConditionalActivator(LogicalKeyboardKey.f2, vm): const DispatchCommandIntent('outliner.rename'),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): const DispatchCommandIntent('file.saveLevel'),
        // Undo/redo are shared with the editors that record into the same
        // transaction stack; a text field still owns them while focused.
        ConditionalActivator(LogicalKeyboardKey.keyZ, vm, control: true, levelEditing: false): const DispatchCommandIntent('edit.undo'),
        ConditionalActivator(LogicalKeyboardKey.keyY, vm, control: true, levelEditing: false): const DispatchCommandIntent('edit.redo'),
        ConditionalActivator(LogicalKeyboardKey.keyZ, vm, control: true, shift: true, levelEditing: false): const DispatchCommandIntent('edit.redo'),
        ConditionalActivator(LogicalKeyboardKey.keyD, vm, control: true): const DispatchCommandIntent('edit.duplicate'),
        const SingleActivator(LogicalKeyboardKey.keyP, alt: true): const DispatchCommandIntent('debug.togglePie'),
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): const DispatchCommandIntent('shell.quickOpen'),
        // Blueprints ▸ Open Level Blueprint.
        const SingleActivator(LogicalKeyboardKey.keyB, control: true, shift: true): const DispatchCommandIntent('edit.levelBlueprint'),
        // File ▸ Import Asset Folder…
        const SingleActivator(LogicalKeyboardKey.keyI, control: true, shift: true): const DispatchCommandIntent('file.importAssetFolder'),
        const SingleActivator(LogicalKeyboardKey.escape): const DispatchCommandIntent('shell.cancel'),
        // View ▸ Full Screen.
        const SingleActivator(LogicalKeyboardKey.f11): const DispatchCommandIntent('view.fullscreen'),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          DispatchCommandIntent: CallbackAction<DispatchCommandIntent>(
            onInvoke: (DispatchCommandIntent intent) {
              if (intent.commandId == 'shell.cancel') {
                // Esc: stop Play (the gizmo is suspended while it runs),
                // else cancel a transform drag in progress.
                if (vm.isPlaying) {
                  vm.commands.execute('debug.stopPie', context);
                } else {
                  vm.cancelTransformDrag();
                }
                return null;
              }
              if (intent.commandId == 'shell.quickOpen') {
                _showQuickOpen();
                return null;
              }

              final cmd = vm.commands.byId(intent.commandId);
              if (cmd != null && cmd.canExecute()) {
                cmd.execute(context);
              }
              return null;
            },
          ),
        },
        child: FocusScope(
          node: _focusNode,
          autofocus: true,
          child: widget.child,
        ),
      ),
    );
  }
}
