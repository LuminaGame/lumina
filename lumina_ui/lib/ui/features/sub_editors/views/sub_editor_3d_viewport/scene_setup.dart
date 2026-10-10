part of '../sub_editor_3d_viewport.dart';

/// What the viewport mounts once its native scene exists: the grid, the
/// studio or preview-world lighting, and the mesh or material preview.
mixin _SubEditor3DViewportSceneSetup
    on _SubEditor3DViewportStateBase, _SubEditor3DViewportNativeScene, _SubEditor3DViewportOverlays {
  void _onNativeSceneCreated(
    FilamentEngine engine,
    FilamentScene scene,
    FilamentCamera camera,
    FilamentView view,
  ) {
    try {
      _nativeEngine = engine;
      if (_engineLease == null || _engineLease!.isReleased) {
        _engineLease = FilamentEngineHost.retain(
          engine,
          owner: 'SubEditor3DViewport state',
        );
      }
      _nativeCamera = camera;
      _nativeScene = scene;
      camera.setProjection(
        fovDegrees: 45.0,
        aspect: _viewportAspect,
        near: 0.1,
        far: 3000.0,
      );
      _updateNativeCamera();

       // Native 3D GPU Grid with adaptive sizing
       final mesh = widget.glbMesh;
       final double gridExtent;
       final double gridStep;
       final previewSize = widget.previewShapeSize;
       if (widget.gridExtent != null &&
           widget.gridStep != null) {
         gridExtent = widget.gridExtent!;
         gridStep = widget.gridStep!;
       } else if (mesh == null && previewSize != null && previewSize > 0) {
         // Ten shape sizes across, cells of a round length.
         gridExtent = previewSize * 5.0;
         gridStep = SubEditor3DViewport.roundGridStep(previewSize / 4.0);
       } else if (mesh != null &&
           mesh.positions.isNotEmpty) {
         final spanX = (mesh.maxBounds[0] -
                 mesh.minBounds[0])
             .abs();
         final spanY = (mesh.maxBounds[1] -
                 mesh.minBounds[1])
             .abs();
         final spanZ = (mesh.maxBounds[2] -
                 mesh.minBounds[2])
             .abs();
         final maxSpan = math.max(
           spanX,
           math.max(spanY, spanZ),
         );
         if (maxSpan < 5.0) {
           gridExtent = math.max(
             5.0,
             maxSpan * 8.0,
           );
           gridStep = gridExtent > 15.0
               ? 0.5
               : 0.25;
         } else if (maxSpan < 50.0) {
           gridExtent = math.max(
             50.0,
             maxSpan * 4.0,
           );
           gridStep = 2.0;
         } else {
           gridExtent = math.max(
             500.0,
             maxSpan * 2.5,
           );
           gridStep = 50.0;
         }
       } else {
         gridExtent = 20.0;
         gridStep = 0.5;
       }
       _nativeGrid = FilamentEditorGrid.create(
         engine: engine,
         extent: gridExtent,
         step: gridStep,
       );
       if (widget.renderSceneLights == true) {
         _nativeGrid!.setColor(0.2, 0.2, 0.25, 0.5);
       }
       if (widget.showGrid) _nativeGrid!.addToScene(scene);

       view.setDynamicLightingOptions(
         LuminaUnits.dynamicLightingNear,
         LuminaUnits.dynamicLightingFar,
       );

      // Image-based lighting. Without a real
      // IndirectLight, Filament gives a PBR
      // surface no ambient diffuse and no
      // ambient specular at all, so anything the
      // key light does not face renders black —
      // the black-silhouette bug. The preview
      // world branch below lights itself through
      // its own LuminaSkyComponent.
      if (widget.onPreviewWorldReady ==
          null) {
        _sceneEnvironment.attach(
          engine,
          scene,
        );
        _sceneEnvironment.apply(
          LuminaSkyDescription.studioDefaults,
        );
      }

      // Level/environment preview: hand a lumina world over and let
      // its components (sun, sky, meshes, post-process) light the frame.
      if (widget.onPreviewWorldReady !=
          null) {
        final world = LuminaWorld(
          worldType: LuminaWorldType.editor,
        );
        world.initializeNativeContext(
          engine,
          scene,
          view: view,
        );
        _previewWorld = world;
        widget.onPreviewWorldReady!(world);
        _updateOverlayLines(force: true);
        return;
      }

      // Create Sun Light & Directional Fill Light for PBR Shading
      final lightManager =
          FilamentLightManager(engine);

      // Create 3-Point Studio Lighting (Key, Fill, Rim) with neutral daylight spectrum
      final keyEntity = engine.createEntity();
      lightManager.createLight(
        entity: keyEntity,
        type: LightType.directional,
        colorR: 1.0,
        colorG: 0.98,
        colorB: 0.95,
        intensity: 90000.0,
        dirX: -0.4,
        dirY: -0.6,
        dirZ: -0.7,
        castShadows: true,
      );
      scene.addEntity(keyEntity);
      _studioLights.add(keyEntity);

      final fillEntity = engine
          .createEntity();
      lightManager.createLight(
        entity: fillEntity,
        type: LightType.directional,
        colorR: 0.98,
        colorG: 0.98,
        colorB: 0.98,
        intensity: 40000.0,
        dirX: 0.5,
        dirY: 0.5,
        dirZ: -0.5,
        castShadows: false,
      );
      scene.addEntity(fillEntity);
      _studioLights.add(fillEntity);

      final rimEntity = engine.createEntity();
      lightManager.createLight(
        entity: rimEntity,
        type: LightType.directional,
        colorR: 1.0,
        colorG: 1.0,
        colorB: 1.0,
        intensity: 45000.0,
        dirX: 0.0,
        dirY: -0.8,
        dirZ: 0.6,
        castShadows: false,
      );
      scene.addEntity(rimEntity);
      _studioLights.add(rimEntity);

      if (_isMaterialPreview) {
        _mountMaterialPreview(engine, scene);
        return;
      }
      // Meshes come from the engine's
      // shared cache: a
      // mesh another viewport shows is
      // not uploaded again.
      _drawsMeshes = true;
      if (widget.meshComponents != null &&
          widget.meshComponents!.isNotEmpty) {
        _rebuildComponentAssets(engine, scene);
        _recalculateBoundsAndFraming();
      } else if (widget.glbMesh?.rawPayload != null &&
          widget.glbMesh!.rawPayload!.isNotEmpty) {
        _loadNativeMesh(engine, scene, widget.glbMesh!.rawPayload!);
      }
    } catch (e) {
      debugPrint(
        '[Lumina Studio UI] Native Filament C++ FFI error: $e',
      );
    }
  }
}
