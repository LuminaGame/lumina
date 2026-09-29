import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:flutter_filament/flutter_filament.dart';

class MockParamTestCompilerRunner implements FilamatCompilerRunner {
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
    return Uint8List.fromList([0x46, 0x49, 0x4C, 0x41, 0x01, 0x02]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('mat_param_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('MaterialEditorViewModel Parameter Reflection & Write-through', () {
    test('extracts parameters block and populates MaterialParamModel list', () {
      const source = '''material {
    name : "M_Custom",
    shadingModel : lit,
    blending : opaque,
    parameters : [
        { type : float, name : roughness, default : 0.65 },
        { type : float, name : metallic, default : 0.2 },
        { type : float4, name : baseColor, default : [0.8, 0.1, 0.2, 1.0] },
        { type : sampler2d, name : albedoMap }
    ],
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = materialParams.baseColor;
        material.roughness = materialParams.roughness;
        material.metallic = materialParams.metallic;
    }
}''';

      final asset = LuminaAsset(
        assetId: 'M_Custom',
        name: 'M_Custom',
        type: AssetType.filamat,
        rawMatSource: source,
      );

      final vm = MaterialEditorViewModel(
        assetPath: '${tempDir.path}/M_Custom.lmas',
        initialAsset: asset,
        compilerRunner: MockParamTestCompilerRunner(),
      );

      expect(vm.parameters.length, equals(4));
      
      final roughnessParam = vm.parameters.firstWhere((p) => p.name == 'roughness');
      expect(roughnessParam.type, equals(MaterialParamType.floatType));
      expect(roughnessParam.value, equals(0.65));

      final metallicParam = vm.parameters.firstWhere((p) => p.name == 'metallic');
      expect(metallicParam.type, equals(MaterialParamType.floatType));
      expect(metallicParam.value, equals(0.2));

      final baseColorParam = vm.parameters.firstWhere((p) => p.name == 'baseColor');
      expect(baseColorParam.type, equals(MaterialParamType.colorType));

      final albedoMapParam = vm.parameters.firstWhere((p) => p.name == 'albedoMap');
      expect(albedoMapParam.type, equals(MaterialParamType.sampler2dType));
      expect(albedoMapParam.isSampler, isTrue);
    });

    test('setParam updates value, fires onParamChanged hook, and marks dirty without recompiling', () {
      const source = '''material {
    name : "M_Custom",
    parameters : [
        { type : float, name : roughness, default : 0.5 }
    ],
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
    }
}''';

      final asset = LuminaAsset(
        assetId: 'M_Custom',
        name: 'M_Custom',
        type: AssetType.filamat,
        rawMatSource: source,
      );

      final vm = MaterialEditorViewModel(
        assetPath: '${tempDir.path}/M_Custom.lmas',
        initialAsset: asset,
        compilerRunner: MockParamTestCompilerRunner(),
      );

      String? changedName;
      dynamic changedVal;
      vm.onParamChanged = (name, val) {
        changedName = name;
        changedVal = val;
      };

      vm.setParam('roughness', 0.85);

      expect(vm.getParamValue('roughness'), equals(0.85));
      expect(changedName, equals('roughness'));
      expect(changedVal, equals(0.85));
      expect(vm.isDirty, isTrue);
    });

    test('save() persists parameter defaults and texture references into .lmas', () async {
      const source = '''material {
    name : "M_SaveParam",
    parameters : [
        { type : float, name : roughness, default : 0.3 },
        { type : sampler2d, name : normalMap }
    ],
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
    }
}''';

      final assetFile = File('${tempDir.path}/M_SaveParam.lmas');
      final asset = LuminaAsset(
        assetId: 'M_SaveParam',
        name: 'M_SaveParam',
        type: AssetType.filamat,
        rawMatSource: source,
      );
      await assetFile.writeAsBytes(asset.toProtoBufferBytes());

      final vm = MaterialEditorViewModel(
        assetPath: assetFile.path,
        initialAsset: asset,
        compilerRunner: MockParamTestCompilerRunner(),
      );

      // Modify parameter values and bind texture reference
      vm.setParam('roughness', 0.9);
      vm.setTextureReference('normalMap', assetId: 'T_Brick_N', assetPath: 'contents/textures/T_Brick_N.lmas');

      final saved = await vm.save();
      expect(saved, isTrue);
      expect(vm.isDirty, isFalse);

      // Read back from disk
      final diskBytes = await assetFile.readAsBytes();
      final loadedAsset = LuminaAsset.fromBytes(diskBytes);

      expect(loadedAsset.metadata['parameter_defaults'], isNotNull);
      final defaults = Map<String, dynamic>.from(jsonDecode(loadedAsset.metadata['parameter_defaults']!) as Map);
      expect(defaults['roughness'], equals(0.9));

      expect(loadedAsset.references.any((r) => r.slotName == 'normalMap' && r.assetId == 'T_Brick_N'), isTrue);
    });

    test('updateHeaderSettings rewrites material header and triggers recompile', () async {
      const initialSource = '''material {
    name : "M_Header",
    shadingModel : lit,
    blending : opaque,
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
    }
}''';

      final asset = LuminaAsset(
        assetId: 'M_Header',
        name: 'M_Header',
        type: AssetType.filamat,
        rawMatSource: initialSource,
      );

      final vm = MaterialEditorViewModel(
        assetPath: '${tempDir.path}/M_Header.lmas',
        initialAsset: asset,
        compilerRunner: MockParamTestCompilerRunner(),
      );

      expect(vm.shading, equals(FilamatShading.lit));
      expect(vm.blending, equals(BlendingMode.opaque));

      await vm.updateHeaderSettings(
        shading: FilamatShading.unlit,
        blending: BlendingMode.opaque,
        doubleSided: true,
      );

      expect(vm.shading, equals(FilamatShading.unlit));
      expect(vm.doubleSided, isTrue);
      expect(vm.currentCode, contains('shadingModel : unlit'));
      expect(vm.currentCode, contains('doubleSided : true'));
    });
  });
}
