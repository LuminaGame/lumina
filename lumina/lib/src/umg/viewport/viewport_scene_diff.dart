import 'package:lumina/src/umg/viewport/viewport_scene.dart';

/// What one [LuminaViewportSceneOp] changes.
enum LuminaViewportSceneOpKind {
  addNode,
  removeNode,
  updateNode,
  environment,
  grid,
  camera,
  interaction,
  addOverlay,
  removeOverlay,
  updateOverlay,
  gizmo,
  addMarker,
  removeMarker,
  updateMarker,
}

/// One change between two descriptions: [id] names the node, overlay (its
/// node) or marker; [value] is the new state (null for a removal or a hidden
/// gizmo); [fields] are the keys of a node that changed (an update).
class LuminaViewportSceneOp {
  const LuminaViewportSceneOp(this.kind, {this.id, this.value, this.fields = const {}});

  final LuminaViewportSceneOpKind kind;
  final String? id;
  final Map<String, Object?>? value;
  final Set<String> fields;

  @override
  String toString() => 'LuminaViewportSceneOp(${kind.name}${id == null ? '' : ' $id'}${fields.isEmpty ? '' : ' $fields'})';
}

/// The minimal edit from one description to the next, so a small change
/// (a moved node, a removed marker) never rebuilds the preview scene.
abstract final class LuminaViewportSceneDiff {
  /// The ops that turn [old] (null: nothing shown yet) into [next]: node
  /// removals first, then additions in description order (parents are added
  /// before the children the runtime attaches to them), then updates, then
  /// the scene-wide parts that changed.
  static List<LuminaViewportSceneOp> diff(LuminaViewportScene? old, LuminaViewportScene next) {
    final ops = <LuminaViewportSceneOp>[];
    final before = {for (final n in old?.nodes ?? const <Map<String, Object?>>[]) '${n['id']}': n};
    final after = {for (final n in next.nodes) '${n['id']}': n};

    final updates = <LuminaViewportSceneOp>[];
    final adds = <LuminaViewportSceneOp>[];
    for (final id in before.keys) {
      final now = after[id];
      if (now == null || now['kind'] != before[id]!['kind']) {
        ops.add(LuminaViewportSceneOp(LuminaViewportSceneOpKind.removeNode, id: id));
      }
    }
    for (final entry in after.entries) {
      final was = before[entry.key];
      if (was == null || was['kind'] != entry.value['kind']) {
        adds.add(LuminaViewportSceneOp(LuminaViewportSceneOpKind.addNode, id: entry.key, value: entry.value));
        continue;
      }
      final fields = {
        for (final k in {...was.keys, ...entry.value.keys})
          if (!jsonEquals(was[k], entry.value[k])) k,
      };
      if (fields.isNotEmpty) {
        updates.add(LuminaViewportSceneOp(LuminaViewportSceneOpKind.updateNode, id: entry.key, value: entry.value, fields: fields));
      }
    }
    ops
      ..addAll(adds)
      ..addAll(updates);

    void whole(String key, LuminaViewportSceneOpKind kind) {
      if (old != null && jsonEquals(old.json[key], next.json[key])) return;
      final v = next.json[key];
      ops.add(LuminaViewportSceneOp(kind, value: v is Map<String, Object?> ? v : <String, Object?>{'value': v}));
    }

    whole('environment', LuminaViewportSceneOpKind.environment);
    whole('grid', LuminaViewportSceneOpKind.grid);
    whole('camera', LuminaViewportSceneOpKind.camera);
    whole('interaction', LuminaViewportSceneOpKind.interaction);

    _keyed(ops, old?.skeletonOverlays ?? const [], next.skeletonOverlays, 'node', LuminaViewportSceneOpKind.addOverlay,
        LuminaViewportSceneOpKind.removeOverlay, LuminaViewportSceneOpKind.updateOverlay);

    final oldGizmo = old?.gizmo;
    if (old == null ? next.gizmo != null : !jsonEquals(oldGizmo, next.gizmo)) {
      ops.add(LuminaViewportSceneOp(LuminaViewportSceneOpKind.gizmo, id: next.gizmo?['node'] as String?, value: next.gizmo));
    }

    _keyed(ops, old?.markers ?? const [], next.markers, 'id', LuminaViewportSceneOpKind.addMarker,
        LuminaViewportSceneOpKind.removeMarker, LuminaViewportSceneOpKind.updateMarker);
    return ops;
  }

  static void _keyed(List<LuminaViewportSceneOp> ops, List<Map<String, Object?>> old, List<Map<String, Object?>> next, String key,
      LuminaViewportSceneOpKind add, LuminaViewportSceneOpKind remove, LuminaViewportSceneOpKind update) {
    final before = {for (final o in old) '${o[key]}': o};
    final after = {for (final o in next) '${o[key]}': o};
    for (final id in before.keys) {
      if (!after.containsKey(id)) ops.add(LuminaViewportSceneOp(remove, id: id));
    }
    for (final e in after.entries) {
      final was = before[e.key];
      if (was == null) {
        ops.add(LuminaViewportSceneOp(add, id: e.key, value: e.value));
      } else if (!jsonEquals(was, e.value)) {
        ops.add(LuminaViewportSceneOp(update, id: e.key, value: e.value));
      }
    }
  }

  /// Deep equality of two JSON values (numbers compare by value, so `1` and
  /// `1.0` are equal).
  static bool jsonEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is num && b is num) return a.toDouble() == b.toDouble();
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final e in a.entries) {
        if (!b.containsKey(e.key) || !jsonEquals(e.value, b[e.key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!jsonEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
