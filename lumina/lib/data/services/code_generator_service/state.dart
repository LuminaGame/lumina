part of '../code_generator_service.dart';

/// State shared by the [DartCodeGeneratorService] domain mixins: every
/// instance field (in the original order, so initialisers run in the same
/// order) and the members the mixins call on one another.
abstract class _DartCodeGeneratorServiceState {

  // --- Implemented by the domain mixins or [DartCodeGeneratorService]. ---

  String _emitPostProcess(Map<String, dynamic> pp);

  ({Map<String, String> parents, Map<String, List<LuminaBlueprintCustomEvent>> events}) _levelActorClasses(
      List<Map<String, dynamic>> maps, String? projectDir);
}
