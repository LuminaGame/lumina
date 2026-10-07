import 'dart:async';
import 'dart:isolate';
import 'package:vector_math/vector_math_64.dart';
import 'package:lumina/src/world/level.dart';
import 'package:lumina/src/world/level_streaming.dart';
import 'package:lumina/src/world/level_streaming_volume.dart';
import 'package:lumina/src/world/subsystem/world_subsystem.dart';

/// Lightweight pure-data payload describing level actor descriptors parsed off the main thread.
class LuminaLevelPayload {
  final String levelPath;
  final List<Map<String, dynamic>> actorDescriptors;

  const LuminaLevelPayload({
    required this.levelPath,
    this.actorDescriptors = const [],
  });
}

/// A time-sliced task queue that limits per-frame execution to a configured duration budget.
class LuminaTimeSlicedWorkQueue {
  final List<void Function()> _steps = [];

  /// Number of pending work items.
  int get pendingCount => _steps.length;

  /// Enqueues tasks to be processed within per-frame time budgets.
  void enqueue(Iterable<void Function()> steps) {
    _steps.addAll(steps);
  }

  /// Processes queued tasks until [budget] is exhausted.
  void pump(Duration budget) {
    if (_steps.isEmpty) return;

    final stopwatch = Stopwatch()..start();
    while (_steps.isNotEmpty) {
      if (stopwatch.elapsed >= budget) break;
      final step = _steps.removeAt(0);
      step();
    }
  }
}

class _RegisteredStreamingLevel {
  final LuminaLevelStreaming streaming;
  final Vector3 origin;
  bool isDistanceInside = false;

  _RegisteredStreamingLevel({
    required this.streaming,
    required this.origin,
  });
}

/// Subsystem managing sub-level streaming, spatial volume evaluation, distance policies,
/// double-buffered request dispatch, and time-sliced workload execution.
class LuminaLevelStreamingManager extends LuminaWorldSubsystem {
  double streamingDistance;
  Duration frameBudget;

  final LuminaTimeSlicedWorkQueue workQueue = LuminaTimeSlicedWorkQueue();

  final Map<String, _RegisteredStreamingLevel> _registeredLevels = {};
  final List<LuminaLevelStreamingVolume> _volumes = [];

  Vector3 _viewerPosition = Vector3.zero();

  List<void Function()> _bufferA = [];
  List<void Function()> _bufferB = [];
  bool _writingToA = true;

  LuminaLevelStreamingManager({
    this.streamingDistance = 50000.0, // cm
    this.frameBudget = const Duration(milliseconds: 4),
  });

  /// The active viewer position (e.g. camera / player pawn location).
  Vector3 get viewerPosition => _viewerPosition;

  /// Sets the primary viewer location for distance-based streaming evaluations.
  void setViewerPosition(Vector3 position) {
    _viewerPosition = position;
  }

  /// Registers a sub-level streaming handle with an optional spatial origin.
  void registerStreamingLevel(LuminaLevelStreaming level, {Vector3? levelOrigin}) {
    _registeredLevels[level.levelPath] = _RegisteredStreamingLevel(
      streaming: level,
      origin: levelOrigin ?? Vector3.zero(),
    );
  }

  /// Unregisters a sub-level streaming handle.
  void unregisterStreamingLevel(String levelPath) {
    _registeredLevels.remove(levelPath);
  }

  /// Finds a registered streaming level handle by its path/name.
  /// Every registered streaming level.
  List<LuminaLevelStreaming> get registeredLevels => [for (final r in _registeredLevels.values) r.streaming];

  LuminaLevelStreaming? findByName(String levelPath) {
    return _registeredLevels[levelPath]?.streaming;
  }

  /// Adds a streaming trigger volume.
  void addVolume(LuminaLevelStreamingVolume volume) {
    _volumes.add(volume);
  }

  /// Removes a streaming trigger volume.
  void removeVolume(LuminaLevelStreamingVolume volume) {
    _volumes.remove(volume);
  }

  /// Enqueues a streaming request into the current double-buffer.
  void enqueueRequest(void Function() request) {
    if (_writingToA) {
      _bufferA.add(request);
    } else {
      _bufferB.add(request);
    }
  }

  /// Swaps double buffers and dispatches requests collected from the previous tick.
  void processPendingRequests() {
    List<void Function()> toProcess;
    if (_writingToA) {
      toProcess = _bufferA;
      _bufferA = [];
      _writingToA = false;
    } else {
      toProcess = _bufferB;
      _bufferB = [];
      _writingToA = true;
    }

    for (final req in toProcess) {
      req();
    }
  }

  /// Dynamically creates, registers, and initiates loading for a streaming level.
  Future<LuminaLevel> loadLevelInstanceAsync(
    String levelPath, {
    Vector3? origin,
    bool visible = true,
  }) async {
    var registered = findByName(levelPath);
    if (registered == null) {
      final levelInstance = LuminaLevel();
      registered = LuminaLevelStreaming(
        levelPath: levelPath,
        levelInstance: levelInstance,
        bShouldBeLoaded: true,
        bShouldBeVisible: visible,
      );
      registerStreamingLevel(registered, levelOrigin: origin);
      if (world != null && !world!.streamingLevels.contains(levelInstance)) {
        world!.streamingLevels.add(levelInstance);
      }
    }

    registered.bShouldBeVisible = visible;
    await registered.loadLevelAsync();
    if (visible && registered.state != LevelState.visible) {
      await registered.setVisibleAsync(true);
    }
    return registered.levelInstance;
  }

  /// Decodes level data in a background Dart isolate.
  static Future<LuminaLevelPayload> parseLevelInIsolate(String levelPath) async {
    return Isolate.run(() {
      return LuminaLevelPayload(
        levelPath: levelPath,
        actorDescriptors: <Map<String, dynamic>>[],
      );
    });
  }

  @override
  void onWorldTick(double deltaTime) {
    super.onWorldTick(deltaTime);

    // 1. Time-slice pump
    workQueue.pump(frameBudget);

    // 2. Evaluate volumes against all registered world actors
    if (world != null) {
      final actors = world!.actors;
      for (final volume in _volumes) {
        for (final actor in actors) {
          volume.evaluatePawnPosition(actor, actor.actorLocation, deltaTime);
        }
      }
    }

    // 3. Collect active requested levels from volumes
    final volumeRequested = <String>{};
    for (final volume in _volumes) {
      volumeRequested.addAll(volume.requestedLevels);
    }

    // 4. Evaluate distance policy & manual intent per registered level
    for (final reg in _registeredLevels.values) {
      final level = reg.streaming;
      final distSq = (reg.origin - _viewerPosition).length2;
      final maxDist = streamingDistance;
      final unloadDist = streamingDistance * 1.1;

      if (!reg.isDistanceInside) {
        if (distSq <= maxDist * maxDist) {
          reg.isDistanceInside = true;
        }
      } else {
        if (distSq > unloadDist * unloadDist) {
          reg.isDistanceInside = false;
        }
      }

      final isWantedByDistance = !level.bDisableDistanceStreaming && reg.isDistanceInside;
      final isWantedByVolume = volumeRequested.contains(level.levelPath);
      final isWanted = isWantedByDistance || isWantedByVolume || level.bShouldBeLoaded;

      if (isWanted) {
        if (level.state == LevelState.unloaded && !level.isTransitioning) {
          enqueueRequest(() {
            level.bShouldBeVisible = true;
            level.loadLevelAsync();
          });
        } else if (level.state == LevelState.loaded && !level.isTransitioning && (isWantedByDistance || isWantedByVolume || level.bShouldBeVisible)) {
          enqueueRequest(() {
            level.setVisibleAsync(true);
          });
        }
      } else {
        if ((level.state == LevelState.visible || level.state == LevelState.loaded) && !level.isTransitioning) {
          enqueueRequest(() {
            level.unloadLevelAsync();
          });
        }
      }
    }

    // 5. Swap double buffers and process requests from previous tick
    processPendingRequests();
  }
}
