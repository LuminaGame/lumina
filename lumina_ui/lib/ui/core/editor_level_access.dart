import 'package:flutter/foundation.dart' show Listenable;
import 'package:lumina/lumina.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

import '../features/details/models/editor_component_node.dart';
import '../features/main_editor/commands/editor_transaction.dart';
import '../features/main_editor/view_models/editor_view_model.dart';

/// The open level as plugins see it: a thin adapter over
/// [EditorViewModel] that hands out immutable snapshots and routes every
/// edit through the view model's transaction / dirty-flag path, so a
/// plugin's Generate is one undo entry like a hand-placed actor.
class EditorViewModelLevelAccess implements EditorLevelAccess {
  final EditorViewModel viewModel;

  EditorViewModelLevelAccess(this.viewModel);

  @override
  String get projectDirPath => viewModel.projectDirPath;

  @override
  String get activeLevelPath => viewModel.project.activeLevel;

  @override
  Listenable get changes => viewModel;

  /// Every level edit [body] makes is one undo step.
  @override
  Future<T> runTransaction<T>(String label, Future<T> Function() body) => TransactionManager.runGrouped(label, body);

  @override
  String? get undoTopLabel {
    final t = viewModel.transactions;
    return t.canUndo ? t.history(limit: 1).first.label : null;
  }

  @override
  bool undoIfTop(String label) {
    final t = viewModel.transactions;
    if (undoTopLabel != label || t.isFrozen) return false;
    t.undo();
    return true;
  }

  @override
  List<EditorActorSnapshot> get actors => [for (final a in viewModel.actors) snapshotOf(a)];

  @override
  List<String> get selectedActorIds => viewModel.selectedActorIds.toList();

  /// The immutable view of [node] a plugin gets.
  static EditorActorSnapshot snapshotOf(EditorActorNode node) => EditorActorSnapshot(
        id: node.id,
        name: node.name,
        type: node.type,
        parentId: node.parentId,
        location: List.unmodifiable(node.location),
        rotation: List.unmodifiable(node.rotation),
        scale: List.unmodifiable(node.scale),
        isVisible: node.isVisible,
        meshAssetPath: node.meshAssetPath,
        components: [
          for (final c in node.components)
            EditorComponentSnapshot(
              id: c.id,
              type: c.type,
              name: c.name,
              enabled: c.enabled,
              properties: Map.unmodifiable(c.properties),
            ),
        ],
      );

  @override
  Future<List<String>> addActors(List<EditorActorSpec> specs, {String? label}) async {
    final nodes = <EditorActorNode>[];
    final meshCache = <String, GlbMeshData?>{};
    var counter = viewModel.actors.length;
    final taken = viewModel.actors.map((a) => a.id).toSet();
    for (final spec in specs) {
      var id = spec.id;
      if (id == null || taken.contains(id)) {
        do {
          counter++;
          id = 'act_$counter';
        } while (taken.contains(id));
      }
      taken.add(id);
      final node = EditorActorNode(
        id: id,
        name: spec.name,
        type: spec.type,
        parentId: spec.parentId,
        location: List<double>.from(spec.location),
        rotation: List<double>.from(spec.rotation),
        scale: List<double>.from(spec.scale),
        meshAssetPath: spec.meshAssetPath,
        components: [
          for (var i = 0; i < spec.components.length; i++)
            EditorComponentNode(
              id: '${id}_c$i',
              type: spec.components[i].type,
              name: spec.components[i].name,
              properties: Map<String, dynamic>.from(spec.components[i].properties),
            ),
        ],
      );
      final mesh = spec.meshAssetPath;
      if (mesh != null && mesh.isNotEmpty) {
        // One parse per distinct file: a scatter of 200 barrels reads the
        // .glb once.
        if (!meshCache.containsKey(mesh)) meshCache[mesh] = await AssetRepository.loadMeshFromDisk(mesh);
        node.meshData = meshCache[mesh];
      }
      nodes.add(node);
    }
    viewModel.addActorNodes(nodes, label: label);
    return [for (final n in nodes) n.id];
  }

  @override
  void removeActors(Iterable<String> ids, {String? label}) => viewModel.removeActorNodes(ids, label: label);

  @override
  void setComponentProperty(String actorId, String componentType, String propertyId, Object? value, {String? label}) =>
      viewModel.setComponentPropertyWithTransaction(actorId, componentType, propertyId, value, label: label);

  @override
  void selectActors(Iterable<String> ids) {
    viewModel.clearSelection();
    viewModel.selectActors(ids);
  }

  @override
  Future<void> saveLevel() => viewModel.saveLevelAndGenerateCode();

  @override
  void openAssetEditor(String assetPath) => viewModel.openAssetEditorByPath(assetPath);

  @override
  void log(String message, {String level = 'info', String source = 'Plugin'}) =>
      viewModel.logger.log(message, level: level, source: source);
}
