import 'dart:io';
import 'dart:typed_data';

import 'package:lumina_editor_data/lumina_editor.dart' show LuminaUmgViewport, LuminaViewportNodeKind, LuminaViewportScene;
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The design-time description of a Viewport element: its Details
/// (background, grid, camera preset, interaction) and the preview content
/// the designer shows (`previewMesh`, `previewAnimation`), never in a game.
Map<String, Object?> umgViewportDesignScene(Map<String, dynamic> props) {
  final scene = LuminaViewportScene()
    ..setEnvironment('${props['background'] ?? 'sky'}')
    ..gridVisible = props['grid'] != false
    ..setInteraction(
      orbit: props['orbit'] != false,
      pan: props['pan'] != false,
      zoom: props['zoom'] != false,
      pick: props['pick'] != false,
      autoRotate: props['autoRotate'] is num ? (props['autoRotate'] as num).toDouble() : 0.0,
    )
    ..setCameraPreset('${props['cameraPreset'] ?? 'perspective'}');
  final mesh = '${props['previewMesh'] ?? ''}';
  if (mesh.isNotEmpty) {
    final node = scene.addNode(LuminaViewportNodeKind.skeletalMesh, asset: mesh);
    final animation = '${props['previewAnimation'] ?? ''}';
    if (animation.isNotEmpty) scene.playAnimation(node, animation);
  }
  return scene.json;
}

/// A Viewport element as the designer canvas and the runtime view render
/// it: the real `LuminaUmgViewport` with the element's Details. [instance]
/// null shows the design-time content ([umgViewportDesignScene]).
Widget umgViewportElement({
  required Map<String, Object?>? instance,
  required String name,
  required Map<String, dynamic> props,
  Key? key,
  bool allowFiles = false,
  String? projectDir,
  void Function(String event, Map<String, Object?> args)? onEvent,
}) {
  double number(String k, double d) => props[k] is num ? (props[k] as num).toDouble() : d;
  return LuminaUmgViewport(
    key: key,
    instance: instance,
    name: name,
    designScene: instance == null ? umgViewportDesignScene(props) : null,
    background: '${props['background'] ?? 'sky'}',
    grid: props['grid'] != false,
    cameraPreset: '${props['cameraPreset'] ?? 'perspective'}',
    orbit: props['orbit'] != false,
    pan: props['pan'] != false,
    zoom: props['zoom'] != false,
    pick: props['pick'] != false,
    autoRotate: number('autoRotate', 0.0),
    renderScale: number('renderScale', 1.0).clamp(0.25, 1.0),
    maxFps: number('maxFps', 60).round(),
    allowFiles: allowFiles,
    assetProvider: projectDir == null ? null : (path) => _readProjectFile(projectDir, path),
    onEvent: onEvent,
  );
}

/// A project asset (`contents/…`) or an absolute file, read asynchronously.
Future<Uint8List> _readProjectFile(String projectDir, String path) {
  final normal = path.replaceAll(r'\', '/');
  final absolute = normal.startsWith('/') || RegExp(r'^[A-Za-z]:/').hasMatch(normal);
  return File(absolute ? normal : '$projectDir/$normal').readAsBytes();
}
