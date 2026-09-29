import 'dart:typed_data';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

Uint8List buildTestFilamatPackage({
  String name = 'TestBaseMaterial',
  bool doubleSided = true,
}) {
  FilamentMaterialBuilder.initEngine();
  final builder = FilamentMaterialBuilder.create();
  builder.setName(name);
  builder.setShading(FilamatShading.lit);
  builder.materialDomain(MaterialDomain.surface);
  builder.blending(BlendingMode.opaque);
  builder.culling(CullingMode.none);
  if (doubleSided) {
    builder.setDoubleSided(true);
  }
  builder.addParameter('baseColorFactor', UniformType.float4);
  builder.addSamplerParameter('albedoMap');
  builder.constantBool('useTint', false);
  builder.platform(MaterialPlatform.desktop);
  builder.targetApi(TargetApi.vulkan);
  builder.optimization(OptimizationLevel.none);
  builder.setCode('''
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = materialParams.baseColorFactor;
    }
  ''');
  final bytes = builder.build()!;
  builder.dispose();
  return bytes;
}

void main() {
  group('LuminaMaterial & LuminaMaterialInstance Tests (Task 01)', () {
    late FilamentEngine engine;
    late FilamentScene scene;
    late LuminaWorld world;
    late Uint8List sampleBytes;

    setUpAll(() {
      sampleBytes = buildTestFilamatPackage();
    });

    setUp(() {
      engine = FilamentEngine.create()!;
      scene = engine.createScene();
      world = LuminaWorld(worldType: LuminaWorldType.game);
      world.initializeNativeContext(engine, scene);
    });

    tearDown(() {
      world.cleanup();
      scene.dispose();
      engine.dispose();
    });

    test('Loads LuminaMaterial and reflects parameters and introspection', () async {
      final mat = await LuminaMaterial.load(
        world,
        'contents/materials/M_Base.filamat',
        assetProvider: (_) async => sampleBytes,
      );

      expect(mat.parameterCount, greaterThanOrEqualTo(2));
      expect(mat.hasParameter('baseColorFactor'), isTrue);
      expect(mat.isSampler('baseColorFactor'), isFalse);
      expect(mat.hasParameter('albedoMap'), isTrue);
      expect(mat.isSampler('albedoMap'), isTrue);

      final p = mat.parameters.firstWhere((e) => e.name == 'baseColorFactor');
      expect(p.uniformType, equals(UniformType.float4));

      expect(mat.name, equals('TestBaseMaterial'));
      expect(mat.shading, equals(FilamatShading.lit));
      expect(mat.blendingMode, equals(BlendingMode.opaque));
      expect(mat.isDoubleSided, isTrue);
    });

    test('Same path shares cached LuminaMaterial, distinct constants create separate entries', () async {
      int loadCount = 0;
      Future<Uint8List> provider(String path) async {
        loadCount++;
        return sampleBytes;
      }

      final mat1 = await LuminaMaterial.load(
        world,
        'contents/materials/M_Base.filamat',
        assetProvider: provider,
      );
      final mat2 = await LuminaMaterial.load(
        world,
        'contents/materials/M_Base.filamat',
        assetProvider: provider,
      );

      expect(identical(mat1, mat2), isTrue);
      expect(loadCount, equals(1));

      final matWithConst = await LuminaMaterial.load(
        world,
        'contents/materials/M_Base.filamat',
        constants: const [MaterialConstant.bool_('useTint', true)],
        assetProvider: provider,
      );

      expect(identical(mat1, matWithConst), isFalse);
      expect(loadCount, equals(2));
    });

    test('createInstance creates named instances and defaultInstance is non-destroyable', () async {
      final mat = await LuminaMaterial.load(
        world,
        'contents/materials/M_Base.filamat',
        assetProvider: (_) async => sampleBytes,
      );

      final inst1 = mat.createInstance(name: 'enemy_red');
      expect(inst1.name, equals('enemy_red'));
      expect(identical(inst1.material, mat), isTrue);

      final inst2 = mat.createInstance();
      final inst3 = mat.createInstance();
      expect(inst2.name, isNot(equals(inst3.name)));

      final defInst = mat.defaultInstance;
      expect(identical(mat.defaultInstance, defInst), isTrue);
      expect(() => defInst.dispose(), throwsStateError);
    });

    test('Sets and gets default parameters with typed reflection validation', () async {
      final mat = await LuminaMaterial.load(
        world,
        'contents/materials/M_Base.filamat',
        assetProvider: (_) async => sampleBytes,
      );

      mat.setDefaultParameterFloat4('baseColorFactor', Vector4(1.0, 0.0, 0.0, 1.0));
      final readColor = mat.defaultInstance.getFloat4('baseColorFactor');
      expect(readColor.x, closeTo(1.0, 1e-4));
      expect(readColor.y, closeTo(0.0, 1e-4));
      expect(readColor.z, closeTo(0.0, 1e-4));
      expect(readColor.w, closeTo(1.0, 1e-4));

      // Guarded against nonexistent parameters
      expect(
        () => mat.setDefaultParameterFloat4('nonExistentParam', Vector4.zero()),
        throwsArgumentError,
      );

      // Guarded against wrong-typed reads on instance
      expect(
        () => mat.defaultInstance.getFloat('baseColorFactor'),
        throwsArgumentError,
      );
    });

    test('preWarm compiles variants without blocking game loop', () async {
      final mat = await LuminaMaterial.load(
        world,
        'contents/materials/M_Base.filamat',
        assetProvider: (_) async => sampleBytes,
      );

      final future = mat.preWarm(priority: CompilerPriorityQueue.high);
      expect(future, isA<Future<void>>());
      engine.flushAndWait();
      engine.pumpMessageQueues();
      await expectLater(future, completes);
    });

    test('Lifecycle and refcounting destroys native material only when all instances are disposed', () async {
      final mat = await LuminaMaterial.load(
        world,
        'contents/materials/M_Base.filamat',
        assetProvider: (_) async => sampleBytes,
      );

      final inst1 = mat.createInstance();
      final inst2 = mat.createInstance();
      final inst3 = mat.createInstance();

      mat.release();
      expect(mat.isDisposed, isFalse);

      inst1.dispose();
      inst2.dispose();
      expect(mat.isDisposed, isFalse);

      inst3.dispose();
      expect(mat.isDisposed, isTrue);

      // Double-dispose on instance is safe no-op
      inst1.dispose();
    });
  });
}
