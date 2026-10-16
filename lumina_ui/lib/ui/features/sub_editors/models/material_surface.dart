import 'package:flutter_filament/flutter_filament.dart' show BlendingMode, FilamatShading;
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart' show MaterialNodes;

/// The surface the Material output node shades: which of its pins are used.
class MaterialSurface {
  final FilamatShading shading;
  final BlendingMode blending;
  const MaterialSurface({this.shading = FilamatShading.lit, this.blending = BlendingMode.opaque});

  bool get usesOpacity =>
      blending == BlendingMode.transparent || blending == BlendingMode.masked || blending == BlendingMode.fade;

  /// Whether the output pin [pinId] feeds anything for this shading model and
  /// blend mode (Filament's `MaterialInputs` has no field for the rest).
  bool uses(String pinId) {
    if (pinId == MaterialNodes.opacity) return usesOpacity;
    switch (shading) {
      case FilamatShading.unlit:
        return const {
          MaterialNodes.baseColor,
          MaterialNodes.emissive,
          MaterialNodes.postLightingColor,
          MaterialNodes.postLightingMix,
        }.contains(pinId);
      case FilamatShading.cloth:
        return pinId != MaterialNodes.metallic && pinId != MaterialNodes.specular;
      default:
        return true;
    }
  }
}
