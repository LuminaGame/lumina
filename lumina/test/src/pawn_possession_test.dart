import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

class ProbePawn extends LuminaPawn {
  final List<String> callLog;
  ProbePawn(this.callLog);

  @override
  void restart() {
    callLog.add('restart');
    super.restart();
  }

  @override
  void setupPlayerInputComponent(LuminaPlayerComponent playerInput) {
    callLog.add('setupPlayerInputComponent');
    super.setupPlayerInputComponent(playerInput);
  }
}

class ProbePlayerController extends LuminaPlayerController {
  final List<String> callLog;
  ProbePlayerController(this.callLog);

  @override
  void onPossess(LuminaPawn pawn) {
    callLog.add('onPossess');
    super.onPossess(pawn);
  }

  @override
  void onUnpossess(LuminaPawn pawn) {
    callLog.add('onUnpossess');
    super.onUnpossess(pawn);
  }
}

class DummyAIController extends LuminaController {
  final List<String> callLog;
  DummyAIController(this.callLog);

  @override
  void onPossess(LuminaPawn pawn) {
    callLog.add('ai.onPossess');
    super.onPossess(pawn);
  }

  @override
  void onUnpossess(LuminaPawn pawn) {
    callLog.add('ai.onUnpossess');
    super.onUnpossess(pawn);
  }
}

void main() {
  group('Pawn Possession Tests (Pawn Task 01)', () {
    test('playerController.possess(pawn) establishes bidirectional references and state queries', () {
      final log = <String>[];
      final pc = ProbePlayerController(log);
      final pawn = ProbePawn(log);

      pc.possess(pawn);

      expect(pawn.controller, equals(pc));
      expect(pc.pawn, equals(pawn));
      expect(pawn.isPawnControlled(), isTrue);
      expect(pawn.isPlayerControlled(), isTrue);
      expect(pawn.isBotControlled(), isFalse);
    });

    test('Call-order recording: possession runs [restart, setupPlayerInputComponent, onPossessed, onPossess]', () {
      final log = <String>[];
      final pc = ProbePlayerController(log);
      final pawn = ProbePawn(log);

      pawn.addOnPossessed((c) {
        log.add('onPossessed');
      });

      pc.possess(pawn);

      expect(log, equals([
        'restart',
        'setupPlayerInputComponent',
        'onPossessed',
        'onPossess',
      ]));
    });

    test('possess(pawn) twice with same pawn is idempotent', () {
      final log = <String>[];
      final pc = ProbePlayerController(log);
      final pawn = ProbePawn(log);

      int possessedCount = 0;
      pawn.addOnPossessed((c) {
        possessedCount++;
      });

      pc.possess(pawn);
      pc.possess(pawn);

      expect(possessedCount, equals(1));
    });

    test('Steal semantics: controllerA.possess then controllerB.possess steals pawn cleanly', () {
      final logA = <String>[];
      final logB = <String>[];
      final pcA = ProbePlayerController(logA);
      final pcB = ProbePlayerController(logB);
      final pawn = ProbePawn(logA);

      pcA.possess(pawn);
      expect(pawn.controller, equals(pcA));
      expect(pcA.pawn, equals(pawn));

      pcB.possess(pawn);

      expect(pawn.controller, equals(pcB));
      expect(pcB.pawn, equals(pawn));
      expect(pcA.pawn, isNull);
      expect(logA, contains('onUnpossess'));
    });

    test('unpossess nulls both sides and notifies onUnpossessed listeners', () {
      final log = <String>[];
      final pc = ProbePlayerController(log);
      final pawn = ProbePawn(log);

      LuminaController? receivedOldController;
      int unpossessCount = 0;
      pawn.addOnUnpossessed((c) {
        receivedOldController = c;
        unpossessCount++;
      });

      pc.possess(pawn);
      pc.unpossess();

      expect(pawn.controller, isNull);
      expect(pc.pawn, isNull);
      expect(pawn.isPawnControlled(), isFalse);
      expect(unpossessCount, equals(1));
      expect(identical(receivedOldController, pc), isTrue);
    });

    test('AIController possession sets isBotControlled true and skips setupPlayerInputComponent', () {
      final log = <String>[];
      final ai = DummyAIController(log);
      final pawn = ProbePawn(log);

      ai.possess(pawn);

      expect(pawn.isPawnControlled(), isTrue);
      expect(pawn.isPlayerControlled(), isFalse);
      expect(pawn.isBotControlled(), isTrue);
      expect(log.contains('setupPlayerInputComponent'), isFalse);
    });

    test('restart() resets accumulated input vector', () {
      final log = <String>[];
      final pc = ProbePlayerController(log);
      final pawn = ProbePawn(log);

      pawn.addMovementInput(Vector3(1.0, 0.0, 0.0), 1.0);
      pc.possess(pawn);

      final remainingInput = pawn.consumeMovementInputVector();
      expect(remainingInput, equals(Vector3.zero()));
    });

    test('removeOnPossessed removes listener and supports mutation inside listener callback', () {
      final log = <String>[];
      final pc = ProbePlayerController(log);
      final pawn = ProbePawn(log);

      void Function(LuminaController)? listenerA;
      int countA = 0;
      int countB = 0;

      listenerA = (c) {
        countA++;
        pawn.removeOnPossessed(listenerA!);
      };

      void listenerB(LuminaController c) {
        countB++;
      }

      pawn.addOnPossessed(listenerA);
      pawn.addOnPossessed(listenerB);

      pc.possess(pawn);
      expect(countA, equals(1));
      expect(countB, equals(1));

      pc.unpossess();
      pc.possess(pawn);

      expect(countA, equals(1));
      expect(countB, equals(2));
    });
  });
}
