import 'dart:math' as math;
import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart';
import '../components/collision/collision_component.dart';
import '../world/subsystem/world_subsystem.dart';

/// Configuration properties for rasterizing a navigation grid and sizing agent clearances.
class NavGridConfig {
  final double cellSize;
  final double agentRadius;
  final double agentHeight;
  final double maxStepHeight;
  final int walkableLayerMask;

  const NavGridConfig({
    // World units (cm).
    this.cellSize = 50.0,
    this.agentRadius = 35.0,
    this.agentHeight = 180.0,
    this.maxStepHeight = 30.0,
    this.walkableLayerMask = 0xFFFFFFFF,
  });
}

/// A computed path across the navigation grid consisting of world-space waypoint coordinates.
class NavPath {
  final List<Vector3> points;
  final bool isPartial;

  NavPath({required this.points, this.isPartial = false});

  double get length {
    if (points.length < 2) return 0.0;
    double dist = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      dist += (points[i + 1] - points[i]).length;
    }
    return dist;
  }
}

/// World subsystem that turns collision geometry into an inflated walkable grid and performs fast A* pathfinding.
class LuminaNavigationSystem extends LuminaWorldSubsystem {
  Aabb3 _bounds = Aabb3();
  NavGridConfig _config = const NavGridConfig();
  int _cols = 0;
  int _rows = 0;
  Uint8List _grid = Uint8List(0); // 1 = walkable, 0 = blocked
  Float32List _floorHeights = Float32List(0);
  int _walkableCount = 0;
  bool _isBuilt = false;

  final List<Aabb3> _dirtyRegions = [];

  bool get isBuilt => _isBuilt;
  int get walkableCellCount => _walkableCount;
  NavGridConfig get config => _config;

  int _cellIndex(int col, int row) => row * _cols + col;

  int _worldToCol(double x) => ((x - _bounds.min.x) / _config.cellSize).floor();
  int _worldToRow(double z) => ((z - _bounds.min.z) / _config.cellSize).floor();
  double _colToWorldX(int col) => _bounds.min.x + (col + 0.5) * _config.cellSize;
  double _rowToWorldZ(int row) => _bounds.min.z + (row + 0.5) * _config.cellSize;

  bool _isValidCell(int col, int row) => col >= 0 && col < _cols && row >= 0 && row < _rows;

  /// Builds a uniform navigation grid by rasterizing collision components in the world within [bounds].
  void buildFromWorld({
    required Aabb3 bounds,
    NavGridConfig config = const NavGridConfig(),
  }) {
    _bounds = Aabb3.copy(bounds);
    _config = config;

    final width = _bounds.max.x - _bounds.min.x;
    final depth = _bounds.max.z - _bounds.min.z;

    _cols = (width / _config.cellSize).ceil();
    _rows = (depth / _config.cellSize).ceil();
    final totalCells = _cols * _rows;

    _grid = Uint8List(totalCells)..fillRange(0, totalCells, 1);
    _floorHeights = Float32List(totalCells)..fillRange(0, totalCells, _bounds.min.y);

    _rasterizeObstacles();

    _walkableCount = 0;
    for (int i = 0; i < totalCells; i++) {
      if (_grid[i] == 1) _walkableCount++;
    }
    _isBuilt = true;
  }

  void _rasterizeObstacles([Aabb3? region]) {
    final currentWorld = world;
    if (currentWorld == null) return;

    final queryLevels = [currentWorld.persistentLevel, ...currentWorld.streamingLevels];
    for (final level in queryLevels) {
      for (final actor in level.actors) {
        for (final comp in actor.components) {
          if (comp is LuminaCollisionComponent) {
            if (!comp.collisionEnabled) continue;
            final respPawn = comp.getResponse(CollisionObjectType.pawn);
            final respDyn = comp.getResponse(CollisionObjectType.worldDynamic);
            if (respPawn != CollisionResponse.block && respDyn != CollisionResponse.block) {
              continue; // Triggers don't block navigation
            }
            if ((comp.collisionLayer & _config.walkableLayerMask) == 0) continue;

            final aabb = comp.getAABB();
            if (region != null && !region.intersectsWithAabb3(aabb)) continue;

            // Inflate obstacle bounds by agentRadius
            final minX = aabb.min.x - _config.agentRadius;
            final maxX = aabb.max.x + _config.agentRadius;
            final minZ = aabb.min.z - _config.agentRadius;
            final maxZ = aabb.max.z + _config.agentRadius;

            final minCol = math.max(0, _worldToCol(minX));
            final maxCol = math.min(_cols - 1, _worldToCol(maxX));
            final minRow = math.max(0, _worldToRow(minZ));
            final maxRow = math.min(_rows - 1, _worldToRow(maxZ));

            for (int r = minRow; r <= maxRow; r++) {
              for (int c = minCol; c <= maxCol; c++) {
                _grid[_cellIndex(c, r)] = 0;
              }
            }
          }
        }
      }
    }
  }

  /// Returns true if [worldPoint] lies within the grid bounds and is marked walkable.
  bool isWalkable(Vector3 worldPoint) {
    if (!_isBuilt) return false;
    final c = _worldToCol(worldPoint.x);
    final r = _worldToRow(worldPoint.z);
    if (!_isValidCell(c, r)) return false;
    return _grid[_cellIndex(c, r)] == 1;
  }

  /// Projects [point] onto the nearest walkable cell center within [searchRadius].
  Vector3? projectPointToNavigation(Vector3 point, {double searchRadius = 200.0}) {
    if (!_isBuilt) return null;
    if (isWalkable(point)) {
      final c = _worldToCol(point.x);
      final r = _worldToRow(point.z);
      return Vector3(_colToWorldX(c), _floorHeights[_cellIndex(c, r)], _rowToWorldZ(r));
    }

    final startCol = _worldToCol(point.x);
    final startRow = _worldToRow(point.z);
    final maxRadiusCells = (searchRadius / _config.cellSize).ceil();

    Vector3? closest;
    double bestDistSq = double.infinity;

    for (int dr = -maxRadiusCells; dr <= maxRadiusCells; dr++) {
      for (int dc = -maxRadiusCells; dc <= maxRadiusCells; dc++) {
        final c = startCol + dc;
        final r = startRow + dr;
        if (!_isValidCell(c, r)) continue;
        if (_grid[_cellIndex(c, r)] == 1) {
          final pos = Vector3(_colToWorldX(c), _floorHeights[_cellIndex(c, r)], _rowToWorldZ(r));
          final distSq = (pos.x - point.x) * (pos.x - point.x) + (pos.z - point.z) * (pos.z - point.z);
          if (distSq <= searchRadius * searchRadius && distSq < bestDistSq) {
            bestDistSq = distSq;
            closest = pos;
          }
        }
      }
    }
    return closest;
  }

  /// Tests if a direct unobstructed line of walkability exists between [a] and [b] using supercover rasterization.
  bool hasDirectWalkableLine(Vector3 a, Vector3 b) {
    if (!_isBuilt) return false;

    int c0 = _worldToCol(a.x);
    int r0 = _worldToRow(a.z);
    int c1 = _worldToCol(b.x);
    int r1 = _worldToRow(b.z);

    if (!_isValidCell(c0, r0) || !_isValidCell(c1, r1)) return false;
    if (_grid[_cellIndex(c0, r0)] == 0 || _grid[_cellIndex(c1, r1)] == 0) return false;

    int dx = (c1 - c0).abs();
    int dz = (r1 - r0).abs();
    int c = c0;
    int r = r0;
    int n = 1 + dx + dz;
    int xInc = (c1 > c0) ? 1 : -1;
    int zInc = (r1 > r0) ? 1 : -1;
    int error = dx - dz;
    dx *= 2;
    dz *= 2;

    int lastC = c;
    int lastR = r;

    for (; n > 0; --n) {
      if (!_isValidCell(c, r) || _grid[_cellIndex(c, r)] == 0) return false;

      // Prevent corner cutting on diagonal steps
      if (c != lastC && r != lastR) {
        if (_grid[_cellIndex(c, lastR)] == 0 || _grid[_cellIndex(lastC, r)] == 0) {
          return false;
        }
      }

      lastC = c;
      lastR = r;

      if (error > 0) {
        c += xInc;
        error -= dz;
      } else if (error < 0) {
        r += zInc;
        error += dx;
      } else {
        // Line passes through exact vertex: step both ways
        c += xInc;
        r += zInc;
        error -= dz;
        error += dx;
        --n;
      }
    }
    return true;
  }

  /// Computes a path from [start] to [end] using A* pathfinding with octile heuristic and string pulling smoothing.
  NavPath? findPathSync(
    Vector3 start,
    Vector3 end, {
    bool allowPartialPath = true,
    bool smooth = true,
  }) {
    if (!_isBuilt) return null;

    final projStart = projectPointToNavigation(start);
    final projEnd = projectPointToNavigation(end);

    if (projStart == null) return null;
    if (projEnd == null && !allowPartialPath) return null;

    final startCol = _worldToCol(projStart.x);
    final startRow = _worldToRow(projStart.z);
    final goalCol = projEnd != null ? _worldToCol(projEnd.x) : _worldToCol(end.x);
    final goalRow = projEnd != null ? _worldToRow(projEnd.z) : _worldToRow(end.z);

    final startIdx = _cellIndex(startCol, startRow);
    final totalCells = _cols * _rows;

    final gScore = Float64List(totalCells)..fillRange(0, totalCells, double.infinity);
    final cameFrom = Int32List(totalCells)..fillRange(0, totalCells, -1);
    final closed = Uint8List(totalCells);

    // Min-Heap priority queue for A*
    final openSet = <int>[startIdx];
    final fScoreMap = <int, double>{startIdx: _octileHeuristic(startCol, startRow, goalCol, goalRow)};
    gScore[startIdx] = 0.0;

    int bestNodeIdx = startIdx;
    double bestHScore = _octileHeuristic(startCol, startRow, goalCol, goalRow);

    const sqrt2 = 1.41421356237;
    const dxDirs = [-1, 0, 1, -1, 1, -1, 0, 1];
    const dzDirs = [-1, -1, -1, 0, 0, 1, 1, 1];
    const moveCosts = [sqrt2, 1.0, sqrt2, 1.0, 1.0, sqrt2, 1.0, sqrt2];

    bool foundGoal = false;
    int goalNodeIdx = -1;

    while (openSet.isNotEmpty) {
      // Find lowest fScore in openSet
      int bestOpenIdx = 0;
      double lowestF = fScoreMap[openSet[0]] ?? double.infinity;
      for (int i = 1; i < openSet.length; i++) {
        final f = fScoreMap[openSet[i]] ?? double.infinity;
        if (f < lowestF) {
          lowestF = f;
          bestOpenIdx = i;
        }
      }

      final current = openSet.removeAt(bestOpenIdx);
      closed[current] = 1;

      final curCol = current % _cols;
      final curRow = current ~/ _cols;

      if (curCol == goalCol && curRow == goalRow) {
        foundGoal = true;
        goalNodeIdx = current;
        break;
      }

      // Track closest node for partial path
      final h = _octileHeuristic(curCol, curRow, goalCol, goalRow);
      if (h < bestHScore) {
        bestHScore = h;
        bestNodeIdx = current;
      }

      for (int i = 0; i < 8; i++) {
        final nc = curCol + dxDirs[i];
        final nr = curRow + dzDirs[i];
        if (!_isValidCell(nc, nr)) continue;

        final nIdx = _cellIndex(nc, nr);
        if (closed[nIdx] == 1) continue;
        if (_grid[nIdx] == 0) continue;

        // Diagonal corner cutting check
        if (dxDirs[i] != 0 && dzDirs[i] != 0) {
          if (_grid[_cellIndex(curCol + dxDirs[i], curRow)] == 0 ||
              _grid[_cellIndex(curCol, curRow + dzDirs[i])] == 0) {
            continue; // Orthogonal neighbor blocked, cannot step diagonally
          }
        }

        final tentativeG = gScore[current] + moveCosts[i] * _config.cellSize;
        if (tentativeG < gScore[nIdx]) {
          cameFrom[nIdx] = current;
          gScore[nIdx] = tentativeG;
          final f = tentativeG + _octileHeuristic(nc, nr, goalCol, goalRow);
          fScoreMap[nIdx] = f;
          if (!openSet.contains(nIdx)) {
            openSet.add(nIdx);
          }
        }
      }
    }

    if (!foundGoal) {
      if (!allowPartialPath || bestNodeIdx == startIdx) return null;
      goalNodeIdx = bestNodeIdx;
    }

    // Reconstruct path
    final rawPoints = <Vector3>[];
    int curr = goalNodeIdx;
    while (curr != -1) {
      final c = curr % _cols;
      final r = curr ~/ _cols;
      rawPoints.add(Vector3(_colToWorldX(c), _floorHeights[curr], _rowToWorldZ(r)));
      curr = cameFrom[curr];
    }
    final points = rawPoints.reversed.toList();

    // Replace start and end with precise project coordinates
    if (points.isNotEmpty) {
      points[0] = projStart;
      if (foundGoal && projEnd != null) {
        points[points.length - 1] = projEnd;
      }
    }

    // Path smoothing (string pulling)
    if (smooth && points.length > 2) {
      final smoothed = <Vector3>[points.first];
      int currentIndex = 0;
      while (currentIndex < points.length - 1) {
        int nextIndex = points.length - 1;
        for (; nextIndex > currentIndex + 1; nextIndex--) {
          if (hasDirectWalkableLine(points[currentIndex], points[nextIndex])) {
            break;
          }
        }
        smoothed.add(points[nextIndex]);
        currentIndex = nextIndex;
      }
      return NavPath(points: smoothed, isPartial: !foundGoal);
    }

    return NavPath(points: points, isPartial: !foundGoal);
  }

  double _octileHeuristic(int c1, int r1, int c2, int r2) {
    final dx = (c1 - c2).abs();
    final dz = (r1 - r2).abs();
    const sqrt2 = 1.41421356237;
    return (math.max(dx, dz) + (sqrt2 - 1.0) * math.min(dx, dz)) * _config.cellSize;
  }

  /// Marks a bounding region as dirty for incremental re-rasterization.
  void markDirty(Aabb3 region) {
    _dirtyRegions.add(Aabb3.copy(region));
  }

  /// Rebuilds all marked dirty regions immediately.
  void rebuildDirty() {
    for (final r in _dirtyRegions) {
      _rasterizeObstacles(r);
    }
    _dirtyRegions.clear();
  }

  @override
  void onWorldTick(double deltaTime) {
    if (_dirtyRegions.isNotEmpty) {
      final region = _dirtyRegions.removeAt(0);
      _rasterizeObstacles(region);
    }
  }
}
