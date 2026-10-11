part of '../blueprint_function_library.dart';

/// Generated code calls the Pose Authoring nodes on
/// [LuminaPoseAuthoringNodes], which the game runtime library exports.
const String _poseLibrary = 'package:lumina/lumina_runtime.dart';

LuminaBlueprintCallShape _pose(String method, List<String> args, {List<String> outputs = const []}) =>
    LuminaBlueprintCallShape('LuminaPoseAuthoringNodes.$method', args, self: true, outputs: outputs, library: _poseLibrary);

/// [LuminaBlueprintFunctionLibrary.callShapes]: the Pose Authoring nodes.
final Map<String, LuminaBlueprintCallShape> _poseAuthoringCallShapes = <String, LuminaBlueprintCallShape>{
  'add_pose_authoring': _pose('addPoseAuthoring', ['mesh'], outputs: LuminaBlueprintFunctionLibrary._r),
  'set_pose_handle_target': _pose('setHandleTarget', ['handle', 'location', 'use_rotation', 'rotation'],
      outputs: LuminaBlueprintFunctionLibrary._r),
  'get_pose_handle_transform': _pose('getHandleTransform', ['handle'], outputs: ['location', 'rotation']),
  'clear_pose_handle': _pose('clearHandle', ['handle']),
  'reset_pose': _pose('resetPose', []),
  'find_nearest_pose_handle': _pose('findNearestHandle', ['location', 'max_distance'], outputs: ['handle', 'distance']),
  'capture_pose': _pose('capturePose', ['name'], outputs: ['pose']),
  'apply_pose': _pose('applyPose', ['pose', 'blend_time'], outputs: LuminaBlueprintFunctionLibrary._r),
  'save_pose': _pose('savePose', ['slot', 'name'], outputs: LuminaBlueprintFunctionLibrary._r),
  'load_pose': _pose('loadPose', ['slot', 'name', 'blend_time'], outputs: LuminaBlueprintFunctionLibrary._r),
  'add_grab_interactor': _pose('addGrabInteractor', ['use_mouse'], outputs: LuminaBlueprintFunctionLibrary._r),
  'register_grabber': _pose('registerGrabber', ['grabber'], outputs: LuminaBlueprintFunctionLibrary._r),
  'set_grab_radius': _pose('setGrabRadius', ['radius']),
  'undo_last_grab': _pose('undoLastGrab', [], outputs: LuminaBlueprintFunctionLibrary._r),
};

String _ps(Object? v, [String d = '']) => v is String ? v : (v == null ? d : '$v');

/// [LuminaBlueprintFunctionLibrary.builtInFunctions]: the Pose Authoring nodes.
final Map<String, LuminaBlueprintFunction> _poseAuthoringFunctions = <String, LuminaBlueprintFunction>{
  'add_pose_authoring': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaPoseAuthoringNodes.addPoseAuthoring(c.self, i['mesh'])),
  'set_pose_handle_target': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaPoseAuthoringNodes.setHandleTarget(
      c.self,
      _ps(i['handle'], 'hand_r'),
      _vec3(i['location']),
      i['use_rotation'] as bool? ?? false,
      i['rotation'] is LuminaRotator ? i['rotation'] as LuminaRotator : const LuminaRotator.zero())),
  'get_pose_handle_transform': (c, i) {
    final t = LuminaPoseAuthoringNodes.getHandleTransform(c.self, _ps(i['handle']));
    return {'location': t.location, 'rotation': t.rotation};
  },
  'clear_pose_handle': (c, i) {
    LuminaPoseAuthoringNodes.clearHandle(c.self, _ps(i['handle']));
    return const {};
  },
  'reset_pose': (c, i) {
    LuminaPoseAuthoringNodes.resetPose(c.self);
    return const {};
  },
  'find_nearest_pose_handle': (c, i) {
    final r = LuminaPoseAuthoringNodes.findNearestHandle(
        c.self, _vec3(i['location']), LuminaBlueprintFunctionLibrary._d(i['max_distance'], 10.0));
    return {'handle': r.handle, 'distance': r.distance};
  },
  'capture_pose': (c, i) => {'pose': LuminaPoseAuthoringNodes.capturePose(c.self, _ps(i['name'], 'Pose'))},
  'apply_pose': (c, i) => LuminaBlueprintFunctionLibrary._ret(
      LuminaPoseAuthoringNodes.applyPose(c.self, _ps(i['pose']), LuminaBlueprintFunctionLibrary._d(i['blend_time'], 0.0))),
  'save_pose': (c, i) => LuminaBlueprintFunctionLibrary._ret(
      LuminaPoseAuthoringNodes.savePose(c.self, _ps(i['slot'], 'Poses'), _ps(i['name'], 'Pose'))),
  'load_pose': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaPoseAuthoringNodes.loadPose(
      c.self, _ps(i['slot'], 'Poses'), _ps(i['name'], 'Pose'), LuminaBlueprintFunctionLibrary._d(i['blend_time'], 0.0))),
  'add_grab_interactor': (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaPoseAuthoringNodes.addGrabInteractor(c.self, i['use_mouse'] as bool? ?? false)),
  'register_grabber': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaPoseAuthoringNodes.registerGrabber(c.self, i['grabber'])),
  'set_grab_radius': (c, i) {
    LuminaPoseAuthoringNodes.setGrabRadius(c.self, LuminaBlueprintFunctionLibrary._d(i['radius'], 8.0));
    return const {};
  },
  'undo_last_grab': (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaPoseAuthoringNodes.undoLastGrab(c.self)),
};
