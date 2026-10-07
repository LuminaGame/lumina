import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_completion.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/glsl_syntax_highlighter.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/material/mat_completion_popup.dart';

/// Monospace `.mat` source editor: syntax colours (when the controller is a
/// [GlslCodeController]), a line-number gutter aligned row for row, and
/// code completion ([MatCompletion]) in a popup anchored below the caret.
///
/// The popup opens while an identifier is typed (from its first character)
/// or after `.`, and on Ctrl+Space; Up/Down and PageUp/PageDown move the
/// selection, Enter or Tab accept, Esc closes, typing filters it. Its keys
/// are handled through the field's [focusNode] only while it is open.
class MaterialGlslEditorWidget extends StatefulWidget {
  final MaterialEditorViewModel viewModel;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController? scrollController;

  const MaterialGlslEditorWidget({
    super.key,
    required this.viewModel,
    required this.controller,
    required this.focusNode,
    this.scrollController,
  });

  @override
  State<MaterialGlslEditorWidget> createState() => MaterialGlslEditorWidgetState();
}

class MaterialGlslEditorWidgetState extends State<MaterialGlslEditorWidget> {
  late final ScrollController _scrollController;
  final ScrollController _gutterScrollController = ScrollController();

  /// One code line and one gutter row, in logical pixels.
  static const double _lineHeight = 20.0;

  /// The code area's background (a dark editor surface, darker than the
  /// panels around it).
  static const Color _editorBackground = Color(0xFF1E1E1E);

  /// The width of the gutter left of the code area.
  static const double _gutterWidth = 48.0;

  /// The code area's padding around the text field.
  static const double _codePadding = 8.0;

  static const TextStyle _codeStyle = TextStyle(
    fontFamily: EditorTypography.monoFamily,
    fontSize: 13,
    height: _lineHeight / 13,
  );

  /// The open suggestions; null when the popup is closed.
  MatCompletionResult? _completion;
  int _selectedIndex = 0;

  /// Whether the open popup was asked for with Ctrl+Space (it then stays
  /// open with an empty prefix).
  bool _explicit = false;
  String _lastText = '';
  bool _accepting = false;
  final ScrollController _popupScroll = ScrollController();
  FocusOnKeyEventCallback? _previousKeyHandler;
  double? _charWidth;

  /// The open popup's items; empty when it is closed.
  List<MatCompletionItem> get completionItems => _completion?.items ?? const [];

  /// The selected row of the open popup.
  int get selectedCompletionIndex => _selectedIndex;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _lastText = widget.controller.text;
    widget.controller.addListener(_onTextChanged);
    _previousKeyHandler = widget.focusNode.onKeyEvent;
    widget.focusNode.onKeyEvent = _onKeyEvent;
    widget.focusNode.addListener(_onFocusChanged);
  }

  bool _isSyncingScroll = false;

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    _gutterScrollController.dispose();
    _popupScroll.dispose();
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    if (widget.focusNode.onKeyEvent == _onKeyEvent) widget.focusNode.onKeyEvent = _previousKeyHandler;
    super.dispose();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_isSyncingScroll) return false;
    if (_gutterScrollController.hasClients) {
      if ((_gutterScrollController.offset - notification.metrics.pixels).abs() > 0.5) {
        _isSyncingScroll = true;
        _gutterScrollController.jumpTo(notification.metrics.pixels);
        _isSyncingScroll = false;
      }
    }
    return false;
  }

  void _onTextChanged() {
    final value = widget.controller.value;
    final text = value.text;
    if (widget.viewModel.currentCode != text) {
      widget.viewModel.updateCodeFromEditor(text);
    }
    final previous = _lastText;
    _lastText = text;
    if (_accepting) return;
    final selection = value.selection;
    if (!widget.focusNode.hasFocus || !selection.isValid || !selection.isCollapsed) {
      _closeCompletion();
      return;
    }
    if (text == previous) {
      // The caret moved without an edit (a click, Home/End).
      _closeCompletion();
      return;
    }
    if (_completion != null) {
      _updateCompletion(explicit: _explicit);
      return;
    }
    // Closed: open when one identifier character or a '.' was just typed.
    final caret = selection.baseOffset;
    if (text.length == previous.length + 1 && caret > 0 && caret <= text.length) {
      if (_isTrigger(text.codeUnitAt(caret - 1))) _updateCompletion(explicit: false);
    }
  }

  static bool _isTrigger(int c) => (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A) || c == 0x5F || c == 0x2E;

  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) _closeCompletion();
  }

  /// Queries the suggestions at the caret and opens, refreshes or closes
  /// the popup.
  void _updateCompletion({required bool explicit}) {
    final selection = widget.controller.selection;
    if (!selection.isValid || !selection.isCollapsed) return _closeCompletion();
    final result = MatCompletion.suggest(widget.controller.text, selection.baseOffset, explicit: explicit);
    if (result.isEmpty) return _closeCompletion();
    setState(() {
      _completion = result;
      _explicit = explicit;
      _selectedIndex = 0;
    });
    if (_popupScroll.hasClients) _popupScroll.jumpTo(0);
  }

  void _closeCompletion() {
    if (_completion == null) return;
    setState(() {
      _completion = null;
      _explicit = false;
    });
  }

  void _moveSelection(int delta) {
    final count = completionItems.length;
    if (count == 0) return;
    var next = _selectedIndex + delta;
    if (delta.abs() == 1) {
      next %= count; // Up on the first row wraps to the last one.
    } else {
      next = next.clamp(0, count - 1);
    }
    setState(() => _selectedIndex = next);
    if (_popupScroll.hasClients) {
      _popupScroll.jumpTo(
        MatCompletionPopup.offsetRevealing(next, _popupScroll.offset).clamp(0.0, _popupScroll.position.maxScrollExtent),
      );
    }
  }

  /// Replaces the typed identifier with item [index] and places the caret.
  void _acceptCompletion(int index) {
    final result = _completion;
    if (result == null || index < 0 || index >= result.items.length) return;
    final item = result.items[index];
    final text = widget.controller.text;
    final end = result.replaceEnd.clamp(result.replaceStart, text.length);
    final newText = text.replaceRange(result.replaceStart, end, item.insertText);
    setState(() => _completion = null);
    _accepting = true;
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: result.replaceStart + item.caretOffset),
    );
    _accepting = false;
    widget.focusNode.requestFocus();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.space && HardwareKeyboard.instance.isControlPressed) {
        return _handled(() => _updateCompletion(explicit: true));
      }
      if (_completion != null) {
        if (key == LogicalKeyboardKey.arrowDown) return _handled(() => _moveSelection(1));
        if (key == LogicalKeyboardKey.arrowUp) return _handled(() => _moveSelection(-1));
        if (key == LogicalKeyboardKey.pageDown) {
          return _handled(() => _moveSelection(MatCompletionPopup.maxVisibleRows - 1));
        }
        if (key == LogicalKeyboardKey.pageUp) {
          return _handled(() => _moveSelection(-(MatCompletionPopup.maxVisibleRows - 1)));
        }
        if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.tab) {
          return _handled(() => _acceptCompletion(_selectedIndex));
        }
        if (key == LogicalKeyboardKey.escape) return _handled(_closeCompletion);
      }
    }
    return _previousKeyHandler?.call(node, event) ?? KeyEventResult.ignored;
  }

  KeyEventResult _handled(VoidCallback action) {
    action();
    return KeyEventResult.handled;
  }

  /// The monospace character width of the code text.
  double _measureCharWidth() {
    final painter = TextPainter(
      text: const TextSpan(text: 'MMMMMMMMMM', style: _codeStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = painter.width / 10;
    painter.dispose();
    return width;
  }

  /// The popup at the replaced identifier's start: below its line, or above
  /// it when there is no room below.
  Widget _buildCompletionPopup(MatCompletionResult result, Size size) {
    final text = widget.controller.text;
    final anchor = result.replaceStart.clamp(0, text.length);
    final lineStart = anchor == 0 ? 0 : text.lastIndexOf('\n', anchor - 1) + 1;
    var line = 0;
    for (var i = 0; i < lineStart; i++) {
      if (text.codeUnitAt(i) == 0x0A) line++;
    }
    final charWidth = _charWidth ??= _measureCharWidth();
    final scroll = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final caretTop = _codePadding + line * _lineHeight - scroll;
    final height = MatCompletionPopup.listHeight(result.items.length);
    var top = caretTop + _lineHeight;
    if (top + height > size.height && caretTop - height >= 0) top = caretTop - height;
    // The label column starts after the row's icon (6 + 14 + 6 px).
    final textX = _gutterWidth + _codePadding + (anchor - lineStart) * charWidth;
    final maxLeft = math.max(0.0, size.width - MatCompletionPopup.listWidth);
    final left = (textX - 26).clamp(0.0, maxLeft);
    const details = MatCompletionPopup.detailsWidth + 2;
    final side = left + MatCompletionPopup.listWidth + details <= size.width
        ? MatDetailsSide.right
        : left - details >= 0
        ? MatDetailsSide.left
        : MatDetailsSide.none;
    return Positioned(
      key: const ValueKey('mat_completion_popup'),
      left: side == MatDetailsSide.left ? left - details : left,
      top: top,
      child: MatCompletionPopup(
        items: result.items,
        selectedIndex: _selectedIndex,
        scrollController: _popupScroll,
        detailsSide: side,
        onAccept: _acceptCompletion,
      ),
    );
  }

  /// Jumps the editor cursor to a specific 1-indexed line number.
  void jumpToLine(int line1Indexed) {
    final text = widget.controller.text;
    final lines = text.split('\n');
    if (line1Indexed < 1) line1Indexed = 1;
    if (line1Indexed > lines.length) line1Indexed = lines.length;

    int charOffset = 0;
    for (int i = 0; i < line1Indexed - 1; i++) {
      charOffset += lines[i].length + 1; // +1 for newline
    }

    final targetLineLength = lines[line1Indexed - 1].length;
    widget.controller.selection = TextSelection(baseOffset: charOffset, extentOffset: charOffset + targetLineLength);
    widget.focusNode.requestFocus();

    // Scroll roughly to line
    if (_scrollController.hasClients) {
      final targetScroll = (line1Indexed - 1) * _lineHeight;
      _scrollController.animateTo(
        targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = widget.controller.text;
    final lines = text.split('\n');
    final lineCount = lines.isEmpty ? 1 : lines.length;

    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          Container(
            color: _editorBackground,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Line Number Gutter
                Container(
                  width: _gutterWidth,
                  padding: const EdgeInsets.only(top: _codePadding, right: 8),
                  decoration: BoxDecoration(
                    color: _editorBackground,
                    border: Border(right: BorderSide(color: theme.colorScheme.border.withValues(alpha: 0.5))),
                  ),
                  child: ListView.builder(
                    controller: _gutterScrollController,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: lineCount,
                    itemBuilder: (context, index) {
                      final lineNum = index + 1;
                      final hasIssue = widget.viewModel.issues.any((i) => i.line == lineNum);
                      return SizedBox(
                        height: _lineHeight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (hasIssue)
                              Container(
                                width: 4,
                                height: 12,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.destructive,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            Text(
                              '$lineNum',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: EditorTypography.monoFamily,
                                color: hasIssue ? theme.colorScheme.destructive : const Color(0xFF858585),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Code Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(_codePadding),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _onScrollNotification,
                      child: TextField(
                        key: const ValueKey('material_glsl_code'),
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        scrollController: _scrollController,
                        maxLines: null,
                        expands: true,
                        filled: false,
                        border: const Border(),
                        padding: EdgeInsets.zero,
                        cursorColor: const Color(0xFFAEAFAD),
                        style: _codeStyle,
                        // Every line exactly as tall as a gutter row.
                        strutStyle: const StrutStyle(
                          fontFamily: EditorTypography.monoFamily,
                          fontSize: 13,
                          height: _lineHeight / 13,
                          forceStrutHeight: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_completion != null) _buildCompletionPopup(_completion!, constraints.biggest),
        ],
      ),
    );
  }
}
