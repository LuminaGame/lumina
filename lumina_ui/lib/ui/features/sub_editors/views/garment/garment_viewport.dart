part of 'garment_sub_editor.dart';

/// The centre: the body with the garment in the editor world, the gizmo
/// that moves, turns and resizes the garment, landmark crosses (garment
/// points amber, body points cyan, a line between each pair) and clicks
/// that place the selected landmark.
mixin _GarmentViewport on _GarmentEditorBase {
  @override
  final GarmentPreviewScene scene = GarmentPreviewScene();

  ({List<double> location, List<double> rotation, List<double> scale})? _dragStart;

  @override
  late final SubEditorTransformGizmo gizmo = SubEditorTransformGizmo(
    mode: GizmoMode.translate,
    space: GizmoSpace.world,
    onDragBegin: (_) => _dragStart = (location: vm.doc.location, rotation: vm.doc.rotation, scale: vm.doc.scale),
    onDragUpdate: (_, delta) => _drag(delta),
    onDragEnd: (_) => _dragStart = null,
    onDragCancel: (_) {
      final start = _dragStart;
      if (start != null) vm.setPlacement(location: start.location, rotation: start.rotation, scale: start.scale);
      _dragStart = null;
    },
  );

  @override
  void setGizmo(GizmoMode mode) {
    vm.setPickMode(GarmentPickMode.none);
    gizmo.setMode(mode);
    setState(() {});
  }

  /// A gizmo drag (authoring frame) becomes the placement in the body's
  /// space (the runtime frame: Y up, cm).
  void _drag(SubEditorGizmoDelta delta) {
    final start = _dragStart;
    if (start == null) return;
    if (delta.translation != null) {
      final d = AuthoringRotation.toRuntime(delta.translation!);
      vm.setPlacement(location: [start.location[0] + d.x, start.location[1] + d.y, start.location[2] + d.z]);
    } else if (delta.rotationAxis != null) {
      final axis = AuthoringRotation.toRuntime(delta.rotationAxis!).normalized();
      final half = (delta.rotationDegrees ?? 0) * math.pi / 360;
      final dq = [axis.x * math.sin(half), axis.y * math.sin(half), axis.z * math.sin(half), math.cos(half)];
      final q = LuminaGarmentMath.multiply(dq, LuminaGarmentMath.quaternionFromEuler(start.rotation));
      vm.setPlacement(rotation: LuminaGarmentMath.eulerFromQuaternion(q));
    } else if (delta.scaleHandle != null) {
      final amount = delta.scaleDelta ?? 0;
      final s = [...start.scale];
      final h = delta.scaleHandle!;
      // Authoring X, Y, Z are the body's X, −Z, Y.
      if (h == TransformGizmoModel.uniform || h == TransformGizmoModel.axisX) s[0] += amount;
      if (h == TransformGizmoModel.uniform || h == TransformGizmoModel.axisY) s[2] += amount;
      if (h == TransformGizmoModel.uniform || h == TransformGizmoModel.axisZ) s[1] += amount;
      vm.setPlacement(scale: [for (final v in s) math.max(0.01, v)]);
    }
  }

  SubEditorGizmoTarget? _target() {
    if (vm.pickMode != GarmentPickMode.none || vm.doc.sourceMesh.isEmpty || vm.fittedPreview != null) return null;
    final l = vm.doc.location;
    final q = LuminaGarmentMath.quaternionFromEuler(vm.doc.rotation);
    final pivot = LuminaAxes.toAuthoringLocation(Vector3(l[0], l[1], l[2]));
    return SubEditorGizmoTarget(
      id: 'garment',
      pivot: Vector3(pivot[0], pivot[1], pivot[2]),
      rotation: AuthoringRotation.quaternionToAuthoring(Quaternion(q[0], q[1], q[2], q[3])),
    );
  }

  /// The scene follows the document: the meshes shown and the placement.
  @override
  void syncScene() {
    scene.setBody(vm.absolute(vm.previewBody));
    final fitted = vm.fittedPreview;
    if (fitted != null) {
      // Fitted to the preview body: already in its space.
      scene.setGarment(fitted.path, provider: _fittedProvider(fitted));
      scene.place(vm.doc, placed: false);
    } else {
      scene.setGarment(vm.absolute(vm.doc.sourceMesh));
      scene.place(vm.doc);
    }
  }

  LuminaFittedGarment? _servedFit;
  LuminaAssetProvider? _servedProvider;

  /// One provider per fit, so the scene keeps the mesh while the fit stays.
  LuminaAssetProvider _fittedProvider(LuminaFittedGarment fitted) {
    if (!identical(fitted, _servedFit)) {
      _servedFit = fitted;
      _servedProvider = (p) async => p == fitted.path ? fitted.bytes : File(p).readAsBytes();
    }
    return _servedProvider!;
  }

  void _attach(LuminaWorld world) {
    scene.attach(world);
    syncScene();
  }

  void _onRay(ViewportRay ray) {
    if (vm.pickMode == GarmentPickMode.none) return;
    final o = ray.origin, d = ray.direction;
    vm.pick(o.x, o.y, o.z, d.x, d.y, d.z);
  }

  List<SubEditorLineSet> _landmarkLines() {
    final positions = <double>[];
    final indices = <int>[];
    void cross(List<double> p, double r) {
      final base = positions.length ~/ 3;
      for (var axis = 0; axis < 3; axis++) {
        for (final sign in const [-1.0, 1.0]) {
          final v = [...p];
          v[axis] += sign * r;
          positions.addAll(v);
        }
        indices.addAll([base + axis * 2, base + axis * 2 + 1]);
      }
    }

    final garment = <double>[], gIdx = <int>[], body = <double>[], bIdx = <int>[], links = <double>[], lIdx = <int>[];
    for (final l in vm.doc.landmarks) {
      final selected = l.name == vm.selectedLandmark;
      final r = selected ? 2.5 : 1.5;
      final g = l.garment == null ? null : vm.doc.place(l.garment!);
      if (g != null) {
        positions.clear();
        indices.clear();
        cross(g, r);
        final base = garment.length ~/ 3;
        garment.addAll(positions);
        gIdx.addAll([for (final i in indices) base + i]);
      }
      if (l.body != null) {
        positions.clear();
        indices.clear();
        cross(l.body!, r);
        final base = body.length ~/ 3;
        body.addAll(positions);
        bIdx.addAll([for (final i in indices) base + i]);
      }
      if (g != null && l.body != null) {
        final base = links.length ~/ 3;
        links.addAll([...g, ...l.body!]);
        lIdx.addAll([base, base + 1]);
      }
    }
    String sig(List<double> p) => '${p.length}:${p.fold<double>(0, (s, v) => s + v).toStringAsFixed(3)}';
    return [
      if (garment.isNotEmpty)
        SubEditorLineSet(id: 'garment_points', positions: garment, indices: gIdx, r: 0.96, g: 0.62, b: 0.04, signature: sig(garment), xray: true),
      if (body.isNotEmpty)
        SubEditorLineSet(id: 'body_points', positions: body, indices: bIdx, r: 0.13, g: 0.83, b: 0.93, signature: sig(body), xray: true),
      if (links.isNotEmpty)
        SubEditorLineSet(id: 'landmark_links', positions: links, indices: lIdx, r: 1, g: 1, b: 0.4, signature: sig(links), xray: true),
    ];
  }

  Widget viewport() {
    final fit = vm.fittedPreview?.report;
    final summary = [
      if (fit != null) 'fitted: ${fit.maxPenetration.toStringAsFixed(2)} cm inside, ${fit.milliseconds} ms${fit.denseCorrespondence ? ', vertex for vertex' : ''}',
      if (vm.sourceMesh != null) 'garment ${vm.sourceMesh!.data.vertexCount} vertices',
      if (vm.bodyMesh != null) 'body ${vm.bodyMesh!.data.vertexCount} vertices',
      '${vm.doc.landmarks.where((l) => l.isComplete).length}/${vm.doc.landmarks.length} landmarks placed',
    ].join(' · ');
    if (!widget.showViewport) {
      return Container(
        key: const ValueKey('garment_viewport_text'),
        color: EditorColors.graphCanvas,
        alignment: Alignment.center,
        child: Text('Preview (no renderer): $summary', style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
      );
    }
    gizmo.setTarget(_target());
    return SubEditor3DViewport(
      key: const ValueKey('garment_viewport'),
      title: 'Garment Fitting Viewport',
      transformGizmo: gizmo,
      showShapeSelector: false,
      yUpCamera: true,
      initialCameraYaw: 0.0,
      initialCameraDistance: 260.0,
      initialCameraTarget: Vector3(0, 110, 0),
      gridExtent: 300.0,
      gridStep: 25.0,
      overlayLines: _landmarkLines(),
      statsLabel: summary,
      onRayTap: _onRay,
      onPreviewWorldReady: _attach,
      onPreviewWorldDisposing: (_) => scene.detach(),
    );
  }
}
