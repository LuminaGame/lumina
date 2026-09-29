import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import '../controller/controller.dart';
import '../object/actor.dart';
import '../object/pawn.dart';
import 'navigation_system.dart';

/// Result of issuing a path following or moveTo request.
enum PathFollowingRequestResult {
  failed,
  alreadyAtGoal,
  requestSuccessful,
}

/// Current state of the AI path following execution.
enum PathFollowingStatus {
  idle,
  waiting,
  moving,
  paused,
}

/// Final completion status of a path following move request.
enum PathFollowingResult {
  success,
  blocked,
  offPath,
  aborted,
  invalid,
}

/// Focus priority level for AI gaze and orientation targeting.
enum FocusPriority {
  defaultFocus,
  move,
  gameplay,
}

/// Non-player counterpart of [LuminaPlayerController] that possesses a [LuminaPawn],
/// executes path-following move requests, and manages a prioritized focus orientation stack.
class LuminaAIController extends LuminaController {
  PathFollowingStatus _status = PathFollowingStatus.idle;
  List<Vector3> _currentPath = [];
  int _currentWaypointIndex = 0;
  double _acceptanceRadius = 50.0; // cm

  LuminaActor? _goalActor;
  Vector3? _lastGoalActorLocation;
  double repathDistanceThreshold = 100.0; // cm

  void Function(PathFollowingResult result)? onMoveCompleted;

  // Focus Priority Stack
  final Map<FocusPriority, dynamic> _focusStack = {};

  PathFollowingStatus get moveStatus => _status;
  List<Vector3> get currentPath => List.unmodifiable(_currentPath);

  /// Requests the controller to move its possessed pawn to [goal].
  PathFollowingRequestResult moveToLocation(
    Vector3 goal, {
    double acceptanceRadius = 50.0,
    bool usePathfinding = true,
    bool allowPartialPath = true,
  }) {
    _goalActor = null;
    _lastGoalActorLocation = null;
    return _startMove(
      goal,
      acceptanceRadius: acceptanceRadius,
      usePathfinding: usePathfinding,
      allowPartialPath: allowPartialPath,
    );
  }

  /// Requests the controller to continuously move towards and follow [goal].
  PathFollowingRequestResult moveToActor(
    LuminaActor goal, {
    double acceptanceRadius = 50.0,
    bool usePathfinding = true,
  }) {
    if (pawn == null) return PathFollowingRequestResult.failed;
    _goalActor = goal;
    _lastGoalActorLocation = goal.actorLocation.clone();
    return _startMove(
      goal.actorLocation,
      acceptanceRadius: acceptanceRadius,
      usePathfinding: usePathfinding,
    );
  }

  PathFollowingRequestResult _startMove(
    Vector3 goal, {
    double acceptanceRadius = 50.0,
    bool usePathfinding = true,
    bool allowPartialPath = true,
  }) {
    if (pawn == null) return PathFollowingRequestResult.failed;
    _acceptanceRadius = acceptanceRadius;

    final start = pawn!.actorLocation;
    final horizDist = math.sqrt(
      (start.x - goal.x) * (start.x - goal.x) + (start.z - goal.z) * (start.z - goal.z),
    );

    if (horizDist <= acceptanceRadius) {
      stopMovement();
      return PathFollowingRequestResult.alreadyAtGoal;
    }

    if (usePathfinding && pawn?.world != null) {
      final navSys = pawn!.world!.subsystems.getSubsystem<LuminaNavigationSystem>();
      if (navSys != null && navSys.isBuilt) {
        final path = navSys.findPathSync(start, goal, allowPartialPath: allowPartialPath);
        if (path != null && path.points.isNotEmpty) {
          _currentPath = path.points.length > 1 ? path.points.skip(1).toList() : [goal.clone()];
          _currentWaypointIndex = 0;
          _status = PathFollowingStatus.moving;
          return PathFollowingRequestResult.requestSuccessful;
        }
      }
    }

    _currentPath = [goal.clone()];
    _currentWaypointIndex = 0;
    _status = PathFollowingStatus.moving;

    return PathFollowingRequestResult.requestSuccessful;
  }

  /// Aborts active movement and transitions status back to idle.
  void stopMovement() {
    if (_status != PathFollowingStatus.idle) {
      _status = PathFollowingStatus.idle;
      _currentPath = [];
      _currentWaypointIndex = 0;
      _goalActor = null;
      _lastGoalActorLocation = null;
      onMoveCompleted?.call(PathFollowingResult.aborted);
    } else {
      _currentPath = [];
      _currentWaypointIndex = 0;
      _goalActor = null;
      _lastGoalActorLocation = null;
    }
  }

  /// Pauses the active path following.
  void pauseMove() {
    if (_status == PathFollowingStatus.moving) {
      _status = PathFollowingStatus.paused;
    }
  }

  /// Resumes paused path following.
  void resumeMove() {
    if (_status == PathFollowingStatus.paused) {
      _status = PathFollowingStatus.moving;
    }
  }

  /// Sets an actor as the focus target at [priority].
  void setFocus(LuminaActor actor, {FocusPriority priority = FocusPriority.gameplay}) {
    _focusStack[priority] = actor;
  }

  /// Sets a static point in space as the focal point at [priority].
  void setFocalPoint(Vector3 point, {FocusPriority priority = FocusPriority.gameplay}) {
    _focusStack[priority] = point.clone();
  }

  /// Clears the focus setting at [priority].
  void clearFocus(FocusPriority priority) {
    _focusStack.remove(priority);
  }

  /// Evaluates the highest priority focus and returns the 3D world focal coordinate.
  Vector3? get focalPoint {
    const priorities = [FocusPriority.gameplay, FocusPriority.move, FocusPriority.defaultFocus];
    for (final p in priorities) {
      final target = _focusStack[p];
      if (target != null) {
        if (target is LuminaActor) {
          return target.actorLocation;
        } else if (target is Vector3) {
          return target;
        }
      }
    }
    return null;
  }

  @override
  void onTick(double deltaTime) {
    if (pawn == null) return;
    final currentPawn = pawn!;

    // 1. Repath if following dynamic actor
    if (_goalActor != null && _status == PathFollowingStatus.moving) {
      final curGoalLoc = _goalActor!.actorLocation;
      if (_lastGoalActorLocation != null) {
        final distMoved = (_lastGoalActorLocation! - curGoalLoc).length;
        if (distMoved >= repathDistanceThreshold) {
          _lastGoalActorLocation = curGoalLoc.clone();
          _currentPath = [curGoalLoc.clone()];
          _currentWaypointIndex = 0;
        }
      }
    }

    // 2. Path following logic
    if (_status == PathFollowingStatus.moving && _currentPath.isNotEmpty) {
      if (_currentWaypointIndex < _currentPath.length) {
        final waypoint = _currentPath[_currentWaypointIndex];
        final pawnLoc = currentPawn.actorLocation;

        final dx = waypoint.x - pawnLoc.x;
        final dz = waypoint.z - pawnLoc.z;
        final horizDist = math.sqrt(dx * dx + dz * dz);

        if (horizDist <= _acceptanceRadius) {
          _currentWaypointIndex++;
          if (_currentWaypointIndex >= _currentPath.length) {
            // Reached goal!
            _status = PathFollowingStatus.idle;
            _currentPath = [];
            _currentWaypointIndex = 0;
            _goalActor = null;
            _lastGoalActorLocation = null;
            onMoveCompleted?.call(PathFollowingResult.success);
          }
        } else {
          // Steer towards current waypoint
          final dir = Vector3(dx, 0.0, dz);
          if (dir.length > 1e-6) {
            dir.normalize();
            currentPawn.addMovementInput(dir, 1.0);
          }
        }
      }
    }

    // 3. Orientation & Control Rotation update: face the focus, then turn
    // the pawn with it.
    final focus = focalPoint;
    if (focus != null) {
      final pawnLoc = currentPawn.actorLocation;
      final dx = focus.x - pawnLoc.x;
      final dz = focus.z - pawnLoc.z;
      if (dx * dx + dz * dz > 1e-12) {
        // The player controller's convention: degrees, yaw 0
        // facing −Z, positive yaw turning right towards +X — what
        // LuminaPawn.faceRotation, the camera and onMove read.
        final yaw = math.atan2(dx, -dz) * 180.0 / math.pi;
        controlRotation = Vector3(controlRotation.x, yaw, controlRotation.z);
      }
      currentPawn.faceRotation(controlRotation, deltaTime);
    }
  }

  @override
  void onUnpossess(LuminaPawn pawn) {
    stopMovement();
    _focusStack.clear();
    super.onUnpossess(pawn);
  }
}
