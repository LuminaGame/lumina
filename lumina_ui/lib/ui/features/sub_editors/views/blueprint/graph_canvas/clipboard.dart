part of '../graph_canvas.dart';

/// Copy / cut / paste / duplicate on the canvas: Ctrl+C / X / V / D, the
/// node menu's and the canvas palette's Edit rows, the system clipboard
/// (Lumina's JSON graph-nodes text, so copies move between Blueprints and
/// editor windows) and where a paste lands (the mouse, else the view centre).
mixin _BlueprintGraphCanvasClipboard on _BlueprintGraphCanvasStateBase {
  /// The mouse over the canvas, in canvas-widget pixels; null once it left.
  Offset? _clipboardPointer;

  static const String _copyId = 'action_copy_nodes';
  static const String _cutId = 'action_cut_nodes';
  static const String _pasteId = 'action_paste_nodes';
  static const String _duplicateId = 'action_duplicate_nodes';

  static BlueprintPaletteEntry _editEntry(String id, String title, List<String> keywords) => BlueprintPaletteEntry(
        registryId: id,
        title: title,
        category: 'Edit',
        keywords: keywords,
        headerColor: 0xFF3D4A5C,
        kind: LuminaBlueprintNodeKind.pure,
        pinned: true,
      );

  /// The Edit rows the canvas's right-click palette pins first: Paste, and
  /// Copy / Cut / Duplicate while nodes are selected.
  @override
  List<BlueprintPaletteEntry> clipboardPaletteEntries() => [
        _editEntry(_pasteId, 'Paste', const ['paste', 'clipboard', 'ctrl+v']),
        if (editor.selectedNodeIds.isNotEmpty) ...[
          _editEntry(_copyId, 'Copy', const ['copy', 'clipboard', 'ctrl+c']),
          _editEntry(_cutId, 'Cut', const ['cut', 'clipboard', 'ctrl+x']),
          _editEntry(_duplicateId, 'Duplicate', const ['duplicate', 'clone', 'ctrl+d']),
        ],
      ];

  /// Runs an Edit row of the palette at canvas point [at]; false for any
  /// other row.
  @override
  bool _runClipboardEntry(BlueprintPaletteEntry entry, Offset at) {
    switch (entry.registryId) {
      case _pasteId:
        pasteNodes(canvasAt: at);
      case _copyId:
        copySelectedNodes();
      case _cutId:
        cutSelectedNodes();
      case _duplicateId:
        duplicateSelectedNodes();
      default:
        return false;
    }
    return true;
  }

  /// The node menu's Cut / Copy / Paste / Duplicate rows.
  @override
  List<MenuItem> _clipboardMenuItems() {
    MenuButton item(String key, String label, IconData icon, String shortcut, VoidCallback run) => MenuButton(
          key: ValueKey(key),
          leading: Icon(icon, size: 12),
          trailing: Text(shortcut, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          onPressed: (ctx) => run(),
          child: Text(label, style: const TextStyle(fontSize: 10)),
        );
    return [
      item('node_menu_cut', 'Cut', LucideIcons.scissors, 'Ctrl+X', cutSelectedNodes),
      item('node_menu_copy', 'Copy', LucideIcons.copy, 'Ctrl+C', copySelectedNodes),
      item('node_menu_paste', 'Paste', LucideIcons.clipboardPaste, 'Ctrl+V', pasteNodes),
      item('node_menu_duplicate', 'Duplicate', LucideIcons.copyPlus, 'Ctrl+D', duplicateSelectedNodes),
    ];
  }

  /// Wraps the canvas so the paste position follows the mouse.
  Widget _trackClipboardPointer(Widget child) => MouseRegion(
        opaque: false,
        hitTestBehavior: HitTestBehavior.translucent,
        onHover: (e) => _clipboardPointer = _localFromGlobal(e.position),
        onExit: (_) => _clipboardPointer = null,
        child: child,
      );

  /// Ctrl+C / Ctrl+X / Ctrl+V / Ctrl+D; null for other keys. The canvas
  /// checks for a focused text field before it gets here.
  KeyEventResult? _clipboardKey(KeyEvent event) {
    if (event is! KeyDownEvent) return null;
    final keys = HardwareKeyboard.instance;
    if (!(keys.isControlPressed || keys.isMetaPressed) || keys.isAltPressed || keys.isShiftPressed) return null;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyC) {
      if (editor.selectedNodeIds.isEmpty) return null;
      copySelectedNodes();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyX) {
      if (editor.selectedNodeIds.isEmpty) return null;
      cutSelectedNodes();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyD) {
      if (editor.selectedNodeIds.isEmpty) return null;
      duplicateSelectedNodes();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyV) {
      pasteNodes();
      return KeyEventResult.handled;
    }
    return null;
  }

  /// Copies the selected nodes to the system clipboard; false when nothing
  /// is selected.
  Future<bool> copySelectedNodes() async {
    final copy = editor.copySelection();
    if (copy == null) return false;
    await Clipboard.setData(ClipboardData(text: copy.encode()));
    return true;
  }

  /// Copies the selected nodes, then removes them (one undo step).
  Future<bool> cutSelectedNodes() async {
    final copy = editor.copySelection();
    if (copy == null) return false;
    await Clipboard.setData(ClipboardData(text: copy.encode()));
    return editor.cutSelection() != null;
  }

  /// Pastes the system clipboard's graph nodes at [canvasAt] (canvas
  /// units), else at the mouse when it is over the canvas, else at the
  /// view centre. Text that is not Lumina graph nodes pastes nothing.
  Future<BlueprintPasteResult> pasteNodes({Offset? canvasAt}) async {
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } on PlatformException {
      data = null;
    }
    final clipboard = BlueprintGraphClipboard.decode(data?.text);
    if (clipboard == null || !mounted) return BlueprintPasteResult.nothing;
    final pointer = _clipboardPointer;
    final over = pointer != null && (Offset.zero & _size).contains(pointer);
    final at = canvasAt ?? _toCanvas(over ? pointer : Offset(_size.width / 2, _size.height / 2));
    final result = editor.pasteClipboard(clipboard, at);
    _reportSkipped(result);
    return result;
  }

  /// Duplicates the selection 30 units down and right (the clipboard is
  /// left alone).
  BlueprintPasteResult duplicateSelectedNodes() {
    final result = editor.duplicateSelection();
    _reportSkipped(result);
    return result;
  }

  void _reportSkipped(BlueprintPasteResult result) {
    if (result.skipped.isEmpty || !mounted) return;
    showToast(
      context: context,
      location: ToastLocation.bottomRight,
      builder: (toastCtx, overlay) => SurfaceCard(
        key: const ValueKey('graph_paste_skipped_toast'),
        child: Basic(
          title: Text(result.pasted.isEmpty ? 'Nothing pasted' : 'Pasted ${result.pasted.length}, left out ${result.skipped.length}'),
          content: Text(result.skipped.join('\n'), style: const TextStyle(fontSize: 10)),
        ),
      ),
    );
  }
}
