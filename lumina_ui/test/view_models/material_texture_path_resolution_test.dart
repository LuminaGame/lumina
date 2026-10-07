import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';

/// Texture references are stored in a `.lmas` as project-relative paths so a
/// project stays portable. The preview renderer needs a real path on disk, and
/// resolved nothing:
///
///   [MaterialPreviewRenderer] could not decode
///   "contents/textures/SKM_TestChar_FaceMesh/T_EyeL_..._BaseColor.lmas"
///   for sampler baseColorMap; using the neutral fallback
class _StubCompilerRunner implements FilamatCompilerRunner {
  @override
  Future<MaterialCompileResult> compile({
    required String name,
    required String source,
    String? includeDirectory,
  }) async =>
      MaterialCompileResult(bytes: Uint8List.fromList([0x46, 0x49, 0x4C, 0x41, 0x01]));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory projectDir;

  setUp(() {
    projectDir = Directory.systemTemp.createTempSync('mat_tex_path_');
    Directory('${projectDir.path}/contents/materials').createSync(recursive: true);
    Directory('${projectDir.path}/contents/textures').createSync(recursive: true);
  });

  tearDown(() {
    if (projectDir.existsSync()) projectDir.deleteSync(recursive: true);
  });

  const relativeTexturePath = 'contents/textures/T_Base.lmas';

  File writeTexture() {
    final pixels = Uint8List(4 * 4 * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      pixels[i] = 10;
      pixels[i + 1] = 200;
      pixels[i + 2] = 90;
      pixels[i + 3] = 255;
    }
    final file = File('${projectDir.path}/$relativeTexturePath');
    file.writeAsBytesSync(
      LuminaAsset(
        assetId: 'T_Base',
        name: 'T_Base',
        type: AssetType.texture,
        rawPayload: TgaDecoderService.encodePng(pixels, 4, 4),
      ).toProtoBufferBytes(),
    );
    return file;
  }

  File writeMaterial() {
    final file = File('${projectDir.path}/contents/materials/M_Base.lmas');
    file.writeAsBytesSync(
      LuminaAsset(
        assetId: 'M_Base',
        name: 'M_Base',
        type: AssetType.filamat,
        rawMatSource: '''
material {
  name : "M_Base",
  shadingModel : lit,
  requires : [ uv0 ],
  parameters : [
    { type : sampler2d, name : baseColorMap }
  ]
}
fragment {
  void material(inout MaterialInputs material) {
    prepareMaterial(material);
    material.baseColor = texture(materialParams_baseColorMap, getUV0());
  }
}
''',
        references: const [
          AssetReference(
            slotName: 'baseColorMap',
            assetId: 'T_Base',
            assetPath: relativeTexturePath,
          ),
        ],
      ).toProtoBufferBytes(),
    );
    return file;
  }

  test('a project-relative texture reference resolves to a real file on disk', () async {
    final texture = writeTexture();
    final material = writeMaterial();

    final vm = MaterialEditorViewModel(
      assetPath: material.path,
      compilerRunner: _StubCompilerRunner(),
    );
    await vm.load();

    final param = vm.parameters.firstWhere((p) => p.name == 'baseColorMap');
    expect(param.textureRef?.assetPath, equals(relativeTexturePath),
        reason: 'the stored reference stays project-relative so the project is portable');
    expect(
      param.resolvedTexturePath,
      equals(texture.path),
      reason: 'the preview needs a path it can actually open',
    );
    expect(File(param.resolvedTexturePath!).existsSync(), isTrue);
  });

  test('an already-absolute reference is left alone', () async {
    final texture = writeTexture();
    final material = File('${projectDir.path}/contents/materials/M_Abs.lmas');
    material.writeAsBytesSync(
      LuminaAsset(
        assetId: 'M_Abs',
        name: 'M_Abs',
        type: AssetType.filamat,
        rawMatSource: '''
material {
  name : "M_Abs",
  shadingModel : lit,
  parameters : [
    { type : sampler2d, name : baseColorMap }
  ]
}
fragment {
  void material(inout MaterialInputs material) { prepareMaterial(material); }
}
''',
        references: [
          AssetReference(
            slotName: 'baseColorMap',
            assetId: 'T_Base',
            assetPath: texture.path,
          ),
        ],
      ).toProtoBufferBytes(),
    );

    final vm = MaterialEditorViewModel(
      assetPath: material.path,
      compilerRunner: _StubCompilerRunner(),
    );
    await vm.load();

    final param = vm.parameters.firstWhere((p) => p.name == 'baseColorMap');
    expect(param.resolvedTexturePath, equals(texture.path));
  });

  test('saving keeps the reference relative, not the resolved path', () async {
    writeTexture();
    final material = writeMaterial();

    final vm = MaterialEditorViewModel(
      assetPath: material.path,
      compilerRunner: _StubCompilerRunner(),
    );
    await vm.load();
    await vm.save();

    final reloaded = LuminaAsset.fromBytes(material.readAsBytesSync());
    final ref = reloaded.references.firstWhere((r) => r.slotName == 'baseColorMap');
    expect(
      ref.assetPath,
      equals(relativeTexturePath),
      reason: 'writing an absolute path would break the project on another machine',
    );
  });
}
