part of '../asset_repository.dart';

/// Builds the Filament `.mat` source for an imported glTF material.
///
/// [textureSlots] are the sampler names the importer resolved from the glTF
/// (`baseColorMap`, `normalMap`, …); each becomes a real `sampler2d` the
/// fragment reads. [baseColor] is the glTF `baseColorFactor`, baked in as a
/// literal so an imported material renders correctly without anyone setting
/// parameters on an instance at runtime.
///
/// Two Filament rules this encodes:
/// - `material.normal` must be written **before** `prepareMaterial`, or it is
///   silently ignored.
/// - sampler uniforms are addressed as `materialParams_<name>`, while scalars
///   and vectors go through `materialParams.<name>`.
String buildImportedMaterialSource({
  required String name,
  required List<double> baseColor,
  required List<String> textureSlots,
  double metallic = 0.0,
  double roughness = 1.0,
  List<double> emissive = const [0.0, 0.0, 0.0],
}) {
  String f(double v) {
    final text = v.toStringAsFixed(3);
    return text.endsWith('00') ? text.substring(0, text.length - 2) : text;
  }

  final slots = textureSlots.toSet();
  final hasSamplers = slots.isNotEmpty;
  final alpha = baseColor.length > 3 ? baseColor[3] : 1.0;
  final baseColorLiteral =
      'vec4(${f(baseColor[0])}, ${f(baseColor[1])}, ${f(baseColor[2])}, ${f(alpha)})';

  final params = [
    for (final slot in slots) '    { type : sampler2d, name : $slot }',
  ];

  final header = StringBuffer()
    ..writeln('material {')
    ..writeln('  name : "$name",')
    ..writeln('  shadingModel : lit,');
  if (hasSamplers) {
    header.writeln('  requires : [ uv0 ],');
  }
  if (params.isEmpty) {
    header.writeln('  parameters : []');
  } else {
    header
      ..writeln('  parameters : [')
      ..writeln(params.join(',\n'))
      ..writeln('  ]');
  }
  header.writeln('}');

  final body = StringBuffer();
  // Normal first: Filament ignores material.normal written after prepareMaterial.
  if (slots.contains('normalMap')) {
    body.writeln(
      '    material.normal = texture(materialParams_normalMap, getUV0()).xyz * 2.0 - 1.0;',
    );
  }
  body.writeln('    prepareMaterial(material);');
  body.writeln('    material.baseColor = $baseColorLiteral;');
  if (slots.contains('baseColorMap')) {
    body.writeln(
      '    material.baseColor *= texture(materialParams_baseColorMap, getUV0());',
    );
  }
  // The glTF factors, multiplied by the texture as glTF
  // defines (metallic in B, roughness in G).
  body
    ..writeln('    material.metallic = ${f(metallic)};')
    ..writeln('    material.roughness = ${f(roughness)};');
  if (slots.contains('metallicRoughnessMap')) {
    body
      ..writeln(
        '    vec4 mr = texture(materialParams_metallicRoughnessMap, getUV0());',
      )
      ..writeln('    material.roughness *= mr.g;')
      ..writeln('    material.metallic *= mr.b;');
  }
  if (slots.contains('occlusionMap')) {
    body.writeln(
      '    material.ambientOcclusion = texture(materialParams_occlusionMap, getUV0()).r;',
    );
  }
  // Emission at the glTF strength, not weighted by the camera exposure
  // (alpha 0), the way gltfio draws the same GLB in the viewport.
  final emissiveLiteral = 'vec3(${f(emissive[0])}, ${f(emissive[1])}, ${f(emissive[2])})';
  if (slots.contains('emissiveMap')) {
    body.writeln(
      '    material.emissive = vec4(texture(materialParams_emissiveMap, getUV0()).rgb * $emissiveLiteral, 0.0);',
    );
  } else if (emissive.any((c) => c > 0)) {
    body.writeln('    material.emissive = vec4($emissiveLiteral, 0.0);');
  }
  if (slots.contains('specularMap')) {
    body.writeln(
      '    material.reflectance = texture(materialParams_specularMap, getUV0()).r;',
    );
  }

  final buffer = StringBuffer()
    ..writeln(header.toString().trimRight())
    ..writeln('fragment {')
    ..writeln('  void material(inout MaterialInputs material) {')
    ..writeln(body.toString().trimRight())
    ..writeln('  }')
    ..writeln('}');
  return buffer.toString();
}

/// A PBR material an importer made (lumina's glTF import or a plugin
/// converting a foreign material): written as the `filamat` asset the glTF
/// import writes, with its Filament source from [buildImportedMaterialSource].
class ImportedMaterial {
  final String name;

  /// RGBA factor.
  final List<double> baseColor;
  final double metallic;
  final double roughness;

  /// RGB factor.
  final List<double> emissive;

  /// One reference per texture slot (`baseColorMap`, `normalMap`,
  /// `metallicRoughnessMap`, `occlusionMap`, `emissiveMap`, `specularMap`) to
  /// an existing texture asset.
  final List<AssetReference> textures;

  /// Extra metadata entries (for example where the material came from).
  final Map<String, String> metadata;

  const ImportedMaterial({
    required this.name,
    this.baseColor = const [1, 1, 1, 1],
    this.metallic = 0,
    this.roughness = 1,
    this.emissive = const [0, 0, 0],
    this.textures = const [],
    this.metadata = const {},
  });

  /// The Filament `.mat` source.
  String materialSource() => buildImportedMaterialSource(
        name: name,
        baseColor: baseColor,
        metallic: metallic,
        roughness: roughness,
        emissive: emissive,
        textureSlots: [for (final t in textures) t.slotName],
      );

  /// The `filamat` asset, with [assetId] or a fresh id.
  LuminaAsset toAsset({String? assetId}) {
    final color = [for (var i = 0; i < 4; i++) i < baseColor.length ? baseColor[i] : 1.0];
    return LuminaAsset(
      assetId: assetId ?? AssetRepository._generateUuidV4(),
      name: name,
      type: AssetType.filamat,
      rawMatSource: materialSource(),
      metadata: {
        'baseColor': color.join(','),
        'metallic': '$metallic',
        'roughness': '$roughness',
        'emissive': emissive.join(','),
        ...metadata,
      },
      references: textures,
    );
  }
}
