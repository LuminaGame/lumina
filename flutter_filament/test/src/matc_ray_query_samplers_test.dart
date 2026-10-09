// Ray query (ray-traced sun shadows, ReSTIR) exists only on Vulkan. The lit
// shaders of the other APIs must not sample its per-view textures: on OpenGL
// ES / WebGL they would only ever read a 1x1 placeholder, and each one costs
// a fragment sampler. A lit material with eight samplers and fog then reaches
// sixteen active samplers, which Chrome's ANGLE/Direct3D 11 backend does not
// survive (the GPU process crashes and every WebGL context of the page is
// lost).
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

/// A lit material with the eight samplers of a full PBR surface, the shape of
/// the glTF ubershader.
const _eightSamplers = '''
material {
    name : EightSamplers,
    shadingModel : lit,
    requires : [ uv0 ],
    parameters : [
        { type : sampler2d, name : baseColorMap },
        { type : sampler2d, name : metallicRoughnessMap },
        { type : sampler2d, name : normalMap },
        { type : sampler2d, name : occlusionMap },
        { type : sampler2d, name : emissiveMap },
        { type : sampler2d, name : clearCoatMap },
        { type : sampler2d, name : clearCoatRoughnessMap },
        { type : sampler2d, name : clearCoatNormalMap }
    ]
}
fragment {
    void material(inout MaterialInputs material) {
        vec2 uv = getUV0();
        material.normal = texture(materialParams_normalMap, uv).xyz * 2.0 - 1.0;
        prepareMaterial(material);
        material.baseColor = texture(materialParams_baseColorMap, uv);
        vec4 mr = texture(materialParams_metallicRoughnessMap, uv);
        material.metallic = mr.b;
        material.roughness = mr.g;
        material.ambientOcclusion = texture(materialParams_occlusionMap, uv).r;
        material.emissive = texture(materialParams_emissiveMap, uv);
        material.clearCoat = texture(materialParams_clearCoatMap, uv).r;
        material.clearCoatRoughness = texture(materialParams_clearCoatRoughnessMap, uv).g;
        material.clearCoatNormal = texture(materialParams_clearCoatNormalMap, uv).xyz * 2.0 - 1.0;
    }
}
''';

/// The text dictionary (`DIC_TEXT`) of a `.filamat` package: every line of
/// every GLSL / ESSL / MSL shader in it, as stored.
String _textDictionary(Uint8List package) {
  final data = ByteData.sublistView(package);
  var offset = 0;
  while (offset + 12 <= package.length) {
    final tag = String.fromCharCodes(package.sublist(offset, offset + 8).reversed);
    final size = data.getUint32(offset + 8, Endian.little);
    if (tag == 'DIC_TEXT') return latin1.decode(package.sublist(offset + 12, offset + 12 + size));
    offset += 12 + size;
  }
  fail('the package has no DIC_TEXT chunk');
}

/// A Vulkan-only per-view texture passed to a texture function
/// (`texelFetch(sampler0_rtShadow, …)`), as opposed to its declaration.
final _rayQuerySampling = RegExp(r'sampler0_(rtShadow|restirReservoir|restirLights)\s*[,)]');

void main() {
  for (final platform in [MaterialPlatform.mobile, MaterialPlatform.desktop]) {
    test('a lit material compiled for OpenGL (${platform.name}) samples no ray query texture', () {
      final result = FilamentMatc.compile(_eightSamplers, platform: platform, targetApi: TargetApi.opengl);
      expect(result.ok, isTrue, reason: result.log);
      final text = _textDictionary(result.package!);
      // The dictionary holds the lit shaders: the material's own fetches and
      // the per-view shadow map are there.
      expect(text, contains('materialParams_clearCoatNormalMap'));
      expect(text, contains('sampler0_shadowMap'));
      expect(_rayQuerySampling.allMatches(text).map((m) => m.group(0)).toSet(), isEmpty);
    });
  }
}
