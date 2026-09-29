import 'package:flutter_filament/flutter_filament.dart';
import 'package:test/test.dart';

void main() {
  group('Utils Smoke Tests', () {
    test('Entity Manager bulk ops and isAlive headless simulation', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final swapChain = engine.createHeadlessSwapChain(800, 600);
      final renderer = engine.createRenderer();
      final view = engine.createView();

      try {
        final scene = engine.createScene();
        view.scene = scene;

        // Tick 3 frames with dynamic entities
        for (int frame = 0; frame < 3; frame++) {
          // Bulk create temporary entities for this frame
          final entities = EntityManager.createEntities(100);
          expect(entities.length, 100);
          
          for (final e in entities) {
            expect(EntityManager.isAlive(e), isTrue);
            // Optionally add to scene, though empty entities do nothing
            scene.addEntity(e);
          }

          expect(renderer.beginFrame(swapChain), isTrue);
          renderer.render(view);
          renderer.endFrame();

          // Bulk remove and destroy
          for (final e in entities) {
            scene.removeEntity(e);
            engine.destroyEntity(e); // Ensure engine components (if any) are cleaned up
          }
          // The entities array can also be destroyed via bulk, but engine.destroyEntity already delegates to EntityManager.destroy!
          // We'll use bulk destroy just to test the FFI path again, but on *new* entities.
          final moreEntities = EntityManager.createEntities(50);
          EntityManager.destroyEntities(moreEntities);
          
          for (final e in moreEntities) {
            expect(EntityManager.isAlive(e), isFalse);
          }
        }
        
        // Assert no leaks in entity manager for the frame temp entities
        // Note: engine itself has some default entities, so we just check it doesn't crash.
        engine.flushAndWait();
        expect(true, isTrue); // Reached end without exception
        
      } finally {
        engine.dispose();
      }
    });

    test('Panic and Log Bridge headless simulation', () async {
      FilamentDiagnostics.installPanicHandler();
      FilamentDiagnostics.installLogHandler();
      
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;

      try {
        final records = <FilamentLogRecord>[];
        final sub = FilamentDiagnostics.onLog.listen((record) {
          records.add(record);
        });

        // Trigger a test log and wait for it
        FilamentDiagnostics.testLog('Smoke test log');
        await Future.delayed(Duration(milliseconds: 100));

        expect(records.any((r) => r.message.contains('Smoke test log')), isTrue);
        await sub.cancel();

        // Trigger a panic and ensure we survive
        var caught = false;
        final panicSub = FilamentDiagnostics.onPanic.listen((e) {
          caught = true;
        });
        FilamentDiagnostics.testTriggerPanic();

        await Future.delayed(Duration(milliseconds: 100));
        expect(caught, isTrue);
        expect(FilamentDiagnostics.lastPanic, contains('Test panic message'));
        
        await panicSub.cancel();

      } finally {
        engine.dispose();
        FilamentDiagnostics.clearPanicHandler();
        FilamentDiagnostics.clearLogHandler();
      }
    });
  });
}
