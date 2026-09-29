import 'dart:ui' show Offset;

import 'package:lumina/data/services/blueprint_codegen/blueprint_dart_generator.dart';
import 'package:lumina/lumina.dart';

import '../models/blueprint_editor_nodes.dart';
import '../models/blueprint_editor_type_context.dart';
import '../models/blueprint_graph_ref.dart';
import 'blueprint_editor_view_model.dart';

/// The Widget Blueprint graph editor's state:
/// the Blueprint editor configured for a widget. Its document is the
/// widget's graph, stored inside the widget `.lmas` by the UMG designer that
/// owns this view model ([onSave] / [onCompile] run the designer's Save and
/// Compile, which write the tree and the graph together); its graphs resolve
/// in lumina's widget context, so the `Is Variable` elements are typed
/// members (`Get Title` → `WidgetElement:text`) and bound element events
/// (`On Clicked (StartButton)`) are keyed by element name. It has no
/// components, 3D viewport, construction script or class defaults.
class WidgetBlueprintEditorViewModel extends BlueprintEditorViewModel {
  /// The widget class (`WBP_Clicker`).
  final String widgetClass;

  /// The project the widget belongs to.
  final String? projectDirectory;

  /// The widget's `Is Variable` elements as the designer has them now.
  final List<LuminaBlueprintWidgetElement> Function() variablesSource;

  /// The designer's Save (tree and graph); false when it failed.
  final Future<bool> Function()? onSave;

  /// The designer's Compile (graph check, then the widget file).
  final Future<bool> Function()? onCompile;

  /// The widget's generated source (the code preview).
  final String Function()? generatedSource;

  WidgetBlueprintEditorViewModel({
    required super.assetPath,
    required this.widgetClass,
    required this.variablesSource,
    this.projectDirectory,
    this.onSave,
    this.onCompile,
    this.generatedSource,
    LuminaBlueprintDocument? initial,
  }) : super(initialDocument: initial ?? LuminaWidgetBlueprintDocument.emptyGraph()) {
    document.parentClass = LuminaWidgetBlueprintDocument.parentClass;
  }

  /// The script class the graph compiles into (`WbpClickerGraph`).
  String get scriptClassName => '${_className(widgetClass)}Graph';

  static String _className(String name) => dartTypeName(name.replaceAll('.lmas', ''), fallback: 'GeneratedWidget');

  @override
  bool get isWidgetBlueprint => true;

  @override
  String get displayName => widgetClass;

  @override
  String get fileBasename => widgetClass;

  @override
  String get generatedFileName => 'widgets/${dartFileName(widgetClass)}';

  @override
  String? get projectDir => projectDirectory ?? super.projectDir;

  /// A widget graph has no construction script.
  @override
  List<BlueprintGraphRef> get graphs => [
        for (final g in super.graphs)
          if (g.kind != BlueprintGraphKind.constructionScript) g,
      ];

  /// The graph as lumina runs and compiles it: comment boxes and reroutes
  /// flattened, the designer's variables attached.
  LuminaWidgetBlueprintDocument get widgetDocument => LuminaWidgetBlueprintDocument(
        widgetClass: widgetClass,
        variables: variablesSource(),
        blueprint: BlueprintEditorNodes.forEngine(document),
      );

  @override
  LuminaBlueprintTypeContext buildTypeContext({LuminaBlueprintFunctionGraph? function, LuminaBlueprintMacroGraph? macro}) =>
      BlueprintEditorTypeContext.of(
        LuminaBlueprintTypeContext.forDocument(
          document,
          inputActions: inputActions,
          widgetClasses: widgetClassCatalog?.widgetClasses ?? const [],
          className: widgetClass,
          actorParents: widgetClassCatalog?.actorParents ?? const {},
          enums: assetCatalog?.enums,
          interfaces: assetCatalog?.interfaces,
          functionScope: function,
          macroScope: macro,
          widgetVariables: variablesSource(),
        ),
        implementedInterfaces: document.interfaces,
      );

  // ---------------------------------------------------------------------------
  // Variables and bound events
  // ---------------------------------------------------------------------------

  /// The designer's elements changed (added, renamed, deleted, Is Variable
  /// toggled): pins re-type and banners follow.
  void variablesChanged() => graphsChanged();

  /// The bound `On <Event> (<element>)` node of the event graph, or null.
  LuminaBlueprintNode? boundEventNode(String element, String event) {
    for (final n in document.eventGraph.nodes) {
      if (n.registryId == LuminaBlueprintNodeLibrary.eventWidgetElement && n.literals['element'] == element && n.literals['event'] == event) {
        return n;
      }
    }
    return null;
  }

  /// The green `+`: the bound `On <Event> (<element>)` node, placed
  /// below the event graph's other nodes when there is none (one undo step
  /// of the graph), shown and selected. Returns the node, or null when the
  /// element is not a variable or has no such event.
  LuminaBlueprintNode? focusBoundEvent(String element, String event) {
    showGraph(BlueprintGraphRef.eventGraph);
    var node = boundEventNode(element, event);
    if (node == null) {
      final v = typeContext.widgetVariable(element);
      if (v == null || !LuminaWidgetEvents.forType(v.typeName).contains(event)) return null;
      node = eventGraph.addNode(LuminaBlueprintNodeLibrary.eventWidgetElement, _freeSpot(), literals: {'element': element, 'event': event});
      if (node == null) return null;
    }
    eventGraph.focusNode(node.id);
    return node;
  }

  /// Below everything placed so far, at the left edge of the graph.
  Offset _freeSpot() {
    final nodes = document.eventGraph.nodes;
    if (nodes.isEmpty) return const Offset(80, 80);
    var left = double.infinity;
    var bottom = -double.infinity;
    for (final n in nodes) {
      if (n.x < left) left = n.x;
      if (n.y > bottom) bottom = n.y;
    }
    return Offset(left, bottom + 180);
  }

  /// Removes every bound `On <Event> (<element>)` node (the designer removed
  /// the binding), as one undo step of the graph. Returns how many.
  int removeBoundEvent(String element, String event) {
    final ids = [
      for (final n in document.eventGraph.nodes)
        if (n.registryId == LuminaBlueprintNodeLibrary.eventWidgetElement && n.literals['element'] == element && n.literals['event'] == event) n.id,
    ];
    if (ids.isEmpty) return 0;
    mutate('Remove On $event ($element)', () {
      document.eventGraph.nodes.removeWhere((n) => ids.contains(n.id));
      document.eventGraph.wires.removeWhere((w) => ids.contains(w.fromNodeId) || ids.contains(w.toNodeId));
      return true;
    });
    return ids.length;
  }

  /// Renames every `Get <element>` and bound event naming [oldName] (the
  /// designer renamed the element), keeping wires. Not an undo step of the
  /// graph: the reference follows the element, as Level Blueprint actor
  /// references follow the outliner; a saved graph stays saved.
  int renameElementReferences(String oldName, String newName) {
    if (oldName == newName) return 0;
    final wasSaved = !isDirty;
    final count = renameIn(document, oldName, newName);
    if (count > 0 && wasSaved) markSaved();
    if (count > 0) graphsChanged();
    return count;
  }

  /// Renames the widget references of [doc] from [oldName] to [newName].
  static int renameIn(LuminaBlueprintDocument doc, String oldName, String newName) {
    var count = 0;
    for (final g in [doc.eventGraph, for (final f in doc.functions) f.graph, for (final m in doc.macros) m.graph]) {
      for (final n in g.nodes) {
        if (!LuminaBlueprintNodeLibrary.widgetOnlyNodes.contains(n.registryId) || n.literals['element'] != oldName) continue;
        n.literals['element'] = newName;
        n.title = n.registryId == LuminaBlueprintNodeLibrary.getWidgetVariable
            ? newName
            : '${LuminaWidgetEvents.displayName('${n.literals['event'] ?? ''}')} ($newName)';
        count++;
      }
    }
    return count;
  }

  /// One bound event node per event the designer recorded on an element
  /// (a widget designed before its graph existed): each lands in a column at the left of the event graph.
  /// Not an undo step: the graph opens with them. Returns how many.
  int adoptRecordedEvents(List<({String element, String event})> recorded) {
    var placed = 0;
    for (final r in recorded) {
      if (boundEventNode(r.element, r.event) != null) continue;
      final spot = _freeSpot();
      document.eventGraph.nodes.add(LuminaBlueprintNodeLibrary.place(
        LuminaBlueprintNodeLibrary.eventWidgetElement,
        nodeId: 'bound_${r.element}_${r.event}'.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_'),
        x: spot.dx,
        y: spot.dy,
        literals: {'element': r.element, 'event': r.event},
        context: typeContext,
      ));
      placed++;
    }
    if (placed > 0) graphsChanged();
    return placed;
  }

  // ---------------------------------------------------------------------------
  // Save, compile
  // ---------------------------------------------------------------------------

  /// The designer wrote the graph into the widget `.lmas`.
  void documentSaved() => markSaved();

  /// The designer's Save: the widget tree and this graph, in one `.lmas`.
  @override
  Future<bool> save() async => await onSave?.call() ?? false;

  /// The designer's Compile (F7 in the graph): this graph's check, then the
  /// widget file.
  @override
  Future<bool> compile() async => await onCompile?.call() ?? (compileGraph().ok);

  /// lumina's validator and widget-script generator on the graph as it is
  /// now: errors land on their nodes and in Compiler Results. The designer
  /// embeds a clean result in `lib/widgets/WBP_<Name>.dart`.
  BlueprintGenerationResult compileGraph() {
    final dir = projectDir;
    if (dir != null) refreshProjectContext(dir);
    final result = const BlueprintDartGenerator().generateWidgetScript(widgetDocument, className: scriptClassName, inputActions: inputActions);
    final issues = [...result.issues];
    if (!result.ok && !issues.any((d) => d.isError)) {
      issues.add(const LuminaBlueprintDiagnostic(LuminaBlueprintSeverity.error, 'The widget graph could not be generated.'));
    }
    applyCompileResult(issues);
    return result;
  }

  /// The widget's whole generated file (the code preview under the graph).
  @override
  String get generatedDartCode => generatedSource?.call() ?? '';

  /// Readies a freshly opened graph: the project's input actions, functions
  /// and assets, without replacing the document.
  void prepare() {
    final dir = projectDir;
    if (dir != null) refreshProjectContext(dir);
    graphsChanged();
  }

  @override
  Future<void> load() async => prepare();
}
