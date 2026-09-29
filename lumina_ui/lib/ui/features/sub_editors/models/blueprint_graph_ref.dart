/// Which graph of a Blueprint document a tab or a graph editor is about:
/// the event graph, the construction script, one of
/// the user functions or macros (by name), or a Timeline node's curve tab.
enum BlueprintGraphKind { eventGraph, constructionScript, function, macro, timeline }

class BlueprintGraphRef {
  final BlueprintGraphKind kind;

  /// The function or macro name, or the Timeline node id; null otherwise.
  final String? name;

  const BlueprintGraphRef._(this.kind, [this.name]);

  static const BlueprintGraphRef eventGraph = BlueprintGraphRef._(BlueprintGraphKind.eventGraph);
  static const BlueprintGraphRef constructionScript = BlueprintGraphRef._(BlueprintGraphKind.constructionScript);
  const BlueprintGraphRef.function(String name) : this._(BlueprintGraphKind.function, name);
  const BlueprintGraphRef.macro(String name) : this._(BlueprintGraphKind.macro, name);
  const BlueprintGraphRef.timeline(String nodeId) : this._(BlueprintGraphKind.timeline, nodeId);

  bool get isFunction => kind == BlueprintGraphKind.function;
  bool get isMacro => kind == BlueprintGraphKind.macro;
  bool get isTimeline => kind == BlueprintGraphKind.timeline;

  /// Whether this ref names a node graph the canvas edits.
  bool get hasGraph => kind == BlueprintGraphKind.eventGraph || isFunction || isMacro;

  /// The tab label.
  String get label => switch (kind) {
        BlueprintGraphKind.eventGraph => 'Event Graph',
        BlueprintGraphKind.constructionScript => 'Construction Script',
        BlueprintGraphKind.function => name ?? 'Function',
        BlueprintGraphKind.macro => name ?? 'Macro',
        BlueprintGraphKind.timeline => 'Timeline',
      };

  /// A stable key for widgets and editor caches.
  String get key => '${kind.name}:${name ?? ''}';

  @override
  bool operator ==(Object other) => other is BlueprintGraphRef && other.kind == kind && other.name == name;

  @override
  int get hashCode => Object.hash(kind, name);

  @override
  String toString() => 'BlueprintGraphRef($key)';
}
