part of '../physics_asset_editor_view_model.dart';

/// The Physics Asset editor's body property, constraint and
/// collision-disable edits.
extension PhysicsAssetEditorBodyEdits on PhysicsAssetEditorViewModel {
  // ------------------------------------------------------- body properties

  void _withBody(String boneName, void Function(PhysicsBody body) edit) {
    final body = _document.bodyForBone(boneName);
    if (body == null) return;
    edit(body);
    _markDirty();
  }

  void setBodyShape(String boneName, PhysicsShapeType shape) => replaceBody(boneName, shape);

  void setBodyRadius(String boneName, double value) =>
      _withBody(boneName, (b) => b.radius = math.max(PhysicsAssetEditorViewModel._minLength, value));

  void setBodyHalfHeight(String boneName, double value) =>
      _withBody(boneName, (b) => b.halfHeight = math.max(PhysicsAssetEditorViewModel._minLength, value));

  void setBodyExtent(String boneName, int axis, double value) =>
      _withBody(boneName, (b) => b.halfExtents[axis] = math.max(PhysicsAssetEditorViewModel._minLength, value));

  void setBodyOffsetLocation(String boneName, int axis, double value) =>
      _withBody(boneName, (b) => b.offsetLocation[axis] = value);

  void setBodyOffsetRotation(String boneName, int axis, double value) =>
      _withBody(boneName, (b) => b.offsetRotationDeg[axis] = value);

  void setBodyMass(String boneName, double value) =>
      _withBody(boneName, (b) => b.massKg = math.max(0.0, value));

  void setBodyLinearDamping(String boneName, double value) =>
      _withBody(boneName, (b) => b.linearDamping = math.max(0.0, value));

  void setBodyAngularDamping(String boneName, double value) =>
      _withBody(boneName, (b) => b.angularDamping = math.max(0.0, value));

  void setBodyPhysicsMaterial(String boneName, String name) =>
      _withBody(boneName, (b) => b.physicsMaterial = name);

  // -------------------------------------------------------- constraints

  /// Adds a constraint between the bodies on [boneA] (parent) and [boneB].
  bool addConstraint(String boneA, String boneB) {
    if (boneA == boneB) {
      _lastError = 'A constraint needs two distinct bones.';
      _notify();
      return false;
    }
    if (_document.bodyForBone(boneA) == null || _document.bodyForBone(boneB) == null) {
      _lastError = 'Both bones must already carry a body.';
      _notify();
      return false;
    }
    final exists = _document.constraints.any((c) =>
        (c.bodyA == boneA && c.bodyB == boneB) || (c.bodyA == boneB && c.bodyB == boneA));
    if (exists) {
      _lastError = 'These bodies are already constrained.';
      _notify();
      return false;
    }
    final constraint = PhysicsConstraint(bodyA: boneA, bodyB: boneB);
    _document.constraints.add(constraint);
    _selectedConstraintName = constraint.name;
    _selectedBodyBone = null;
    _lastError = null;
    _markDirty();
    return true;
  }

  bool removeConstraint(String name) {
    final before = _document.constraints.length;
    _document.constraints.removeWhere((c) => c.name == name);
    if (_document.constraints.length == before) return false;
    if (_selectedConstraintName == name) _selectedConstraintName = null;
    _markDirty();
    return true;
  }

  void _withConstraint(String name, void Function(PhysicsConstraint c) edit) {
    final c = _document.constraintByName(name);
    if (c == null) return;
    edit(c);
    _markDirty();
  }

  void setConstraintMode(String name, PhysicsAngularMode mode) =>
      _withConstraint(name, (c) => c.angularMode = mode);

  double _clampDegrees(double v) => v.clamp(-180.0, 180.0).toDouble();

  void setConstraintSwing1(String name, double deg) =>
      _withConstraint(name, (c) => c.swing1Deg = _clampDegrees(deg));

  void setConstraintSwing2(String name, double deg) =>
      _withConstraint(name, (c) => c.swing2Deg = _clampDegrees(deg));

  void setConstraintTwist(String name, double deg) =>
      _withConstraint(name, (c) => c.twistDeg = _clampDegrees(deg));

  bool constraintLimitsEnabled(PhysicsConstraint constraint) => constraint.limitsEnabled;

  // ------------------------------------------------- collision disables

  bool disableCollisionBetween(String boneA, String boneB) {
    if (boneA == boneB) return false;
    if (_document.bodyForBone(boneA) == null || _document.bodyForBone(boneB) == null) {
      _lastError = 'Both bones must already carry a body.';
      _notify();
      return false;
    }
    if (_document.isPairDisabled(boneA, boneB)) return false;
    _document.disabledCollisionPairs.add([boneA, boneB]);
    _markDirty();
    return true;
  }

  bool enableCollisionBetween(String boneA, String boneB) {
    final before = _document.disabledCollisionPairs.length;
    _document.disabledCollisionPairs.removeWhere((p) =>
        (p[0] == boneA && p[1] == boneB) || (p[0] == boneB && p[1] == boneA));
    if (_document.disabledCollisionPairs.length == before) return false;
    _markDirty();
    return true;
  }

  bool isCollisionDisabled(String boneA, String boneB) => _document.isPairDisabled(boneA, boneB);
}
