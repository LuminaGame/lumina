import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

void main() {
  group('World Partition HLOD Subsystem Tests (Task 04)', () {
    test('Descriptor registered for cell (5,5), cell unloaded, subsystem ticked -> proxy shown, opacity 1.0', () {
      final hlod = LuminaHlodSubsystem(
        crossFadeDuration: const Duration(milliseconds: 500),
      );
      hlod.registerProxyDescriptor(
        LuminaHlodProxyDescriptor(
          cellX: 5,
          cellY: 5,
          proxyMeshAsset: 'Props/Barrels/dented_barrel.glb',
        ),
      );

      hlod.onWorldTick(0.016);
      final proxy = hlod.proxyForCell(5, 5);

      expect(proxy, isNotNull);
      expect(proxy!.state, equals(HlodProxyState.shown));
      expect(proxy.opacity, equals(1.0));
    });

    test('Cell (5,5) transitions to loading -> proxy remains shown (no premature fade)', () {
      final hlod = LuminaHlodSubsystem(
        crossFadeDuration: const Duration(milliseconds: 500),
      );
      hlod.registerProxyDescriptor(
        LuminaHlodProxyDescriptor(
          cellX: 5,
          cellY: 5,
          proxyMeshAsset: 'Props/Barrels/dented_barrel.glb',
        ),
      );

      hlod.onWorldTick(0.016);
      hlod.onCellStateChanged(5, 5, CellState.unloaded, CellState.loading);
      hlod.onWorldTick(0.016);

      final proxy = hlod.proxyForCell(5, 5)!;
      expect(proxy.state, equals(HlodProxyState.shown));
      expect(proxy.opacity, equals(1.0));
    });

    test('Cell reaches activated with 500ms duration -> at 250ms opacity 0.5 (fadingOut); at 500ms hidden, pooled', () {
      final hlod = LuminaHlodSubsystem(
        crossFadeDuration: const Duration(milliseconds: 500),
        proxyPoolSize: 4,
      );
      hlod.registerProxyDescriptor(
        LuminaHlodProxyDescriptor(
          cellX: 5,
          cellY: 5,
          proxyMeshAsset: 'Props/Barrels/dented_barrel.glb',
        ),
      );

      hlod.onWorldTick(0.016);
      expect(hlod.availablePoolCount, equals(3)); // 1 used from 4

      hlod.onCellStateChanged(5, 5, CellState.loading, CellState.activated);

      // Tick 250ms
      hlod.onWorldTick(0.250);
      final proxy = hlod.proxyForCell(5, 5)!;
      expect(proxy.state, equals(HlodProxyState.fadingOut));
      expect(proxy.opacity, closeTo(0.5, 0.01));

      // Tick remaining 250ms
      hlod.onWorldTick(0.250);
      expect(proxy.state, equals(HlodProxyState.hidden));
      expect(proxy.opacity, equals(0.0));
      expect(hlod.availablePoolCount, equals(4)); // returned to pool
    });

    test('Reversal mid-fade: cell reactivates while proxy is fadingIn at 0.4 -> proxy fades back out from 0.4', () {
      final hlod = LuminaHlodSubsystem(
        crossFadeDuration: const Duration(milliseconds: 500),
      );
      hlod.registerProxyDescriptor(
        LuminaHlodProxyDescriptor(
          cellX: 5,
          cellY: 5,
          proxyMeshAsset: 'Props/Barrels/dented_barrel.glb',
        ),
      );

      // Start hidden/activated
      hlod.onCellStateChanged(5, 5, CellState.unloaded, CellState.activated);
      hlod.onWorldTick(0.5); // full fade out to hidden

      // Cell starts unloading -> proxy fades in
      hlod.onCellStateChanged(5, 5, CellState.activated, CellState.deactivated);
      hlod.onWorldTick(0.2); // 200ms / 500ms = 0.4 opacity

      var proxy = hlod.proxyForCell(5, 5)!;
      expect(proxy.state, equals(HlodProxyState.fadingIn));
      expect(proxy.opacity, closeTo(0.4, 0.01));

      // Reversal: cell reactivates mid-fade!
      hlod.onCellStateChanged(5, 5, CellState.deactivated, CellState.activated);
      expect(proxy.state, equals(HlodProxyState.fadingOut));
      expect(proxy.opacity, closeTo(0.4, 0.01));

      // Tick 200ms -> back to 0.0 and hidden
      hlod.onWorldTick(0.2);
      expect(proxy.state, equals(HlodProxyState.hidden));
      expect(proxy.opacity, equals(0.0));
    });

    test('proxyPoolSize: 2 with 3 distant descriptor cells -> exactly 2 live proxy instances (pool budget respected)', () {
      final hlod = LuminaHlodSubsystem(
        proxyPoolSize: 2,
      );
      hlod.registerProxyDescriptor(
        LuminaHlodProxyDescriptor(cellX: 1, cellY: 1, proxyMeshAsset: 'asset1.glb'),
      );
      hlod.registerProxyDescriptor(
        LuminaHlodProxyDescriptor(cellX: 2, cellY: 2, proxyMeshAsset: 'asset2.glb'),
      );
      hlod.registerProxyDescriptor(
        LuminaHlodProxyDescriptor(cellX: 10, cellY: 10, proxyMeshAsset: 'asset3.glb'),
      );

      hlod.onWorldTick(0.016);

      expect(hlod.liveProxyCount, equals(2));
      expect(hlod.availablePoolCount, equals(0));
    });

    test('Cell with no descriptor -> proxyForCell returns null without errors', () {
      final hlod = LuminaHlodSubsystem();
      hlod.onWorldTick(0.016);
      expect(hlod.proxyForCell(99, 99), isNull);
    });
  });
}
