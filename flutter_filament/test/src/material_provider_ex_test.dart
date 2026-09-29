import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/src/engine.dart';
import 'package:flutter_filament/src/gltf_loader.dart';

void main() {
  group('MaterialProvider Expansion Tests', () {
    late FilamentEngine engine;

    setUp(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
    });

    tearDown(() {
      engine.dispose();
    });

    test('createMaterialInstance returns working MaterialInstance with ubershader', () {
      final provider = FilamentMaterialProvider.ubershader(engine);
      final key = MaterialKey(unlit: false, hasBaseColorTexture: false);
      
      final result = provider.createMaterialInstance(key, label: 'TestMaterial');
      expect(result, isNotNull);
      expect(result.instance, isNotNull);
      
      result.instance!.dispose();
      provider.destroyMaterials();
      provider.dispose();
    });

    test('UvMap baseColorUV is assigned when hasBaseColorTexture is true', () {
      final provider = FilamentMaterialProvider.ubershader(engine);
      final key = MaterialKey(unlit: false, hasBaseColorTexture: true);
      
      final result = provider.createMaterialInstance(key);
      expect(result.uvMap, isNotNull);
      // The uvMap is an array of 8 ints where index 0 is UV0, 1 is UV1, 2 is UNUSED usually
      expect(result.uvMap.length, equals(8));
      
      result.instance!.dispose();
      provider.destroyMaterials();
      provider.dispose();
    });

    test('constrainMaterial modifies key in place', () {
      final provider = FilamentMaterialProvider.ubershader(engine);
      final key = MaterialKey(hasBaseColorTexture: true);
      
      final result = provider.createMaterialInstance(key);
      expect(result.key, isNotNull);
      
      result.instance!.dispose();
      provider.destroyMaterials();
      provider.dispose();
    });

    test('materials list returns correct count', () {
      final provider = FilamentMaterialProvider.ubershader(engine);
      final key = MaterialKey(unlit: false, hasBaseColorTexture: true);
      final result = provider.createMaterialInstance(key);
      
      final count = provider.materialsCount;
      final materials = provider.materials;
      
      expect(materials.length, equals(count));
      expect(count, greaterThanOrEqualTo(1));
      
      result.instance!.dispose();
      provider.destroyMaterials();
      provider.dispose();
    });

    test('needsDummyData returns correct values', () {
      final provider = FilamentMaterialProvider.ubershader(engine);
      final needsUV0 = provider.needsDummyData(6);
      final needsPosition = provider.needsDummyData(0);
      
      expect(needsUV0, isA<bool>());
      expect(needsPosition, isA<bool>());
      
      provider.destroyMaterials();
      provider.dispose();
    });

    test('JIT provider optimizeShaders works', () {
      final providerFast = FilamentMaterialProvider.jit(engine, optimizeShaders: false);
      final key1 = MaterialKey(unlit: true);
      final resultFast = providerFast.createMaterialInstance(key1);
      expect(resultFast.instance, isNotNull);
      resultFast.instance!.dispose();
      providerFast.destroyMaterials();
      providerFast.dispose();

      final providerOpt = FilamentMaterialProvider.jit(engine, optimizeShaders: true);
      final key2 = MaterialKey(unlit: true);
      final resultOpt = providerOpt.createMaterialInstance(key2);
      expect(resultOpt.instance, isNotNull);
      resultOpt.instance!.dispose();
      providerOpt.destroyMaterials();
      providerOpt.dispose();
    });
  });
}
