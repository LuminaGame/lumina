import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_filament/flutter_filament.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MaterialRegistry and Filamesh Tests', () {
    late FilamentEngine engine;
    late FilamentMaterialProvider materialProvider;
    late FilamentMaterialInstance miA;
    late FilamentMaterialInstance miB;
    late Uint8List twoMaterialsFilameshBytes;

    setUpAll(() {
      engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      materialProvider = FilamentMaterialProvider.ubershader(engine);
      final resA = materialProvider.createMaterialInstance(MaterialKey());
      final resB = materialProvider.createMaterialInstance(MaterialKey());
      miA = resA.instance!;
      miB = resB.instance!;

      final filameshFile = File('test/assets/two_materials.filamesh');
      expect(filameshFile.existsSync(), isTrue);
      twoMaterialsFilameshBytes = filameshFile.readAsBytesSync();
    });

    tearDownAll(() {
      miA.dispose();
      miB.dispose();
      materialProvider.dispose();
      engine.dispose();
    });

    test('Registry basics: register, get, names, unregister, count', () {
      final registry = MaterialRegistry();
      expect(registry.numRegistered, equals(0));
      expect(registry.names, isEmpty);

      registry.register('matA', miA);
      registry.register('matB', miB);

      expect(registry.numRegistered, equals(2));
      expect(registry.names, containsAll(['matA', 'matB']));
      expect(registry.getMaterialInstance('matA')?.nativePointer.address, equals(miA.nativePointer.address));
      expect(registry.getMaterialInstance('matB')?.nativePointer.address, equals(miB.nativePointer.address));
      expect(registry.getMaterialInstance('nope'), isNull);

      registry.unregister('matA');
      expect(registry.numRegistered, equals(1));
      expect(registry.getMaterialInstance('matA'), isNull);
      expect(registry.getMaterialInstance('matB')?.nativePointer.address, equals(miB.nativePointer.address));

      registry.destroy();
    });

    test('Registry does not own MaterialInstances on destroy', () {
      final registry = MaterialRegistry();
      registry.register('matA', miA);
      registry.destroy();

      // miA is still alive and valid
      expect(miA.nativePointer.address, isNot(equals(0)));
    });

    test('Registry-load: 2-submesh golden with both names registered binds MIs to primitives', () {
      final registry = MaterialRegistry();
      registry.register('matA', miA);
      registry.register('matB', miB);

      final mesh = loadMeshFromBuffer(engine, twoMaterialsFilameshBytes, materials: registry);
      expect(mesh, isNotNull);
      expect(mesh!.renderable, isNot(equals(0)));
      expect(mesh.vertexBuffer, isNot(equals(0)));
      expect(mesh.indexBuffer, isNot(equals(0)));

      final rm = RenderableManager(engine);
      final primCount = rm.getPrimitiveCount(mesh.renderable);
      expect(primCount, equals(2));

      final miAt0 = rm.getMaterialInstanceAt(mesh.renderable, 0);
      final miAt1 = rm.getMaterialInstanceAt(mesh.renderable, 1);
      expect(miAt0?.nativePointer.address, equals(miA.nativePointer.address));
      expect(miAt1?.nativePointer.address, equals(miB.nativePointer.address));

      mesh.destroy();
      registry.destroy();
    });

    test('Fallback: loading with only matA registered succeeds without crash', () {
      final registry = MaterialRegistry();
      registry.register('matA', miA);

      final mesh = loadMeshFromBuffer(engine, twoMaterialsFilameshBytes, materials: registry);
      expect(mesh, isNotNull);

      final rm = RenderableManager(engine);
      expect(rm.getPrimitiveCount(mesh!.renderable), equals(2));
      expect(rm.getMaterialInstanceAt(mesh.renderable, 0)?.nativePointer.address, equals(miA.nativePointer.address));

      mesh.destroy();
      registry.destroy();
    });

    test('Ownership & double destroy protection', () {
      final mesh = loadMeshFromBuffer(engine, twoMaterialsFilameshBytes);
      expect(mesh, isNotNull);

      mesh!.destroy();
      expect(() => mesh.destroy(), throwsStateError);
    });

    test('Leak regression: load and destroy 100x in a loop', () {
      final registry = MaterialRegistry();
      registry.register('matA', miA);
      registry.register('matB', miB);

      for (int i = 0; i < 100; i++) {
        final mesh = loadMeshFromBuffer(engine, twoMaterialsFilameshBytes, materials: registry);
        expect(mesh, isNotNull);
        mesh!.destroy();
      }

      registry.destroy();
    });

    test('Backwards compatibility: loadMeshFromBuffer without registry', () {
      final mesh = loadMeshFromBuffer(engine, twoMaterialsFilameshBytes);
      expect(mesh, isNotNull);
      expect(mesh!.renderable, isNot(equals(0)));

      final rm = RenderableManager(engine);
      expect(rm.getPrimitiveCount(mesh.renderable), equals(2));

      mesh.destroy();
    });
  });
}
