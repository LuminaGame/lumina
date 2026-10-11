part of '../blueprint_function_library.dart';

/// Generated code calls the Viewport nodes on [LuminaViewportNodes], which
/// the game runtime library exports.
const String _viewportLibrary = 'package:lumina/lumina_runtime.dart';

LuminaBlueprintCallShape _vp(String method, List<String> args, {List<String> outputs = const []}) =>
    LuminaBlueprintCallShape('LuminaViewportNodes.$method', args, self: true, outputs: outputs, library: _viewportLibrary);

/// [LuminaBlueprintFunctionLibrary.callShapes]: the Viewport nodes.
final Map<String, LuminaBlueprintCallShape> _umgViewportCallShapes = <String, LuminaBlueprintCallShape>{
  'viewport_add_static_mesh': _vp('addStaticMesh', ['target', 'mesh', 'transform'], outputs: LuminaBlueprintFunctionLibrary._r),
  'viewport_add_skeletal_mesh':
      _vp('addSkeletalMesh', ['target', 'skeletal_mesh', 'transform'], outputs: LuminaBlueprintFunctionLibrary._r),
  'viewport_remove_node': _vp('removeNode', ['target', 'node_id']),
  'viewport_clear': _vp('clear', ['target']),
  'viewport_set_node_transform': _vp('setNodeTransform', ['target', 'node_id', 'transform']),
  'viewport_set_node_visible': _vp('setNodeVisible', ['target', 'node_id', 'visible']),
  'viewport_set_node_mesh': _vp('setNodeMesh', ['target', 'node_id', 'mesh']),
  'viewport_attach_to_socket': _vp('attachToSocket', ['target', 'node_id', 'parent', 'socket']),
  'viewport_set_material_parameter': _vp('setMaterialParameter', ['target', 'node_id', 'slot', 'parameter', 'value']),
  'viewport_set_morph_target_weight': _vp('setMorphTargetWeight', ['target', 'node_id', 'morph', 'weight']),
  'viewport_play_animation': _vp('playAnimation', ['target', 'node_id', 'animation', 'loop', 'play_rate']),
  'viewport_stop_animation': _vp('stopAnimation', ['target', 'node_id']),
  'viewport_set_animation_time': _vp('setAnimationTime', ['target', 'node_id', 'seconds']),
  'viewport_play_animation_file': _vp('playAnimationFile', ['target', 'node_id', 'path']),
  'viewport_add_light': _vp('addLight', ['target', 'type', 'color', 'intensity', 'transform'], outputs: LuminaBlueprintFunctionLibrary._r),
  'viewport_set_environment': _vp('setEnvironment', ['target', 'mode', 'ibl', 'intensity']),
  'viewport_set_grid_visible': _vp('setGridVisible', ['target', 'visible']),
  'viewport_set_camera_preset': _vp('setCameraPreset', ['target', 'preset', 'fit']),
  'viewport_frame_node': _vp('frameNode', ['target', 'node_id']),
  'viewport_set_orbit': _vp('setOrbit', ['target', 'yaw', 'pitch', 'distance']),
  'viewport_get_camera': const LuminaBlueprintCallShape('LuminaViewportNodes.getCamera', ['target'],
      outputs: ['yaw', 'pitch', 'distance'], library: _viewportLibrary),
  'viewport_set_interaction': _vp('setInteraction', ['target', 'orbit', 'pan', 'zoom', 'pick', 'auto_rotate']),
  'viewport_show_skeleton': _vp('showSkeleton', ['target', 'node_id', 'color', 'joints']),
  'viewport_show_ghost_pose': _vp('showGhostPose', ['target', 'node_id', 'pose_json', 'animation', 'time', 'color', 'label']),
  'viewport_hide_skeleton': _vp('hideSkeleton', ['target', 'node_id']),
  'viewport_set_gizmo': _vp('setGizmo', ['target', 'node_id', 'bone', 'mode', 'space', 'snap']),
  'viewport_hide_gizmo': _vp('hideGizmo', ['target']),
  'viewport_add_marker': _vp('addMarker', ['target', 'label', 'kind', 'from', 'to', 'color'], outputs: LuminaBlueprintFunctionLibrary._r),
  'viewport_remove_marker': _vp('removeMarker', ['target', 'marker_id']),
};

String _vs(Object? v, [String d = '']) => v is String ? v : (v == null ? d : '$v');
double _vd(Object? v, double d) => v is num ? v.toDouble() : d;
bool _vb(Object? v, bool d) => v is bool ? v : d;

/// [LuminaBlueprintFunctionLibrary.builtInFunctions]: the Viewport nodes.
final Map<String, LuminaBlueprintFunction> _umgViewportFunctions = <String, LuminaBlueprintFunction>{
  'viewport_add_static_mesh': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaViewportNodes.addStaticMesh(c.self, i['target'], _vs(i['mesh']), i['transform'])),
  'viewport_add_skeletal_mesh': (c, i) => LuminaBlueprintFunctionLibrary._ret(
      LuminaViewportNodes.addSkeletalMesh(c.self, i['target'], _vs(i['skeletal_mesh']), i['transform'])),
  'viewport_remove_node': (c, i) {
    LuminaViewportNodes.removeNode(c.self, i['target'], _vs(i['node_id']));
    return const {};
  },
  'viewport_clear': (c, i) {
    LuminaViewportNodes.clear(c.self, i['target']);
    return const {};
  },
  'viewport_set_node_transform': (c, i) {
    LuminaViewportNodes.setNodeTransform(c.self, i['target'], _vs(i['node_id']), i['transform']);
    return const {};
  },
  'viewport_set_node_visible': (c, i) {
    LuminaViewportNodes.setNodeVisible(c.self, i['target'], _vs(i['node_id']), _vb(i['visible'], true));
    return const {};
  },
  'viewport_set_node_mesh': (c, i) {
    LuminaViewportNodes.setNodeMesh(c.self, i['target'], _vs(i['node_id']), _vs(i['mesh']));
    return const {};
  },
  'viewport_attach_to_socket': (c, i) {
    LuminaViewportNodes.attachToSocket(c.self, i['target'], _vs(i['node_id']), _vs(i['parent']), _vs(i['socket']));
    return const {};
  },
  'viewport_set_material_parameter': (c, i) {
    LuminaViewportNodes.setMaterialParameter(
        c.self, i['target'], _vs(i['node_id']), _vs(i['slot'], '0'), _vs(i['parameter'], 'baseColorFactor'), i['value']);
    return const {};
  },
  'viewport_set_morph_target_weight': (c, i) {
    LuminaViewportNodes.setMorphTargetWeight(c.self, i['target'], _vs(i['node_id']), _vs(i['morph']), _vd(i['weight'], 0.0));
    return const {};
  },
  'viewport_play_animation': (c, i) {
    LuminaViewportNodes.playAnimation(
        c.self, i['target'], _vs(i['node_id']), _vs(i['animation']), _vb(i['loop'], true), _vd(i['play_rate'], 1.0));
    return const {};
  },
  'viewport_stop_animation': (c, i) {
    LuminaViewportNodes.stopAnimation(c.self, i['target'], _vs(i['node_id']));
    return const {};
  },
  'viewport_set_animation_time': (c, i) {
    LuminaViewportNodes.setAnimationTime(c.self, i['target'], _vs(i['node_id']), _vd(i['seconds'], 0.0));
    return const {};
  },
  'viewport_play_animation_file': (c, i) {
    LuminaViewportNodes.playAnimationFile(c.self, i['target'], _vs(i['node_id']), _vs(i['path']));
    return const {};
  },
  'viewport_add_light': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaViewportNodes.addLight(
      c.self, i['target'], _vs(i['type'], 'directional'), i['color'], _vd(i['intensity'], 100000.0), i['transform'])),
  'viewport_set_environment': (c, i) {
    LuminaViewportNodes.setEnvironment(c.self, i['target'], _vs(i['mode'], 'sky'), _vs(i['ibl']), _vd(i['intensity'], 1.0));
    return const {};
  },
  'viewport_set_grid_visible': (c, i) {
    LuminaViewportNodes.setGridVisible(c.self, i['target'], _vb(i['visible'], true));
    return const {};
  },
  'viewport_set_camera_preset': (c, i) {
    LuminaViewportNodes.setCameraPreset(c.self, i['target'], _vs(i['preset'], 'perspective'), _vb(i['fit'], true));
    return const {};
  },
  'viewport_frame_node': (c, i) {
    LuminaViewportNodes.frameNode(c.self, i['target'], _vs(i['node_id']));
    return const {};
  },
  'viewport_set_orbit': (c, i) {
    LuminaViewportNodes.setOrbit(c.self, i['target'], _vd(i['yaw'], 0.0), _vd(i['pitch'], 0.0), _vd(i['distance'], 400.0));
    return const {};
  },
  'viewport_get_camera': (c, i) {
    final r = LuminaViewportNodes.getCamera(i['target']);
    return {'yaw': r.yaw, 'pitch': r.pitch, 'distance': r.distance};
  },
  'viewport_set_interaction': (c, i) {
    LuminaViewportNodes.setInteraction(c.self, i['target'], _vb(i['orbit'], true), _vb(i['pan'], true), _vb(i['zoom'], true),
        _vb(i['pick'], true), _vd(i['auto_rotate'], 0.0));
    return const {};
  },
  'viewport_show_skeleton': (c, i) {
    LuminaViewportNodes.showSkeleton(c.self, i['target'], _vs(i['node_id']), i['color'], _vb(i['joints'], true));
    return const {};
  },
  'viewport_show_ghost_pose': (c, i) {
    LuminaViewportNodes.showGhostPose(c.self, i['target'], _vs(i['node_id']), _vs(i['pose_json']), _vs(i['animation']),
        _vd(i['time'], 0.0), i['color'], _vs(i['label']));
    return const {};
  },
  'viewport_hide_skeleton': (c, i) {
    LuminaViewportNodes.hideSkeleton(c.self, i['target'], _vs(i['node_id']));
    return const {};
  },
  'viewport_set_gizmo': (c, i) {
    LuminaViewportNodes.setGizmo(c.self, i['target'], _vs(i['node_id']), _vs(i['bone']), _vs(i['mode'], 'translate'),
        _vs(i['space'], 'world'), _vd(i['snap'], 0.0));
    return const {};
  },
  'viewport_hide_gizmo': (c, i) {
    LuminaViewportNodes.hideGizmo(c.self, i['target']);
    return const {};
  },
  'viewport_add_marker': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaViewportNodes.addMarker(
      c.self, i['target'], _vs(i['label']), _vs(i['kind'], 'point'), i['from'], i['to'], i['color'])),
  'viewport_remove_marker': (c, i) {
    LuminaViewportNodes.removeMarker(c.self, i['target'], _vs(i['marker_id']));
    return const {};
  },
};
