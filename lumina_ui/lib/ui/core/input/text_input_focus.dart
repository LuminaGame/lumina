import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether a text input owns the keyboard right now: the primary focus is an
/// [EditableText] (a shadcn `TextField`, a node's literal field, a Details
/// field, a rename box) or sits inside one.
///
/// Editor shortcuts that reuse editing keys (Delete, Backspace, Ctrl+C/X/V/D,
/// Ctrl+Z/Y, arrows, Home, letters) check this first and stand down, so the
/// key reaches the field: Backspace removes a character instead of the
/// selected node, Ctrl+Z undoes the typing instead of the graph.
bool isTextInputFocused() {
  final focus = FocusManager.instance.primaryFocus;
  final context = focus?.context;
  if (context == null) return false;
  if (context.widget is EditableText) return true;
  if (context.findAncestorWidgetOfExactType<EditableText>() != null) return true;
  // A TextField's focus node belongs to the field's own Focus widget, whose
  // element sits just above the EditableText it builds.
  var found = false;
  void visit(Element element) {
    if (found) return;
    if (element.widget is EditableText) {
      found = true;
      return;
    }
    // Stop at the next focus node: a field deeper down is not this one.
    if (element.widget is Focus && (element.widget as Focus).focusNode != focus) return;
    element.visitChildElements(visit);
  }

  context.visitChildElements(visit);
  return found;
}

/// A [SingleActivator] that does not fire while a text input has focus
/// ([isTextInputFocused]): the bindings of a sub-editor's
/// `CallbackShortcuts` (undo, redo, delete) wrap every field of the tab.
class NotWhileTypingActivator extends ShortcutActivator {
  final SingleActivator activator;

  const NotWhileTypingActivator(this.activator);

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) => activator.accepts(event, state) && !isTextInputFocused();

  @override
  Iterable<LogicalKeyboardKey>? get triggers => activator.triggers;

  @override
  String debugDescribeKeys() => activator.debugDescribeKeys();
}
