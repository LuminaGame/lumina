import 'package:lumina/lumina.dart';

/// A Character Blueprint that is `LuminaTemplateCharacter(thirdPerson: true)`
/// re-expressed as a Blueprint, without the mannequin: the template's
/// `LuminaThirdPersonContent.characterBlueprint`.
LuminaBlueprintDocument thirdPersonCharacterBlueprint({List<LuminaInputAction> inputActions = const []}) =>
    LuminaThirdPersonContent.characterBlueprint(inputActions: inputActions, withMesh: false);
