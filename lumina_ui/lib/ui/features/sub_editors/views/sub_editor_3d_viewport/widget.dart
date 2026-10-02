part of '../sub_editor_3d_viewport.dart';

enum PreviewShape { mesh, sphere, cube, cylinder, plane }

enum ViewportShadingMode { lit, wireframe, unlit }

class SubEditor3DViewport extends StatefulWidget {
  final String title;
  final GlbMeshData? glbMesh;

  /// Where [glbMesh] came from (the asset's `.lmas` or GLB), recorded by the
  /// engine's shared mesh cache; sharing itself is decided by the payload's
  /// content.
  final String? meshSourcePath;
  final List<SubEditorMeshComponent>? meshComponents;
  final GlbNode? selectedNode;
  final PreviewShape initialShape;
  final bool showShapeSelector;
  final Widget? overlayHUD;
  final void Function(GlbNode, bool)? onNodeVisibilityChanged;
  final AnimationPlaybackController? playbackController;
  final bool showBones;
  final bool showSockets;
  final List<SkeletalMeshSocket> sockets;
  final SkeletalMeshSocket? selectedSocket;

  /// Meshes previewed on sockets: each
  /// is parented to its bone's joint in the native preview with the socket
  /// offset as its local transform, so it is drawn at
  /// `entityWorld × G_bone × offset` and follows the pose.
  final List<SkeletalSocketAttachment> socketAttachments;

  /// Active morph target / blendshape weights mapped by target name (0.0 to 1.0).
  final Map<String, double>? morphWeights;

  /// Procedural joint deltas (e.g. from RigLogic DNA facial or body evaluation),
  /// keyed by joint name, containing 9 floats:
  /// Tx, Ty, Tz (cm), Rx, Ry, Rz (Euler deg), Sx, Sy, Sz (scale delta).
  final Map<String, List<double>>? jointDeltas;

  /// A whole pose to show instead of [playbackController]'s clip: each
  /// joint's local transform by name, 10 floats — translation (x, y, z),
  /// rotation quaternion (x, y, z, w), scale (x, y, z) — in the GLB's units.
  /// Written through the same joint transforms and `updateBoneMatrices` the
  /// clip playback uses, whenever a different map is passed and after the
  /// mesh (re)loads. The Animation editor's authored sequences pose with it.
  final Map<String, List<double>>? jointLocalPose;

  /// Geometry section indices to leave out of the preview, driven by the mesh
  /// editors' per-slot Isolate toggle.
  ///
  /// Applies to the CPU geometry path. The native gltfio path renders one
  /// renderable per mesh node with one primitive per section, and hiding a single
  /// primitive needs per-primitive control flutter_filament does not expose yet.
  final Set<int> hiddenSectionIndices;

  /// Geometry section indices to tint in the preview, driven by the mesh
  /// editors' per-slot Highlight toggle. Same CPU-path caveat as
  /// [hiddenSectionIndices].
  final Set<int> highlightedSectionIndices;

  /// Compiled `.filamat` bytes to swap onto a geometry section's primitive,
  /// keyed by section index. Drives the mesh editors' per-slot material binding
  /// on the native path: sections are the primitives of the asset's renderable
  /// entities, walked in glTF order — the same order the parser builds
  /// `subPrimitives` in.
  final Map<int, Uint8List> sectionMaterialOverrides;

  /// Compiled `.filamat` package to shade the procedural preview primitive
  /// with (Material Editor). When set and no [glbMesh] payload exists, the
  /// viewport still mounts the real Filament renderer.
  final Uint8List? previewMaterialBytes;

  /// Editor parameter values pushed into the preview material instance.
  final List<MaterialParamModel> previewMaterialParams;

  /// Bump to re-apply [previewMaterialParams] without recreating the widget.
  final int previewMaterialRevision;

  /// Level/environment preview (Environment Lighting mixer): when set, the
  /// viewport mounts the native renderer without a mesh payload, wraps the
  /// engine/scene/view in a lumina [LuminaWorld] (editor world type) and
  /// hands it over. The caller populates the world through lumina components
  /// (lights, sky, meshes, post-process); the built-in studio lights are
  /// skipped so the world's own lighting drives the frame.
  final void Function(LuminaWorld world)? onPreviewWorldReady;

  /// Fired right before the preview world is cleaned up on dispose.
  final void Function(LuminaWorld world)? onPreviewWorldDisposing;

  /// Use a Y-up camera (lumina world convention) instead of inferring the up
  /// axis from the mesh bounds.
  final bool yUpCamera;

  /// Initial orbit distance override (world units).
  final double? initialCameraDistance;

  /// What the orbit camera looks at in a preview world (runtime space, world
  /// units), with [initialCameraDistance]; the origin when null. The Anim
  /// Blueprint preview frames the character's torso rather than its feet.
  final Vector3? initialCameraTarget;

  /// Replaces the bottom stats strip (used by previews whose content is not
  /// a single mesh, so the mesh-derived counts would be meaningless).
  final String? statsLabel;

  /// Primary-button click (no drag) on the viewport, unprojected through the
  /// Y-up orbit camera onto the horizontal plane `y == floorTapPlaneY`
  /// (world units). Used by the Navigation path tester; null disables it.
  final void Function(Vector3 worldPoint)? onFloorTap;

  /// Height of the floor plane [onFloorTap] rays are intersected with.
  final double floorTapPlaneY;

  /// A paint/sculpt tool driven by the mouse (the Landscape editor's
  /// brushes): the Y-up camera's ray under the mouse on hover, and plain LMB
  /// strokes instead of an orbit. Alt+LMB, RMB, MMB and the wheel keep the
  /// camera. Null keeps the plain camera (every other sub-editor).
  final ViewportBrushInput? brushInput;

  /// Whether the editor grid is drawn. A preview whose content is its own
  /// ground (a landscape) turns it off: the grid would z-fight with flat
  /// terrain at y = 0.
  final bool showGrid;

  /// Line segments drawn over the mesh natively (a Static Mesh's collision
  /// view), in the viewport's own frame (the GLB as drawn: metres,
  /// Y up); null draws none. Rebuilt when a different instance is passed.
  final ({List<double> positions, List<int> indices})? collisionLines;

  /// Grid half-extent and cell size in world units, overriding the sizing
  /// guessed from [glbMesh]. A preview world whose content is in cm (the
  /// Physics Asset editor's character) passes a cm grid; null keeps the guess.
  final double? gridExtent;
  final double? gridStep;

  /// Coloured line sets drawn over the scene (a Blueprint's capsule, spring
  /// arm and camera), in the viewport's own frame. A set's native
  /// lines are rebuilt when its [SubEditorLineSet.signature] changes.
  final List<SubEditorLineSet> overlayLines;

  /// The orbit camera's starting (and Reset View) yaw in degrees; -35 when
  /// null. A Y-up preview at 145° looks at an actor facing −Z from its front.
  final double? initialCameraYaw;

  /// The transform gizmo drawn over the scene: its
  /// target gets translate / rotate / scale handles driven by the HUD's
  /// Q/W/E/R cluster, snap fields and Local/World toggle; a click that hits
  /// no handle picks through it. Null draws none (every other sub-editor).
  final SubEditorTransformGizmo? transformGizmo;

  /// Ghost skeletons drawn over the scene (onion skins), in the frame the
  /// bones are drawn in.
  final List<SubEditorGhostSkeleton> ghostSkeletons;

  /// Points drawn over the scene (IK targets and poles), GLB frame.
  final List<SubEditorOverlayMarker> overlayMarkers;

  /// Polylines drawn over the scene (a drawn root path), GLB frame.
  final List<SubEditorOverlayPath> overlayPaths;

  const SubEditor3DViewport({
    super.key,
    required this.title,
    this.glbMesh,
    this.meshSourcePath,
    this.meshComponents,
    this.selectedNode,
    PreviewShape? initialShape,
    this.showShapeSelector = true,
    this.overlayHUD,
    this.onNodeVisibilityChanged,
    this.playbackController,
    this.showBones = false,
    this.showSockets = false,
    this.sockets = const [],
    this.selectedSocket,
    this.socketAttachments = const [],
    this.morphWeights,
    this.jointDeltas,
    this.jointLocalPose,
    this.hiddenSectionIndices = const {},
    this.highlightedSectionIndices = const {},
    this.sectionMaterialOverrides = const {},
    this.previewMaterialBytes,
    this.previewMaterialParams = const [],
    this.previewMaterialRevision = 0,
    this.onPreviewWorldReady,
    this.onPreviewWorldDisposing,
    this.yUpCamera = false,
    this.initialCameraDistance,
    this.initialCameraTarget,
    this.statsLabel,
    this.onFloorTap,
    this.floorTapPlaneY = 0.0,
    this.brushInput,
    this.showGrid = true,
    this.collisionLines,
    this.gridExtent,
    this.gridStep,
    this.overlayLines = const [],
    this.initialCameraYaw,
    this.transformGizmo,
    this.ghostSkeletons = const [],
    this.overlayMarkers = const [],
    this.overlayPaths = const [],
  }) : initialShape =
           initialShape ??
            ((glbMesh != null || meshComponents != null)
                ? PreviewShape.mesh
                : PreviewShape.sphere);

  /// True when the viewport mounts the native Filament renderer: either a
  /// mesh payload or a compiled material to preview on a procedural primitive.
  static bool usesNativePreview({
    GlbMeshData? glbMesh,
    List<SubEditorMeshComponent>? meshComponents,
    Uint8List? previewMaterialBytes,
  }) {
    final hasPayload =
        (glbMesh?.rawPayload != null && glbMesh!.rawPayload!.isNotEmpty) ||
        (meshComponents != null &&
            meshComponents.any(
              (c) =>
                  c.glbMesh.rawPayload != null &&
                  c.glbMesh.rawPayload!.isNotEmpty,
            ));
    // Only a real compiled package may reach Filament (garbage aborts the process).
    final hasMaterial = MaterialPreviewRenderer.isFilamatPackage(
      previewMaterialBytes,
    );
    return hasPayload || hasMaterial;
  }

  @override
  State<SubEditor3DViewport> createState() => _SubEditor3DViewportState();
}
