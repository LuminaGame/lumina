import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';

/// Regression coverage: the material compiler ignored declared parameters,
/// so any textured material failed to compile.
///
/// The compiler was handed only the fragment body, so a material declaring
/// `{ type : sampler2d, name : baseColorMap }` and reading
/// `materialParams_baseColorMap` could never compile — the builder was told
/// about no parameters at all.
class _RecordingCompilerRunner implements FilamatCompilerRunner {
  List<MaterialParamModel> lastParameters = const [];
  Set<int> lastRequiredAttributes = const {};
  String? lastCode;

  @override
  Future<Uint8List?> compile({
    required String name,
    required String code,
    required FilamatShading shading,
    required BlendingMode blending,
    required bool doubleSided,
    List<MaterialParamModel> parameters = const [],
    Set<int> requiredAttributes = const {},
  }) async {
    lastCode = code;
    lastParameters = parameters;
    lastRequiredAttributes = requiredAttributes;
    return Uint8List.fromList([0x46, 0x49, 0x4C, 0x41, 0x01]);
  }
}

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

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('mat_compile_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  MaterialEditorViewModel viewModelFor(String source, _RecordingCompilerRunner runner) {
    final file = File('${tempDir.path}/M_Textured.lmas');
    file.writeAsBytesSync(
      LuminaAsset(
        assetId: 'M_Textured',
        name: 'M_Textured',
        type: AssetType.filamat,
        rawMatSource: source,
      ).toProtoBufferBytes(),
    );
    return MaterialEditorViewModel(assetPath: file.path, compilerRunner: runner);
  }

  test('declared samplers and uniforms reach the compiler', () async {
    final runner = _RecordingCompilerRunner();
    final vm = viewModelFor(_texturedMaterial, runner);
    await vm.load();

    await vm.compile();

    final names = runner.lastParameters.map((p) => p.name).toList();
    expect(
      names,
      containsAll(<String>['baseColorMap', 'normalMap', 'roughness']),
      reason: 'the header declares three parameters; the builder must be told about '
          'all of them or every materialParams reference is undefined. Got: $names',
    );

    final samplers = runner.lastParameters.where((p) => p.isSampler).map((p) => p.name).toSet();
    expect(samplers, equals({'baseColorMap', 'normalMap'}));
  });

  test('`requires : [ uv0 ]` reaches the compiler as VertexAttribute.UV0', () async {
    final runner = _RecordingCompilerRunner();
    final vm = viewModelFor(_texturedMaterial, runner);
    await vm.load();

    await vm.compile();

    expect(
      runner.lastRequiredAttributes,
      contains(3),
      reason: 'getUV0() needs UV0 (VertexAttribute index 3) required on the builder',
    );
  });

  test('a material with no parameters asks for nothing extra', () async {
    final runner = _RecordingCompilerRunner();
    final vm = viewModelFor('''
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
''', runner);
    await vm.load();

    await vm.compile();

    expect(runner.lastParameters, isEmpty);
    expect(runner.lastRequiredAttributes, isEmpty);
  });
}
