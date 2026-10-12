import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

/// A large level: 10 000 static collision components (boxes, spheres and
/// capsules on a 100 m square). 1 000 line traces and 200 sphere traces,
/// and the per-frame overlap pass, on the Dart reference and on Jolt's
/// broad phase: the same hits, and the timings.
void main() {
  tearDown(() => LuminaCollisionSubsystem.defaultQueryBackend = LuminaCollisionQueryBackendKind.auto);

  (LuminaWorld, LuminaCollisionSubsystem) level(
    LuminaCollisionQueryBackendKind kind,
    int count, {
    double spacing = 100,
  }) {
    LuminaCollisionSubsystem.defaultQueryBackend = kind;
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final collision = world.registerSubsystem(LuminaCollisionSubsystem());
    final random = math.Random(7);
    final side = math.sqrt(count).ceil();
    for (var i = 0; i < count; i++) {
      final at = Vector3(
        (i % side) * spacing + random.nextDouble() * 40,
        random.nextDouble() * 200,
        (i ~/ side) * spacing + random.nextDouble() * 40,
      );
      final LuminaCollisionComponent c = switch (i % 3) {
        0 => LuminaBoxComponent(location: at, boxExtent: Vector3(10 + random.nextDouble() * 20, 10, 15)),
        1 => LuminaSphereComponent(location: at, radius: 8 + random.nextDouble() * 15),
        _ => LuminaCapsuleComponent(location: at, radius: 10, halfHeight: 30),
      };
      c.objectType = CollisionObjectType.worldStatic;
      world.persistentLevel.registerActor(LuminaActor(root: c));
    }
    return (world, collision);
  }

  List<(Vector3, Vector3)> rays(int n, int count) {
    final random = math.Random(11);
    final extent = math.sqrt(count).ceil() * 100.0;
    return [
      for (var i = 0; i < n; i++)
        (
          Vector3(random.nextDouble() * extent, 100, random.nextDouble() * extent),
          Vector3(random.nextDouble() * extent, 100 + random.nextDouble() * 50, random.nextDouble() * extent),
        ),
    ];
  }

  test('1 000 line traces and 200 sphere traces in a 10 000-component level: same hits, Jolt faster', () {
    const count = 10000;
    final segments = rays(1000, count);
    final results = <LuminaCollisionQueryBackendKind, (List<String>, int, int)>{};
    for (final kind in [LuminaCollisionQueryBackendKind.dart, LuminaCollisionQueryBackendKind.jolt]) {
      final (world, collision) = level(kind, count);
      final hit = HitResult();
      final found = <String>[];
      // Components by their place in the level (ids differ between worlds).
      final index = {for (final (i, c) in collision.components.indexed) c: i};
      // Warm up (the Jolt proxies are built on the first query).
      collision.lineTraceSingle(start: segments.first.$1, end: segments.first.$2, out: hit);
      final lines = Stopwatch()..start();
      for (final (start, end) in segments) {
        found.add(
          collision.lineTraceSingle(start: start, end: end, out: hit)
              ? '${index[hit.component]}@${hit.distance.toStringAsFixed(3)}'
              : '-',
        );
      }
      lines.stop();
      final spheres = Stopwatch()..start();
      for (final (start, end) in segments.take(200)) {
        final hits = collision.sphereTraceMulti(start: start, end: end, radius: 20);
        found.add(hits.map((h) => '${index[h.component]}@${h.distance.toStringAsFixed(2)}').join(','));
      }
      spheres.stop();
      results[kind] = (found, lines.elapsedMicroseconds, spheres.elapsedMicroseconds);
      expect(collision.queryAccelerator?.name, kind == LuminaCollisionQueryBackendKind.jolt ? 'jolt' : isNull);
      world.cleanup();
    }
    final dart = results[LuminaCollisionQueryBackendKind.dart]!, jolt = results[LuminaCollisionQueryBackendKind.jolt]!;
    // ignore: avoid_print
    print(
      '10 000 components: 1 000 line traces Dart ${(dart.$2 / 1000).toStringAsFixed(1)} ms, '
      'Jolt ${(jolt.$2 / 1000).toStringAsFixed(1)} ms; 200 sphere traces Dart ${(dart.$3 / 1000).toStringAsFixed(1)} ms, '
      'Jolt ${(jolt.$3 / 1000).toStringAsFixed(1)} ms; ${dart.$1.take(1000).where((h) => h != '-').length} line hits',
    );
    for (var i = 0; i < dart.$1.length; i++) {
      if (jolt.$1[i] != dart.$1[i]) {
        // ignore: avoid_print
        print('first difference at query $i: Dart ${dart.$1[i]} Jolt ${jolt.$1[i]}');
        break;
      }
    }
    expect(jolt.$1, dart.$1, reason: 'the same hits, in the same order');
    expect(jolt.$2, lessThan(dart.$2));
  });

  test('the overlap pass of a 3 000-component level: the same events, Jolt faster', () {
    const count = 3000;
    final passes = <LuminaCollisionQueryBackendKind, (int, List<String>)>{};
    for (final kind in [LuminaCollisionQueryBackendKind.dart, LuminaCollisionQueryBackendKind.jolt]) {
      // Packed closer: neighbours overlap.
      final (world, collision) = level(kind, count, spacing: 30);
      final overlaps = <String>[];
      final index = {for (final (i, c) in collision.components.indexed) c: i};
      for (final c in collision.components) {
        c
          ..objectType = CollisionObjectType.worldDynamic
          ..setResponseToAll(CollisionResponse.overlap)
          ..generateOverlapEvents = true
          ..onComponentBeginOverlap = (self, other) => overlaps.add('${index[self]}-${index[other]}');
      }
      final watch = Stopwatch()..start();
      collision.updateCollision(1 / 60);
      passes[kind] = (watch.elapsedMicroseconds, overlaps);
      world.cleanup();
    }
    final dart = passes[LuminaCollisionQueryBackendKind.dart]!, jolt = passes[LuminaCollisionQueryBackendKind.jolt]!;
    // ignore: avoid_print
    print(
      '3 000 components: overlap pass Dart ${(dart.$1 / 1000).toStringAsFixed(1)} ms, '
      'Jolt ${(jolt.$1 / 1000).toStringAsFixed(1)} ms, ${dart.$2.length} begin overlaps',
    );
    expect(dart.$2, isNotEmpty);
    expect(jolt.$2, dart.$2, reason: 'the same overlap events, in the same order');
    expect(jolt.$1, lessThan(dart.$1));
  });
}
