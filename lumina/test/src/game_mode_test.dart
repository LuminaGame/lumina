import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart';

class TestPawn extends LuminaPawn {}

class OrderRecordingGameMode extends LuminaGameMode {
  final List<String> orderLog;

  OrderRecordingGameMode(this.orderLog);

  @override
  void initGame(LuminaWorld world) {
    orderLog.add('initGame');
    super.initGame(world);
  }

  @override
  void handleStartingNewPlayer(LuminaPlayerController controller) {
    orderLog.add('handleStartingNewPlayer');
    super.handleStartingNewPlayer(controller);
  }

  @override
  LuminaTransformSnapshot findPlayerStart(LuminaPlayerController controller, {String? tag}) {
    orderLog.add('findPlayerStart');
    return super.findPlayerStart(controller, tag: tag);
  }
}

class TestActor extends LuminaActor {
  final List<String> orderLog;
  TestActor(this.orderLog);

  @override
  void onBeginPlay() {
    orderLog.add('actor onBeginPlay');
    super.onBeginPlay();
  }
}

void main() {
  group('LuminaGameMode', () {
    test('World init runs initGame before actor onBeginPlay', () {
      final log = <String>[];
      final mode = OrderRecordingGameMode(log);
      final world = LuminaWorld();
      world.gameMode = mode;
      
      world.persistentLevel.registerActor(TestActor(log));
      
      world.beginPlay();
      
      expect(log, equals(['initGame', 'actor onBeginPlay']));
      expect(world.gameState, isNotNull);
    });

    test('login assigns correct player IDs and names', () {
      LuminaPlayerState.resetPlayerIdCounterForTesting();
      final mode = LuminaGameMode();
      final world = LuminaWorld();
      world.gameMode = mode;
      world.persistentLevel.registerActor(LuminaPlayerStart());
      mode.initGame(world);
      
      final c1 = mode.login(playerName: 'A');
      final c2 = mode.login(playerName: 'B');
      
      expect(c1.playerState.playerId, equals(0));
      expect(c2.playerState.playerId, equals(1));
      
      expect(c1.playerState.playerName, equals('A'));
      expect(c2.playerState.playerName, equals('B'));
      
      expect(mode.gameState.playerArray.length, equals(2));
      expect(mode.gameState.playerArray[0], equals(c1.playerState));
      expect(mode.gameState.playerArray[1], equals(c2.playerState));
    });

    test('login spawns and possesses default pawn', () {
      final mode = LuminaGameMode(
        defaultPawnFactory: () => TestPawn(),
      );
      final world = LuminaWorld();
      world.gameMode = mode;
      world.persistentLevel.registerActor(LuminaPlayerStart());
      mode.initGame(world);
      
      final controller = mode.login();
      final pawn = controller.pawn;
      
      expect(pawn, isA<TestPawn>());
      expect(pawn!.controller, equals(controller));
    });

    test('findPlayerStart places pawn correctly', () {
      final mode = LuminaGameMode();
      final world = LuminaWorld();
      world.gameMode = mode;
      
      final start1 = LuminaPlayerStart(playerStartTag: 'blue');
      start1.actorLocation.setValues(10, 0, 0);
      world.persistentLevel.registerActor(start1);

      final start2 = LuminaPlayerStart(playerStartTag: 'red');
      start2.actorLocation.setValues(0, 20, 0);
      world.persistentLevel.registerActor(start2);

      mode.initGame(world);
      
      final controller = mode.login(); // will use first unoccupied (start1) without tag
      expect(controller.pawn!.actorLocation, equals(Vector3(10, 0, 0)));

      final controller2 = mode.login(); // will also use start1 since we don't have collision yet to mark it occupied
      
      // But if we restart with tag 'red'
      mode.restartPlayer(controller2, tag: 'red');
      expect(controller2.pawn!.actorLocation, equals(Vector3(0, 20, 0)));
    });

    test('a level with zero Player Starts does not spawn the player', () {
      final mode = LuminaGameMode(defaultPawnFactory: () => TestPawn());
      final world = LuminaWorld();
      world.gameMode = mode;
      mode.initGame(world);

      final controller = mode.login();
      expect(controller.pawn, isNull);
      expect(world.actors.whereType<TestPawn>(), isEmpty);

      // Placing a Player Start and restarting spawns the pawn there.
      final start = LuminaPlayerStart();
      start.actorLocation.setValues(5, 6, 7);
      world.persistentLevel.registerActor(start);
      mode.restartPlayer(controller);
      expect(controller.pawn, isA<TestPawn>());
      expect(controller.pawn!.actorLocation, equals(Vector3(5, 6, 7)));
    });

    test('spawnWithoutPlayerStart keeps the origin fallback', () {
      final mode = LuminaGameMode(spawnWithoutPlayerStart: true);
      final world = LuminaWorld();
      world.gameMode = mode;
      mode.initGame(world);

      final controller = mode.login();
      expect(controller.pawn!.actorLocation, equals(Vector3.zero()));
    });

    test('restartPlayer destroys old pawn', () {
      final mode = LuminaGameMode();
      final world = LuminaWorld();
      world.gameMode = mode;
      world.persistentLevel.registerActor(LuminaPlayerStart());
      mode.initGame(world);
      
      final controller = mode.login();
      final oldPawn = controller.pawn!;
      
      expect(oldPawn, isNotNull);
      
      mode.restartPlayer(controller);
      final newPawn = controller.pawn!;
      
      expect(newPawn, isNot(equals(oldPawn)));
      expect(oldPawn.controller, isNull); // unpossessed
      
      expect(world.debugActiveDestroyBuffer, contains(oldPawn)); // scheduled for destroy
    });

    test('canRestartPlayer false prevents spawn', () {
      final mode = LuminaGameMode(
        canRestartPlayer: (c) => false,
      );
      final world = LuminaWorld();
      world.gameMode = mode;
      world.persistentLevel.registerActor(LuminaPlayerStart());
      mode.initGame(world);
      
      final controller = mode.login();
      expect(controller.pawn, isNull);
    });

    test('startMatch and endMatch state machine', () {
      final mode = LuminaGameMode();
      final world = LuminaWorld();
      world.gameMode = mode;
      mode.initGame(world);
      
      expect(mode.hasMatchStarted, isFalse);
      
      mode.startMatch();
      expect(mode.hasMatchStarted, isTrue);
      expect(mode.gameState.matchState, equals(LuminaMatchState.inProgress));
      
      // Idempotent
      mode.startMatch();
      expect(mode.gameState.matchState, equals(LuminaMatchState.inProgress));

      mode.endMatch();
      expect(mode.hasMatchEnded, isTrue);
      expect(mode.gameState.matchState, equals(LuminaMatchState.waitingPostMatch));
    });

    test('logout destroys pawn and removes state', () {
      LuminaPlayerState.resetPlayerIdCounterForTesting();
      final mode = LuminaGameMode();
      final world = LuminaWorld();
      world.gameMode = mode;
      world.persistentLevel.registerActor(LuminaPlayerStart());
      mode.initGame(world);
      
      final controller = mode.login();
      final pawn = controller.pawn!;
      final state = controller.playerState;
      
      expect(mode.gameState.playerArray, contains(state));
      expect(pawn.controller, equals(controller));
      
      mode.logout(controller);
      
      expect(pawn.controller, isNull);
      expect(controller.pawn, isNull);
      expect(mode.gameState.playerArray, isNot(contains(state)));
      expect(world.debugActiveDestroyBuffer, contains(pawn));
    });

    test('login pipeline order', () {
      final log = <String>[];
      final mode = OrderRecordingGameMode(log);
      final world = LuminaWorld();
      world.gameMode = mode;
      world.persistentLevel.registerActor(LuminaPlayerStart());
      mode.initGame(world);
      
      log.clear(); // Clear initGame from log
      mode.login();
      
      expect(log, equals(['handleStartingNewPlayer', 'findPlayerStart']));
    });
  });
}
