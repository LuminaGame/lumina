import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:flutter_filament/flutter_filament.dart';

class MockFilamatCompilerRunner implements FilamatCompilerRunner {
  bool shouldSucceed;
  Uint8List? returnBytes;
  String? lastSource;
  String? lastIncludeDirectory;

  MockFilamatCompilerRunner({
    this.shouldSucceed = true,
    this.returnBytes,
  });

  @override
  Future<MaterialCompileResult> compile({
    required String name,
    required String source,
    String? includeDirectory,
  }) async {
    lastSource = source;
    lastIncludeDirectory = includeDirectory;

    if (!shouldSucceed) return const MaterialCompileResult(bytes: null);
    return MaterialCompileResult(bytes: returnBytes ?? Uint8List.fromList([0x46, 0x49, 0x4C, 0x41, 0x01, 0x02, 0x03]));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('material_vm_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('MaterialEditorViewModel', () {
    test('Load round-trip exposes exact rawMatSource from disk', () async {
      final assetFile = File('${tempDir.path}/M_TestMat.lmas');
      const testMatSource = '''material {
    name : "M_TestMat",
    shadingModel : lit,
    blending : opaque,
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(1.0, 0.0, 0.0, 1.0);
    }
}''';

      final asset = LuminaAsset(
        assetId: 'M_TestMat',
        name: 'M_TestMat',
        type: AssetType.filamat,
        rawMatSource: testMatSource,
      );
      await assetFile.writeAsBytes(asset.toProtoBufferBytes());

      final vm = MaterialEditorViewModel(
        assetPath: assetFile.path,
        compilerRunner: MockFilamatCompilerRunner(),
      );

      await vm.load();

      expect(vm.currentCode, equals(testMatSource));
      expect(vm.isDirty, isFalse);
      // load() compiles a material that carries no compiled bytes, so the badge
      // reports the compile rather than the Dart-side syntax check — the whole
      // point being that "Syntax OK" never meant the material had compiled.
      expect(vm.syntaxStatus, startsWith('Compile OK'));
      expect(vm.compiledBytes, isNotNull);
    });

    test('compile() on valid source updates compiledBytes, issues, and status', () async {
      final runner = MockFilamatCompilerRunner(
        shouldSucceed: true,
        returnBytes: Uint8List.fromList([1, 2, 3, 4, 5]),
      );
      final vm = MaterialEditorViewModel(
        assetPath: '${tempDir.path}/test.lmas',
        compilerRunner: runner,
      );

      vm.currentCode = '''material {
    name : "test",
    shadingModel : lit,
    blending : transparent,
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(0.0, 1.0, 0.0, 1.0);
    }
}''';

      Uint8List? hotAppliedBytes;
      vm.onHotApply = (bytes) {
        hotAppliedBytes = bytes;
      };

      final success = await vm.compile();

      expect(success, isTrue);
      expect(vm.compiledBytes, isNotNull);
      expect(vm.compiledBytes!.length, equals(5));
      expect(hotAppliedBytes, isNotNull);
      expect(vm.syntaxStatus, contains('Compile OK'));
      expect(vm.issues.length, equals(1));
      expect(vm.issues.first.severity, equals(MaterialCompileSeverity.info));
      // The whole source goes to the compiler, #includes resolved beside the asset.
      expect(runner.lastSource, equals(vm.currentCode));
      expect(runner.lastIncludeDirectory, equals(tempDir.path));
      expect(vm.blending, equals(BlendingMode.transparent));
      expect(vm.shading, equals(FilamatShading.lit));
    });

    test('compile() on source with unmatched braces reports the compiler error', () async {
      final vm = MaterialEditorViewModel(assetPath: '${tempDir.path}/test.lmas');

      vm.currentCode = '''material {
    name : "test",
    shadingModel : lit,
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
'''; // missing close braces

      final success = await vm.compile();

      expect(success, isFalse);
      expect(vm.issues.any((i) => i.severity == MaterialCompileSeverity.error && i.fromCompiler), isTrue,
          reason: vm.issues.map((i) => i.message).join('\n'));
      expect(vm.syntaxStatus, startsWith('Compile Error'));
    });

    test('compile() on source with missing prepareMaterial reports the compiler error', () async {
      final vm = MaterialEditorViewModel(assetPath: '${tempDir.path}/test.lmas');

      vm.currentCode = '''material {
    name : "test",
}

fragment {
    void material(inout MaterialInputs material) {
        material.baseColor = vec4(1.0);
    }
}''';

      final success = await vm.compile();

      expect(success, isFalse);
      expect(vm.issues.any((i) => i.message.contains('prepareMaterial')), isTrue);
      expect(vm.bodyLineOffset, greaterThanOrEqualTo(5));
    });

    test('save() writes rawMatSource and compiledBytes back to .lmas on disk', () async {
      final assetFile = File('${tempDir.path}/M_SaveTest.lmas');
      final runner = MockFilamatCompilerRunner(
        shouldSucceed: true,
        returnBytes: Uint8List.fromList([0xAA, 0xBB, 0xCC]),
      );

      final vm = MaterialEditorViewModel(
        assetPath: assetFile.path,
        compilerRunner: runner,
      );

      await vm.load();
      vm.currentCode = '''material {
    name : "M_SaveTest",
    shadingModel : lit,
}

fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(0.5, 0.5, 0.5, 1.0);
    }
}''';

      expect(vm.isDirty, isTrue);

      await vm.compile();
      await vm.save();

      expect(vm.isDirty, isFalse);
      expect(assetFile.existsSync(), isTrue);

      final reloaded = LuminaAsset.fromBytes(await assetFile.readAsBytes());
      expect(reloaded.rawMatSource, equals(vm.currentCode));
      expect(reloaded.rawPayload, equals(Uint8List.fromList([0xAA, 0xBB, 0xCC])));
      expect(reloaded.metadata['last_modified'], isNotNull);
    });

    test('discardChanges() reverts currentCode to onDiskCode and clears isDirty', () async {
      final assetFile = File('${tempDir.path}/M_Discard.lmas');
      const initialCode = '''material { name : "M_Discard" }
fragment { void material(inout MaterialInputs material) { prepareMaterial(material); } }''';

      await assetFile.writeAsBytes(
        LuminaAsset(assetId: '1', name: 'M_Discard', type: AssetType.filamat, rawMatSource: initialCode).toProtoBufferBytes(),
      );

      final vm = MaterialEditorViewModel(assetPath: assetFile.path);
      await vm.load();

      vm.currentCode = 'modified code';
      expect(vm.isDirty, isTrue);

      vm.discardChanges();
      expect(vm.isDirty, isFalse);
      expect(vm.currentCode, equals(initialCode));
    });

    test('extractDeclaredParameters parses parameters block correctly', () {
      final vm = MaterialEditorViewModel(assetPath: 'test.lmas');
      vm.currentCode = '''material {
    parameters : [
        float roughness,
        vec3 tintColor,
        sampler2d albedoMap
    ]
}''';

      final params = vm.extractDeclaredParameters();
      expect(params, contains('roughness'));
      expect(params, contains('tintColor'));
      expect(params, contains('albedoMap'));
      expect(params, contains('material.roughness'));
    });
  });
}
