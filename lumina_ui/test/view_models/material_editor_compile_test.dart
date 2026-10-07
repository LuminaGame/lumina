import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';

/// Regression coverage: a material's declared parameters and `requires`
/// reach the compiled material.
///
/// The compiler used to be handed only the fragment body, so a material
/// declaring `{ type : sampler2d, name : baseColorMap }` and reading
/// `materialParams_baseColorMap` could never compile. The whole source now
/// goes to the material compiler, which reads the header itself.
const String _texturedMaterial = '''
material {
  name : "M_Textured",
  shadingModel : lit,
  requires : [ uv0 ],
  parameters : [
    { type : sampler2d, name : baseColorMap },
    { type : sampler2d, name : normalMap },
    { type : float, name : roughness }
  ]
}
fragment {
  void material(inout MaterialInputs material) {
    material.normal = texture(materialParams_normalMap, getUV0()).xyz * 2.0 - 1.0;
    prepareMaterial(material);
    material.baseColor = texture(materialParams_baseColorMap, getUV0());
    material.roughness = materialParams.roughness;
  }
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FilamentEngine engine;

  setUpAll(() {
    engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
  });

  tearDownAll(() {
    if (!engine.isDisposed) engine.dispose();
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('mat_compile_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<FilamentMaterial> compiled(String source) async {
    final file = File('${tempDir.path}/M_Textured.lmas');
    file.writeAsBytesSync(
      LuminaAsset(
        assetId: 'M_Textured',
        name: 'M_Textured',
        type: AssetType.filamat,
        rawMatSource: source,
      ).toProtoBufferBytes(),
    );
    final vm = MaterialEditorViewModel(assetPath: file.path);
    await vm.load();
    expect(await vm.compile(), isTrue, reason: vm.issues.map((i) => i.message).join('\n'));
    return FilamentMaterial.fromBuffer(engine: engine, filamatBuffer: vm.compiledBytes!);
  }

  test('declared samplers and uniforms are in the compiled material', () async {
    final material = await compiled(_texturedMaterial);
    final params = {for (final p in material.parameters) p.name: p};
    expect(params.keys, containsAll(<String>['baseColorMap', 'normalMap', 'roughness']));
    expect(params['baseColorMap']!.isSampler, isTrue);
    expect(params['normalMap']!.isSampler, isTrue);
    expect(params['roughness']!.uniformType, UniformType.floatType);
    material.dispose();
  });

  test('`requires : [ uv0 ]` is required by the compiled material', () async {
    final material = await compiled(_texturedMaterial);
    expect(material.requiredAttributes, contains(VertexAttribute.uv0));
    material.dispose();
  });

  test('a material with no parameters declares none', () async {
    final material = await compiled('''
material {
  name : "M_Plain",
  shadingModel : lit,
  parameters : []
}
fragment {
  void material(inout MaterialInputs material) {
    prepareMaterial(material);
    material.baseColor = vec4(1.0, 0.5, 0.25, 1.0);
  }
}
''');
    expect(material.parameters, isEmpty);
    expect(material.requiredAttributes, isNot(contains(VertexAttribute.uv0)));
    material.dispose();
  });
}
