// FilamentWidgets share one engine, each with its own viewport objects.
import 'package:flutter/material.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

class _Created {
  _Created(this.engine, this.scene, this.view);
  final FilamentEngine engine;
  final FilamentScene scene;
  final FilamentView view;
}

Widget _viewports({
  required bool showA,
  required bool showB,
  required void Function(String id, _Created created) onCreated,
  bool shared = true,
  VoidCallback? onDisposeA,
}) {
  // Keyed boxes: removing A must not re-parent B's widget into A's slot.
  Widget viewport(String id, {VoidCallback? onDispose}) => SizedBox(
        key: ValueKey('box $id'),
        width: 320,
        height: 240,
        child: FilamentWidget(
          key: ValueKey(id),
          backend: FilamentBackend.noop,
          sharedEngine: shared,
          debugLabel: 'viewport $id',
          onDispose: onDispose,
          onSceneCreated: (engine, scene, camera, view) => onCreated(id, _Created(engine, scene, view)),
        ),
      );
  return MaterialApp(
    home: Scaffold(
      body: Row(children: [
        if (showA) viewport('A', onDispose: onDisposeA),
        if (showB) viewport('B'),
      ]),
    ),
  );
}

Future<void> _settle(WidgetTester tester, [int frames = 20]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  }
}

void main() {
  tearDown(() => expect(FilamentEngineHost.liveEngineCount, 0));

  testWidgets('two viewports share one engine, each with its own scene and view', (tester) async {
    final created = <String, _Created>{};
    await tester.pumpWidget(_viewports(showA: true, showB: true, onCreated: (id, c) => created[id] = c));
    await _settle(tester);
    expect(created.keys, containsAll(['A', 'B']));
    final engine = created['A']!.engine;
    expect(identical(engine, created['B']!.engine), isTrue);
    expect(FilamentEngineHost.liveEngineCount, 1);
    expect(FilamentEngineHost.leaseOwners(engine), ['viewport A', 'viewport B']);
    expect(identical(created['A']!.scene, created['B']!.scene), isFalse);
    expect(identical(created['A']!.view, created['B']!.view), isFalse);
    final both = engine.resourceCounts;

    // Unmount A: B keeps drawing on the same engine; exactly one viewport's
    // objects are gone.
    await tester.pumpWidget(_viewports(showA: false, showB: true, onCreated: (id, c) => created[id] = c));
    await _settle(tester);
    expect(engine.isDisposed, isFalse);
    final one = engine.resourceCounts;
    expect((both - one).views, 1);
    expect((both - one).scenes, 1);
    expect((both - one).swapChains, 1);
    expect(FilamentEngineHost.leaseOwners(engine), ['viewport B']);
    expect(find.byType(RawImage), findsOneWidget, reason: 'viewport B still presents frames');

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(engine.isDisposed, isTrue);
  });

  testWidgets('onDispose runs with the engine alive, even for the last viewport', (tester) async {
    final created = <String, _Created>{};
    bool? aliveInOnDispose;
    int? lightEntity;
    await tester.pumpWidget(_viewports(
      showA: true,
      showB: false,
      onCreated: (id, c) {
        created[id] = c;
        lightEntity = c.engine.createEntity();
        LightBuilder(LightType.directional).build(c.engine, lightEntity!);
      },
      onDisposeA: () {
        final engine = created['A']!.engine;
        aliveInOnDispose = !engine.isDisposed;
        engine.destroyEntityComponents(lightEntity!);
        engine.destroyEntity(lightEntity!);
      },
    ));
    await _settle(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(aliveInOnDispose, isTrue);
    expect(created['A']!.engine.isDisposed, isTrue);
  });

  testWidgets('a parent that retains the engine can free its objects after the widget is gone', (tester) async {
    final created = <String, _Created>{};
    FilamentEngineLease? parentLease;
    int? entity;
    await tester.pumpWidget(_viewports(
      showA: true,
      showB: false,
      onCreated: (id, c) {
        created[id] = c;
        parentLease = FilamentEngineHost.retain(c.engine, owner: 'parent state');
        entity = c.engine.createEntity();
        LightBuilder(LightType.point).build(c.engine, entity!);
      },
    ));
    await _settle(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    final engine = created['A']!.engine;
    expect(engine.isDisposed, isFalse, reason: 'the parent still holds a lease');
    // What a parent State.dispose does after its FilamentWidget child is gone.
    engine.destroyEntityComponents(entity!);
    engine.destroyEntity(entity!);
    parentLease!.release();
    expect(engine.isDisposed, isTrue);
  });

  testWidgets('sharedEngine: false keeps a dedicated engine per widget', (tester) async {
    final created = <String, _Created>{};
    await tester.pumpWidget(_viewports(showA: true, showB: true, shared: false, onCreated: (id, c) => created[id] = c));
    await _settle(tester);
    expect(identical(created['A']!.engine, created['B']!.engine), isFalse);
    expect(FilamentEngineHost.liveEngineCount, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(created['A']!.engine.isDisposed, isTrue);
    expect(created['B']!.engine.isDisposed, isTrue);
  });
}
