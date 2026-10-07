import 'package:lumina_editor_data/lumina_editor.dart';

/// lumina's type context plus what only the editor's palette needs:
/// the interfaces the document implements, so
/// `Event <Function>` rows are offered for those and nothing else. Built by
/// [of] from the context lumina resolves for a document, function or macro.
class BlueprintEditorTypeContext extends LuminaBlueprintTypeContext {
  final List<String> implementedInterfaces;

  const BlueprintEditorTypeContext({
    super.variables,
    super.inputActions,
    super.widgetClasses,
    super.components,
    super.selfClass,
    super.actorParents,
    super.functions,
    super.macros,
    super.dispatchers,
    super.dispatcherOwners,
    super.customEvents,
    super.inheritedCustomEvents,
    super.enums,
    super.interfaces,
    super.functionScope,
    super.macroScope,
    super.levelActors,
    super.customEventOwners,
    super.variableOwners,
    super.componentOwners,
    super.widgetVariables,
    this.implementedInterfaces = const [],
  });

  /// [base] with [implementedInterfaces] attached.
  factory BlueprintEditorTypeContext.of(LuminaBlueprintTypeContext base, {List<String> implementedInterfaces = const []}) =>
      BlueprintEditorTypeContext(
        variables: base.variables,
        inputActions: base.inputActions,
        widgetClasses: base.widgetClasses,
        components: base.components,
        selfClass: base.selfClass,
        actorParents: base.actorParents,
        functions: base.functions,
        macros: base.macros,
        dispatchers: base.dispatchers,
        dispatcherOwners: base.dispatcherOwners,
        customEvents: base.customEvents,
        inheritedCustomEvents: base.inheritedCustomEvents,
        enums: base.enums,
        interfaces: base.interfaces,
        functionScope: base.functionScope,
        macroScope: base.macroScope,
        levelActors: base.levelActors,
        customEventOwners: base.customEventOwners,
        variableOwners: base.variableOwners,
        componentOwners: base.componentOwners,
        widgetVariables: base.widgetVariables,
        implementedInterfaces: implementedInterfaces,
      );

  /// The interfaces [context] implements: none for a plain lumina context.
  static List<String> implementedBy(LuminaBlueprintTypeContext context) =>
      context is BlueprintEditorTypeContext ? context.implementedInterfaces : const [];
}
