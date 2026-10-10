import 'package:flutter/widgets.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lumina_ui/ui/core/plugin_3d_viewport_mesh_loader.dart';
import 'package:lumina_ui/ui/features/main_editor/services/transform_gizmo.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/sub_editor_transform_gizmo.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';

/// Renders a Filament 3D viewport inside a plugin editor with full support for
/// skeleton bones, joint picking, and interactive 3D translation gizmo manipulation.
class Plugin3DViewportContainer extends StatefulWidget {
  final Plugin3DViewportOptions options;
  final String? projectDir;

  const Plugin3DViewportContainer({
    super.key,
    required this.options,
    this.projectDir,
  });

  @override
  State<Plugin3DViewportContainer> createState() => _Plugin3DViewportContainerState();
}

class _Plugin3DViewportContainerState extends State<Plugin3DViewportContainer> {
  GlbMeshData? _mesh;
  String? _loadedKey;
  int _loadToken = 0;
  String? _selectedBoneName;
  Vector3? _dragStartWorldPos;
  SubEditorTransformGizmo? _transformGizmo;

  @override
  void initState() {
    super.initState();
    _selectedBoneName = widget.options.selectedBoneName;
    _initGizmo();
    _loadMesh();
  }

  void _initGizmo() {
    _transformGizmo = SubEditorTransformGizmo(
      mode: GizmoMode.translate,
      space: GizmoSpace.world,
      onDragBegin: (id) {
        _dragStartWorldPos = _getBoneWorldPosition(id);
      },
      onDragUpdate: (id, delta) {
        if (delta.translation != null && _dragStartWorldPos != null) {
          final runtimeDelta = AuthoringRotation.toRuntime(delta.translation!);
          final newPos = _dragStartWorldPos! + runtimeDelta;
          widget.options.onBoneMoved?.call(
            id,
            [newPos.x, newPos.y, newPos.z],
            [runtimeDelta.x, runtimeDelta.y, runtimeDelta.z],
          );
        }
      },
      onDragEnd: (id) {
        _dragStartWorldPos = null;
      },
    );
  }

  @override
  void didUpdateWidget(covariant Plugin3DViewportContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.options.selectedBoneName != oldWidget.options.selectedBoneName) {
      _selectedBoneName = widget.options.selectedBoneName;
      _syncGizmoTarget();
    }
    if (widget.options.meshPath != oldWidget.options.meshPath ||
        widget.options.glbBytes != oldWidget.options.glbBytes ||
        widget.projectDir != oldWidget.projectDir) {
      _loadMesh();
    } else if (widget.options.jointLocalPose != oldWidget.options.jointLocalPose) {
      _syncGizmoTarget();
    }
  }

  @override
  void dispose() {
    _transformGizmo?.dispose();
    super.dispose();
  }

  Vector3? _getBoneWorldPosition(String boneName) {
    if (_mesh == null) return null;
    final positions = computeSkeletonBonePositions(
      glbMesh: _mesh!,
      jointLocalPose: widget.options.jointLocalPose,
    );
    return positions[boneName];
  }

  void _syncGizmoTarget() {
    final bone = _selectedBoneName;
    if (bone == null || _mesh == null || !widget.options.showGizmo) {
      _transformGizmo?.setTarget(null);
      return;
    }
    final worldPos = _getBoneWorldPosition(bone);
    if (worldPos != null) {
      _transformGizmo?.setTarget(
        SubEditorGizmoTarget(
          id: bone,
          pivot: AuthoringRotation.toAuthoring(worldPos),
          rotation: Quaternion.identity(),
        ),
      );
    } else {
      _transformGizmo?.setTarget(null);
    }
  }

  /// Shows the mesh the options name. The read and the parse run off the UI
  /// isolate ([Plugin3DViewportMeshLoader]); the viewport shows no mesh until
  /// it arrives, and a result for a mesh no longer selected is dropped.
  Future<void> _loadMesh() async {
    final opts = widget.options;
    final key = opts.meshPath ?? opts.glbBytes?.hashCode.toString();
    if (key == null) {
      _loadToken++;
      if (mounted) setState(() => _mesh = null);
      return;
    }
    if (key == _loadedKey && _mesh != null) {
      _syncGizmoTarget();
      return;
    }

    final token = ++_loadToken;
    if (mounted && _loadedKey != key) {
      setState(() {
        _mesh = null;
        _loadedKey = key;
      });
    }

    try {
      final bytes = opts.glbBytes;
      final meshPath = opts.meshPath;
      final GlbMeshData? mesh;
      if (bytes != null) {
        mesh = bytes.isEmpty ? null : await Plugin3DViewportMeshLoader.parseBytes(bytes);
      } else {
        mesh = await Plugin3DViewportMeshLoader.load(meshPath!, projectDir: widget.projectDir);
      }
      if (mesh != null && mounted && token == _loadToken) {
        setState(() {
          _mesh = mesh;
          _loadedKey = key;
        });
        _syncGizmoTarget();
      }
    } catch (e) {
      EngineLoggerService().log('Plugin viewport could not load ${opts.meshPath ?? 'its mesh'}: $e', level: 'warn');
    }
  }

  void _handleBoneSelected(String boneName) {
    setState(() {
      _selectedBoneName = boneName;
      _syncGizmoTarget();
    });
    widget.options.onBoneSelected?.call(boneName);
  }

  @override
  Widget build(BuildContext context) {
    _syncGizmoTarget();

    return SubEditor3DViewport(
      title: widget.options.title,
      glbMesh: _mesh,
      meshSourcePath: widget.options.meshPath,
      jointLocalPose: widget.options.jointLocalPose,
      overlayHUD: widget.options.overlayHUD,
      initialCameraDistance: widget.options.cameraDistance,
      showBones: widget.options.showBones,
      selectedBoneName: _selectedBoneName,
      visibleBoneNames: widget.options.visibleBoneNames,
      onBoneSelected: _handleBoneSelected,
      onBoneMoved: widget.options.onBoneMoved,
      transformGizmo: widget.options.showGizmo ? _transformGizmo : null,
      showTransformGizmo: widget.options.showGizmo && _selectedBoneName != null,
      ghostSkeletons: [
        if (widget.options.ghostSkeletons != null)
          for (final g in widget.options.ghostSkeletons!)
            SubEditorGhostSkeleton(
              jointLocalPose: g.jointLocalPose,
              color: g.color,
              opacity: g.opacity,
              label: g.label,
              volumetric: g.volumetric,
            ),
      ],
      yUpCamera: false,
    );
  }
}

