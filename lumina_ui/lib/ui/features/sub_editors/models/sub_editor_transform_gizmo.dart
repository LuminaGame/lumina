import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:vector_math/vector_math_64.dart';

import '../../main_editor/services/gizmo_controller.dart';
import '../../main_editor/services/transform_gizmo.dart';
import 'viewport_ray.dart';

export '../../main_editor/services/gizmo_controller.dart' show GizmoMode, GizmoSpace;
export '../../main_editor/services/transform_gizmo.dart' show TransformGizmoSnap;

/// What a sub-editor viewport's transform gizmo sits on: one object with a
/// world transform in the **authoring** frame (Z up, cm — what the Details
/// panel shows), as `SubEditor3DViewport` draws it through `LuminaAxes`.
class SubEditorGizmoTarget {
  final String id;

  /// The object's world location, authoring frame.
  final Vector3 pivot;

  /// The object's world rotation, authoring frame (local-space axes).
  final Quaternion rotation;

  /// A gizmo that is drawn but refuses to drag (a Blueprint's root
  /// component), with the hint the banner shows.
  final bool locked;
  final String lockedHint;

  const SubEditorGizmoTarget({
    required this.id,
    required this.pivot,
    required this.rotation,
    this.locked = false,
    this.lockedHint = 'Transform is fixed',
  });
}

/// One pointer move of a drag, as a world-space delta in the authoring frame
/// since the grab. Exactly one of the three groups is set, by the tool.
class SubEditorGizmoDelta {
  /// Translate: the pivot's offset.
  final Vector3? translation;

  /// Rotate: the world axis turned about and the (snapped) angle, degrees.
  final Vector3? rotationAxis;
  final double? rotationDegrees;

  /// Scale: the handle (`X`, `Y`, `Z` or `UNIFORM`) and the (snapped) amount
  /// to add to each affected scale component.
  final String? scaleHandle;
  final double? scaleDelta;

  const SubEditorGizmoDelta.translate(this.translation)
      : rotationAxis = null,
        rotationDegrees = null,
        scaleHandle = null,
        scaleDelta = null;

  const SubEditorGizmoDelta.rotate(this.rotationAxis, this.rotationDegrees)
      : translation = null,
        scaleHandle = null,
        scaleDelta = null;

  const SubEditorGizmoDelta.scale(this.scaleHandle, this.scaleDelta)
      : translation = null,
        rotationAxis = null,
        rotationDegrees = null;
}

/// The transform gizmo of a sub-editor 3D viewport:
/// the tool (Q/W/E/R), Local/World space and snap settings the viewport's
/// toolbar cluster drives, the [target] it manipulates, and the callbacks the
/// owning editor turns into document edits. The viewport listens to it.
class SubEditorTransformGizmo extends ChangeNotifier {
  GizmoMode _mode;
  GizmoSpace _space;
  TransformGizmoSnap _snap;
  SubEditorGizmoTarget? _target;

  /// A drag on [target] started (snapshot for undo / cancel).
  final void Function(String id)? onDragBegin;

  /// The pointer moved during a drag.
  final void Function(String id, SubEditorGizmoDelta delta)? onDragUpdate;

  /// The button came up: commit one undo step.
  final void Function(String id)? onDragEnd;

  /// Esc during the drag: restore the snapshot.
  final void Function(String id)? onDragCancel;

  /// A click that hit no handle: what is under the pointer's camera ray
  /// (runtime frame, as the viewport's rays are), or null.
  final String? Function(ViewportRay ray)? pick;

  /// The click's result, so the owner can sync its selection.
  final void Function(String? id)? onPick;

  SubEditorTransformGizmo({
    GizmoMode mode = GizmoMode.translate,
    GizmoSpace space = GizmoSpace.world,
    TransformGizmoSnap snap = TransformGizmoSnap.none,
    SubEditorGizmoTarget? target,
    this.onDragBegin,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel,
    this.pick,
    this.onPick,
    // ignore: prefer_initializing_formals
  })  : _mode = mode,
        // ignore: prefer_initializing_formals
        _space = space,
        // ignore: prefer_initializing_formals
        _snap = snap,
        // ignore: prefer_initializing_formals
        _target = target;

  GizmoMode get mode => _mode;
  GizmoSpace get space => _space;
  TransformGizmoSnap get snap => _snap;
  SubEditorGizmoTarget? get target => _target;

  /// The level editor's tool names (`select` shows the translate gizmo).
  static GizmoMode modeForTool(String tool) => switch (tool) {
        'rotate' => GizmoMode.rotate,
        'scale' => GizmoMode.scale,
        _ => GizmoMode.translate,
      };

  void setMode(GizmoMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }

  void setSpace(GizmoSpace space) {
    if (space == _space) return;
    _space = space;
    notifyListeners();
  }

  void toggleSpace() => setSpace(_space == GizmoSpace.world ? GizmoSpace.local : GizmoSpace.world);

  void setSnap(TransformGizmoSnap snap) {
    _snap = snap;
    notifyListeners();
  }

  /// Replaces the target; a target with the same id, pivot and rotation is
  /// not a change.
  void setTarget(SubEditorGizmoTarget? target) {
    final old = _target;
    if (old == null && target == null) return;
    if (old != null &&
        target != null &&
        old.id == target.id &&
        old.locked == target.locked &&
        old.pivot == target.pivot &&
        old.rotation == target.rotation) {
      return;
    }
    _target = target;
    notifyListeners();
  }
}
