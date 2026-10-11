// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_pose_authoring.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina_runtime.dart' as fn_lumina_lumina_runtime;

class BpPoseAuthoring extends LuminaActor with LuminaBlueprintRuntime {
  BpPoseAuthoring({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_pose_authoring';

  /// The component tree (the Blueprint's construction script).
  static final List<LuminaBlueprintComponent> _components = [
    LuminaBlueprintComponent(
      id: 'root',
      name: 'Root',
      type: 'LuminaSceneComponent',
      parentId: null,
      properties: <String, dynamic>{},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'mesh',
      name: 'Mesh',
      type: 'LuminaSkeletalMeshComponent',
      parentId: 'root',
      properties: <String, dynamic>{'skeletalMeshAsset': '../test-assets/mannequin/SKM_Manny_Simple.glb'},
      isSceneComponent: true,
    ),
  ];

  @override
  void onBeginPlay() {
    super.onBeginPlay();
    _onBegin();
  }

  @override
  void onTick(double deltaSeconds) {
    super.onTick(deltaSeconds);
    advanceBlueprintLatent(deltaSeconds);
  }

  @override
  void onPoseHandleChanged(String handle) {
    super.onPoseHandleChanged(handle);
    _onChanged(handle);
  }

  /// Event BeginPlay (node begin).
  void _onBegin() {
    Object? oadd_return_value;
    bool? oset_return_value;
    final r0 = fn_lumina_lumina_runtime.LuminaPoseAuthoringNodes.addPoseAuthoring(this, null as dynamic);
    oadd_return_value = r0;
    if (trace != null) blueprintTrace('begin', 'add', 'add_pose_authoring', {'mesh': null, 'return_value': r0});
    final r1 = fn_lumina_lumina_runtime.LuminaPoseAuthoringNodes.setHandleTarget(this, 'hand_r', Vector3(-35.0, -25.0, 130.0), false, const LuminaRotator(0.0, 0.0, 0.0));
    oset_return_value = r1;
    if (trace != null) blueprintTrace('begin', 'set', 'set_pose_handle_target', {'handle': 'hand_r', 'location': Vector3(-35.0, -25.0, 130.0), 'use_rotation': false, 'rotation': const LuminaRotator(0.0, 0.0, 0.0), 'return_value': r1});
    final p2 = LuminaBlueprintFunctionLibrary.boolToString((oset_return_value ?? false));
    if (trace != null) blueprintTrace('begin', 'set_text', 'bool_to_string', {'in_bool': (oset_return_value ?? false), 'return_value': p2});
    LuminaBlueprintFunctionLibrary.printString(this, p2, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_set', 'print_string', {'in_string': p2, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p2);
    final p3 = fn_lumina_lumina_runtime.LuminaPoseAuthoringNodes.findNearestHandle(this, Vector3(-35.0, -25.0, 130.0), 8.0);
    if (trace != null) blueprintTrace('begin', 'nearest', 'find_nearest_pose_handle', {'location': Vector3(-35.0, -25.0, 130.0), 'max_distance': 8.0, 'handle': p3.handle, 'distance': p3.distance});
    LuminaBlueprintFunctionLibrary.printString(this, p3.handle, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_nearest', 'print_string', {'in_string': p3.handle, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p3.handle);
  }

  /// Event On Pose Handle Changed (node changed).
  void _onChanged(String handle) {
    LuminaBlueprintFunctionLibrary.printString(this, handle, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('changed', 'say_changed', 'print_string', {'in_string': handle, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: handle);
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
