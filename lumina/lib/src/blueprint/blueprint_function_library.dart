import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'package:lumina/src/audio/audio_subsystem.dart';
import 'package:lumina/src/audio/sound_base.dart';
import 'package:lumina/src/components/audio/audio_component.dart';
import 'package:lumina/src/components/light/light_component.dart';
import 'package:lumina/src/components/light/point_light_component.dart';
import 'package:lumina/src/components/light/spot_light_component.dart';
import 'package:lumina/src/components/particles/particle_emitter_config.dart';
import 'package:lumina/src/components/particles/particle_system_component.dart';
import 'package:lumina/src/game/console.dart';
import 'package:lumina/src/game/game_instance.dart';
import 'package:lumina/src/material/dynamic_material_instance.dart';
import 'package:lumina/src/media/video_playback.dart';
import 'package:lumina/src/utility/lumina_platform.dart';
import 'package:lumina/src/save/save_game.dart';
import 'package:lumina/src/save/save_game_subsystem.dart';
import 'package:lumina/src/world/level.dart';
import 'package:lumina/src/world/level_streaming.dart';
import 'package:lumina/src/world/level_streaming_manager.dart';
import 'package:lumina/src/world/level_preloader.dart';
import 'package:lumina/src/blueprint/anim/anim_blueprint_instance.dart';
import 'package:lumina/src/blueprint/blueprint_assets.dart';

import 'package:lumina/src/collision/collision_subsystem.dart';
import 'package:lumina/src/components/base/actor_component.dart';
import 'package:lumina/src/components/base/scene_component.dart';
import 'package:lumina/src/components/camera/camera_component.dart';
import 'package:lumina/src/components/camera/spring_arm_component.dart';
import 'package:lumina/src/components/collision/box_component.dart';
import 'package:lumina/src/components/collision/capsule_component.dart';
import 'package:lumina/src/components/collision/collision_component.dart';
import 'package:lumina/src/components/collision/sphere_component.dart';
import 'package:lumina/src/components/mesh/animated_mesh_component.dart';
import 'package:lumina/src/components/mesh/skeletal_mesh_component.dart';
import 'package:lumina/src/components/mesh/static_mesh_component.dart';
import 'package:lumina/src/components/movement/character_movement_component.dart';
import 'package:lumina/src/physics/ragdoll/ragdoll_component.dart';
import 'package:lumina/src/components/movement/traversal/traversal_check.dart';
import 'package:lumina/src/components/movement/traversal/traversal_component.dart';
import 'package:lumina/src/controller/controller.dart';
import 'package:lumina/src/input/input_component.dart';
import 'package:lumina/src/controller/player_controller.dart';
import 'package:lumina/src/game/lumina_game.dart';
import 'package:lumina/src/game/player_camera_manager.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/object/character.dart';
import 'package:lumina/src/object/pawn.dart';
import 'package:lumina/src/utility/gameplay_statics.dart';
import 'package:lumina/src/utility/gameplay_volumes.dart';
import 'package:lumina/src/world/level_script_actor.dart';
import 'package:lumina/src/game/player_start.dart';
import 'package:lumina/src/utility/timer_manager.dart';
import 'package:lumina/src/world/debug_shapes.dart';
import 'package:lumina/src/world/subsystem/widget_subsystem.dart';
import 'package:lumina/src/world/subsystem/user_settings_subsystem.dart';
import 'package:lumina/src/umg/user_widget.dart';
import 'package:lumina/src/world/world.dart';
import 'package:lumina/src/blueprint/blueprint_enums_interfaces.dart';
import 'package:lumina/src/blueprint/blueprint_function_registry.dart';
import 'package:lumina/src/blueprint/blueprint_model.dart';
import 'package:lumina/src/blueprint/blueprint_runtime.dart';
import 'package:lumina/src/blueprint/component_mapping.dart';
import 'package:lumina/src/blueprint/level_blueprint.dart';
import 'package:lumina/src/blueprint/node_library.dart';
import 'package:lumina/src/blueprint/widget_classes.dart';

part 'blueprint_function_library/call_shapes.dart';
part 'blueprint_function_library/vm_functions_core_and_objects.dart';
part 'blueprint_function_library/vm_functions_math_to_timers.dart';
part 'blueprint_function_library/vm_functions_game_framework.dart';
part 'blueprint_function_library/pawn_transform_ui.dart';
part 'blueprint_function_library/objects_and_widget_elements.dart';
part 'blueprint_function_library/components_collision_physics.dart';
part 'blueprint_function_library/gameplay_structs_math.dart';
part 'blueprint_function_library/strings_arrays_flow.dart';
part 'blueprint_function_library/engine_trace_view_camera.dart';
part 'blueprint_function_library/actor_events_enums_timers.dart';
part 'blueprint_function_library/game_framework_save_input.dart';
part 'blueprint_function_library/audio_animation_effects_debug.dart';
part 'blueprint_function_library/widget_blueprint.dart';
part 'blueprint_function_library/ragdoll.dart';
part 'blueprint_function_library/traversal.dart';

/// What a node function gets when the VM calls it: the
/// Blueprint instance it runs on.
class LuminaBlueprintCallContext {
  final LuminaActor self;
  const LuminaBlueprintCallContext(this.self);
}

/// A node's behaviour as the VM calls it: inputs by pin id → outputs by pin id.
typedef LuminaBlueprintFunction =
    Map<String, Object?> Function(
      LuminaBlueprintCallContext context,
      Map<String, Object?> inputs,
    );

/// How generated code calls a node's function: the static
/// method on [LuminaBlueprintFunctionLibrary], its arguments as input pin ids
/// in order, whether the Blueprint itself (`self`) comes first, and its
/// outputs: none, `return_value`, or record fields named after the pins.
///
/// A Dart function exposed with `@BlueprintCallable` / `@BlueprintPure`
/// also names the [library] it is imported from, and which
/// arguments are [named] and which [optional] (left out of a direct call when
/// the pin is neither wired nor set, so Dart's default applies).
class LuminaBlueprintCallShape {
  /// The function: a method of [LuminaBlueprintFunctionLibrary], or for a
  /// [library] function its name (`applyDamage`, `Class.method`).
  final String method;
  final List<String> args;
  final bool self;
  final List<String> outputs;

  /// The library URI an exposed function is imported from; null for the
  /// function library.
  final String? library;

  /// Arguments passed by name.
  final Set<String> named;

  /// Arguments with a Dart default (optional named or positional).
  final Set<String> optional;

  /// The outputs are a record's fields even when there is one.
  final bool record;

  const LuminaBlueprintCallShape(
    this.method,
    this.args, {
    this.self = false,
    this.outputs = const [],
    this.library,
    this.named = const {},
    this.optional = const {},
    this.record = false,
  });

  bool get returnsRecord => record || outputs.length > 1;
}

/// Every pure and impure node's behaviour, written once. The
/// VM calls it through [functions]; generated Dart calls the static methods
/// directly, so both run the same code.
///
/// Vectors and rotators are **authoring space** (cm, Z up; rotators about
/// X/Y/Z like the Details panel). This class is the one place they cross into
/// the Y-up runtime.
abstract final class LuminaBlueprintFunctionLibrary {

  // --- Authoring ↔ runtime --------------------------------------------------
  /// Authoring (x, y, z) → runtime (x, z, −y): `LuminaAxes.location`.
  static const toRuntime = _toRuntime;
  /// Runtime → authoring: `LuminaAxes.toAuthoringLocation`.
  static const toAuthoring = _toAuthoring;
  /// A rotator as the pawn's runtime Euler (pitch X, yaw Y, roll Z): pitch is
  /// about authoring X, yaw about authoring Z (runtime Y), roll about
  /// authoring Y (runtime −Z).
  static const toControlRotation = _toControlRotation;
  static const fromControlRotation = _fromControlRotation;

  // --- Development -----------------------------------------------------------

  /// Where Print String goes; the VM and generated code route it into the
  /// instance's trace.
  static void Function(LuminaActor self, String text) onPrintString = _log;
  /// Print String: to the log (through [onPrintString]) and to the screen
  /// (`LuminaWorld.screenMessages`, drawn by the PIE HUD overlay); a [key]
  /// replaces the line printed with the same key.
  static const printString = _printString;
  /// Add Movement Input: characters feed their movement component,
  /// like `LuminaTemplateCharacter.onMove`; other pawns accumulate input.
  static const addMovementInput = _addMovementInput;
  static const addControllerYawInput = _addControllerYawInput;
  static const addControllerPitchInput = _addControllerPitchInput;
  /// The controller's rotation; zero without a controller.
  static const getControlRotation = _getControlRotation;
  /// Set Free Look: the body keeps its heading while the
  /// controller (and the camera boom) turns; off recentres the camera.
  static const setFreeLook = _setFreeLook;
  static const isFreeLooking = _isFreeLooking;
  static const jump = _jump;
  static const stopJumping = _stopJumping;
  static const getVelocity = _getVelocity;
  static const isFalling = _isFalling;

  // --- Transformation --------------------------------------------------------
  static const getActorLocation = _getActorLocation;
  /// Teleports; `sweep` is not supported (the validator warns when it is set).
  static const setActorLocation = _setActorLocation;
  static const getActorRotation = _getActorRotation;

  // --- UI / Widget -----------------------------------------------------------
  /// A widget instance: a JSON-plain map with the class, the owner, viewport
  /// state and, per named element of the class (from
  /// [LuminaWidgetClassRegistry]), that element's own state.
  static const createWidget = _createWidget;
  static const addToViewport = _addToViewport;
  static const removeFromParent = _removeFromParent;
  static const setWidgetVisibility = _setWidgetVisibility;
  static const isInViewport = _isInViewport;
  static const getOwningPlayer = _getOwningPlayer;
  /// Deprecated: writes the widget's legacy `text` and every
  /// Text element. Use `Get <element>` → `Set Text (Text)`.
  static const setWidgetText = _setWidgetText;
  /// Deprecated: writes the widget's legacy `percent` and
  /// every Progress Bar element. Use `Get <element>` → `Set Percent`.
  static const setWidgetPercent = _setWidgetPercent;
  /// A widget's own `Is Variable` element, and Self, in its graph.
  static const getWidgetVariable = _getWidgetVariable;
  static const getWidgetSelf = _getWidgetSelf;

  // --- Objects, validity, casting -----------------------------
  /// Whether [widget] is a widget instance map (has a `class` and `elements`).
  static const isWidgetInstance = _isWidgetInstance;
  /// Whether [o] is a widget element state map.
  static const isWidgetElement = _isWidgetElement;
  /// The class string of a runtime object (`Widget:WBP_HUD`,
  /// `WidgetElement:text`, `Component:LuminaSpringArmComponent`,
  /// `Actor:BP_Door`), `Object` for anything else, '' for null.
  static const classOf = _classOf;
  /// The class chain of a runtime actor, most derived first: the Blueprint's
  /// own name, then the engine classes it is (`LuminaCharacter`,
  /// `LuminaPawn`, `LuminaActor`).
  static const actorClassChain = _actorClassChain;
  /// Whether [o] is an instance of class string [cls] (the Is A node):
  /// `Object` matches any object, a kind alone (`Actor`, `Widget`) any object
  /// of that kind, an actor class itself or one of its engine ancestors.
  static const isA = _isA;
  static const isValid = _isValid;
  /// [object] when it [isA] [cls], else null (Cast To).
  static const castTo = _castTo;
  static const getClassName = _getClassName;
  static const getDisplayName = _getDisplayName;

  // --- Widget elements ----------------------------------------
  /// The element [element] of widget [target] (its state map), null when
  /// the widget has no such element.
  static const getWidgetElement = _getWidgetElement;
  static const setElementVisibility = _setElementVisibility;
  static const getElementVisibility = _getElementVisibility;
  static const isElementVisible = _isElementVisible;
  static const setElementIsEnabled = _setElementIsEnabled;
  static const getElementIsEnabled = _getElementIsEnabled;
  static const setElementRenderOpacity = _setElementRenderOpacity;
  static const setElementText = _setElementText;
  static const getElementText = _getElementText;
  static const setElementColor = _setElementColor;
  static const setElementFontSize = _setElementFontSize;

  // Text shadow and outline, under the designer's own keys.
  static const setElementShadowEnabled = _setElementShadowEnabled;
  static const setElementShadowColor = _setElementShadowColor;
  static const setElementShadowOffset = _setElementShadowOffset;
  static const setElementOutline = _setElementOutline;
  static const setElementPercent = _setElementPercent;
  static const getElementPercent = _getElementPercent;
  static const setElementFillColor = _setElementFillColor;
  static const setElementBrushFromTexture = _setElementBrushFromTexture;
  static const setElementImageColor = _setElementImageColor;
  static const setElementLabel = _setElementLabel;
  static const setElementSliderValue = _setElementSliderValue;
  static const getElementSliderValue = _getElementSliderValue;
  static const setElementIsChecked = _setElementIsChecked;
  static const getElementIsChecked = _getElementIsChecked;
  static const setElementEditableText = _setElementEditableText;
  static const getElementEditableText = _getElementEditableText;
  static const setElementHintText = _setElementHintText;
  static const setElementSelectedOption = _setElementSelectedOption;
  static const getElementSelectedOption = _getElementSelectedOption;
  static const addElementOption = _addElementOption;
  static const clearElementOptions = _clearElementOptions;
  static const setElementActiveIndex = _setElementActiveIndex;
  static const getElementActiveIndex = _getElementActiveIndex;

  // Container styling, under the designer's own keys.
  static const setElementBackgroundColor = _setElementBackgroundColor;
  static const setElementBorderColor = _setElementBorderColor;
  static const setElementCornerRadius = _setElementCornerRadius;
  static const setElementPadding = _setElementPadding;
  /// The component named [component] in the Blueprint, else null.
  static const getComponent = _getComponent;
  /// The first component of class [cls] (`Component:LuminaCameraComponent`
  /// or the bare class name) on [self], else null.
  static const getComponentByClass = _getComponentByClass;
  /// Adds a component of class [cls] to [self] at run time, attached to its
  /// root; null when the class has no runtime counterpart.
  static const addComponent = _addComponent;
  static const setRelativeLocation = _setRelativeLocation;
  static const setRelativeRotation = _setRelativeRotation;
  static const setRelativeScale = _setRelativeScale;
  static const getRelativeLocation = _getRelativeLocation;
  static const getRelativeRotation = _getRelativeRotation;
  static const getRelativeScale = _getRelativeScale;
  static const setWorldLocation = _setWorldLocation;
  static const setWorldRotation = _setWorldRotation;
  static const getWorldLocation = _getWorldLocation;
  static const getWorldRotation = _getWorldRotation;
  static const attachToComponent = _attachToComponent;
  static const setComponentVisibility = _setComponentVisibility;
  static const setHiddenInGame = _setHiddenInGame;
  static const getSocketLocation = _getSocketLocation;
  static const setTargetArmLength = _setTargetArmLength;
  static const getTargetArmLength = _getTargetArmLength;
  static const setCameraLagEnabled = _setCameraLagEnabled;
  static const setCameraLagSpeed = _setCameraLagSpeed;
  static const setSocketOffset = _setSocketOffset;
  static const setFieldOfView = _setFieldOfView;
  static const getFieldOfView = _getFieldOfView;
  static const setCameraActive = _setCameraActive;
  static const isCameraActive = _isCameraActive;
  static const playAnimation = _playAnimation;
  static const stopAnimation = _stopAnimation;
  /// Swaps the mesh's Animation Blueprint for [animClass] (a project `.lmas`
  /// path the Blueprint's anim class resolver knows); '' removes it.
  static const setAnimClass = _setAnimClass;
  static const setPlayRate = _setPlayRate;
  static const getCurrentClip = _getCurrentClip;
  /// Replaces the mesh component with one loading [newMesh] (same parent,
  /// transform and shadow flags), keeping the Blueprint's component id.
  static const setStaticMesh = _setStaticMesh;
  /// Sets the material at [elementIndex] to the material asset [material]:
  /// loaded through the world's material cache when the world renders, else
  /// remembered on the component's owner for the world to apply.
  static const setMaterial = _setMaterial;
  /// Set Collision Enabled: a `NoCollision` / `QueryOnly` /
  /// `QueryAndPhysics` literal (or a plain bool from older graphs).
  /// `NoCollision` disables the component; the query modes enable it and
  /// its overlap events.
  static const setCollisionEnabled = _setCollisionEnabled;

  // --- Collision presets and shapes ------------------------------
  static const setCollisionPreset = _setCollisionPreset;
  static const getCollisionPreset = _getCollisionPreset;
  static const setCollisionResponseToChannel = _setCollisionResponseToChannel;
  static const setCollisionResponseToAllChannels = _setCollisionResponseToAllChannels;
  static const getCollisionResponseToChannel = _getCollisionResponseToChannel;
  static const setCollisionObjectType = _setCollisionObjectType;
  static const getCollisionObjectType = _getCollisionObjectType;
  static const setGenerateOverlapEvents = _setGenerateOverlapEvents;
  /// Set Box Extent: authoring (X, Y, Z) half extents → runtime axes.
  static const setBoxExtent = _setBoxExtent;
  static const getBoxExtent = _getBoxExtent;
  static const setSphereRadius = _setSphereRadius;
  static const getSphereRadius = _getSphereRadius;
  static const setCapsuleSize = _setCapsuleSize;
  static const getScaledCapsuleRadius = _getScaledCapsuleRadius;
  static const getScaledCapsuleHalfHeight = _getScaledCapsuleHalfHeight;
  /// The actors (deduplicated) with a component overlapping [target] right
  /// now, filtered by [cls]; the component's owner is left out.
  static const getOverlappingActors = _getOverlappingActors;
  static const getOverlappingComponents = _getOverlappingComponents;
  static const isOverlappingActor = _isOverlappingActor;
  static const setSimulatePhysics = _setSimulatePhysics;
  static const isSimulatingPhysics = _isSimulatingPhysics;
  static const addImpulse = _addImpulse;
  static const addImpulseAtLocation = _addImpulseAtLocation;
  static const addForce = _addForce;
  static const addForceAtLocation = _addForceAtLocation;
  static const addTorqueInRadians = _addTorqueInRadians;
  static const addAngularImpulseInRadians = _addAngularImpulseInRadians;
  static const setPhysicsLinearVelocity = _setPhysicsLinearVelocity;
  static const getPhysicsLinearVelocity = _getPhysicsLinearVelocity;
  static const setPhysicsAngularVelocityInDegrees = _setPhysicsAngularVelocityInDegrees;
  static const getPhysicsAngularVelocityInDegrees = _getPhysicsAngularVelocityInDegrees;
  /// The body's mass (kg): its override, the static mesh's, or density × volume.
  static const getMass = _getMass;
  static const setMassOverrideInKg = _setMassOverrideInKg;
  static const setEnableGravity = _setEnableGravity;
  static const setLinearDamping = _setLinearDamping;
  static const setAngularDamping = _setAngularDamping;
  static const wakeRigidBody = _wakeRigidBody;
  static const putRigidBodyToSleep = _putRigidBodyToSleep;
  static const isAnyRigidBodyAwake = _isAnyRigidBodyAwake;
  static const setCollisionLayer = _setCollisionLayer;
  static const setMaxWalkSpeed = _setMaxWalkSpeed;
  static const getMaxWalkSpeed = _getMaxWalkSpeed;
  static const setJumpZVelocity = _setJumpZVelocity;
  static const getJumpZVelocity = _getJumpZVelocity;
  static const setGravityScale = _setGravityScale;
  static const getGravityScale = _getGravityScale;
  static const setAirControl = _setAirControl;
  static const getAirControl = _getAirControl;

  static const Map<String, MovementMode> movementModes = {
    'Walking': MovementMode.walking,
    'Falling': MovementMode.falling,
    'Flying': MovementMode.flying,
    'Swimming': MovementMode.swimming,
    'Custom': MovementMode.custom,
  };
  static const setMovementMode = _setMovementMode;
  static const getMovementMode = _getMovementMode;
  static const crouch = _crouch;
  static const unCrouch = _unCrouch;
  static const isCrouched = _isCrouched;
  static const launchCharacter = _launchCharacter;
  static const stopMovementImmediately = _stopMovementImmediately;

  // --- Gameplay / Player -----------------------------------------------------
  static const getPlayerController = _getPlayerController;
  static const getPlayerPawn = _getPlayerPawn;
  static const getPlayerCharacter = _getPlayerCharacter;
  static const setShowMouseCursor = _setShowMouseCursor;
  static const setInputModeGameAndUI = _setInputModeGameAndUI;
  static const setInputModeGameOnly = _setInputModeGameOnly;
  static const setInputModeUIOnly = _setInputModeUIOnly;

  // --- Structs ---------------------------------------------------------------
  static const makeVector2D = _makeVector2D;
  static const breakVector2D = _breakVector2D;
  static const makeVector = _makeVector;
  static const breakVector = _breakVector;
  static const makeRotator = _makeRotator;
  static const breakRotator = _breakRotator;
  /// The direction a pawn facing [inRot] moves forward: the pawn's own
  /// `forwardVector` for that rotation (so a Blueprint character walks exactly
  /// like `LuminaTemplateCharacter`), in authoring space.
  static const getForwardVector = _getForwardVector;
  static const getRightVector = _getRightVector;
  /// Calculate Direction: the signed angle in degrees, right positive,
  /// from the facing of [baseRotation] to [velocity], on the ground plane;
  /// 0 when not moving. The facing is the pawn's own forward for that
  /// rotation, as the locomotion driver measures it.
  static const calculateDirection = _calculateDirection;

  // --- Math ------------------------------------------------------------------
  static const vectorLength = _vectorLength;
  /// Horizontal length: authoring Z is up.
  static const vectorLengthXY = _vectorLengthXY;
  static const vectorScale = _vectorScale;
  static const vectorAdd = _vectorAdd;
  static const floatAdd = _floatAdd;
  static const floatSubtract = _floatSubtract;
  static const floatMultiply = _floatMultiply;
  /// Division by zero returns 0.
  static const floatDivide = _floatDivide;
  static const floatClamp = _floatClamp;
  static const floatGreater = _floatGreater;
  static const floatLess = _floatLess;
  static const floatEqual = _floatEqual;
  static const boolAnd = _boolAnd;
  static const boolOr = _boolOr;
  static const boolNot = _boolNot;

  // --- Math | Float ----------------------------------------------
  static const floatAbs = _floatAbs;
  static const floatMin = _floatMin;
  static const floatMax = _floatMax;
  static const floatLerp = _floatLerp;
  /// Moves [current] towards [target] by
  /// `distance × speed × dt`, arriving exactly; speed ≤ 0 jumps.
  static const floatInterpTo = _floatInterpTo;
  static const floatSqrt = _floatSqrt;
  static const floatPower = _floatPower;
  /// fmod; division by zero returns 0.
  static const floatModulo = _floatModulo;
  static const floatSign = _floatSign;
  static const floatMapRangeClamped = _floatMapRangeClamped;
  static const floatNearlyEqual = _floatNearlyEqual;
  static const floatSin = _floatSin;
  static const floatCos = _floatCos;
  static const floatTan = _floatTan;
  static const floatAsin = _floatAsin;
  static const floatAcos = _floatAcos;
  static const floatAtan = _floatAtan;
  static const floatAtan2 = _floatAtan2;
  static const degreesToRadians = _degreesToRadians;
  static const radiansToDegrees = _radiansToDegrees;
  static const floatGreaterEqual = _floatGreaterEqual;
  static const floatLessEqual = _floatLessEqual;
  static const floatNotEqual = _floatNotEqual;

  /// The random source of the Random nodes; tests may seed it.
  static math.Random random = math.Random();
  static const randomFloatInRange = _randomFloatInRange;
  static const randomBoolWithWeight = _randomBoolWithWeight;
  static const selectFloat = _selectFloat;
  static const round = _round;
  static const truncate = _truncate;
  static const ceil = _ceil;
  static const floor = _floor;
  static const intToFloat = _intToFloat;

  // --- Math | Int ----------------------------------------------------------------
  static const intAdd = _intAdd;
  static const intSubtract = _intSubtract;
  static const intMultiply = _intMultiply;
  /// Division by zero returns 0.
  static const intDivide = _intDivide;
  static const intModulo = _intModulo;
  static const intClamp = _intClamp;
  static const intAbs = _intAbs;
  static const intMin = _intMin;
  static const intMax = _intMax;
  static const intGreater = _intGreater;
  static const intLess = _intLess;
  static const intEqual = _intEqual;
  static const intNotEqual = _intNotEqual;
  static const intGreaterEqual = _intGreaterEqual;
  static const intLessEqual = _intLessEqual;
  static const randomIntegerInRange = _randomIntegerInRange;
  static const intIncrement = _intIncrement;
  static const selectInt = _selectInt;

  // --- Math | Vector ---------------------------------------------------------------
  static const vectorNormalize = _vectorNormalize;
  static const vectorDot = _vectorDot;
  static const vectorCross = _vectorCross;
  static const vectorDistance = _vectorDistance;
  static const vectorDistance2D = _vectorDistance2D;
  static const vectorLerp = _vectorLerp;
  static const vectorInterpTo = _vectorInterpTo;
  static const vectorSubtract = _vectorSubtract;
  static const vectorDivideFloat = _vectorDivideFloat;
  static const vectorNegate = _vectorNegate;
  static const vectorEqual = _vectorEqual;
  static const vectorProjectOnTo = _vectorProjectOnTo;
  /// Rodrigues' rotation of [inVect] by [angleDeg] about [axis] (authoring
  /// axes, right-handed).
  static const rotateVectorAroundAxis = _rotateVectorAroundAxis;
  static const getUpVector = _getUpVector;
  static const randomUnitVector = _randomUnitVector;
  static const vectorIsZero = _vectorIsZero;
  static const selectVector = _selectVector;

  // --- Math | Rotator --------------------------------------------------------------
  /// Wraps [angle] into (-180, 180].
  static const normalizeAxis = _normalizeAxis;
  /// Normalises first, then clamps.
  static const clampAngle = _clampAngle;
  /// [a] applied first, then [b].
  static const combineRotators = _combineRotators;
  /// `a - b`, each axis normalised.
  static const deltaRotator = _deltaRotator;
  /// Lerps each axis along the shortest path.
  static const rotatorLerp = _rotatorLerp;
  static const rotatorInterpTo = _rotatorInterpTo;
  /// The rotator whose forward ([getForwardVector]) points from [start] to
  /// [target], so a Set Actor Rotation from it faces the target: yaw 0 faces
  /// +Y (authoring), yaw 90 faces +X; no roll.
  static const findLookAtRotation = _findLookAtRotation;
  /// The rotator whose forward is [x] (see [findLookAtRotation]). The
  /// forward for (pitch p, yaw y) is `(cos p·sin y, cos p·cos y, sin p)`
  /// (`luminaPawnEulerToQuaternion`: positive pitch looks up, about the
  /// view's own right axis), which this inverts exactly.
  static const makeRotFromX = _makeRotFromX;
  static const rotatorEqual = _rotatorEqual;
  /// The forward direction of [inRot].
  static const rotatorToVector = _rotatorToVector;
  static const makeTransform = _makeTransform;
  static const breakTransform = _breakTransform;
  static const transformLocation = _transformLocation;
  static const inverseTransformLocation = _inverseTransformLocation;
  static const transformDirection = _transformDirection;
  /// [a] then [b]: the transform that applies [a] in [b]'s space.
  static const composeTransforms = _composeTransforms;
  static const makeColor = _makeColor;
  static const breakColor = _breakColor;
  static const colorLerp = _colorLerp;
  /// `#RRGGBB` or `#RRGGBBAA` (the `#` is optional); unparsable → white.
  static const hexToColor = _hexToColor;
  static const colorToHex = _colorToHex;

  // --- String / Conversion -----------------------------------------------------------
  static const floatToString = _floatToString;
  static const intToString = _intToString;
  static const boolToString = _boolToString;
  static const vectorToString = _vectorToString;
  static const rotatorToString = _rotatorToString;
  static const stringToFloat = _stringToFloat;
  static const stringToInt = _stringToInt;
  static const append = _append;
  static const append3 = _append3;
  /// Replaces `{0}`…`{3}` with the arguments that are set; a placeholder
  /// whose argument is empty stays as written.
  static const formatString = _formatString;
  static const stringLength = _stringLength;
  static const stringEqual = _stringEqual;
  static const stringContains = _stringContains;
  static const stringReplace = _stringReplace;
  static const stringToUpper = _stringToUpper;
  static const stringToLower = _stringToLower;
  static const stringSubstring = _stringSubstring;
  static const stringSplit = _stringSplit;
  static const stringIsEmpty = _stringIsEmpty;
  static const stringTrim = _stringTrim;
  static const selectString = _selectString;
  static const selectBool = _selectBool;
  static const selectObject = _selectObject;

  // --- Array -----------------------------------------------------------
  /// Whether two array items are the same value: identity, `==`, or the
  /// same components for colours / lists.
  static const sameItem = _sameItem;
  /// A copy of [v]'s items when it is an array, else no items: what a
  /// ForEachLoop iterates (the VM and generated code alike).
  static const arrayItems = _arrayItems;
  static const arrayLength = _arrayLength;
  static const arrayLastIndex = _arrayLastIndex;
  static const arrayIsEmpty = _arrayIsEmpty;
  /// The item at [index], or null (logged once per index / length pair)
  /// when the index is out of range.
  static const arrayGet = _arrayGet;
  static const arrayContains = _arrayContains;
  static const arrayFind = _arrayFind;
  static const arrayFirst = _arrayFirst;
  static const arrayLast = _arrayLast;
  static const makeArray = _makeArray;
  /// Adds [newItem] in place and returns its index.
  static const arrayAdd = _arrayAdd;
  static const arrayRemoveIndex = _arrayRemoveIndex;
  static const arrayClear = _arrayClear;
  static const arraySet = _arraySet;
  /// The objects of [targetArray] that are a [cls] (`Actor:BP_Door`).
  static const arrayFilterByClass = _arrayFilterByClass;
  static const arrayShuffle = _arrayShuffle;

  // --- Flow-control helpers shared by the VM and generated code -------------------------
  /// MultiGate's next output: [used] outputs so far (null = fresh), the
  /// output [count], and the node's settings. Returns the output index to
  /// take (-1 when every output was used and Loop is off) and the new used
  /// list.
  static const multiGateNext = _multiGateNext;
  /// Logs a WhileLoop that hit its iteration cap.
  static const whileLoopCapped = _whileLoopCapped;

  // --- Structs: hit result -----------------------------------------------------------
  static const makeHitResult = _makeHitResult;
  static const breakHitResult = _breakHitResult;
  static const getFrameRate = _getFrameRate;
  static const getFrameTimeMs = _getFrameTimeMs;
  static const getFrameNumber = _getFrameNumber;
  static const getWorldDeltaSeconds = _getWorldDeltaSeconds;
  static const getGameTimeInSeconds = _getGameTimeInSeconds;
  static const getRealTimeSeconds = _getRealTimeSeconds;
  static const getActorCount = _getActorCount;
  static const getTimeDilation = _getTimeDilation;
  static const setTimeDilation = _setTimeDilation;
  /// `Linux`, `Windows`, `MacOS`, `Android`, `IOS`, `Web`.
  static const getPlatformName = _getPlatformName;
  static const isEditor = _isEditor;
  /// Asks the game host to quit (`LuminaGame.onQuitRequested`): the built
  /// game exits, Play-In-Editor stops the session. With no host hook it only
  /// logs.
  static const quitGame = _quitGame;

  // --- Collision | Trace -------------------------------------------

  /// The trace channels a `Channel` literal may name (on Lumina's
  /// layers and object types): `Visibility` and `Camera` see everything,
  /// `WorldStatic` / `WorldDynamic` / `Pawn` one object type, `Layer N` one
  /// layer.
  static const List<String> traceChannels = ['Visibility', 'Camera', 'WorldStatic', 'WorldDynamic', 'Pawn'];
  /// Whether [channel] is a channel name a trace accepts.
  static const isTraceChannel = _isTraceChannel;
  /// A hit as the `hitResult` pin carries it: authoring-space vectors, the
  /// actor and the component.
  static const hitToMap = _hitToMap;
  /// The Event Hit outputs for a blocking hit of [self] against [other]: the
  /// VM dispatches them, generated classes pass the same map.
  static const hitEventOutputs = _hitEventOutputs;
  /// Line Trace By Channel: the first blocking hit between [start] and [end]
  /// (authoring space). Self is always ignored.
  static const lineTraceByChannel = _lineTraceByChannel;
  /// Multi Line Trace By Channel: every hit, nearest first.
  static const multiLineTraceByChannel = _multiLineTraceByChannel;
  /// Sphere Trace By Channel: a sphere of [radius] swept from [start] to [end].
  static const sphereTraceByChannel = _sphereTraceByChannel;
  static const lineTraceForward = _lineTraceForward;
  static const multiLineTraceForward = _multiLineTraceForward;
  static const sphereTraceForward = _sphereTraceForward;
  /// Sphere Overlap Actors: the actors of [cls] with a component inside the
  /// sphere, nearest first. Self is left out.
  static const sphereOverlapActors = _sphereOverlapActors;

  // --- Self | View -------------------------------------------------
  /// Where Self looks: along its control rotation when a controller drives
  /// it, else its own facing (authoring space, unit length).
  static const getLookForwardDirection = _getLookForwardDirection;
  /// Self's eyes (a pawn's Base Eye Height above its location) and its view
  /// rotation; a plain actor's location and rotation.
  static const getActorEyesViewPoint = _getActorEyesViewPoint;
  static const findLookAtLocation = _findLookAtLocation;
  static const getAllActorsOfClass = _getAllActorsOfClass;
  static const getAllActorsWithTag = _getAllActorsWithTag;
  /// The actors of [cls] within [radius] of [location], nearest first.
  static const getActorsWithinRadius = _getActorsWithinRadius;
  /// The actors of [cls] (other than Self) within [distance] of Self's eyes
  /// and within [coneAngle] degrees of its look direction, nearest first.
  static const getActorsInViewCone = _getActorsInViewCone;
  static const getClosestActorOfClassInDirection = _getClosestActorOfClassInDirection;
  static const setViewTarget = _setViewTarget;

  static const Map<String, LuminaViewTargetBlendFunction> blendFunctions = {
    'Linear': LuminaViewTargetBlendFunction.linear,
    'Cubic': LuminaViewTargetBlendFunction.cubic,
    'EaseIn': LuminaViewTargetBlendFunction.easeIn,
    'EaseOut': LuminaViewTargetBlendFunction.easeOut,
    'EaseInOut': LuminaViewTargetBlendFunction.easeInOut,
  };
  static const setViewTargetWithBlend = _setViewTargetWithBlend;
  static const getViewTarget = _getViewTarget;
  static const getPlayerCameraManager = _getPlayerCameraManager;
  /// Self's active camera component, else its first camera.
  static const getActiveCamera = _getActiveCamera;
  /// Where the world renders from (the view target, or the active camera).
  static const getCameraLocation = _getCameraLocation;
  static const getCameraRotation = _getCameraRotation;
  /// Spawn Actor from Class: a new actor of [cls] (a Blueprint class
  /// registered in [LuminaBlueprintActorClasses], or `LuminaActor` /
  /// `LuminaPawn` / `LuminaCharacter`) at [spawnTransform], registered in
  /// Self's world at once with its BeginPlay run. Null (and a
  /// log) when the class is unknown.
  static const spawnActorFromClass = _spawnActorFromClass;
  static const destroyActor = _destroyActor;
  static const setLifeSpan = _setLifeSpan;
  static const getActorTransform = _getActorTransform;
  static const setActorTransform = _setActorTransform;
  static const setActorRotation = _setActorRotation;
  static const setActorScale3D = _setActorScale3D;
  static const getActorScale3D = _getActorScale3D;
  static const setActorHiddenInGame = _setActorHiddenInGame;
  static const isHidden = _isHidden;
  static const setActorEnableCollision = _setActorEnableCollision;
  static const getActorEnableCollision = _getActorEnableCollision;
  static const teleport = _teleport;
  static const getActorBounds = _getActorBounds;
  static const getActorForwardVector = _getActorForwardVector;
  static const getActorRightVector = _getActorRightVector;
  static const getActorUpVector = _getActorUpVector;
  static const attachActorToComponent = _attachActorToComponent;
  static const detachFromActor = _detachFromActor;
  static const getAttachParentActor = _getAttachParentActor;
  static const getOwner = _getOwner;
  static const setOwner = _setOwner;
  static const getInstigator = _getInstigator;
  static const actorHasTag = _actorHasTag;
  static const addTag = _addTag;
  static const removeTag = _removeTag;
  static const getDistanceTo = _getDistanceTo;
  static const getHorizontalDistanceTo = _getHorizontalDistanceTo;
  static const isActorBeingDestroyed = _isActorBeingDestroyed;
  /// Apply Damage; an unwired Damaged Actor is Self.
  static const applyDamage = _applyDamage;
  static const applyPointDamage = _applyPointDamage;
  static const applyRadialDamage = _applyRadialDamage;
  /// The Blueprint's answer to [name] with [args]: a custom event's chain, a
  /// user function's outputs, an implemented interface function.
  static const callBlueprint = _callBlueprint;
  /// Call Custom Event on Self, or on [target] (e.g. a Level
  /// Blueprint calls a placed Blueprint actor's event); an unwired Target is Self.
  static const callCustomEvent = _callCustomEvent;
  static const callFunction = _callFunction;
  static const callDispatcher = _callDispatcher;
  static const bindEventToDispatcher = _bindEventToDispatcher;
  static const unbindEventFromDispatcher = _unbindEventFromDispatcher;
  /// Unbind All Events: every delegate of Self bound to [target]'s dispatcher.
  static const unbindAllEvents = _unbindAllEvents;

  // --- Level Blueprints ----------------------------------------
  /// `Get <Actor>` in a Level Blueprint: the level's placed actor [name],
  /// null once it was destroyed or removed (Is Valid is then false), and null
  /// outside a level script.
  static const getLevelActor = _getLevelActor;
  /// The level's live placed actors of class string [cls], in level order.
  static const getLevelActorsOfClass = _getLevelActorsOfClass;
  static const implementsInterface = _implementsInterface;
  /// Does Implement Interface with Self as the default target.
  static const doesImplementInterface = _doesImplementInterface;
  /// Interface Message: the implementer's answer, or no outputs (and no
  /// error) when [target] (Self when unwired) does not implement [interface].
  static const interfaceMessage = _interfaceMessage;

  // --- Enums -----------------------------------------------------
  static const enumLiteral = _enumLiteral;
  static const enumToString = _enumToString;
  /// The index of [value] in [enumName]'s values (any registered enum when
  /// [enumName] is empty); -1 when unknown.
  static const enumToInt = _enumToInt;
  /// The value at [index], clamped into range with a warning (Int →
  /// Enum); '' for an unknown or empty enum.
  static const intToEnum = _intToEnum;
  static const enumEqual = _enumEqual;
  static const getEnumValueCount = _getEnumValueCount;
  static const setTimerByEvent = _setTimerByEvent;
  static const setTimerByFunctionName = _setTimerByFunctionName;
  static const setTimerForNextTick = _setTimerForNextTick;
  static const clearTimerByHandle = _clearTimerByHandle;
  static const clearAndInvalidateTimer = _clearAndInvalidateTimer;
  static const pauseTimer = _pauseTimer;
  static const unpauseTimer = _unpauseTimer;
  static const isTimerActive = _isTimerActive;
  static const isTimerPaused = _isTimerPaused;
  static const getTimerRemainingTime = _getTimerRemainingTime;
  static const getTimerElapsedTime = _getTimerElapsedTime;
  /// The data arguments of a signature call node: every input but exec and
  /// the node's own settings.
  static const signatureArgs = _signatureArgs;

  // --- Game framework --------------------------------------------
  static const getGameInstance = _getGameInstance;
  static const getGameMode = _getGameMode;
  static const getGameState = _getGameState;
  static const getPlayerState = _getPlayerState;
  static const setGamePaused = _setGamePaused;
  static const isGamePaused = _isGamePaused;
  static const executeConsoleCommand = _executeConsoleCommand;
  static const getCurrentLevelName = _getCurrentLevelName;
  static const openLevel = _openLevel;
  /// Seconds of game time since this actor's BeginPlay.
  static const getGameTimeSinceCreation = _getGameTimeSinceCreation;
  /// Load Stream Level: loads (and shows) the streaming level [levelName];
  /// [onCompleted] runs on the actor's next latent advance once the level is
  /// in. An unknown level completes at once with a log.
  static const loadStreamLevel = _loadStreamLevel;
  static const unloadStreamLevel = _unloadStreamLevel;
  static const isStreamLevelLoaded = _isStreamLevelLoaded;

  // --- Level loading with progress --------------------------------
  /// The data outputs of a Load Level result pin for [p].
  static const levelLoadOutputs = _levelLoadOutputs;
  /// What a custom event bound to a level-loading delegate receives, by
  /// parameter name: `Percent`, `TotalCount`, `LoadedCount`,
  /// `CurrentContent`, `Error`, `StackTrace` (a custom event takes the ones it
  /// declares).
  static const levelLoadEventArgs = _levelLoadEventArgs;
  /// Load Level: preloads persistent level [levelName] through
  /// [LuminaLevelPreloader.instance]. [resume] re-enters the chain at
  /// `on_progress` once per loaded asset, then `on_success` — or `on_error`
  /// with the message and stack trace — with the node's outputs
  /// ([levelLoadOutputs]); the custom event bound to the matching delegate
  /// input runs after it with the same values.
  static const loadLevel = _loadLevel;
  /// Change Level: switches the game to [levelName] through the host
  /// ([LuminaGame.changeLevel]) — at once when it was preloaded, else after
  /// loading it; [resume] runs `on_success` after the new level's BeginPlay,
  /// or `on_error` with the message and stack trace.
  static const changeLevel = _changeLevel;
  /// Load And Change Level: Load Level then Change Level in one node, with
  /// only the error and success results.
  static const loadAndChangeLevel = _loadAndChangeLevel;
  /// Cancel Level Load: stops preloading [levelName] (every level when
  /// empty) and drops what it loaded.
  static const cancelLevelLoad = _cancelLevelLoad;
  /// Is Level Loaded: whether [levelName] is preloaded and can be switched
  /// to at once.
  static const isLevelLoaded = _isLevelLoaded;
  static const createSaveGameObject = _createSaveGameObject;
  /// A pin value as the save file stores it: JSON-plain, authoring space.
  static const saveFieldPlain = _saveFieldPlain;
  static const setSaveField = _setSaveField;
  /// The field as the pin type of the class's declaration (a stored
  /// `[x, y, z]` comes back as a Vector3); the raw value for an unknown class.
  static const getSaveField = _getSaveField;
  static const saveGameToSlot = _saveGameToSlot;
  static const loadGameFromSlot = _loadGameFromSlot;
  static const doesSaveGameExist = _doesSaveGameExist;
  static const deleteGameInSlot = _deleteGameInSlot;
  /// Async Save Game to Slot: writes on a background isolate; [onCompleted]
  /// runs with the result on the actor's next latent advance.
  static const asyncSaveGameToSlot = _asyncSaveGameToSlot;
  static const isInputKeyDown = _isInputKeyDown;
  static const getInputKeyTimeDown = _getInputKeyTimeDown;
  static const wasInputKeyJustPressed = _wasInputKeyJustPressed;
  static const getInputAxisValue = _getInputAxisValue;
  static const getMousePosition = _getMousePosition;
  static const setMousePosition = _setMousePosition;
  static const getLastInputDevice = _getLastInputDevice;
  static const getViewportSize = _getViewportSize;
  /// Enable Input: binds the Blueprint's input again after Disable Input.
  static const enableInput = _enableInput;
  static const disableInput = _disableInput;
  /// Project World to Screen: the viewport pixel of [worldLocation]
  /// (authoring space) through the view the world renders from; false when
  /// it lies behind the camera.
  static const projectWorldToScreen = _projectWorldToScreen;
  /// Deproject Screen to World: the ray through viewport pixel
  /// [screenPosition], in authoring space.
  static const deprojectScreenToWorld = _deprojectScreenToWorld;

  // --- Settings & Scalability -----------------------------------------
  static const setOverallScalabilityLevel = _setOverallScalabilityLevel;
  static const getOverallScalabilityLevel = _getOverallScalabilityLevel;
  static const setViewDistanceQuality = _setViewDistanceQuality;
  static const getViewDistanceQuality = _getViewDistanceQuality;
  static const setViewDistance = _setViewDistance;
  static const getViewDistance = _getViewDistance;
  static const setShadowQuality = _setShadowQuality;
  static const getShadowQuality = _getShadowQuality;
  static const setAntiAliasingQuality = _setAntiAliasingQuality;
  static const getAntiAliasingQuality = _getAntiAliasingQuality;
  static const setPostProcessingQuality = _setPostProcessingQuality;
  static const getPostProcessingQuality = _getPostProcessingQuality;
  static const setTextureQuality = _setTextureQuality;
  static const getTextureQuality = _getTextureQuality;
  static const setShadingQuality = _setShadingQuality;
  static const getShadingQuality = _getShadingQuality;
  static const setResolutionScale = _setResolutionScale;
  static const getResolutionScale = _getResolutionScale;
  static const setTargetFps = _setTargetFps;
  static const getTargetFps = _getTargetFps;
  static const setVsyncEnabled = _setVsyncEnabled;
  static const getVsyncEnabled = _getVsyncEnabled;
  static const applyScalabilitySettings = _applyScalabilitySettings;

  static const playSound2D = _playSound2D;
  static const playSoundAtLocation = _playSoundAtLocation;
  static const spawnSound2D = _spawnSound2D;
  static const spawnSoundAttached = _spawnSoundAttached;
  static const stopSound = _stopSound;
  static const fadeOutSound = _fadeOutSound;
  static const setSoundVolume = _setSoundVolume;
  static const setSoundPitch = _setSoundPitch;
  static const isSoundPlaying = _isSoundPlaying;
  static const setSoundClassVolume = _setSoundClassVolume;

  static const openVideo = _openVideo;
  static const playVideo = _playVideo;
  static const pauseVideo = _pauseVideo;
  static const stopVideo = _stopVideo;
  static const seekVideo = _seekVideo;
  static const setVideoVolume = _setVideoVolume;
  static const setVideoRate = _setVideoRate;
  static const setVideoLooping = _setVideoLooping;
  static const isVideoPlaying = _isVideoPlaying;
  static const getVideoPosition = _getVideoPosition;
  static const getVideoDuration = _getVideoDuration;

  /// Play Anim Montage: plays the montage's clip on the skeletal mesh while
  /// the Anim Blueprint stands aside; returns the length in seconds at
  /// [playRate], 0 when the montage or mesh is missing.
  static const playAnimMontage = _playAnimMontage;
  static const stopAnimMontage = _stopAnimMontage;
  static const montageJumpToSection = _montageJumpToSection;
  static const montageSetNextSection = _montageSetNextSection;
  static const isPlayingMontage = _isPlayingMontage;
  static const getCurrentMontage = _getCurrentMontage;
  static const getAnimInstance = _getAnimInstance;
  static const setAnimVariable = _setAnimVariable;
  static const getAnimVariable = _getAnimVariable;

  /// The owner's ragdoll (see `LuminaRagdollComponent`).
  static const startRagdoll = _startRagdoll;
  static const stopRagdoll = _stopRagdoll;
  static const toggleRagdoll = _toggleRagdoll;
  static const isRagdoll = _isRagdoll;
  static const addRagdollImpulse = _addRagdollImpulse;

  /// Traversal through the owner's traversal component (see its class).
  static const tryTraversalAction = _tryTraversalAction;
  static const traversalCheck = _traversalCheck;
  static const isTraversing = _isTraversing;
  static const spawnEmitterAtLocation = _spawnEmitterAtLocation;
  static const spawnEmitterAttached = _spawnEmitterAttached;
  static const activateParticleSystem = _activateParticleSystem;
  /// `Spawn Decal at Location`: the engine has no decal component yet,
  /// so nothing is spawned and the return value is null; the
  /// validator reports the node as not supported.
  static const spawnDecalAtLocation = _spawnDecalAtLocation;
  static const deactivateParticleSystem = _deactivateParticleSystem;
  static const setParticleParameter = _setParticleParameter;

  // --- Material -------------------------------------------------------
  static const createDynamicMaterialInstance = _createDynamicMaterialInstance;
  static const setScalarParameterValue = _setScalarParameterValue;
  static const setVectorParameterValue = _setVectorParameterValue;
  /// Set Texture Parameter Value: binds a texture asset (`contents/…/T_x.lmas`)
  /// or an image file to the sampler, with the texture's settings.
  static const setTextureParameterValue = _setTextureParameterValue;
  static const getScalarParameterValue = _getScalarParameterValue;
  /// Sets a scalar on every mesh of [target] (Self when unwired), making
  /// dynamic instances where a mesh has a material override.
  static const setMaterialScalarParameterOnActor = _setMaterialScalarParameterOnActor;

  // --- Light ----------------------------------------------------------
  static const setLightIntensity = _setLightIntensity;
  static const getLightIntensity = _getLightIntensity;
  static const setLightColor = _setLightColor;
  static const setLightVisibility = _setLightVisibility;
  static const toggleLightVisibility = _toggleLightVisibility;
  static const setLightRadius = _setLightRadius;
  static const setSpotLightAngles = _setSpotLightAngles;

  // --- Debug ----------------------------------------------------------

  /// Where Log Warning / Log Error go besides `developer.log`; the editor's
  /// Output Log hooks it.
  static void Function(LuminaActor self, String message, int level)? onLog;
  static const logWarning = _logWarning;
  static const logError = _logError;
  /// Breakpoint: nothing at run time; the editor's debugger pauses on it.
  static const breakpoint = _breakpoint;
  static const printText = _printText;
  static const drawDebugLine = _drawDebugLine;
  static const drawDebugSphere = _drawDebugSphere;
  static const drawDebugBox = _drawDebugBox;
  static const drawDebugPoint = _drawDebugPoint;
  static const drawDebugArrow = _drawDebugArrow;
  static const drawDebugString = _drawDebugString;
  static const drawDebugCapsule = _drawDebugCapsule;
  static const flushDebugShapes = _flushDebugShapes;

  // --- How generated code calls each node ----------------------------------

  static const _r = ['return_value'];

  /// One entry per [functions] key: the direct call generated code emits.
  static final Map<String, LuminaBlueprintCallShape> callShapes = Map.unmodifiable(<String, LuminaBlueprintCallShape>{
    ..._coreCallShapes,
    ..._objectCallShapes,
    ..._mathCallShapes,
    ..._engineCallShapes,
    ..._gameFrameworkCallShapes,
    ..._widgetBlueprintCallShapes,
    ..._ragdollCallShapes,
    ..._traversalCallShapes,
    // @@CALL_SHAPES_END
  });

  // --- The VM's dispatch table -----------------------------------------------

  static Map<String, Object?> _ret(Object? value) => {'return_value': value};
  static double _d(Object? v, double fallback) => v is num ? v.toDouble() : fallback;
  static int _n(Object? v, int fallback) => v is num ? v.toInt() : fallback;
  static List<double> _c(Object? v) => v is List
      ? [for (var i = 0; i < 4; i++) i < v.length && v[i] is num ? (v[i] as num).toDouble() : (i == 3 ? 1.0 : 0.0)]
      : const [1.0, 1.0, 1.0, 1.0];

  /// Every node the VM can call, keyed by node id: the built-ins, then the
  /// functions registered in [LuminaBlueprintFunctionRegistry].
  /// Inputs arrive converted to their pin types (the VM resolves wires,
  /// literals and defaults first).
  static final Map<String, LuminaBlueprintFunction> functions =
      _WithRegistered();

  /// One entry per pure / impure built-in node, keyed by node id.
  static final Map<String, LuminaBlueprintFunction>
  builtInFunctions = Map.unmodifiable(<String, LuminaBlueprintFunction>{
    ..._coreFunctions,
    ..._objectFunctions,
    ..._mathFunctions,
    ..._engineFunctions,
    ..._graphMemberFunctions,
    ..._gameFrameworkFunctions,
    ..._widgetBlueprintFunctions,
    ..._ragdollFunctions,
    ..._traversalFunctions,
    // @@FUNCTIONS_END
  });
}

/// [LuminaBlueprintFunctionLibrary.functions]: the built-ins, then the
/// registry's callable functions, read live.
class _WithRegistered
    extends UnmodifiableMapBase<String, LuminaBlueprintFunction> {
  @override
  LuminaBlueprintFunction? operator [](Object? key) => key is String
      ? LuminaBlueprintFunctionLibrary.builtInFunctions[key] ??
            LuminaBlueprintFunctionRegistry.function(key)
      : null;

  @override
  bool containsKey(Object? key) => this[key] != null;

  @override
  Iterable<String> get keys => LuminaBlueprintFunctionRegistry.isEmpty
      ? LuminaBlueprintFunctionLibrary.builtInFunctions.keys
      : [
          ...LuminaBlueprintFunctionLibrary.builtInFunctions.keys,
          ...LuminaBlueprintFunctionRegistry.callableIds,
        ];
}
