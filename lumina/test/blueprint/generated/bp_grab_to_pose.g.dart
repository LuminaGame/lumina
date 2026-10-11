// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_grab_to_pose.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/lumina_runtime.dart' as fn_lumina_lumina_runtime;

class BpGrabToPose extends LuminaActor with LuminaBlueprintRuntime {
  BpGrabToPose({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_grab_to_pose';

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
  void onPoseHandleGrabbed(String handle, String grabber) {
    super.onPoseHandleGrabbed(handle, grabber);
    _onGrabbed(handle, grabber);
  }

  @override
  void onPoseHandleReleased(String handle, String grabber) {
    super.onPoseHandleReleased(handle, grabber);
    _onReleased(handle, grabber);
  }

  @override
  void onPoseHandleHovered(String handle, String grabber) {
    super.onPoseHandleHovered(handle, grabber);
    _onHovered(handle, grabber);
  }

  /// Event BeginPlay (node begin).
  void _onBegin() {
    Object? oadd_return_value;
    final r0 = fn_lumina_lumina_runtime.LuminaPoseAuthoringNodes.addGrabInteractor(this, false);
    oadd_return_value = r0;
    if (trace != null) blueprintTrace('begin', 'add', 'add_grab_interactor', {'use_mouse': false, 'return_value': r0});
    fn_lumina_lumina_runtime.LuminaPoseAuthoringNodes.setGrabRadius(this, 8.0);
    if (trace != null) blueprintTrace('begin', 'radius', 'set_grab_radius', {'radius': 8.0});
  }

  /// Event On Pose Handle Grabbed (node grabbed).
  void _onGrabbed(String handle, String grabber) {
    LuminaBlueprintFunctionLibrary.printString(this, handle, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('grabbed', 'say_grabbed', 'print_string', {'in_string': handle, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: handle);
  }

  /// Event On Pose Handle Released (node released).
  void _onReleased(String handle, String grabber) {
    LuminaBlueprintFunctionLibrary.printString(this, grabber, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('released', 'say_released', 'print_string', {'in_string': grabber, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: grabber);
  }

  /// Event On Pose Handle Hovered (node hovered).
  void _onHovered(String handle, String grabber) {
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
