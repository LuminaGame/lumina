import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/plugin_3d_viewport_mesh_loader.dart';
import 'package:lumina_editor_data/lumina_editor.dart'
    show LuminaAxes, LuminaUmgInstanceBinding, LuminaUmgInstanceScope, LuminaUmgViewport, LuminaViewportController, LuminaViewportNodeKind, LuminaViewportScene, LuminaWidgetEvents;

/// Renders a plugin's 3D viewport (`Plugin3DViewportOptions`) on the UMG
/// Viewport widget: the options become a Viewport scene description — the
/// mesh (a path or GLB bytes) as a skeletal node posed by
/// `jointLocalPose`, the skeleton overlay (`showBones`, `visibleBoneNames`,
/// the selected bone), the ghost skeletons and the bone gizmo — and the
/// Viewport's events become the plugin's callbacks (`onBoneSelected` from a
/// pick, `onBoneMoved` from the gizmo's previews, in the mesh's glTF frame).
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
  static const String _element = 'Viewport';
  static const String _memoryPrefix = 'memory://plugin-viewport/';

  late final Map<String, Object?> _instance = <String, Object?>{
    'class': 'Plugin3DViewport',
    'elements': <String, Object?>{
      _element: <String, Object?>{'type': 'viewport', 'name': _element, 'visibility': 'Visible'},
    },
  };
  late final LuminaUmgInstanceBinding _binding = LuminaUmgInstanceBinding(_instance);
  String? _selectedBone;
  LuminaViewportController? _controller;
  String? _nodeId;
  String? _meshKey;
  bool _cameraSet = false;

  /// The bone gizmo's start (glTF frame) while a drag runs.
  List<double>? _dragStart;

  Map<String, Object?> get _state => (_instance['elements']! as Map)[_element] as Map<String, Object?>;

  @override
  void initState() {
    super.initState();
    _selectedBone = widget.options.selectedBoneName;
    _sync();
  }

  @override
  void didUpdateWidget(covariant Plugin3DViewportContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.options.selectedBoneName != oldWidget.options.selectedBoneName) _selectedBone = widget.options.selectedBoneName;
    _sync();
    _binding.refresh();
  }

  @override
  void dispose() {
    _binding.dispose();
    super.dispose();
  }

  /// The mesh asset key: the path the options name, or the GLB bytes kept
  /// under a key of their own.
  String? get _meshAsset {
    final o = widget.options;
    if (o.meshPath != null && o.meshPath!.isNotEmpty) return o.meshPath;
    final bytes = o.glbBytes;
    if (bytes == null || bytes.isEmpty) return null;
    return '$_memoryPrefix${identityHashCode(bytes)}.glb';
  }

  /// Reads a mesh: the options' bytes, an absolute file, or a file of the
  /// project.
  Future<Uint8List> _provider(String path) async {
    if (path.startsWith(_memoryPrefix)) {
      final bytes = widget.options.glbBytes;
      if (bytes == null) throw StateError('no GLB bytes');
      return bytes;
    }
    // An absolute path, or one of the project (Plugin3DViewportMeshLoader's
    // rule), read asynchronously.
    final resolved = await Plugin3DViewportMeshLoader.resolve(path, projectDir: widget.projectDir);
    if (resolved == null) throw FileSystemException('not found', path);
    return File(resolved).readAsBytes();
  }

  static List<double> _rgba(Color c, [double? opacity]) => [c.r, c.g, c.b, opacity ?? c.a];

  /// Writes the options into the Viewport's description.
  void _sync() {
    final o = widget.options;
    final scene = LuminaViewportScene.of(_state);
    final asset = _meshAsset;
    if (asset != _meshKey) {
      _meshKey = asset;
      scene.clear();
      _nodeId = asset == null ? null : scene.addNode(LuminaViewportNodeKind.skeletalMesh, asset: asset);
      if (_nodeId != null) scene.frameNode(_nodeId!);
    }
    if (!_cameraSet) {
      _cameraSet = true;
      scene
        ..setEnvironment('color')
        ..gridVisible = true
        ..setInteraction(pick: true);
      final distance = o.cameraDistance;
      if (distance != null) scene.setOrbit(scene.yaw, scene.pitch, distance * 100.0);
    }
    final node = _nodeId;
    if (node == null) return;
    final n = scene.node(node)!;
    n['pose'] = o.jointLocalPose == null ? null : LuminaViewportScene.plain(o.jointLocalPose);
    if (o.showBones) {
      scene.showSkeleton(node, const [1.0, 0.85, 0.2, 1.0]);
    } else {
      scene.hideSkeleton(node);
      scene.showSkeleton(node, const [0.0, 0.0, 0.0, 0.0], joints: false);
    }
    final overlay = scene.skeletonOverlay(node)!;
    overlay['bones'] = o.visibleBoneNames?.toList();
    overlay['selected'] = _selectedBone;
    overlay['ghosts'] = [
      for (final g in o.ghostSkeletons ?? const <PluginGhostSkeleton>[])
        {'pose': LuminaViewportScene.plain(g.jointLocalPose), 'color': _rgba(g.color, g.opacity), 'label': g.label ?? ''},
    ];
    if (o.showGizmo && _selectedBone != null) {
      scene.setGizmo(node, bone: _selectedBone);
    } else {
      scene.hideGizmo();
    }
  }

  /// The selected bone's position in the mesh's glTF frame (metres, Y up).
  List<double>? _bonePosition(String bone) {
    final c = _controller;
    final node = _nodeId;
    if (c == null || node == null) return null;
    for (final j in c.runtime.jointsOf(node)) {
      if (j.name != bone) continue;
      final local = c.runtime.toMeshFrame(node, j.position);
      return local == null ? null : [local.x, local.y, local.z];
    }
    return null;
  }

  void _onEvent(String event, Map<String, Object?> args) {
    final o = widget.options;
    switch (event) {
      case LuminaWidgetEvents.onPicked:
        final bone = '${args['bone'] ?? ''}';
        if (bone.isEmpty) return;
        setState(() {
          _selectedBone = bone;
          _sync();
        });
        _binding.refresh();
        o.onBoneSelected?.call(bone);
      case LuminaWidgetEvents.onGizmoPreview:
      case LuminaWidgetEvents.onGizmoCommit:
        final bone = '${args['bone'] ?? ''}';
        final t = args['transform'];
        if (bone.isEmpty || t is! Map || t['location'] is! List) return;
        final start = _dragStart ??= _bonePosition(bone);
        if (start == null) return;
        final l = [for (final v in (t['location'] as List).take(3)) (v as num).toDouble()];
        // Authoring cm → the mesh's glTF frame (Y up, metres).
        final p = LuminaAxes.location(l) / 100.0;
        final node = _nodeId;
        final local = node == null ? null : _controller?.runtime.toMeshFrame(node, p * 100.0);
        if (local == null) return;
        final newPos = [local.x, local.y, local.z];
        final delta = [for (var i = 0; i < 3; i++) newPos[i] - start[i]];
        o.onBoneMoved?.call(bone, newPos, delta);
        if (event == LuminaWidgetEvents.onGizmoCommit) _dragStart = null;
      case LuminaWidgetEvents.onGizmoCancel:
        _dragStart = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hud = widget.options.overlayHUD;
    return LuminaUmgInstanceScope(
      binding: _binding,
      child: Stack(fit: StackFit.expand, children: [
        LuminaUmgViewport(
          key: const ValueKey('plugin_3d_viewport'),
          instance: _instance,
          name: _element,
          background: 'color',
          allowFiles: true,
          assetProvider: _provider,
          onEvent: _onEvent,
          onController: (c) => _controller = c,
        ),
        Positioned(
          left: 8,
          top: 6,
          child: IgnorePointer(
            child: Text(widget.options.title, style: const TextStyle(fontSize: 10, color: Color(0xFFB0B6C2))),
          ),
        ),
        ?hud,
      ]),
    );
  }
}
