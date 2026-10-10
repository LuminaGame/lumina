part of '../outliner_widget.dart';

/// The outliner's inline rename (driven by the view model's rename request)
/// and its drag and drop: drop targets, hover-to-expand, the folder a
/// selection is wrapped into.
mixin _OutlinerRenameAndDrop on _OutlinerWidgetStateBase {
  // A collapsed folder hovered by a drag opens after a short hold.
  static const Duration _hoverExpandDelay = Duration(milliseconds: 600);

  // --- Inline rename, driven by EditorViewModel.outlinerRenamingId ---------

  /// Follows the VM's rename request (F2, New Folder, context menu).
  void _syncRenameRequest() {
    final requested = _vm.outlinerRenamingId;
    if (requested == _editingId) return;
    _editingId = requested;
    _renameHadFocus = false;
    if (requested == null) return;
    final node = _vm.actors.where((a) => a.id == requested).firstOrNull;
    _renameController.text = node?.name ?? '';
    _renameController.selection = TextSelection(baseOffset: 0, extentOffset: _renameController.text.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editingId == requested) _renameFocusNode.requestFocus();
    });
  }

  void _onRenameFocusChanged() {
    if (_renameFocusNode.hasFocus) {
      _renameHadFocus = true;
    } else if (_renameHadFocus && _editingId != null) {
      _commitRename();
    }
  }

  void _commitRename() {
    final id = _editingId;
    if (id == null) return;
    final name = _renameController.text.trim();
    final node = _vm.actors.where((a) => a.id == id).firstOrNull;
    if (node != null && name.isNotEmpty && name != node.name) {
      _vm.renameActorWithTransaction(id, name);
    }
    _vm.endOutlinerRename();
  }

  // --- Drag and drop -------------------------------------------------------

  List<String> _idsFor(EditorActorNode node) =>
      _vm.selectedActorIds.contains(node.id) ? _vm.selectedActorIds.toList() : [node.id];

  bool _canDropOn(_OutlinerDrag drag, EditorActorNode target) => target.type == 'Folder'
      ? drag.ids.any((id) => _vm.canMoveToFolder(id, target.id))
      : drag.ids.any((id) => _vm.canAttachToActor(id, target.id));

  void _dropOn(_OutlinerDrag drag, EditorActorNode target) {
    _cancelHoverExpand();
    if (target.type == 'Folder') {
      _vm.moveToFolder(drag.ids, target.id);
    } else {
      _vm.attachToActor(drag.ids, target.id);
    }
  }

  void _scheduleHoverExpand(EditorActorNode node) {
    if (node.type != 'Folder' || _vm.isOutlinerExpanded(node.id) || _hoverExpandId == node.id) return;
    _cancelHoverExpand();
    _hoverExpandId = node.id;
    _hoverExpandTimer = Timer(_hoverExpandDelay, () {
      if (mounted && _hoverExpandId == node.id) _vm.setOutlinerExpanded(node.id, true);
      _hoverExpandId = null;
    });
  }

  void _cancelHoverExpand([String? onlyFor]) {
    if (onlyFor != null && _hoverExpandId != onlyFor) return;
    _hoverExpandTimer?.cancel();
    _hoverExpandTimer = null;
    _hoverExpandId = null;
  }

  /// Where a folder that wraps [ids] is created: their shared parent folder,
  /// else the root.
  String? _sharedParentFolder(List<String> ids) {
    final parents = ids.map((id) => _vm.actors.where((a) => a.id == id).firstOrNull?.parentId).toSet();
    if (parents.length != 1 || parents.single == null) return null;
    final parent = _vm.actors.where((a) => a.id == parents.single).firstOrNull;
    return parent?.type == 'Folder' ? parent!.id : null;
  }
}
