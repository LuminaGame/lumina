// GENERATED CODE - DO NOT MODIFY BY HAND
// Lumina Engine 0.0.1 Blueprint class factories: every compiled
// Blueprint, by its project-relative .lmas path.
// ignore_for_file: unused_import

import 'package:flutter/foundation.dart' show Key;
import 'package:lumina/lumina_runtime.dart';
import 'package:vector_math/vector_math_64.dart';
import 'bp_door.dart';

/// A Blueprint actor class's constructor, as a level places it.
typedef LuminaBlueprintActorFactory = LuminaActor Function({Key? key, Vector3? location, Quaternion? rotation});

/// Every compiled Blueprint actor class, by its `.lmas` path.
final Map<String, LuminaBlueprintActorFactory> luminaBlueprintFactories = {
  'contents/blueprints/BP_Door.lmas': ({key, location, rotation}) => BpDoor(key: key, location: location, rotation: rotation),
};

/// Every compiled GameMode Blueprint, by its `.lmas` path.
final Map<String, LuminaGameMode Function()> luminaGameModeFactories = {
};

/// The Blueprint actor classes by class name.
final Map<String, LuminaActor Function()> blueprintActorFactories = {
  'BpDoor': () => BpDoor(),
};
