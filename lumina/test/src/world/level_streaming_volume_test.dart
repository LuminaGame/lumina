import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  group('LuminaLevelStreamingVolume Tests (Task 02)', () {
    test('Constructing with both bounds and sphereRadius, or neither -> ArgumentError', () {
      expect(
        () => LuminaLevelStreamingVolume(
          volumeName: 'InvalidBoth',
          targetLevelNames: ['SubLevel_A'],
          bounds: Aabb3.minMax(Vector3(0, 0, 0), Vector3(10, 10, 10)),
          sphereRadius: 10.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => LuminaLevelStreamingVolume(
          volumeName: 'InvalidNeither',
          targetLevelNames: ['SubLevel_A'],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('AABB volume: entry, hysteresis hold in margin, exit after exitDelay commit', () {
      final enteredPawns = <Object>[];
      final exitedPawns = <Object>[];

      final volume = LuminaLevelStreamingVolume(
        volumeName: 'VolAABB',
        targetLevelNames: ['SubLevel_A', 'SubLevel_B'],
        bounds: Aabb3.minMax(Vector3(0, 0, 0), Vector3(10, 10, 10)),
        bufferMargin: 5.0,
        exitDelay: const Duration(seconds: 2),
      );

      volume.onPawnEnteredVolume = (id) => enteredPawns.add(id);
      volume.onPawnExitedVolume = (id) => exitedPawns.add(id);

      const pawn1 = 'Pawn1';

      // 1. Pawn enters at (5,5,5) -> inside, entered event fires once
      bool inside = volume.evaluatePawnPosition(pawn1, Vector3(5, 5, 5), 0.1);
      expect(inside, isTrue);
      expect(volume.isAnyPawnInside, isTrue);
      expect(volume.requestedLevels, containsAll(['SubLevel_A', 'SubLevel_B']));
      expect(enteredPawns, equals(['Pawn1']));
      expect(exitedPawns, isEmpty);

      // 2. Same pawn moves to (12,5,5) (outside tight (0..10), inside margin (-5..15))
      inside = volume.evaluatePawnPosition(pawn1, Vector3(12, 5, 5), 0.1);
      expect(inside, isTrue, reason: 'Hysteresis margin keeps pawn inside');
      expect(volume.isAnyPawnInside, isTrue);
      expect(enteredPawns, equals(['Pawn1']));
      expect(exitedPawns, isEmpty);

      // 3. Pawn moves to (20,5,5) (outside margin), but time elapsed is only 1.0s (< 2.0s exitDelay)
      inside = volume.evaluatePawnPosition(pawn1, Vector3(20, 5, 5), 1.0);
      expect(inside, isTrue, reason: 'Pawn remains inside until exitDelay elapses');
      expect(exitedPawns, isEmpty);

      // 4. Pawn stays at (20,5,5) for another 1.1s (total 2.1s >= 2.0s exitDelay) -> exit committed
      inside = volume.evaluatePawnPosition(pawn1, Vector3(20, 5, 5), 1.1);
      expect(inside, isFalse);
      expect(volume.isAnyPawnInside, isFalse);
      expect(volume.requestedLevels, isEmpty);
      expect(exitedPawns, equals(['Pawn1']));
    });

    test('Pawn leaves outside margin but returns inside before exitDelay -> debounce cancels, no exit event', () {
      final enteredPawns = <Object>[];
      final exitedPawns = <Object>[];

      final volume = LuminaLevelStreamingVolume(
        volumeName: 'VolDebounce',
        targetLevelNames: ['SubLevel_A'],
        bounds: Aabb3.minMax(Vector3(0, 0, 0), Vector3(10, 10, 10)),
        bufferMargin: 5.0,
        exitDelay: const Duration(seconds: 2),
      );

      volume.onPawnEnteredVolume = enteredPawns.add;
      volume.onPawnExitedVolume = exitedPawns.add;

      const pawn = 'PlayerPawn';

      // Enter
      volume.evaluatePawnPosition(pawn, Vector3(5, 5, 5), 0.1);
      expect(enteredPawns, equals(['PlayerPawn']));

      // Step outside to (20,5,5) for 1.0s
      volume.evaluatePawnPosition(pawn, Vector3(20, 5, 5), 1.0);
      expect(exitedPawns, isEmpty);

      // Return back inside to (5,5,5)
      final inside = volume.evaluatePawnPosition(pawn, Vector3(5, 5, 5), 0.5);
      expect(inside, isTrue);
      expect(exitedPawns, isEmpty, reason: 'Exit debounce cancelled when returning inside');
      expect(enteredPawns.length, equals(1));
    });

    test('Sphere volume: inside, hysteresis in margin, exit after delay', () {
      final volume = LuminaLevelStreamingVolume(
        volumeName: 'VolSphere',
        targetLevelNames: ['SubLevel_Sphere'],
        sphereCenter: Vector3(0, 0, 0),
        sphereRadius: 10.0,
        bufferMargin: 5.0,
        exitDelay: const Duration(seconds: 1),
      );

      const pawn = 'SpherePawn';

      // 1. Inside at (0, 0, 9.9) (dist < 10)
      expect(volume.evaluatePawnPosition(pawn, Vector3(0, 0, 9.9), 0.1), isTrue);

      // 2. In margin at (0, 0, 14.9) (dist < 10 + 5)
      expect(volume.evaluatePawnPosition(pawn, Vector3(0, 0, 14.9), 0.1), isTrue);

      // 3. Outside margin at (0, 0, 15.1) (dist > 15), for 0.5s (< 1.0s)
      expect(volume.evaluatePawnPosition(pawn, Vector3(0, 0, 15.1), 0.5), isTrue);

      // 4. Stays outside for another 0.6s -> exit committed
      expect(volume.evaluatePawnPosition(pawn, Vector3(0, 0, 15.1), 0.6), isFalse);
    });

    test('Two pawns: A inside, B outside -> isAnyPawnInside holds until all exit; removePawn forgets without event', () {
      final enteredPawns = <Object>[];
      final exitedPawns = <Object>[];

      final volume = LuminaLevelStreamingVolume(
        volumeName: 'VolMulti',
        targetLevelNames: ['SubLevel_Multi'],
        bounds: Aabb3.minMax(Vector3(0, 0, 0), Vector3(10, 10, 10)),
        bufferMargin: 2.0,
        exitDelay: const Duration(seconds: 1),
      );

      volume.onPawnEnteredVolume = enteredPawns.add;
      volume.onPawnExitedVolume = exitedPawns.add;

      // Pawn A enters
      volume.evaluatePawnPosition('A', Vector3(5, 5, 5), 0.1);
      // Pawn B outside
      volume.evaluatePawnPosition('B', Vector3(30, 30, 30), 0.1);

      expect(volume.isAnyPawnInside, isTrue);
      expect(enteredPawns, equals(['A']));

      // Pawn B enters
      volume.evaluatePawnPosition('B', Vector3(2, 2, 2), 0.1);
      expect(enteredPawns, equals(['A', 'B']));

      // Pawn A exits and commits exit
      volume.evaluatePawnPosition('A', Vector3(50, 50, 50), 1.5);
      expect(exitedPawns, equals(['A']));
      expect(volume.isAnyPawnInside, isTrue, reason: 'Pawn B is still inside');

      // Despawn Pawn B using removePawn -> no exit event fired
      volume.removePawn('B');
      expect(exitedPawns, equals(['A']));
      expect(volume.isAnyPawnInside, isFalse);
      expect(volume.requestedLevels, isEmpty);
    });

    test('bDisabled: true -> requestedLevels is always empty even with pawn inside', () {
      final volume = LuminaLevelStreamingVolume(
        volumeName: 'VolDisabled',
        targetLevelNames: ['SubLevel_Disabled'],
        bounds: Aabb3.minMax(Vector3(0, 0, 0), Vector3(10, 10, 10)),
        bDisabled: true,
      );

      final inside = volume.evaluatePawnPosition('Pawn1', Vector3(5, 5, 5), 0.1);
      expect(inside, isTrue);
      expect(volume.isAnyPawnInside, isTrue);
      expect(volume.requestedLevels, isEmpty, reason: 'Disabled volume must not request levels');
    });
  });
}
