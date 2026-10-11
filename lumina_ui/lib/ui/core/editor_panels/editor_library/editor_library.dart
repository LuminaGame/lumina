import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/core/editor_panels/editor_library/assets_library.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_library/level_library.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_library/native_widgets_library.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_library/notifications_library.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_library/panels_library.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_library/process_library.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_host.dart';
import 'package:lumina_ui/ui/core/editor_panels/editor_panel_runtime.dart';

/// The editor function library editor panel graphs call: `editorOnly`
/// nodes in the Blueprint function registry, category `Editor|…`. Every
/// call runs on the UI isolate and returns at once; anything touching disk
/// or the plugin process is a latent node whose work runs async (its result
/// pins fire later). Writes need the panel's declared capability (the
/// validator enforces it), level edits go through the level proxy and
/// asset edits through the reference-safe asset operations, both undoable.
abstract final class EditorPanelLibrary {
  /// Registers every editor library node and the Json nodes (once; again
  /// after the registry was cleared).
  static void ensureRegistered() {
    LuminaJsonBlueprintNodes.ensureRegistered();
    for (final n in nodes) {
      if (LuminaBlueprintFunctionRegistry.entry(n.spec.id) != null) continue;
      final latent = n.latent;
      if (latent != null) {
        LuminaBlueprintFunctionRegistry.registerLatent(n.spec, latent);
      } else {
        LuminaBlueprintFunctionRegistry.register(n.spec, n.function!);
      }
    }
  }

  /// Every node, by category.
  static final List<EditorLibraryNode> nodes = [
    ...levelLibraryNodes,
    ...assetsLibraryNodes,
    ...notificationsLibraryNodes,
    ...panelsLibraryNodes,
    ...processLibraryNodes,
    ...nativeWidgetsLibraryNodes,
  ];

  /// What an instance leaves behind when it closes (its menu items).
  static void panelClosed(EditorPanelHost host, EditorPanelInstance instance) => panelsLibraryClosed(host, instance);
}

/// One editor library node: its spec and its VM callable (pure / impure) or
/// latent callable.
class EditorLibraryNode {
  const EditorLibraryNode(this.spec, {this.function, this.latent});

  final LuminaBlueprintNodeSpec spec;
  final LuminaBlueprintFunction? function;
  final LuminaBlueprintLatentFunction? latent;
}

/// The panel instance and host a library call runs for; null outside an
/// editor panel (the call then does nothing).
({EditorPanelHost host, EditorPanelInstance instance})? editorPanelCall(LuminaBlueprintCallContext c) {
  final instance = EditorPanelHost.instanceOfScript(c.self);
  final host = instance == null ? null : EditorPanelHost.hostOf(instance);
  if (instance == null || host == null) return null;
  return (host: host, instance: instance);
}

// --- Spec helpers --------------------------------------------------------------

const int _pureColor = 0xFF2E7D32;
const int _functionColor = 0xFF1565C0;
const int _latentColor = 0xFF00838F;

const LuminaBlueprintPinSpec execIn = LuminaBlueprintPinSpec('exec_in', 'Exec In', LuminaPinType.exec);
const LuminaBlueprintPinSpec execOut = LuminaBlueprintPinSpec('exec_out', 'Exec Out', LuminaPinType.exec);

LuminaBlueprintPinSpec exec(String id, String name) => LuminaBlueprintPinSpec(id, name, LuminaPinType.exec);
LuminaBlueprintPinSpec strPin(String id, String name, [String d = '']) =>
    LuminaBlueprintPinSpec(id, name, LuminaPinType.string, defaultValue: d);
LuminaBlueprintPinSpec boolPin(String id, String name, [bool d = false]) =>
    LuminaBlueprintPinSpec(id, name, LuminaPinType.boolean, defaultValue: d);
LuminaBlueprintPinSpec floatPin(String id, String name, [double d = 0.0]) =>
    LuminaBlueprintPinSpec(id, name, LuminaPinType.float, defaultValue: d);
LuminaBlueprintPinSpec intPin(String id, String name, [int d = 0]) =>
    LuminaBlueprintPinSpec(id, name, LuminaPinType.integer, defaultValue: d);
LuminaBlueprintPinSpec jsonPin(String id, String name) => LuminaBlueprintPinSpec(id, name, LuminaPinType.json);
LuminaBlueprintPinSpec idsPin(String id, String name) =>
    LuminaBlueprintPinSpec(id, name, LuminaPinType.array, elementType: LuminaPinType.string);
LuminaBlueprintPinSpec transformPin(String id, String name) => LuminaBlueprintPinSpec(id, name, LuminaPinType.transform);
LuminaBlueprintPinSpec ret(LuminaPinType type, {LuminaPinType? elementType}) =>
    LuminaBlueprintPinSpec('return_value', 'Return Value', type, elementType: elementType);

/// A pure editor node.
LuminaBlueprintNodeSpec pureNode(String id, String title, String category,
        {List<LuminaBlueprintPinSpec> inputs = const [], List<LuminaBlueprintPinSpec> outputs = const [], String? tooltip, String? capability}) =>
    LuminaBlueprintNodeSpec(
      id: id,
      title: title,
      category: category,
      kind: LuminaBlueprintNodeKind.pure,
      headerColor: _pureColor,
      inputs: inputs,
      outputs: outputs,
      keywords: _keywords(title, category),
      tooltip: tooltip,
      editorOnly: true,
      editorCapability: capability,
    );

/// An impure editor node (Exec In → Exec Out).
LuminaBlueprintNodeSpec impureNode(String id, String title, String category,
        {List<LuminaBlueprintPinSpec> inputs = const [], List<LuminaBlueprintPinSpec> outputs = const [], String? tooltip, String? capability}) =>
    LuminaBlueprintNodeSpec(
      id: id,
      title: title,
      category: category,
      kind: LuminaBlueprintNodeKind.impure,
      headerColor: _functionColor,
      inputs: [execIn, ...inputs],
      outputs: [execOut, ...outputs],
      keywords: _keywords(title, category),
      tooltip: tooltip,
      editorOnly: true,
      editorCapability: capability,
    );

/// A latent editor node: Exec Out goes on at once, [results] fire later.
LuminaBlueprintNodeSpec latentNode(String id, String title, String category,
        {List<LuminaBlueprintPinSpec> inputs = const [],
        required List<LuminaBlueprintPinSpec> results,
        List<LuminaBlueprintPinSpec> outputs = const [],
        String? tooltip,
        String? capability}) =>
    LuminaBlueprintNodeSpec(
      id: id,
      title: title,
      category: category,
      kind: LuminaBlueprintNodeKind.latent,
      headerColor: _latentColor,
      inputs: [execIn, ...inputs],
      outputs: [execOut, ...results, ...outputs],
      keywords: _keywords(title, category),
      tooltip: tooltip,
      editorOnly: true,
      editorCapability: capability,
    );

List<String> _keywords(String title, String category) =>
    ['editor', ...category.toLowerCase().split('|'), ...title.toLowerCase().split(' ')];

// --- Value helpers ---------------------------------------------------------------

String inStr(Map<String, Object?> i, String key) => '${i[key] ?? ''}';

List<String> inIds(Map<String, Object?> i, String key) {
  final v = i[key];
  if (v is List) return [for (final e in v) '$e'];
  if (v is String && v.isNotEmpty) return [v];
  return const [];
}

/// A transform pin value `{location, rotation, scale}` as three lists.
({List<double> location, List<double> rotation, List<double> scale}) inTransform(Object? v) {
  List<double> l(Object? x, double d) => x is List
      ? [for (var k = 0; k < 3; k++) k < x.length && x[k] is num ? (x[k] as num).toDouble() : d]
      : [d, d, d];
  final m = v is Map ? v : const {};
  return (location: l(m['location'], 0), rotation: l(m['rotation'], 0), scale: l(m['scale'], 1));
}

Map<String, Object?> transformOut(List<double> location, List<double> rotation, List<double> scale) => {
      'location': List<double>.of(location),
      'rotation': List<double>.of(rotation),
      'scale': List<double>.of(scale),
    };

/// Resumes the panel's graph at [pin] with [outputs] (a latent result), as
/// one editor panel event.
void Function(String pin, [Map<String, Object?> outputs]) resumer(
        EditorPanelHost host, EditorPanelInstance instance, void Function(String execPin, Map<String, Object?> outputs) resume) =>
    (pin, [outputs = const {}]) => host.resume(instance, () => resume(pin, outputs));
