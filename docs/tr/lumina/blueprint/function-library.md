[English](../../../en/lumina/blueprint/function-library.md)

# Blueprint fonksiyon kütüphanesi

Blueprint fonksiyon kütüphanesi: her pure ve impure node'un bir kez yazılmış davranışı. VM onu fonksiyon tablosu üzerinden çağırır, üretilen Dart kodu aynı static metotları doğrudan çağırır; böylece ikisi de aynı kodu çalıştırır. Dosya yolları `lumina/` paket dizinine görelidir.

## `lib/src/blueprint/blueprint_function_library.dart`

### `class LuminaBlueprintCallContext`

What a node function gets when the VM calls it: the Blueprint instance it runs on.

**Yapıcı Metotlar (Constructors):**

- `const LuminaBlueprintCallContext(this.self)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `self` | `final LuminaActor self` |  |

### `typedef LuminaBlueprintFunction`

A node's behaviour as the VM calls it: inputs by pin id → outputs by pin id.

### `class LuminaBlueprintCallShape`

How generated code calls a node's function: the static method on [LuminaBlueprintFunctionLibrary], its arguments as input pin ids in order, whether the Blueprint itself (`self`) comes first, and its outputs: none, `return_value`, or record fields named after the pins.

A Dart function exposed with `@BlueprintCallable` / `@BlueprintPure` also names the [library] it is imported from, and which arguments are [named] and which [optional] (left out of a direct call when the pin is neither wired nor set, so Dart's default applies).

**Yapıcı Metotlar (Constructors):**

- `const LuminaBlueprintCallShape(this.method, this.args, {this.self = false, this.outputs = const [], this.library, this.named = const {}, this.optional = const {...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `method` | `final String method` | The function: a method of [LuminaBlueprintFunctionLibrary], or for a [library] function its name (`applyDamage`, `Class.method`). |
| `args` | `final List<String> args` |  |
| `self` | `final bool self` |  |
| `outputs` | `final List<String> outputs` |  |
| `library` | `final String? library` | The library URI an exposed function is imported from; null for the function library. |
| `named` | `final Set<String> named` | Arguments passed by name. |
| `optional` | `final Set<String> optional` | Arguments with a Dart default (optional named or positional). |
| `record` | `final bool record` | The outputs are a record's fields even when there is one. |
| `returnsRecord` | `bool get returnsRecord` |  |

### `abstract final class LuminaBlueprintFunctionLibrary`

Every pure and impure node's behaviour, written once. The VM calls it through [functions]; generated Dart calls the static methods directly, so both run the same code.

Vectors and rotators are **authoring space** (cm, Z up; rotators about X/Y/Z like the Details panel). This class is the one place they cross into the Y-up runtime.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `toRuntime` | `static const toRuntime` | Authoring (x, y, z) → runtime (x, z, −y): `LuminaAxes.location`. |
| `toAuthoring` | `static const toAuthoring` | Runtime → authoring: `LuminaAxes.toAuthoringLocation`. |
| `toControlRotation` | `static const toControlRotation` | A rotator as the pawn's runtime Euler (pitch X, yaw Y, roll Z): pitch is about authoring X, yaw about authoring Z (runtime Y), roll about authoring Y (runtime −Z). |
| `fromControlRotation` | `static const fromControlRotation` |  |
| `onPrintString` | `static void Function(LuminaActor self, String text) onPrintString` | Where Print String goes; the VM and generated code route it into the instance's trace. |
| `printString` | `static const printString` | Print String: to the log (through [onPrintString]) and to the screen (`LuminaWorld.screenMessages`, drawn by the PIE HUD overlay); a [key] replaces the line printed with the same key. |
| `addMovementInput` | `static const addMovementInput` | Add Movement Input: characters feed their movement component, like `LuminaTemplateCharacter.onMove`; other pawns accumulate input. |
| `addControllerYawInput` | `static const addControllerYawInput` |  |
| `addControllerPitchInput` | `static const addControllerPitchInput` |  |
| `getControlRotation` | `static const getControlRotation` | The controller's rotation; zero without a controller. |
| `setFreeLook` | `static const setFreeLook` | Set Free Look: the body keeps its heading while the controller (and the camera boom) turns; off recentres the camera. |
| `isFreeLooking` | `static const isFreeLooking` |  |
| `jump` | `static const jump` |  |
| `stopJumping` | `static const stopJumping` |  |
| `getVelocity` | `static const getVelocity` |  |
| `isFalling` | `static const isFalling` |  |
| `getActorLocation` | `static const getActorLocation` |  |
| `setActorLocation` | `static const setActorLocation` | Teleports; `sweep` is not supported (the validator warns when it is set). |
| `getActorRotation` | `static const getActorRotation` |  |
| `createWidget` | `static const createWidget` | A widget instance: a JSON-plain map with the class, the owner, viewport state and, per named element of the class (from [LuminaWidgetClassRegistry]), that element's own state. |
| `addToViewport` | `static const addToViewport` |  |
| `removeFromParent` | `static const removeFromParent` |  |
| `setWidgetVisibility` | `static const setWidgetVisibility` |  |
| `isInViewport` | `static const isInViewport` |  |
| `getOwningPlayer` | `static const getOwningPlayer` |  |
| `setWidgetText` | `static const setWidgetText` | Deprecated: writes the widget's legacy `text` and every Text element. Use `Get <element>` → `Set Text (Text)`. |
| `setWidgetPercent` | `static const setWidgetPercent` | Deprecated: writes the widget's legacy `percent` and every Progress Bar element. Use `Get <element>` → `Set Percent`. |
| `getWidgetVariable` | `static const getWidgetVariable` | A widget's own `Is Variable` element, and Self, in its graph. |
| `getWidgetSelf` | `static const getWidgetSelf` |  |
| `isWidgetInstance` | `static const isWidgetInstance` | Whether [widget] is a widget instance map (has a `class` and `elements`). |
| `isWidgetElement` | `static const isWidgetElement` | Whether [o] is a widget element state map. |
| `classOf` | `static const classOf` | The class string of a runtime object (`Widget:WBP_HUD`, `WidgetElement:text`, `Component:LuminaSpringArmComponent`, `Actor:BP_Door`), `Object` for anything else, '' for null. |
| `actorClassChain` | `static const actorClassChain` | Bir çalışma zamanı aktörünün en türetilmişten en temele sınıf zinciri: Blueprint'in kendi adı, üst Blueprint sınıf hiyerarşisi, ardından ait olduğu motor sınıfları (`LuminaCharacter`, `LuminaPawn`, `LuminaActor`). |
| `isA` | `static const isA` | [o] nesnesinin [cls] sınıf dizesinin bir örneği olup olmadığı (Is A düğümü): `Object` herhangi bir nesneyle eşleşir, tek başına bir tür (`Actor`, `Widget`) o türdeki herhangi bir nesneyle eşleşir; bir aktör sınıfının kendisi ya da ata Blueprint / motor sınıflarından biriyle eşleşir. |
| `isValid` | `static const isValid` |  |
| `castTo` | `static const castTo` | [object] when it [isA] [cls], else null (Cast To). |
| `getClassName` | `static const getClassName` |  |
| `getDisplayName` | `static const getDisplayName` |  |
| `getWidgetElement` | `static const getWidgetElement` | The element [element] of widget [target] (its state map), null when the widget has no such element. |
| `setElementVisibility` | `static const setElementVisibility` |  |
| `getElementVisibility` | `static const getElementVisibility` |  |
| `isElementVisible` | `static const isElementVisible` |  |
| `setElementIsEnabled` | `static const setElementIsEnabled` |  |
| `getElementIsEnabled` | `static const getElementIsEnabled` |  |
| `setElementRenderOpacity` | `static const setElementRenderOpacity` |  |
| `setElementText` | `static const setElementText` |  |
| `getElementText` | `static const getElementText` |  |
| `setElementColor` | `static const setElementColor` |  |
| `setElementFontSize` | `static const setElementFontSize` |  |
| `setElementShadowEnabled` | `static const setElementShadowEnabled` |  |
| `setElementShadowColor` | `static const setElementShadowColor` |  |
| `setElementShadowOffset` | `static const setElementShadowOffset` |  |
| `setElementOutline` | `static const setElementOutline` |  |
| `setElementPercent` | `static const setElementPercent` |  |
| `getElementPercent` | `static const getElementPercent` |  |
| `setElementFillColor` | `static const setElementFillColor` |  |
| `setElementBrushFromTexture` | `static const setElementBrushFromTexture` |  |
| `setElementImageColor` | `static const setElementImageColor` |  |
| `setElementLabel` | `static const setElementLabel` |  |
| `setElementSliderValue` | `static const setElementSliderValue` |  |
| `getElementSliderValue` | `static const getElementSliderValue` |  |
| `setElementIsChecked` | `static const setElementIsChecked` |  |
| `getElementIsChecked` | `static const getElementIsChecked` |  |
| `setElementEditableText` | `static const setElementEditableText` |  |
| `getElementEditableText` | `static const getElementEditableText` |  |
| `setElementHintText` | `static const setElementHintText` |  |
| `setElementSelectedOption` | `static const setElementSelectedOption` |  |
| `getElementSelectedOption` | `static const getElementSelectedOption` |  |
| `addElementOption` | `static const addElementOption` |  |
| `clearElementOptions` | `static const clearElementOptions` |  |
| `setElementActiveIndex` | `static const setElementActiveIndex` |  |
| `getElementActiveIndex` | `static const getElementActiveIndex` |  |
| `setElementBackgroundColor` | `static const setElementBackgroundColor` |  |
| `setElementBorderColor` | `static const setElementBorderColor` |  |
| `setElementCornerRadius` | `static const setElementCornerRadius` |  |
| `setElementPadding` | `static const setElementPadding` |  |
| `getComponent` | `static const getComponent` | The component named [component] in the Blueprint, else null. |
| `getComponentByClass` | `static const getComponentByClass` | The first component of class [cls] (`Component:LuminaCameraComponent` or the bare class name) on [self], else null. |
| `addComponent` | `static const addComponent` | Adds a component of class [cls] to [self] at run time, attached to its root; null when the class has no runtime counterpart. |
| `setRelativeLocation` | `static const setRelativeLocation` |  |
| `setRelativeRotation` | `static const setRelativeRotation` |  |
| `setRelativeScale` | `static const setRelativeScale` |  |
| `getRelativeLocation` | `static const getRelativeLocation` |  |
| `getRelativeRotation` | `static const getRelativeRotation` |  |
| `getRelativeScale` | `static const getRelativeScale` |  |
| `setWorldLocation` | `static const setWorldLocation` |  |
| `setWorldRotation` | `static const setWorldRotation` |  |
| `getWorldLocation` | `static const getWorldLocation` |  |
| `getWorldRotation` | `static const getWorldRotation` |  |
| `attachToComponent` | `static const attachToComponent` |  |
| `setComponentVisibility` | `static const setComponentVisibility` |  |
| `setHiddenInGame` | `static const setHiddenInGame` |  |
| `getSocketLocation` | `static const getSocketLocation` |  |
| `setTargetArmLength` | `static const setTargetArmLength` |  |
| `getTargetArmLength` | `static const getTargetArmLength` |  |
| `setCameraLagEnabled` | `static const setCameraLagEnabled` |  |
| `setCameraLagSpeed` | `static const setCameraLagSpeed` |  |
| `setSocketOffset` | `static const setSocketOffset` |  |
| `setFieldOfView` | `static const setFieldOfView` |  |
| `getFieldOfView` | `static const getFieldOfView` |  |
| `setCameraActive` | `static const setCameraActive` |  |
| `isCameraActive` | `static const isCameraActive` |  |
| `playAnimation` | `static const playAnimation` |  |
| `stopAnimation` | `static const stopAnimation` |  |
| `setAnimClass` | `static const setAnimClass` | Swaps the mesh's Animation Blueprint for [animClass] (a project `.lmas` path the Blueprint's anim class resolver knows); '' removes it. |
| `setPlayRate` | `static const setPlayRate` |  |
| `getCurrentClip` | `static const getCurrentClip` |  |
| `setStaticMesh` | `static const setStaticMesh` | Replaces the mesh component with one loading [newMesh] (same parent, transform and shadow flags), keeping the Blueprint's component id. |
| `setMaterial` | `static const setMaterial` | Sets the material at [elementIndex] to the material asset [material]: loaded through the world's material cache when the world renders, else remembered on the component's owner for the world to apply. |
| `setCollisionEnabled` | `static const setCollisionEnabled` | Set Collision Enabled: a `NoCollision` / `QueryOnly` / `QueryAndPhysics` literal (or a plain bool from older graphs). `NoCollision` disables the component; the query modes enable it and its overlap events. |
| `setCollisionPreset` | `static const setCollisionPreset` |  |
| `getCollisionPreset` | `static const getCollisionPreset` |  |
| `setCollisionResponseToChannel` | `static const setCollisionResponseToChannel` |  |
| `setCollisionResponseToAllChannels` | `static const setCollisionResponseToAllChannels` |  |
| `getCollisionResponseToChannel` | `static const getCollisionResponseToChannel` |  |
| `setCollisionObjectType` | `static const setCollisionObjectType` |  |
| `getCollisionObjectType` | `static const getCollisionObjectType` |  |
| `setGenerateOverlapEvents` | `static const setGenerateOverlapEvents` |  |
| `setBoxExtent` | `static const setBoxExtent` | Set Box Extent: authoring (X, Y, Z) half extents → runtime axes. |
| `getBoxExtent` | `static const getBoxExtent` |  |
| `setSphereRadius` | `static const setSphereRadius` |  |
| `getSphereRadius` | `static const getSphereRadius` |  |
| `setCapsuleSize` | `static const setCapsuleSize` |  |
| `getScaledCapsuleRadius` | `static const getScaledCapsuleRadius` |  |
| `getScaledCapsuleHalfHeight` | `static const getScaledCapsuleHalfHeight` |  |
| `getOverlappingActors` | `static const getOverlappingActors` | The actors (deduplicated) with a component overlapping [target] right now, filtered by [cls]; the component's owner is left out. |
| `getOverlappingComponents` | `static const getOverlappingComponents` |  |
| `isOverlappingActor` | `static const isOverlappingActor` |  |
| `setSimulatePhysics` | `static const setSimulatePhysics` |  |
| `isSimulatingPhysics` | `static const isSimulatingPhysics` |  |
| `addImpulse` | `static const addImpulse` |  |
| `addImpulseAtLocation` | `static const addImpulseAtLocation` |  |
| `addForce` | `static const addForce` |  |
| `addForceAtLocation` | `static const addForceAtLocation` |  |
| `addTorqueInRadians` | `static const addTorqueInRadians` |  |
| `addAngularImpulseInRadians` | `static const addAngularImpulseInRadians` |  |
| `setPhysicsLinearVelocity` | `static const setPhysicsLinearVelocity` |  |
| `getPhysicsLinearVelocity` | `static const getPhysicsLinearVelocity` |  |
| `setPhysicsAngularVelocityInDegrees` | `static const setPhysicsAngularVelocityInDegrees` |  |
| `getPhysicsAngularVelocityInDegrees` | `static const getPhysicsAngularVelocityInDegrees` |  |
| `getMass` | `static const getMass` | The body's mass (kg): its override, the static mesh's, or density × volume. |
| `setMassOverrideInKg` | `static const setMassOverrideInKg` |  |
| `setEnableGravity` | `static const setEnableGravity` |  |
| `setLinearDamping` | `static const setLinearDamping` |  |
| `setAngularDamping` | `static const setAngularDamping` |  |
| `wakeRigidBody` | `static const wakeRigidBody` |  |
| `putRigidBodyToSleep` | `static const putRigidBodyToSleep` |  |
| `isAnyRigidBodyAwake` | `static const isAnyRigidBodyAwake` |  |
| `setCollisionLayer` | `static const setCollisionLayer` |  |
| `setMaxWalkSpeed` | `static const setMaxWalkSpeed` |  |
| `getMaxWalkSpeed` | `static const getMaxWalkSpeed` |  |
| `setJumpZVelocity` | `static const setJumpZVelocity` |  |
| `getJumpZVelocity` | `static const getJumpZVelocity` |  |
| `setGravityScale` | `static const setGravityScale` |  |
| `getGravityScale` | `static const getGravityScale` |  |
| `setAirControl` | `static const setAirControl` |  |
| `getAirControl` | `static const getAirControl` |  |
| `movementModes` | `static const Map<String, MovementMode> movementModes` |  |
| `setMovementMode` | `static const setMovementMode` |  |
| `getMovementMode` | `static const getMovementMode` |  |
| `crouch` | `static const crouch` |  |
| `unCrouch` | `static const unCrouch` |  |
| `isCrouched` | `static const isCrouched` |  |
| `launchCharacter` | `static const launchCharacter` |  |
| `stopMovementImmediately` | `static const stopMovementImmediately` |  |
| `getPlayerController` | `static const getPlayerController` |  |
| `getPlayerPawn` | `static const getPlayerPawn` |  |
| `getPlayerCharacter` | `static const getPlayerCharacter` |  |
| `setShowMouseCursor` | `static const setShowMouseCursor` |  |
| `setInputModeGameAndUI` | `static const setInputModeGameAndUI` |  |
| `setInputModeGameOnly` | `static const setInputModeGameOnly` |  |
| `setInputModeUIOnly` | `static const setInputModeUIOnly` |  |
| `makeVector2D` | `static const makeVector2D` |  |
| `breakVector2D` | `static const breakVector2D` |  |
| `makeVector` | `static const makeVector` |  |
| `breakVector` | `static const breakVector` |  |
| `makeRotator` | `static const makeRotator` |  |
| `breakRotator` | `static const breakRotator` |  |
| `getForwardVector` | `static const getForwardVector` | The direction a pawn facing [inRot] moves forward: the pawn's own `forwardVector` for that rotation (so a Blueprint character walks exactly like `LuminaTemplateCharacter`), in authoring space. |
| `getRightVector` | `static const getRightVector` |  |
| `calculateDirection` | `static const calculateDirection` | Calculate Direction: the signed angle in degrees, right positive, from the facing of [baseRotation] to [velocity], on the ground plane; 0 when not moving. The facing is the pawn's own forward for that rotation, as the locomotion driver measures it. |
| `vectorLength` | `static const vectorLength` |  |
| `vectorLengthXY` | `static const vectorLengthXY` | Horizontal length: authoring Z is up. |
| `vectorScale` | `static const vectorScale` |  |
| `vectorAdd` | `static const vectorAdd` |  |
| `floatAdd` | `static const floatAdd` |  |
| `floatSubtract` | `static const floatSubtract` |  |
| `floatMultiply` | `static const floatMultiply` |  |
| `floatDivide` | `static const floatDivide` | Division by zero returns 0. |
| `floatClamp` | `static const floatClamp` |  |
| `floatGreater` | `static const floatGreater` |  |
| `floatLess` | `static const floatLess` |  |
| `floatEqual` | `static const floatEqual` |  |
| `boolAnd` | `static const boolAnd` |  |
| `boolOr` | `static const boolOr` |  |
| `boolNot` | `static const boolNot` |  |
| `floatAbs` | `static const floatAbs` |  |
| `floatMin` | `static const floatMin` |  |
| `floatMax` | `static const floatMax` |  |
| `floatLerp` | `static const floatLerp` |  |
| `floatInterpTo` | `static const floatInterpTo` | Moves [current] towards [target] by `distance × speed × dt`, arriving exactly; speed ≤ 0 jumps. |
| `floatSqrt` | `static const floatSqrt` |  |
| `floatPower` | `static const floatPower` |  |
| `floatModulo` | `static const floatModulo` | fmod; division by zero returns 0. |
| `floatSign` | `static const floatSign` |  |
| `floatMapRangeClamped` | `static const floatMapRangeClamped` |  |
| `floatNearlyEqual` | `static const floatNearlyEqual` |  |
| `floatSin` | `static const floatSin` |  |
| `floatCos` | `static const floatCos` |  |
| `floatTan` | `static const floatTan` |  |
| `floatAsin` | `static const floatAsin` |  |
| `floatAcos` | `static const floatAcos` |  |
| `floatAtan` | `static const floatAtan` |  |
| `floatAtan2` | `static const floatAtan2` |  |
| `degreesToRadians` | `static const degreesToRadians` |  |
| `radiansToDegrees` | `static const radiansToDegrees` |  |
| `floatGreaterEqual` | `static const floatGreaterEqual` |  |
| `floatLessEqual` | `static const floatLessEqual` |  |
| `floatNotEqual` | `static const floatNotEqual` |  |
| `random` | `static math.Random random` | The random source of the Random nodes; tests may seed it. |
| `randomFloatInRange` | `static const randomFloatInRange` |  |
| `randomBoolWithWeight` | `static const randomBoolWithWeight` |  |
| `selectFloat` | `static const selectFloat` |  |
| `round` | `static const round` |  |
| `truncate` | `static const truncate` |  |
| `ceil` | `static const ceil` |  |
| `floor` | `static const floor` |  |
| `intToFloat` | `static const intToFloat` |  |
| `intAdd` | `static const intAdd` |  |
| `intSubtract` | `static const intSubtract` |  |
| `intMultiply` | `static const intMultiply` |  |
| `intDivide` | `static const intDivide` | Division by zero returns 0. |
| `intModulo` | `static const intModulo` |  |
| `intClamp` | `static const intClamp` |  |
| `intAbs` | `static const intAbs` |  |
| `intMin` | `static const intMin` |  |
| `intMax` | `static const intMax` |  |
| `intGreater` | `static const intGreater` |  |
| `intLess` | `static const intLess` |  |
| `intEqual` | `static const intEqual` |  |
| `intNotEqual` | `static const intNotEqual` |  |
| `intGreaterEqual` | `static const intGreaterEqual` |  |
| `intLessEqual` | `static const intLessEqual` |  |
| `randomIntegerInRange` | `static const randomIntegerInRange` |  |
| `intIncrement` | `static const intIncrement` |  |
| `selectInt` | `static const selectInt` |  |
| `vectorNormalize` | `static const vectorNormalize` |  |
| `vectorDot` | `static const vectorDot` |  |
| `vectorCross` | `static const vectorCross` |  |
| `vectorDistance` | `static const vectorDistance` |  |
| `vectorDistance2D` | `static const vectorDistance2D` |  |
| `vectorLerp` | `static const vectorLerp` |  |
| `vectorInterpTo` | `static const vectorInterpTo` |  |
| `vectorSubtract` | `static const vectorSubtract` |  |
| `vectorDivideFloat` | `static const vectorDivideFloat` |  |
| `vectorNegate` | `static const vectorNegate` |  |
| `vectorEqual` | `static const vectorEqual` |  |
| `vectorProjectOnTo` | `static const vectorProjectOnTo` |  |
| `rotateVectorAroundAxis` | `static const rotateVectorAroundAxis` | Rodrigues' rotation of [inVect] by [angleDeg] about [axis] (authoring axes, right-handed). |
| `getUpVector` | `static const getUpVector` |  |
| `randomUnitVector` | `static const randomUnitVector` |  |
| `vectorIsZero` | `static const vectorIsZero` |  |
| `selectVector` | `static const selectVector` |  |
| `normalizeAxis` | `static const normalizeAxis` | Wraps [angle] into (-180, 180]. |
| `clampAngle` | `static const clampAngle` | Normalises first, then clamps. |
| `combineRotators` | `static const combineRotators` | [a] applied first, then [b]. |
| `deltaRotator` | `static const deltaRotator` | `a - b`, each axis normalised. |
| `rotatorLerp` | `static const rotatorLerp` | Lerps each axis along the shortest path. |
| `rotatorInterpTo` | `static const rotatorInterpTo` |  |
| `findLookAtRotation` | `static const findLookAtRotation` | The rotator whose forward ([getForwardVector]) points from [start] to [target], so a Set Actor Rotation from it faces the target: yaw 0 faces +Y (authoring), yaw 90 faces +X; no roll. |
| `makeRotFromX` | `static const makeRotFromX` | The rotator whose forward is [x] (see [findLookAtRotation]). The forward for (pitch p, yaw y) is `(cos p·sin y, cos p·cos y, sin p)` (`luminaPawnEulerToQuaternion`: positive pitch looks up, about the view's own right axis), which this inverts exactly. |
| `rotatorEqual` | `static const rotatorEqual` |  |
| `rotatorToVector` | `static const rotatorToVector` | The forward direction of [inRot]. |
| `makeTransform` | `static const makeTransform` |  |
| `breakTransform` | `static const breakTransform` |  |
| `transformLocation` | `static const transformLocation` |  |
| `inverseTransformLocation` | `static const inverseTransformLocation` |  |
| `transformDirection` | `static const transformDirection` |  |
| `composeTransforms` | `static const composeTransforms` | [a] then [b]: the transform that applies [a] in [b]'s space. |
| `makeColor` | `static const makeColor` |  |
| `breakColor` | `static const breakColor` |  |
| `colorLerp` | `static const colorLerp` |  |
| `hexToColor` | `static const hexToColor` | `#RRGGBB` or `#RRGGBBAA` (the `#` is optional); unparsable → white. |
| `colorToHex` | `static const colorToHex` |  |
| `floatToString` | `static const floatToString` |  |
| `intToString` | `static const intToString` |  |
| `boolToString` | `static const boolToString` |  |
| `vectorToString` | `static const vectorToString` |  |
| `rotatorToString` | `static const rotatorToString` |  |
| `stringToFloat` | `static const stringToFloat` |  |
| `stringToInt` | `static const stringToInt` |  |
| `append` | `static const append` |  |
| `append3` | `static const append3` |  |
| `formatString` | `static const formatString` | Replaces `{0}`…`{3}` with the arguments that are set; a placeholder whose argument is empty stays as written. |
| `stringLength` | `static const stringLength` |  |
| `stringEqual` | `static const stringEqual` |  |
| `stringContains` | `static const stringContains` |  |
| `stringReplace` | `static const stringReplace` |  |
| `stringToUpper` | `static const stringToUpper` |  |
| `stringToLower` | `static const stringToLower` |  |
| `stringSubstring` | `static const stringSubstring` |  |
| `stringSplit` | `static const stringSplit` |  |
| `stringIsEmpty` | `static const stringIsEmpty` |  |
| `stringTrim` | `static const stringTrim` |  |
| `selectString` | `static const selectString` |  |
| `selectBool` | `static const selectBool` |  |
| `selectObject` | `static const selectObject` |  |
| `sameItem` | `static const sameItem` | Whether two array items are the same value: identity, `==`, or the same components for colours / lists. |
| `arrayItems` | `static const arrayItems` | A copy of [v]'s items when it is an array, else no items: what a ForEachLoop iterates (the VM and generated code alike). |
| `arrayLength` | `static const arrayLength` |  |
| `arrayLastIndex` | `static const arrayLastIndex` |  |
| `arrayIsEmpty` | `static const arrayIsEmpty` |  |
| `arrayGet` | `static const arrayGet` | The item at [index], or null (logged once per index / length pair) when the index is out of range. |
| `arrayContains` | `static const arrayContains` |  |
| `arrayFind` | `static const arrayFind` |  |
| `arrayFirst` | `static const arrayFirst` |  |
| `arrayLast` | `static const arrayLast` |  |
| `makeArray` | `static const makeArray` |  |
| `arrayAdd` | `static const arrayAdd` | Adds [newItem] in place and returns its index. |
| `arrayRemoveIndex` | `static const arrayRemoveIndex` |  |
| `arrayClear` | `static const arrayClear` |  |
| `arraySet` | `static const arraySet` |  |
| `arrayFilterByClass` | `static const arrayFilterByClass` | The objects of [targetArray] that are a [cls] (`Actor:BP_Door`). |
| `arrayShuffle` | `static const arrayShuffle` |  |
| `multiGateNext` | `static const multiGateNext` | MultiGate's next output: [used] outputs so far (null = fresh), the output [count], and the node's settings. Returns the output index to take (-1 when every output was used and Loop is off) and the new used list. |
| `whileLoopCapped` | `static const whileLoopCapped` | Logs a WhileLoop that hit its iteration cap. |
| `makeHitResult` | `static const makeHitResult` |  |
| `breakHitResult` | `static const breakHitResult` |  |
| `getFrameRate` | `static const getFrameRate` |  |
| `getFrameTimeMs` | `static const getFrameTimeMs` |  |
| `getFrameNumber` | `static const getFrameNumber` |  |
| `getWorldDeltaSeconds` | `static const getWorldDeltaSeconds` |  |
| `getGameTimeInSeconds` | `static const getGameTimeInSeconds` |  |
| `getRealTimeSeconds` | `static const getRealTimeSeconds` |  |
| `getActorCount` | `static const getActorCount` |  |
| `getTimeDilation` | `static const getTimeDilation` |  |
| `setTimeDilation` | `static const setTimeDilation` |  |
| `getPlatformName` | `static const getPlatformName` | `Linux`, `Windows`, `MacOS`, `Android`, `IOS`, `Web`. |
| `isEditor` | `static const isEditor` |  |
| `quitGame` | `static const quitGame` | Asks the game host to quit (`LuminaGame.onQuitRequested`): the built game exits, Play-In-Editor stops the session. With no host hook it only logs. |
| `traceChannels` | `static const List<String> traceChannels` | The trace channels a `Channel` literal may name (on Lumina's layers and object types): `Visibility` and `Camera` see everything, `WorldStatic` / `WorldDynamic` / `Pawn` one object type, `Layer N` one layer. |
| `isTraceChannel` | `static const isTraceChannel` | Whether [channel] is a channel name a trace accepts. |
| `hitToMap` | `static const hitToMap` | A hit as the `hitResult` pin carries it: authoring-space vectors, the actor and the component. |
| `hitEventOutputs` | `static const hitEventOutputs` | The Event Hit outputs for a blocking hit of [self] against [other]: the VM dispatches them, generated classes pass the same map. |
| `lineTraceByChannel` | `static const lineTraceByChannel` | Line Trace By Channel: the first blocking hit between [start] and [end] (authoring space). Self is always ignored. |
| `multiLineTraceByChannel` | `static const multiLineTraceByChannel` | Multi Line Trace By Channel: every hit, nearest first. |
| `sphereTraceByChannel` | `static const sphereTraceByChannel` | Sphere Trace By Channel: a sphere of [radius] swept from [start] to [end]. |
| `lineTraceForward` | `static const lineTraceForward` |  |
| `multiLineTraceForward` | `static const multiLineTraceForward` |  |
| `sphereTraceForward` | `static const sphereTraceForward` |  |
| `sphereOverlapActors` | `static const sphereOverlapActors` | Sphere Overlap Actors: the actors of [cls] with a component inside the sphere, nearest first. Self is left out. |
| `getLookForwardDirection` | `static const getLookForwardDirection` | Where Self looks: along its control rotation when a controller drives it, else its own facing (authoring space, unit length). |
| `getActorEyesViewPoint` | `static const getActorEyesViewPoint` | Self's eyes (a pawn's Base Eye Height above its location) and its view rotation; a plain actor's location and rotation. |
| `findLookAtLocation` | `static const findLookAtLocation` |  |
| `getAllActorsOfClass` | `static const getAllActorsOfClass` |  |
| `getAllActorsWithTag` | `static const getAllActorsWithTag` |  |
| `getActorsWithinRadius` | `static const getActorsWithinRadius` | The actors of [cls] within [radius] of [location], nearest first. |
| `getActorsInViewCone` | `static const getActorsInViewCone` | The actors of [cls] (other than Self) within [distance] of Self's eyes and within [coneAngle] degrees of its look direction, nearest first. |
| `getClosestActorOfClassInDirection` | `static const getClosestActorOfClassInDirection` |  |
| `setViewTarget` | `static const setViewTarget` |  |
| `blendFunctions` | `static const Map<String, LuminaViewTargetBlendFunction> blendFunctions` |  |
| `setViewTargetWithBlend` | `static const setViewTargetWithBlend` |  |
| `getViewTarget` | `static const getViewTarget` |  |
| `getPlayerCameraManager` | `static const getPlayerCameraManager` |  |
| `getActiveCamera` | `static const getActiveCamera` | Self's active camera component, else its first camera. |
| `getCameraLocation` | `static const getCameraLocation` | Where the world renders from (the view target, or the active camera). |
| `getCameraRotation` | `static const getCameraRotation` |  |
| `spawnActorFromClass` | `static const spawnActorFromClass` | Spawn Actor from Class: a new actor of [cls] (a Blueprint class registered in [LuminaBlueprintActorClasses], or `LuminaActor` / `LuminaPawn` / `LuminaCharacter`) at [spawnTransform], registered in Self's world at once with its BeginPlay run. Null (and a log) when the class is unknown. |
| `destroyActor` | `static const destroyActor` |  |
| `setLifeSpan` | `static const setLifeSpan` |  |
| `getActorTransform` | `static const getActorTransform` |  |
| `setActorTransform` | `static const setActorTransform` |  |
| `setActorRotation` | `static const setActorRotation` |  |
| `setActorScale3D` | `static const setActorScale3D` |  |
| `getActorScale3D` | `static const getActorScale3D` |  |
| `setActorHiddenInGame` | `static const setActorHiddenInGame` |  |
| `isHidden` | `static const isHidden` |  |
| `setActorEnableCollision` | `static const setActorEnableCollision` |  |
| `getActorEnableCollision` | `static const getActorEnableCollision` |  |
| `teleport` | `static const teleport` |  |
| `getActorBounds` | `static const getActorBounds` |  |
| `getActorForwardVector` | `static const getActorForwardVector` |  |
| `getActorRightVector` | `static const getActorRightVector` |  |
| `getActorUpVector` | `static const getActorUpVector` |  |
| `attachActorToComponent` | `static const attachActorToComponent` |  |
| `detachFromActor` | `static const detachFromActor` |  |
| `getAttachParentActor` | `static const getAttachParentActor` |  |
| `getOwner` | `static const getOwner` |  |
| `setOwner` | `static const setOwner` |  |
| `getInstigator` | `static const getInstigator` |  |
| `actorHasTag` | `static const actorHasTag` |  |
| `addTag` | `static const addTag` |  |
| `removeTag` | `static const removeTag` |  |
| `getDistanceTo` | `static const getDistanceTo` |  |
| `getHorizontalDistanceTo` | `static const getHorizontalDistanceTo` |  |
| `isActorBeingDestroyed` | `static const isActorBeingDestroyed` |  |
| `applyDamage` | `static const applyDamage` | Apply Damage; an unwired Damaged Actor is Self. |
| `applyPointDamage` | `static const applyPointDamage` |  |
| `applyRadialDamage` | `static const applyRadialDamage` |  |
| `callBlueprint` | `static const callBlueprint` | The Blueprint's answer to [name] with [args]: a custom event's chain, a user function's outputs, an implemented interface function. |
| `callCustomEvent` | `static const callCustomEvent` | Call Custom Event on Self, or on [target] (e.g. a Level Blueprint calls a placed Blueprint actor's event); an unwired Target is Self. |
| `callFunction` | `static const callFunction` |  |
| `callDispatcher` | `static const callDispatcher` |  |
| `bindEventToDispatcher` | `static const bindEventToDispatcher` |  |
| `unbindEventFromDispatcher` | `static const unbindEventFromDispatcher` |  |
| `unbindAllEvents` | `static const unbindAllEvents` | Unbind All Events: every delegate of Self bound to [target]'s dispatcher. |
| `getLevelActor` | `static const getLevelActor` | `Get <Actor>` in a Level Blueprint: the level's placed actor [name], null once it was destroyed or removed (Is Valid is then false), and null outside a level script. |
| `getLevelActorsOfClass` | `static const getLevelActorsOfClass` | The level's live placed actors of class string [cls], in level order. |
| `implementsInterface` | `static const implementsInterface` | [target] (bir Blueprint ya da `Create Widget`'ın döndürdüğü, grafiğiyle birlikte bir widget örneği) [interface]'i uyguluyor mu. |
| `doesImplementInterface` | `static const doesImplementInterface` | Does Implement Interface with Self as the default target. |
| `interfaceMessage` | `static const interfaceMessage` | Interface Message: the implementer's answer, or no outputs (and no error) when [target] (Self when unwired) does not implement [interface]. `Create Widget`'ın döndürdüğü widget örneği grafiğiyle yanıt verir. |
| `enumLiteral` | `static const enumLiteral` |  |
| `enumToString` | `static const enumToString` |  |
| `enumToInt` | `static const enumToInt` | The index of [value] in [enumName]'s values (any registered enum when [enumName] is empty); -1 when unknown. |
| `intToEnum` | `static const intToEnum` | The value at [index], clamped into range with a warning (Int → Enum); '' for an unknown or empty enum. |
| `enumEqual` | `static const enumEqual` |  |
| `getEnumValueCount` | `static const getEnumValueCount` |  |
| `setTimerByEvent` | `static const setTimerByEvent` |  |
| `setTimerByFunctionName` | `static const setTimerByFunctionName` |  |
| `setTimerForNextTick` | `static const setTimerForNextTick` |  |
| `clearTimerByHandle` | `static const clearTimerByHandle` |  |
| `clearAndInvalidateTimer` | `static const clearAndInvalidateTimer` |  |
| `pauseTimer` | `static const pauseTimer` |  |
| `unpauseTimer` | `static const unpauseTimer` |  |
| `isTimerActive` | `static const isTimerActive` |  |
| `isTimerPaused` | `static const isTimerPaused` |  |
| `getTimerRemainingTime` | `static const getTimerRemainingTime` |  |
| `getTimerElapsedTime` | `static const getTimerElapsedTime` |  |
| `signatureArgs` | `static const signatureArgs` | The data arguments of a signature call node: every input but exec and the node's own settings. |
| `getGameInstance` | `static const getGameInstance` |  |
| `getGameMode` | `static const getGameMode` |  |
| `getGameState` | `static const getGameState` |  |
| `getPlayerState` | `static const getPlayerState` |  |
| `setGamePaused` | `static const setGamePaused` |  |
| `isGamePaused` | `static const isGamePaused` |  |
| `executeConsoleCommand` | `static const executeConsoleCommand` |  |
| `getCurrentLevelName` | `static const getCurrentLevelName` |  |
| `openLevel` | `static const openLevel` |  |
| `getGameTimeSinceCreation` | `static const getGameTimeSinceCreation` | Seconds of game time since this actor's BeginPlay. |
| `loadStreamLevel` | `static const loadStreamLevel` | Load Stream Level: loads (and shows) the streaming level [levelName]; [onCompleted] runs on the actor's next latent advance once the level is in. An unknown level completes at once with a log. |
| `unloadStreamLevel` | `static const unloadStreamLevel` |  |
| `isStreamLevelLoaded` | `static const isStreamLevelLoaded` |  |
| `levelLoadOutputs` | `static const levelLoadOutputs` | The data outputs of a Load Level result pin for [p]. |
| `levelLoadEventArgs` | `static const levelLoadEventArgs` | What a custom event bound to a level-loading delegate receives, by parameter name: `Percent`, `TotalCount`, `LoadedCount`, `CurrentContent`, `Error`, `StackTrace` (a custom event takes the ones it declares). |
| `loadLevel` | `static const loadLevel` | Load Level: preloads persistent level [levelName] through [LuminaLevelPreloader.instance]. [resume] re-enters the chain at `on_progress` once per loaded asset, then `on_success` — or `on_error` with the message and stack trace — with the node's outputs ([levelLoadOutputs]); the custom event bound to the matching delegate input runs after it with the same values. |
| `changeLevel` | `static const changeLevel` | Change Level: switches the game to [levelName] through the host ([LuminaGame.changeLevel]) — at once when it was preloaded, else after loading it; [resume] runs `on_success` after the new level's BeginPlay, or `on_error` with the message and stack trace. |
| `loadAndChangeLevel` | `static const loadAndChangeLevel` | Load And Change Level: Load Level then Change Level in one node, with only the error and success results. |
| `cancelLevelLoad` | `static const cancelLevelLoad` | Cancel Level Load: stops preloading [levelName] (every level when empty) and drops what it loaded. |
| `isLevelLoaded` | `static const isLevelLoaded` | Is Level Loaded: whether [levelName] is preloaded and can be switched to at once. |
| `createSaveGameObject` | `static const createSaveGameObject` |  |
| `saveFieldPlain` | `static const saveFieldPlain` | A pin value as the save file stores it: JSON-plain, authoring space. |
| `setSaveField` | `static const setSaveField` |  |
| `getSaveField` | `static const getSaveField` | The field as the pin type of the class's declaration (a stored `[x, y, z]` comes back as a Vector3); the raw value for an unknown class. |
| `saveGameToSlot` | `static const saveGameToSlot` |  |
| `loadGameFromSlot` | `static const loadGameFromSlot` |  |
| `doesSaveGameExist` | `static const doesSaveGameExist` |  |
| `deleteGameInSlot` | `static const deleteGameInSlot` |  |
| `asyncSaveGameToSlot` | `static const asyncSaveGameToSlot` | Async Save Game to Slot: writes on a background isolate; [onCompleted] runs with the result on the actor's next latent advance. |
| `isInputKeyDown` | `static const isInputKeyDown` |  |
| `getInputKeyTimeDown` | `static const getInputKeyTimeDown` |  |
| `wasInputKeyJustPressed` | `static const wasInputKeyJustPressed` |  |
| `getInputAxisValue` | `static const getInputAxisValue` |  |
| `getMousePosition` | `static const getMousePosition` |  |
| `setMousePosition` | `static const setMousePosition` |  |
| `getLastInputDevice` | `static const getLastInputDevice` |  |
| `getViewportSize` | `static const getViewportSize` |  |
| `enableInput` | `static const enableInput` | Enable Input: binds the Blueprint's input again after Disable Input. |
| `disableInput` | `static const disableInput` |  |
| `projectWorldToScreen` | `static const projectWorldToScreen` | Project World to Screen: the viewport pixel of [worldLocation] (authoring space) through the view the world renders from; false when it lies behind the camera. |
| `deprojectScreenToWorld` | `static const deprojectScreenToWorld` | Deproject Screen to World: the ray through viewport pixel [screenPosition], in authoring space. |
| `playSound2D` | `static const playSound2D` |  |
| `playSoundAtLocation` | `static const playSoundAtLocation` |  |
| `spawnSound2D` | `static const spawnSound2D` |  |
| `spawnSoundAttached` | `static const spawnSoundAttached` |  |
| `stopSound` | `static const stopSound` |  |
| `fadeOutSound` | `static const fadeOutSound` |  |
| `setSoundVolume` | `static const setSoundVolume` |  |
| `setSoundPitch` | `static const setSoundPitch` |  |
| `isSoundPlaying` | `static const isSoundPlaying` |  |
| `setSoundClassVolume` | `static const setSoundClassVolume` |  |
| `playAnimMontage` | `static const playAnimMontage` | Play Anim Montage: plays the montage's clip on the skeletal mesh while the Anim Blueprint stands aside; returns the length in seconds at [playRate], 0 when the montage or mesh is missing. |
| `stopAnimMontage` | `static const stopAnimMontage` |  |
| `montageJumpToSection` | `static const montageJumpToSection` |  |
| `montageSetNextSection` | `static const montageSetNextSection` |  |
| `isPlayingMontage` | `static const isPlayingMontage` |  |
| `getCurrentMontage` | `static const getCurrentMontage` |  |
| `getAnimInstance` | `static const getAnimInstance` |  |
| `setAnimVariable` | `static const setAnimVariable` |  |
| `getAnimVariable` | `static const getAnimVariable` |  |
| `tryTraversalAction` | `static const tryTraversalAction` | Try Traversal Action: sahibin `LuminaTraversalComponent`'i öndeki engeli ölçer ve hurdle, vault ya da mantle oynatır; hiçbiri uymazsa false (bkz. [Traversal](../traversal.md)). |
| `traversalCheck` | `static const traversalCheck` | Traversal Check: eylemsiz olarak ölçülen engel (eylem türü, yükseklik, derinlik, arka kenar yüksekliği, ön kenar var mı). |
| `isTraversing` | `static const isTraversing` | Is Traversing: bir traversal eyleminin oynayıp oynamadığı. |
| `spawnEmitterAtLocation` | `static const spawnEmitterAtLocation` |  |
| `spawnEmitterAttached` | `static const spawnEmitterAttached` |  |
| `activateParticleSystem` | `static const activateParticleSystem` |  |
| `spawnDecalAtLocation` | `static const spawnDecalAtLocation` | `Spawn Decal at Location`: the engine has no decal component yet, so nothing is spawned and the return value is null; the validator reports the node as not supported. |
| `deactivateParticleSystem` | `static const deactivateParticleSystem` |  |
| `setParticleParameter` | `static const setParticleParameter` |  |
| `createDynamicMaterialInstance` | `static const createDynamicMaterialInstance` | Create Dynamic Material Instance: bölümün `LuminaDynamicMaterialInstance`'ı; bileşenin Material Override'ı (ya da slot materyali) hâlâ yüklenirken (BeginPlay'deki gibi) bir `LuminaPendingDynamicMaterialInstance` döner: Set Scalar / Vector / Texture Parameter Value düğümleri ona sıraya girer, materyal yüklenince instance yapılır ve değerler uygulanır. |
| `setScalarParameterValue` | `static const setScalarParameterValue` |  |
| `setVectorParameterValue` | `static const setVectorParameterValue` |  |
| `setTextureParameterValue` | `static const setTextureParameterValue` | Set Texture Parameter Value: bir doku asset'ini (`contents/…/T_x.lmas`, editör ve MCP'nin verdiği yol) ya da bir görüntü dosyasını `LuminaDynamicMaterialInstance.setTextureAsset` ile sampler'a bağlar (dokunun ayarları, tek paylaşılan yükleme; bulunamayan doku bir kez loglanır ve hiçbir şey bağlanmaz). |
| `getScalarParameterValue` | `static const getScalarParameterValue` |  |
| `setMaterialScalarParameterOnActor` | `static const setMaterialScalarParameterOnActor` | Sets a scalar on every mesh of [target] (Self when unwired), making dynamic instances where a mesh has a material override. |
| `setLightIntensity` | `static const setLightIntensity` |  |
| `getLightIntensity` | `static const getLightIntensity` |  |
| `setLightColor` | `static const setLightColor` |  |
| `setLightVisibility` | `static const setLightVisibility` |  |
| `toggleLightVisibility` | `static const toggleLightVisibility` |  |
| `setLightRadius` | `static const setLightRadius` |  |
| `setSpotLightAngles` | `static const setSpotLightAngles` |  |
| `onLog` | `static void Function(LuminaActor self, String message, int level)? onLog` | Where Log Warning / Log Error go besides `developer.log`; the editor's Output Log hooks it. |
| `logWarning` | `static const logWarning` |  |
| `logError` | `static const logError` |  |
| `breakpoint` | `static const breakpoint` | Breakpoint: nothing at run time; the editor's debugger pauses on it. |
| `printText` | `static const printText` |  |
| `drawDebugLine` | `static const drawDebugLine` |  |
| `drawDebugSphere` | `static const drawDebugSphere` |  |
| `drawDebugBox` | `static const drawDebugBox` |  |
| `drawDebugPoint` | `static const drawDebugPoint` |  |
| `drawDebugArrow` | `static const drawDebugArrow` |  |
| `drawDebugString` | `static const drawDebugString` |  |
| `drawDebugCapsule` | `static const drawDebugCapsule` |  |
| `flushDebugShapes` | `static const flushDebugShapes` |  |
| `setOverallScalabilityLevel` | `static const setOverallScalabilityLevel` | Genel grafik ölçeklenebilirlik presetini belirler (`low`, `medium`, `high`, `epic`, `cinematic`). Tüm alt sistem ölçeklenebilirlik seviyelerini tek seferde senkronize eder. |
| `getOverallScalabilityLevel` | `static const getOverallScalabilityLevel` | Geçerli genel grafik ölçeklenebilirlik preset adını döner (örn. `'epic'`, `'cinematic'`). |
| `setViewDistanceQuality` | `static const setViewDistanceQuality` | Görüş mesafesi kalite kademesini ayarlar (`low`: 250 m, `medium`: 500 m, `high`: 1 km, `epic`: 2 km, `cinematic`: 4 km). |
| `getViewDistanceQuality` | `static const getViewDistanceQuality` | Geçerli görüş mesafesi kalite kademesini döner. |
| `setViewDistance` | `static const setViewDistance` | Santimetre cinsinden açık kamera far clip görüş mesafesini ayarlar (1 dünya birimi = 1 cm). |
| `getViewDistance` | `static const getViewDistance` | Santimetre cinsinden geçerli kamera far clip görüş mesafesini döner. |
| `setShadowQuality` | `static const setShadowQuality` | Gölge kalitesi kademesini ayarlar (`low`: 512px 1 cascade, `medium`: 1024px 2 cascades, `high`: 2048px 3 cascades VSM, `epic`: 4096px 4 cascades PCSS 8 adım, `cinematic`: 4096px 4 cascades PCSS 16 adımlı temas gölgeleri). |
| `getShadowQuality` | `static const getShadowQuality` | Geçerli gölge kalitesi kademesini döner. |
| `setAntiAliasingQuality` | `static const setAntiAliasingQuality` | Kenar yumuşatma (Anti-Aliasing) modunu belirler (`none`, `fxaa`, `msaa`, `taa`). |
| `getAntiAliasingQuality` | `static const getAntiAliasingQuality` | Geçerli kenar yumuşatma modunu döner. |
| `setPostProcessingQuality` | `static const setPostProcessingQuality` | Post-process kalite kademesini ayarlar (`low`, `medium`, `high`, `epic`, `cinematic`). |
| `getPostProcessingQuality` | `static const getPostProcessingQuality` | Geçerli post-process kalite kademesini döner. |
| `setTextureQuality` | `static const setTextureQuality` | Doku kalite kademesini ayarlar (`low`: 1/4 çözünürlük MIP+2, `medium`: 1/2 çözünürlük MIP+1, `high`: tam çözünürlük 4x anizotropik, `epic`: tam çözünürlük 8x anizo, `cinematic`: sıkıştırmasız 16x anizo). |
| `getTextureQuality` | `static const getTextureQuality` | Geçerli doku kalite kademesini döner. |
| `setShadingQuality` | `static const setShadingQuality` | Gölgelendirme (shading) kalite kademesini ayarlar (`low`: basit PBR min %50 dinamik çözünürlük, `medium`: standart PBR min %75, `high`: tam PBR %100 SSR, `epic`: ultra PBR + AO, `cinematic`: ultra PBR + 4x MSAA + maks SSR). |
| `getShadingQuality` | `static const getShadingQuality` | Geçerli gölgelendirme kalite kademesini döner. |
| `setResolutionScale` | `static const setResolutionScale` | Dahili render çözünürlük ölçeği yüzdesini ayarlar (%25 - %200). |
| `getResolutionScale` | `static const getResolutionScale` | Geçerli render çözünürlük ölçeği yüzdesini döner. |
| `setTargetFPS` | `static const setTargetFPS` | Hedef kare hızı sınırını belirler (sınırsız için 0). |
| `getTargetFPS` | `static const getTargetFPS` | Geçerli hedef kare hızı sınırını döner. |
| `setVSyncEnabled` | `static const setVSyncEnabled` | Dikey senkronizasyonu (VSync) açar veya kapatır. |
| `getVSyncEnabled` | `static const getVSyncEnabled` | Dikey senkronizasyonun açık olup olmadığını döner. |
| `applyScalabilitySettings` | `static const applyScalabilitySettings` | Bekleyen tüm ölçeklenebilirlik ve görüş mesafesi ayarlarını canlı sahneye ve kameralara anında derleyip uygular. |
| `setRayTracingEnabled` / `getRayTracingEnabled` | `static const setRayTracingEnabled` | **Set / Get Ray Tracing Enabled** node'u (kategori `Settings\|Ray Tracing & Upscaling`): oyun kullanıcı ayarlarındaki donanımsal ışın izleme, alttaki ikisinin ana anahtarı. Buradaki her setter gibi bekletilir; Apply Scalability Settings uygular. |
| `setRayTracedShadowsEnabled` / `getRayTracedShadowsEnabled` | `static const setRayTracedShadowsEnabled` | Güneş, gölge haritaları yerine ışın izlemeli sert gölge düşürür (varsayılan açık). |
| `setRestirEnabled` / `getRestirEnabled` | `static const setRestirEnabled` | Nokta ve spot ışıkların ReSTIR doğrudan aydınlatması. |
| `setRestirCandidates` / `getRestirCandidates` | `static const setRestirCandidates` | ReSTIR'in piksel ve kare başına örneklediği ışık sayısı (1–64, varsayılan 8). |
| `setRestirSpatialSamples` / `getRestirSpatialSamples` | `static const setRestirSpatialSamples` | Piksel başına birleştirilen komşu rezervuar sayısı (0–8, varsayılan 2). |
| `setUpscaler` / `getUpscaler` | `static const setUpscaler` | Seçilen ölçekleyici: `None`, `FSR3` veya `DLSS` (büyük/küçük harf duyarsız; `fsr` FSR3'tür, diğer her şey None). |
| `setUpscalerQuality` / `getUpscalerQuality` | `static const setUpscalerQuality` | `Native AA`, `Quality`, `Balanced`, `Performance`, `Ultra Performance`; FSR3 eksen başına 1/1, 1/1.5, 1/1.7, 1/2, 1/3 çözünürlükte çizer, DLSS DLAA, Max Quality, Balanced, Max Performance, Ultra Performance kullanır. |
| `setUpscalerSharpness` / `getUpscalerSharpness` | `static const setUpscalerSharpness` | Ölçekleme sonrası keskinleştirme, 0–1 (FSR3'ün RCAS'ı; DLSS yok sayar). |
| `setFrameGenerationEnabled` / `getFrameGenerationEnabled` | `static const setFrameGenerationEnabled` | FSR3 kare üretimi: her çizilen karenin önüne ara kare. Yalnızca FSR3 ölçekleyiciyle. |
| `isRayTracingSupported` | `static const isRayTracingSupported` | Oyunun motoru ışın izleyebiliyor (Vulkan ray query; `LuminaGameWidget` motordan önce ister). Web'de ve renderer yokken false. |
| `isDlssSupported` | `static const isDlssSupported` | Vulkan backend, NVIDIA GPU ve NGX runtime'ı (`nvngx_dlss`); bu view'da DLSS başlatılamadıysa false. |
| `isFsr3Supported` / `isFrameGenerationSupported` | `static const isFsr3Supported` | View hareket vektörü çizebiliyor (feature level 1 veya üstü bir GPU backend'i). |
| `getSupportedUpscalers` | `static const getSupportedUpscalers` | Bu GPU'nun çalıştırabildiği ölçekleyicilerin string dizisi, önce `None`: ayarlar menüsü için. |
| `getActiveUpscaler` / `isRayTracingActive` | `static const getActiveUpscaler` | Son uygulamanın geri düşüşten sonra gerçekten açtığı (Get Upscaler oyuncunun seçimini korur). |
| `saveGameUserSettings` / `loadGameUserSettings` | `static const saveGameUserSettings` | Tüm kullanıcı ayarlarını kayıt dizinindeki `GameUserSettings.json` dosyasına arka planda yazar / okur; Load okuduğunu uygular. |
| `callShapes` | `static final Map<String, LuminaBlueprintCallShape> callShapes` | One entry per [functions] key: the direct call generated code emits. |
| `functions` | `static final Map<String, LuminaBlueprintFunction> functions` | Every node the VM can call, keyed by node id: the built-ins, then the functions registered in [LuminaBlueprintFunctionRegistry]. Inputs arrive converted to their pin types (the VM resolves wires, literals and defaults first). |
| `builtInFunctions` | `static final Map<String, LuminaBlueprintFunction> builtInFunctions` | One entry per pure / impure built-in node, keyed by node id. |

---

[Önceki: Blueprint runtime'ı, VM ve node kütüphanesi](runtime.md) | [Üst: Blueprint'ler](index.md) | [Sonraki: Animation Blueprint'ler](animation.md)
