part of '../physics_asset_editor_view_model.dart';

/// The Physics Asset editor's bind-pose overlap validation, document checks
/// and viewport overlays.
extension PhysicsAssetEditorValidation on PhysicsAssetEditorViewModel {
  // ----------------------------------------------------------- validation

  /// Runs lumina's real narrow phase over every authored body pair in bind
  /// pose. Disabled pairs are skipped (and labelled); clean pairs are omitted.
  List<PhysicsOverlapResult> validateOverlaps() {
    final bodies = _document.bodies;
    final results = <PhysicsOverlapResult>[];
    final contact = ContactResult();
    for (int i = 0; i < bodies.length; i++) {
      for (int j = i + 1; j < bodies.length; j++) {
        final a = bodies[i];
        final b = bodies[j];
        if (_document.isPairDisabled(a.boneName, b.boneName)) {
          results.add(PhysicsOverlapResult(
            bodyA: a.name,
            bodyB: b.name,
            boneA: a.boneName,
            boneB: b.boneName,
            penetrationDepth: 0.0,
            isColliding: false,
            disabled: true,
          ));
          continue;
        }
        contact.reset();
        final hit = testPair(
          a.toCollisionShape(),
          bodyWorldTransform(a),
          b.toCollisionShape(),
          bodyWorldTransform(b),
          contact,
        );
        if (!hit) continue;
        results.add(PhysicsOverlapResult(
          bodyA: a.name,
          bodyB: b.name,
          boneA: a.boneName,
          boneB: b.boneName,
          penetrationDepth: contact.penetrationDepth,
          isColliding: true,
          disabled: false,
        ));
      }
    }
    _lastValidation = results;
    _hasValidated = true;
    _notify();
    return results;
  }

  /// Blocking document errors, surfaced inline and gating Save.
  List<String> get validationErrors {
    final errors = <String>[];
    final bodyBones = _document.bodies.map((b) => b.boneName).toSet();
    final seen = <String>{};
    for (final b in _document.bodies) {
      if (!seen.add(b.boneName)) {
        errors.add('Bone "${b.boneName}" carries more than one body.');
      }
    }
    for (final c in _document.constraints) {
      if (!bodyBones.contains(c.bodyA)) {
        errors.add('Constraint ${c.name} references missing body "${c.bodyA}".');
      }
      if (!bodyBones.contains(c.bodyB)) {
        errors.add('Constraint ${c.name} references missing body "${c.bodyB}".');
      }
      if (c.bodyA == c.bodyB) {
        errors.add('Constraint ${c.name} joins a body to itself.');
      }
    }
    for (final p in _document.disabledCollisionPairs) {
      for (final bone in p) {
        if (!bodyBones.contains(bone)) {
          errors.add('Disabled collision pair references missing body "$bone".');
        }
      }
    }
    return errors;
  }

  // -------------------------------------------------------------- overlays

  /// World-space line sets for the current view mode.
  List<PhysicsOverlayLineSet> buildOverlay() {
    final sets = <PhysicsOverlayLineSet>[];
    if (_viewMode != PhysicsViewMode.constraintsOnly) {
      for (final body in _document.bodies) {
        sets.add(PhysicsOverlayBuilder.buildBody(
          body,
          bodyWorldTransform(body),
          isSelected: _selectedBodyBone == body.boneName,
          dimmed: _document.disabledCollisionPairs.any((p) => p.contains(body.boneName)),
          filled: _viewMode == PhysicsViewMode.solidBodies,
        ));
      }
    }
    for (final c in _document.constraints) {
      final a = _document.bodyForBone(c.bodyA);
      final b = _document.bodyForBone(c.bodyB);
      if (a == null || b == null) continue;
      sets.add(PhysicsOverlayBuilder.buildConstraint(
        c,
        bodyWorldTransform(a),
        bodyWorldTransform(b),
        isSelected: _selectedConstraintName == c.name,
      ));
    }
    return sets;
  }

  /// Translucent solid bodies — only the `Solid Bodies` view mode draws them.
  List<PhysicsSolidMesh> buildSolidBodies() {
    if (_viewMode != PhysicsViewMode.solidBodies) return const [];
    return [
      for (final body in _document.bodies)
        PhysicsOverlayBuilder.buildSolidBody(
          body,
          bodyWorldTransform(body),
          isSelected: _selectedBodyBone == body.boneName,
          dimmed: _document.disabledCollisionPairs.any((p) => p.contains(body.boneName)),
        ),
    ];
  }
}
