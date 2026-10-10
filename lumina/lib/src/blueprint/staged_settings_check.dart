import 'package:lumina/src/blueprint/blueprint_model.dart';
import 'package:lumina/src/blueprint/node_library.dart';

/// Warns once when [doc] calls a staged game user settings setter
/// ([LuminaBlueprintNodeSpec.requiresApply]) but none of its graphs calls
/// Apply Scalability Settings: the value would wait for another Blueprint to
/// apply the settings.
void checkStagedSettingsApplied(
  LuminaBlueprintDocument doc,
  void Function(String m, {String? node, String? pin}) warning,
) {
  final graphs = [doc.eventGraph, for (final f in doc.functions) f.graph, for (final m in doc.macros) m.graph];
  LuminaBlueprintNode? firstStaged;
  LuminaBlueprintNodeSpec? firstSpec;
  for (final g in graphs) {
    for (final n in g.nodes) {
      if (n.registryId == 'apply_scalability_settings') return;
      if (firstStaged != null) continue;
      final spec = LuminaBlueprintNodeLibrary.builtIn(n.registryId);
      if (spec != null && spec.requiresApply) {
        firstStaged = n;
        firstSpec = spec;
      }
    }
  }
  if (firstStaged == null || firstSpec == null) return;
  warning(
      '${firstSpec.title} only stages its value and nothing in this Blueprint calls Apply Scalability Settings; '
      'it takes effect only when Apply Scalability Settings runs.',
      node: firstStaged.id);
}
