part of '../landscape_component.dart';

/// The editor's sculpt brush cursor drawn on the terrain.
mixin _LandscapeBrushCursor on _LuminaLandscapeComponentState {

  // --- Brush cursor ------------------------------------------------------------

  /// The brush cursor currently shown, or null when it is hidden.
  LandscapeBrushCursor? get brushCursor => _brushCursor;

  /// The mesh drawing the brush cursor, once it has been shown.
  LuminaProceduralMeshComponent? get brushCursorMesh => _cursorMesh;

  /// Drapes [cursor] over the terrain: a translucent disc that
  /// is solid in the full-strength core and fades across the falloff band,
  /// with a crisp ring at the end of the core and one at the radius.
  ///
  /// The mesh is built once with a fixed topology; later calls move and
  /// reshape it with one in-place upload. It is unlit and blended, and drawn
  /// **without depth testing** over the terrain it is draped on, so the
  /// ground can neither cut it nor hide part of it (like a selection outline,
  /// it shows through a hill in front). It neither casts nor receives
  /// shadows. Does nothing until the terrain has a payload.
  void showBrushCursor(LandscapeBrushCursor cursor) {
    final d = _data;
    final ownerActor = owner;
    if (d == null || ownerActor == null) return;
    final origin = worldLocation;
    final geo = LandscapeBrushCursorGeometry.build(
      d,
      centerX: (cursor.centerX - origin.x) / unitsPerMetre,
      centerZ: (cursor.centerZ - origin.z) / unitsPerMetre,
      radius: cursor.radius / unitsPerMetre,
      falloff: cursor.falloff,
      color: cursor.color,
      unitsPerMetre: unitsPerMetre,
    );
    var mesh = _cursorMesh;
    if (mesh == null) {
      mesh = LuminaProceduralMeshComponent();
      mesh.attachToComponent(this);
      mesh.onRegister(ownerActor);
      _cursorMesh = mesh;
    }
    if (!mesh.hasSection(0) || mesh.sectionVertexCount(0) != geo.vertexCount) {
      mesh.createMeshSection(
        0,
        positions: geo.positions,
        uv0: geo.uv0,
        colors: geo.colors,
        indices: geo.indices,
        material: _buildCursorMaterial(),
        generateTangents: false,
        dynamic: true,
        // The whole terrain volume: the cursor roams over all of it and must
        // never be culled against the box it was first built in.
        bounds: terrainBounds,
        castShadows: false,
        receiveShadows: false,
      );
    } else {
      mesh.updateMeshSection(0, positions: geo.positions, colors: geo.colors);
      mesh.setSectionVisible(0, true);
    }
    _brushCursor = cursor;
  }

  /// Takes the brush cursor out of the scene (it is kept for the next show).
  void hideBrushCursor() {
    _brushCursor = null;
    _cursorMesh?.setSectionVisible(0, false);
  }

  FilamentMaterialInstance? _buildCursorMaterial() {
    if (_cursorMaterial != null) return _cursorMaterial;
    final w = owner?.world;
    if (w == null || !w.hasNativeContext) return null;
    try {
      _provider ??= FilamentMaterialProvider.ubershader(w.filamentEngine);
      // alphaMode 2 = glTF BLEND: translucent, no depth writes.
      final mi = _provider!
          .createMaterialInstance(
            MaterialKey(unlit: true, doubleSided: true, hasVertexColors: true, alphaMode: 2),
            label: 'lumina_landscape_brush_cursor',
          )
          .instance;
      if (mi == null) return null;
      mi.setFloat4('baseColorFactor', 1.0, 1.0, 1.0, 1.0);
      mi.setCullingMode(CullingMode.none);
      mi.setDepthWrite(false);
      // Draped on the bilinear surface, a draped mesh and the triangulated
      // terrain intersect wherever they disagree; drawn over it, it is always
      // whole.
      mi.setDepthCulling(false);
      _cursorMaterial = mi;
      return mi;
    } catch (e) {
      _loadError = 'brush cursor material unavailable: $e';
      return null;
    }
  }
}
