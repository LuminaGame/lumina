import '../object/actor.dart';
import '../object/pawn.dart';
import '../controller/player_controller.dart';
import '../controller/player_state.dart';
import '../world/world.dart';
import '../math/transform_snapshot.dart';
import 'game_state.dart';
import 'player_start.dart';
import 'dart:developer' as developer;

import 'package:vector_math/vector_math_64.dart';

/// Defines the rules of a running world.
class LuminaGameMode {
  /// Factory for creating the default pawn. Settable, so the project's Maps &
  /// Modes Default Pawn Class can override the mode's own.
  LuminaPawn Function() defaultPawnFactory;

  /// Spawn the pawn at the origin when the level has no Player Start.
  /// Off by default: the player is only spawned at a Player Start.
  bool spawnWithoutPlayerStart;

  /// Factory for creating the player controller.
  final LuminaPlayerController Function() playerControllerFactory;

  /// Factory for creating the game state.
  final LuminaGameState Function() gameStateFactory;

  /// Factory for creating the player state.
  final LuminaPlayerState Function() playerStateFactory;

  /// Hook to determine if a player can be restarted.
  final bool Function(LuminaPlayerController controller) canRestartPlayerHook;

  LuminaGameState? _gameState;
  LuminaWorld? _world;

  LuminaGameMode({
    LuminaPawn Function()? defaultPawnFactory,
    this.spawnWithoutPlayerStart = false,
    LuminaPlayerController Function()? playerControllerFactory,
    LuminaGameState Function()? gameStateFactory,
    LuminaPlayerState Function()? playerStateFactory,
    bool Function(LuminaPlayerController controller)? canRestartPlayer,
  })  : defaultPawnFactory = defaultPawnFactory ?? (() => LuminaPawn()),
        gameStateFactory = gameStateFactory ?? (() => LuminaGameState()),
        playerStateFactory = playerStateFactory ?? (() => LuminaPlayerState()),
        canRestartPlayerHook = canRestartPlayer ?? ((_) => true),
        playerControllerFactory = playerControllerFactory ?? (() => LuminaPlayerController(
          playerState: playerStateFactory != null ? playerStateFactory() : LuminaPlayerState()
        ));

  /// The game state for this mode. Available after [initGame].
  LuminaGameState get gameState {
    if (_gameState == null) {
      throw StateError('gameState accessed before initGame() was called');
    }
    return _gameState!;
  }

  /// Whether the match has started.
  bool get hasMatchStarted => _gameState?.hasMatchStarted ?? false;

  /// Whether the match has ended.
  bool get hasMatchEnded => _gameState?.hasMatchEnded ?? false;

  /// Called once before any actor onBeginPlay. Creates the game state.
  void initGame(LuminaWorld world) {
    _world = world;
    _gameState = gameStateFactory();
  }

  /// Logs in a player, creates a controller and player state, and adds to game state.
  LuminaPlayerController login({String playerName = 'Player'}) {
    final controller = playerControllerFactory();
    controller.playerState.playerName = playerName;

    gameState.addPlayerState(controller.playerState);
    handleStartingNewPlayer(controller);
    // PostLogin: the level scripts hear the player has arrived.
    _world?.notifyPostLogin(controller);

    return controller;
  }

  /// Unpossesses and destroys the pawn, and removes player state from game state.
  void logout(LuminaPlayerController controller) {
    final pawn = controller.pawn;
    controller.unpossess();
    
    if (pawn != null && _world != null) {
      _world!.destroyActor(pawn);
    }
    
    gameState.removePlayerState(controller.playerState);
    _world?.notifyLogout(controller);
  }

  /// Called after login to start a new player. Default implementation calls restartPlayer.
  void handleStartingNewPlayer(LuminaPlayerController controller) {
    restartPlayer(controller);
  }

  /// Restarts the player at a player start.
  void restartPlayer(LuminaPlayerController controller, {String? tag}) {
    if (!canRestartPlayer(controller)) return;

    if (_world == null) {
      throw StateError('Cannot restart player before initGame is called');
    }

    if (!spawnWithoutPlayerStart && !hasPlayerStart(tag: tag)) {
      // Rather than spawn at the origin with a warning, Lumina leaves the player
      // unspawned: a level with no Player
      // Start is not playable, and an origin pawn with its HUD is misleading.
      developer.log(
        'No Player Start${tag == null ? '' : " tagged '$tag'"} in the level; the player is not spawned.',
        name: 'GameMode',
        level: 900,
      );
      return;
    }

    final oldPawn = controller.pawn;
    if (oldPawn != null) {
      controller.unpossess();
      _world!.destroyActor(oldPawn);
    }

    final start = findPlayerStart(controller, tag: tag);
    
    final newPawn = defaultPawnFactory();
    newPawn.actorLocation.setFrom(start.location);
    newPawn.actorRotation.setFrom(start.rotation);

    _world!.spawnActor(newPawn);
    
    // Possess immediately. Position applies at registration in world tick phase 1.
    controller.possess(newPawn);
  }

  /// Determines if the player can be restarted.
  bool canRestartPlayer(LuminaPlayerController controller) {
    return canRestartPlayerHook(controller);
  }

  /// Whether the world holds a [LuminaPlayerStart] (with [tag] when given).
  bool hasPlayerStart({String? tag}) {
    if (_world == null) return false;
    Iterable<LuminaActor> actors = _world!.persistentLevel.actors;
    for (final level in _world!.streamingLevels) {
      actors = actors.followedBy(level.actors);
    }
    for (final actor in actors) {
      if (actor is LuminaPlayerStart && (tag == null || actor.playerStartTag == tag)) return true;
    }
    return false;
  }

  /// Finds a suitable start location for the player.
  LuminaTransformSnapshot findPlayerStart(LuminaPlayerController controller, {String? tag}) {
    if (_world == null) return LuminaTransformSnapshot.zero();

    LuminaPlayerStart? firstStart;

    // Iterate through persistent level actors
    for (final actor in _world!.persistentLevel.actors) {
      if (actor is LuminaPlayerStart) {
        firstStart ??= actor;
        if (tag != null && actor.playerStartTag == tag) {
          return LuminaTransformSnapshot(
            location: Vector3.copy(actor.actorLocation),
            rotation: Quaternion.copy(actor.actorRotation),
          );
        }
      }
    }

    // Iterate through streaming levels
    for (final level in _world!.streamingLevels) {
      for (final actor in level.actors) {
        if (actor is LuminaPlayerStart) {
          firstStart ??= actor;
          if (tag != null && actor.playerStartTag == tag) {
            return LuminaTransformSnapshot(
              location: Vector3.copy(actor.actorLocation),
              rotation: Quaternion.copy(actor.actorRotation),
            );
          }
        }
      }
    }

    if (firstStart != null) {
      return LuminaTransformSnapshot(
        location: Vector3.copy(firstStart.actorLocation),
        rotation: Quaternion.copy(firstStart.actorRotation),
      );
    }

    return LuminaTransformSnapshot.zero();
  }

  /// Starts the match.
  void startMatch() {
    gameState.setMatchState(LuminaMatchState.inProgress);
  }

  /// Ends the match.
  void endMatch() {
    gameState.setMatchState(LuminaMatchState.waitingPostMatch);
  }
}
