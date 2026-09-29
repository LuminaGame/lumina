// One shared engine per backend and GPU, handed out as leases.
import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FilamentEngineHost', () {
    tearDown(() {
      // Every test releases what it takes; a leftover engine is a test bug.
      expect(FilamentEngineHost.liveEngineCount, 0, reason: 'leases left: ${[
        for (final e in FilamentEngineHost.liveEngines) FilamentEngineHost.leaseOwners(e)
      ]}');
    });

    test('two acquires share one engine; it lives until the last release', () {
      final a = FilamentEngineHost.acquire(owner: 'viewport A', backend: FilamentBackend.noop)!;
      final b = FilamentEngineHost.acquire(owner: 'viewport B', backend: FilamentBackend.noop)!;
      expect(identical(a.engine, b.engine), isTrue);
      final engine = a.engine;
      expect(FilamentEngineHost.liveEngineCount, 1);
      expect(FilamentEngineHost.leaseCount(engine), 2);
      expect(FilamentEngineHost.leaseOwners(engine), ['viewport A', 'viewport B']);
      expect(FilamentEngineHost.owns(engine), isTrue);
      expect(engine.isHostOwned, isTrue);

      a.release();
      expect(a.isReleased, isTrue);
      expect(engine.isDisposed, isFalse, reason: 'viewport B still holds it');
      expect(FilamentEngineHost.leaseCount(engine), 1);
      // Still usable: another viewport's objects can be created and destroyed.
      final scene = engine.createScene();
      scene.dispose();
      expect(() => a.engine, throwsStateError);

      b.release();
      expect(engine.isDisposed, isTrue);
      expect(FilamentEngineHost.liveEngineCount, 0);
    });

    test('different backends and GPU preferences get different engines', () {
      final noop = FilamentEngineHost.acquire(owner: 'noop', backend: FilamentBackend.noop)!;
      final named = FilamentEngineHost.acquire(
        owner: 'named',
        backend: FilamentBackend.noop,
        gpu: const FilamentGpuPreference(deviceName: 'some other GPU'),
      )!;
      expect(identical(noop.engine, named.engine), isFalse);
      expect(FilamentEngineHost.liveEngineCount, 2);
      noop.release();
      named.release();
    });

    test('the default GPU preference is read at acquire time', () {
      final before = FilamentEngine.defaultGpuPreference;
      addTearDown(() => FilamentEngine.defaultGpuPreference = before);
      final first = FilamentEngineHost.acquire(owner: 'first', backend: FilamentBackend.noop)!;
      FilamentEngine.defaultGpuPreference = const FilamentGpuPreference(index: 7);
      final second = FilamentEngineHost.acquire(owner: 'second', backend: FilamentBackend.noop)!;
      expect(identical(first.engine, second.engine), isFalse,
          reason: 'a new preference gives new viewports a new engine; the old one keeps its own');
      first.release();
      second.release();
    });

    test('retain adds a lease on a hosted engine and nothing on a dedicated one', () {
      final lease = FilamentEngineHost.acquire(owner: 'widget', backend: FilamentBackend.noop)!;
      final retained = FilamentEngineHost.retain(lease.engine, owner: 'parent state')!;
      expect(FilamentEngineHost.leaseCount(lease.engine), 2);
      final engine = lease.engine;
      lease.release();
      lease.release(); // a second release is a no-op
      expect(engine.isDisposed, isFalse);
      expect(FilamentEngineHost.leaseCount(engine), 1);
      retained.release();
      expect(engine.isDisposed, isTrue);

      final dedicated = FilamentEngine.create(backend: FilamentBackend.noop)!;
      expect(FilamentEngineHost.retain(dedicated), isNull);
      expect(FilamentEngineHost.owns(dedicated), isFalse);
      dedicated.dispose();
      expect(dedicated.isDisposed, isTrue);
    });

    test('disposing a hosted engine directly throws and names the holders', () {
      final a = FilamentEngineHost.acquire(owner: 'level viewport', backend: FilamentBackend.noop)!;
      final b = FilamentEngineHost.acquire(owner: 'blueprint viewport', backend: FilamentBackend.noop)!;
      expect(
        () => a.engine.dispose(),
        throwsA(isA<StateError>().having((e) => e.message, 'message',
            allOf(contains('level viewport'), contains('blueprint viewport')))),
      );
      expect(a.engine.isDisposed, isFalse);
      final scene = a.engine.createScene();
      scene.dispose();
      a.release();
      b.release();
    });
  });

  group('engine-scoped resources', () {
    test('created once per key, disposed in reverse order before the engine', () {
      final lease = FilamentEngineHost.acquire(owner: 'viewport', backend: FilamentBackend.noop)!;
      final engine = lease.engine;
      final events = <String>[];
      var creates = 0;
      final first = engine.engineScoped<List<String>>('cache', () {
        creates++;
        return ['cache'];
      }, dispose: (v) {
        // The engine is still alive when a scoped value is torn down.
        final scene = engine.createScene();
        scene.dispose();
        events.add('dispose ${v.first} (engine alive: ${!engine.isDisposed})');
      });
      final again = engine.engineScoped<List<String>>('cache', () => throw StateError('created twice'));
      expect(identical(first, again), isTrue);
      expect(creates, 1);
      engine.engineScoped<List<String>>('materials', () => ['materials'],
          dispose: (v) => events.add('dispose ${v.first} (engine alive: ${!engine.isDisposed})'));
      expect(engine.engineScopedOrNull<List<String>>('materials'), ['materials']);

      lease.release();
      expect(events, ['dispose materials (engine alive: true)', 'dispose cache (engine alive: true)']);
      expect(engine.isDisposed, isTrue);
      expect(engine.engineScopedOrNull<List<String>>('cache'), isNull);
    });

    test('a dedicated engine tears its scoped values down too, and one can be released early', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final events = <String>[];
      engine.engineScoped<Object>('a', () => Object(), dispose: (_) => events.add('a'));
      engine.engineScoped<Object>('b', () => Object(), dispose: (_) => events.add('b'));
      engine.releaseEngineScoped('a');
      expect(events, ['a']);
      expect(engine.engineScopedOrNull<Object>('a'), isNull);
      engine.releaseEngineScoped('missing');
      engine.dispose();
      expect(events, ['a', 'b']);
    });

    test('a failing disposer does not keep the engine alive', () {
      final engine = FilamentEngine.create(backend: FilamentBackend.noop)!;
      final events = <String>[];
      engine.engineScoped<Object>('ok', () => Object(), dispose: (_) => events.add('ok'));
      engine.engineScoped<Object>('bad', () => Object(), dispose: (_) => throw StateError('boom'));
      engine.dispose();
      expect(events, ['ok']);
      expect(engine.isDisposed, isTrue);
    });
  });
}
