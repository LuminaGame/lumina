// GENERATED CODE - DO NOT MODIFY BY HAND (except inside the USER CODE region).
// Blueprint contents/blueprints/bp_slots.lmas, compiled by Lumina.
// ignore_for_file: camel_case_types, non_constant_identifier_names, unused_import, prefer_const_constructors, unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression

import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';

class BpSlots extends LuminaActor with LuminaBlueprintRuntime {
  BpSlots({super.key, super.location, super.rotation}) {
    blueprintComponentTree = _components;
    blueprintComponents = LuminaBlueprintComponents.construct(this, _components);
  }

  @override
  String get blueprintClassName => 'bp_slots';

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
      id: 'body',
      name: 'Body',
      type: 'LuminaSkeletalMeshComponent',
      parentId: 'root',
      properties: <String, dynamic>{'skeletalMeshAsset': 'contents/meshes/skeletal/SK_Hero_Body.lmas', 'slot': 'Body'},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'hair',
      name: 'Hair',
      type: 'LuminaSkeletalMeshComponent',
      parentId: 'body',
      properties: <String, dynamic>{'skeletalMeshAsset': '', 'slot': 'Hair', 'poseFrom': 'body'},
      isSceneComponent: true,
    ),
    LuminaBlueprintComponent(
      id: 'torso',
      name: 'Torso',
      type: 'LuminaSkeletalMeshComponent',
      parentId: 'body',
      properties: <String, dynamic>{'skeletalMeshAsset': '', 'slot': 'Torso', 'poseFrom': 'body'},
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

  /// Event BeginPlay (node begin).
  void _onBegin() {
    bool? ofill_return_value;
    bool? oempty_return_value;
    bool? omissing_return_value;
    bool? ofit_return_value;
    final p0 = LuminaBlueprintFunctionLibrary.getSlots(this, null);
    if (trace != null) blueprintTrace('begin', 'slots', 'get_slots', {'target': null, 'return_value': p0});
    final p1 = LuminaBlueprintFunctionLibrary.arrayLength(p0);
    if (trace != null) blueprintTrace('begin', 'count', 'array_length', {'target_array': p0, 'return_value': p1});
    final p2 = LuminaBlueprintFunctionLibrary.intToString(p1);
    if (trace != null) blueprintTrace('begin', 'count_text', 'int_to_string', {'in_int': p1, 'return_value': p2});
    LuminaBlueprintFunctionLibrary.printString(this, p2, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_count', 'print_string', {'in_string': p2, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p2);
    final r3 = LuminaBlueprintFunctionLibrary.setSlotMesh(this, null, 'Hair', 'contents/meshes/skeletal/SK_Hero_Hair.lmas');
    ofill_return_value = r3;
    if (trace != null) blueprintTrace('begin', 'fill', 'set_slot_mesh', {'target': null, 'slot': 'Hair', 'mesh': 'contents/meshes/skeletal/SK_Hero_Hair.lmas', 'return_value': r3});
    final p4 = LuminaBlueprintFunctionLibrary.boolToString((ofill_return_value ?? false));
    if (trace != null) blueprintTrace('begin', 'fill_text', 'bool_to_string', {'in_bool': (ofill_return_value ?? false), 'return_value': p4});
    LuminaBlueprintFunctionLibrary.printString(this, p4, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_fill', 'print_string', {'in_string': p4, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p4);
    final p5 = LuminaBlueprintFunctionLibrary.getSlotMesh(this, null, 'Hair');
    if (trace != null) blueprintTrace('begin', 'hair_mesh', 'get_slot_mesh', {'target': null, 'slot': 'Hair', 'return_value': p5});
    LuminaBlueprintFunctionLibrary.printString(this, p5, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_hair', 'print_string', {'in_string': p5, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p5);
    final r6 = LuminaBlueprintFunctionLibrary.clearSlot(this, null, 'Hair');
    oempty_return_value = r6;
    if (trace != null) blueprintTrace('begin', 'empty', 'clear_slot', {'target': null, 'slot': 'Hair', 'return_value': r6});
    final p7 = LuminaBlueprintFunctionLibrary.boolToString((oempty_return_value ?? false));
    if (trace != null) blueprintTrace('begin', 'empty_text', 'bool_to_string', {'in_bool': (oempty_return_value ?? false), 'return_value': p7});
    LuminaBlueprintFunctionLibrary.printString(this, p7, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_empty', 'print_string', {'in_string': p7, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p7);
    final p8 = LuminaBlueprintFunctionLibrary.getSlotMesh(this, null, 'Hair');
    if (trace != null) blueprintTrace('begin', 'hair_after', 'get_slot_mesh', {'target': null, 'slot': 'Hair', 'return_value': p8});
    LuminaBlueprintFunctionLibrary.printString(this, p8, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_after', 'print_string', {'in_string': p8, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p8);
    final r9 = LuminaBlueprintFunctionLibrary.setSlotMesh(this, null, 'Cape', 'contents/meshes/skeletal/SK_Cape.lmas');
    omissing_return_value = r9;
    if (trace != null) blueprintTrace('begin', 'missing', 'set_slot_mesh', {'target': null, 'slot': 'Cape', 'mesh': 'contents/meshes/skeletal/SK_Cape.lmas', 'return_value': r9});
    final p10 = LuminaBlueprintFunctionLibrary.boolToString((omissing_return_value ?? false));
    if (trace != null) blueprintTrace('begin', 'missing_text', 'bool_to_string', {'in_bool': (omissing_return_value ?? false), 'return_value': p10});
    LuminaBlueprintFunctionLibrary.printString(this, p10, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_missing', 'print_string', {'in_string': p10, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p10);
    final r11 = LuminaBlueprintFunctionLibrary.fitGarment(this, null, 'Torso', 'contents/characters/G_Shirt.lmas');
    ofit_return_value = r11;
    if (trace != null) blueprintTrace('begin', 'fit', 'fit_garment', {'target': null, 'slot': 'Torso', 'garment': 'contents/characters/G_Shirt.lmas', 'return_value': r11});
    final p12 = LuminaBlueprintFunctionLibrary.boolToString((ofit_return_value ?? false));
    if (trace != null) blueprintTrace('begin', 'fit_text', 'bool_to_string', {'in_bool': (ofit_return_value ?? false), 'return_value': p12});
    LuminaBlueprintFunctionLibrary.printString(this, p12, true, true, <double>[0.0, 0.66, 1.0, 1.0], 2.0, '');
    if (trace != null) blueprintTrace('begin', 'say_fit', 'print_string', {'in_string': p12, 'print_to_screen': true, 'print_to_log': true, 'text_color': <double>[0.0, 0.66, 1.0, 1.0], 'duration': 2.0, 'key': ''}, printed: p12);
  }

  // BEGIN USER CODE: class_body
  // END USER CODE
}
