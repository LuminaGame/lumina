import 'blueprint_function_library.dart';
import 'node_library.dart';

/// A node added to the library at run time: its spec, how
/// generated code calls it, and its VM callable — null for a function that is
/// only declared (project code the editor process cannot run).
class LuminaBlueprintRegisteredFunction {
  final LuminaBlueprintNodeSpec spec;
  final LuminaBlueprintCallShape? call;
  final LuminaBlueprintFunction? function;

  const LuminaBlueprintRegisteredFunction(this.spec, this.call, this.function);

  /// Whether the VM of this process can run it.
  bool get callable => function != null;
}

/// Nodes beyond the built-in library: Dart functions registered as
/// Blueprint-callable.
///
/// A project's generated `registerProjectBlueprintFunctions()`
/// (`lib/blueprint/blueprint_functions.g.dart`) [register]s each annotated
/// function with a closure the VM calls; editor plugins can register theirs
/// the same way. The editor, which cannot run project code, [declare]s the
/// project's functions from `project.blueprint_functions.json` so the palette,
/// the validator and the code generator know them, and the VM reports them as
/// requiring Play Standalone.
///
/// [LuminaBlueprintNodeLibrary.spec] / `all` and
/// [LuminaBlueprintFunctionLibrary.functions] consult the registry after the
/// built-ins.
abstract final class LuminaBlueprintFunctionRegistry {
  static final Map<String, LuminaBlueprintRegisteredFunction> _entries = {};

  /// What the VM and the validator say about a declared-only function.
  static const String unavailableMessage =
      'is project code the editor cannot run; it runs in the built game (requires Play Standalone)';

  /// The prefix of a node id generated for an annotated Dart function:
  /// `fn:<library uri>#<function name>`.
  static const String idPrefix = 'fn:';

  /// The node id of the annotated function [function] (`name` or
  /// `Class.name`) in the library [libraryUri].
  static String idFor(String libraryUri, String function) => '$idPrefix$libraryUri#$function';

  /// Adds node [spec], run by [function] in the VM. [call] tells generated
  /// Blueprint code how to call it directly. Throws [StateError] when the id
  /// is a built-in node or already registered or declared.
  static void register(LuminaBlueprintNodeSpec spec, LuminaBlueprintFunction function, {LuminaBlueprintCallShape? call}) {
    _checkShape(spec);
    if (LuminaBlueprintNodeLibrary.builtIn(spec.id) != null) {
      throw StateError("Cannot register Blueprint function '${spec.id}': a built-in node has that id.");
    }
    final existing = _entries[spec.id];
    if (existing != null) {
      throw StateError("Blueprint function '${spec.id}' is already ${existing.callable ? 'registered' : 'declared'}.");
    }
    _entries[spec.id] = LuminaBlueprintRegisteredFunction(spec, call, function);
  }

  /// Makes node [spec] known without a callable: the palette lists it, the
  /// validator accepts it (with a warning), the code generator calls it
  /// through [call], and the VM skips it with a "requires Play Standalone"
  /// log. A new declaration replaces an earlier one; a built-in id or a
  /// registered function throws [StateError].
  static void declare(LuminaBlueprintNodeSpec spec, {LuminaBlueprintCallShape? call}) {
    _checkShape(spec);
    if (LuminaBlueprintNodeLibrary.builtIn(spec.id) != null) {
      throw StateError("Cannot declare Blueprint function '${spec.id}': a built-in node has that id.");
    }
    if (_entries[spec.id]?.callable ?? false) {
      throw StateError("Blueprint function '${spec.id}' is already registered.");
    }
    _entries[spec.id] = LuminaBlueprintRegisteredFunction(spec, call, null);
  }

  static void _checkShape(LuminaBlueprintNodeSpec spec) {
    if (spec.kind != LuminaBlueprintNodeKind.pure && spec.kind != LuminaBlueprintNodeKind.impure) {
      throw ArgumentError.value(spec.kind, 'spec.kind', "'${spec.id}' must be a pure or impure node");
    }
  }

  static LuminaBlueprintRegisteredFunction? entry(String id) => _entries[id];
  static LuminaBlueprintNodeSpec? spec(String id) => _entries[id]?.spec;
  static LuminaBlueprintFunction? function(String id) => _entries[id]?.function;
  static LuminaBlueprintCallShape? callShape(String id) => _entries[id]?.call;

  /// Whether [id] is declared but not callable in this process.
  static bool isDeclaredOnly(String id) {
    final e = _entries[id];
    return e != null && !e.callable;
  }

  static bool get isEmpty => _entries.isEmpty;

  /// Every registered and declared node, in registration order.
  static List<LuminaBlueprintNodeSpec> get specs => [for (final e in _entries.values) e.spec];

  /// Ids of the nodes the VM can call, in registration order.
  static Iterable<String> get callableIds => _entries.values.where((e) => e.callable).map((e) => e.spec.id);

  static void unregister(String id) => _entries.remove(id);

  /// Removes every declared-only function (before re-reading a project's
  /// manifest); registered ones stay.
  static void clearDeclared() => _entries.removeWhere((_, e) => !e.callable);

  /// Removes everything.
  static void clear() => _entries.clear();
}
