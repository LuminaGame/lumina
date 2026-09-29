import 'dart:math' as math;

/// FBX Phong/Lambert material values → glTF metallic/roughness:
///
/// - **base colour** = the FBX diffuse colour (Assimp: `DiffuseColor ×
///   DiffuseFactor`), raw — FBX colours are linear; alpha = the FBX
///   `Opacity` (below 1 → alpha blend). A diffuse *texture* replaces the
///   colour (the factor becomes white): the texture is wired straight into
///   Base Color;
/// - **emissive** = the FBX emissive colour (`EmissiveColor × EmissiveFactor`);
///   above 1 it is normalized and the rest goes into
///   `KHR_materials_emissive_strength`; an emissive texture with a black
///   emissive colour emits at full strength;
/// - **roughness** from the Phong exponent, see [roughnessFromPhong];
/// - **metallic** 0 — Phong has no metalness — unless the file carries a PBR
///   value (Maya Stingray/Arnold `Maya|metallic`, 3ds Max Physical
///   `metalness`). `ReflectionFactor` is *not* used: the FBX SDK template
///   defaults it to 1, so every such export would come in as metal.
abstract final class FbxMaterialMapper {
  /// Perceptual roughness for a Phong material with exponent [shininess] and
  /// specular intensity [specular] (specular colour luminance × specular
  /// factor).
  ///
  /// A Blinn-Phong lobe of exponent n matches a GGX lobe of
  /// α = sqrt(2 / (n + 2)) (Walter et al. 2007; the mapping Filament's docs
  /// use), and Filament "roughness" is sqrt(α), so
  /// roughness = (2 / (n + 2))^¼: n 20 (the FBX SDK default many exporters
  /// leave) → 0.549, close to the common default 0.5; n 1000 → 0.21.
  /// A material with no highlight at all (n ≤ 0 or no specular) is fully
  /// rough.
  static double roughnessFromPhong({required double shininess, required double specular}) {
    if (!(shininess > 0) || !(specular > 0)) return 1.0;
    return math.pow(2 / (shininess + 2), 0.25).toDouble().clamp(0.0, 1.0);
  }

  static List<double>? _color(Object? v) {
    if (v is! List || v.length < 3) return null;
    return [for (var i = 0; i < 3; i++) (v[i] as num).toDouble()];
  }

  static double? _num(Object? v) => v is num && v.isFinite ? v.toDouble() : null;

  /// The glTF values for one flutter_assimp `material_details` entry.
  static ({List<double>? baseColor, double alpha, double metallic, double roughness, List<double> emissive}) valuesFor(
    Map detail,
  ) {
    final specularColor = _color(detail['specular']) ?? const [0.0, 0.0, 0.0];
    final specular = (0.2126 * specularColor[0] + 0.7152 * specularColor[1] + 0.0722 * specularColor[2]) *
        (_num(detail['shininess_strength']) ?? 1.0);
    final pbrRoughness = _num(detail['raw_roughness']) ?? _num(detail['raw_max_roughness']);
    final roughness = pbrRoughness?.clamp(0.0, 1.0) ??
        roughnessFromPhong(shininess: _num(detail['shininess']) ?? 0, specular: specular);
    final metallic = (_num(detail['raw_metalness']) ?? _num(detail['raw_max_metalness']) ?? 0.0).clamp(0.0, 1.0);
    final opacity = _num(detail['opacity']);
    return (
      baseColor: _color(detail['diffuse']),
      alpha: opacity != null && opacity > 0 && opacity < 1 ? opacity : 1.0,
      metallic: metallic.toDouble(),
      roughness: roughness.toDouble(),
      emissive: _color(detail['emissive']) ?? const [0.0, 0.0, 0.0],
    );
  }

  /// Writes each FBX material's values ([details], flutter_assimp's
  /// `material_details`, matched by name, else by index) into the glTF
  /// [json]'s materials in place, replacing the glTF exporter's guess
  /// (`roughness = 1 − sqrt(shininess/1000) × specular`, which makes every
  /// such export fully rough).
  static void applyToGltf(Map<String, dynamic> json, List<Map> details) {
    final materials = ((json['materials'] as List?) ?? const []).cast<Map>();
    if (details.isEmpty) return;
    for (var i = 0; i < materials.length; i++) {
      final material = materials[i];
      final name = material['name'];
      final detail = details.where((d) => d['name'] == name).firstOrNull ?? (i < details.length ? details[i] : null);
      if (detail == null) continue;
      final v = valuesFor(detail);
      final pbr = (material['pbrMetallicRoughness'] as Map?) ?? <String, dynamic>{};
      material['pbrMetallicRoughness'] = pbr;
      final base = v.baseColor ?? _color(pbr['baseColorFactor']) ?? const [1.0, 1.0, 1.0];
      pbr['baseColorFactor'] = [base[0], base[1], base[2], v.alpha];
      if (v.alpha < 1) material['alphaMode'] = 'BLEND';
      pbr['metallicFactor'] = v.metallic;
      pbr['roughnessFactor'] = v.roughness;
      setEmissive(json, material, v.emissive);
    }
  }

  /// Sets [material]'s emissive colour [rgb] (linear, any intensity): a
  /// colour above 1 is normalized, the scale going into
  /// `KHR_materials_emissive_strength`; black removes the emission.
  static void setEmissive(Map<String, dynamic> json, Map material, List<double> rgb) {
    final extensions = material['extensions'] as Map?;
    extensions?.remove('KHR_materials_emissive_strength');
    if (extensions != null && extensions.isEmpty) material.remove('extensions');
    final peak = rgb.fold<double>(0, math.max);
    if (!(peak > 0)) {
      material.remove('emissiveFactor');
      return;
    }
    if (peak <= 1) {
      material['emissiveFactor'] = [for (final c in rgb) c];
      return;
    }
    material['emissiveFactor'] = [for (final c in rgb) c / peak];
    ((material['extensions'] as Map?) ?? (material['extensions'] = <String, dynamic>{}))['KHR_materials_emissive_strength'] =
        {'emissiveStrength': peak};
    final used = ((json['extensionsUsed'] as List?) ?? (json['extensionsUsed'] = <dynamic>[]));
    if (!used.contains('KHR_materials_emissive_strength')) used.add('KHR_materials_emissive_strength');
  }

  /// The emissive colour × strength a glTF [material] asks for.
  static List<double> emissiveOf(Map material) {
    final factor = _color(material['emissiveFactor']) ?? const [0.0, 0.0, 0.0];
    final strength = _num(((material['extensions'] as Map?)?['KHR_materials_emissive_strength'] as Map?)?['emissiveStrength']) ?? 1.0;
    return [for (final c in factor) c * strength];
  }
}
