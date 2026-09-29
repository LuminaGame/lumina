import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';
import 'animation_clip.dart';

/// Single scatter point sample mapping an animation clip to 1D or 2D parameter space coordinates.
class BlendSample {
  final LuminaAnimationClip clip;
  final double x;
  final double y;

  const BlendSample(this.clip, this.x, [this.y = 0.0]);
}

/// 1D Parametric blend space interpolating along a single continuous axis (e.g. Speed).
class LuminaBlendSpace1D implements AnimPoseSource {
  final List<BlendSample> _samples;
  final double minAxis;
  final double maxAxis;
  final double interpolationTime;

  double _targetParameter = 0.0;
  double _currentParameter = 0.0;
  double _normalizedPhase = 0.0;
  double _phaseDuration = 1.0;
  final List<double> _sampleWeights;

  LuminaBlendSpace1D({
    required List<BlendSample> samples,
    required this.minAxis,
    required this.maxAxis,
    this.interpolationTime = 0.0,
  })  : _samples = List.of(samples),
        _sampleWeights = List.filled(samples.length, 0.0) {
    if (samples.isEmpty) {
      throw ArgumentError('BlendSpace1D requires at least 1 sample');
    }
    if (minAxis >= maxAxis) {
      throw ArgumentError('minAxis ($minAxis) must be strictly less than maxAxis ($maxAxis)');
    }

    _samples.sort((a, b) => a.x.compareTo(b.x));

    for (int i = 0; i < _samples.length - 1; i++) {
      if ((_samples[i].x - _samples[i + 1].x).abs() < 1e-7) {
        throw ArgumentError('Duplicate sample x position: ${_samples[i].x}');
      }
    }

    _currentParameter = _samples.first.x.clamp(minAxis, maxAxis);
    _targetParameter = _currentParameter;
    _computeWeights();
  }

  List<BlendSample> get samples => _samples;
  List<double> get sampleWeights => _sampleWeights;
  double get currentParameter => _currentParameter;
  double get normalizedPhase => _normalizedPhase;

  @override
  double get phaseDuration => _phaseDuration;

  @override
  double get duration => _phaseDuration;

  /// Sets the raw target parameter along the 1D axis.
  void setParameter(double x) {
    _targetParameter = x.clamp(minAxis, maxAxis);
  }

  void _computeWeights() {
    for (int i = 0; i < _sampleWeights.length; i++) {
      _sampleWeights[i] = 0.0;
    }

    if (_samples.length == 1) {
      _sampleWeights[0] = 1.0;
    } else if (_currentParameter <= _samples.first.x) {
      _sampleWeights[0] = 1.0;
    } else if (_currentParameter >= _samples.last.x) {
      _sampleWeights[_samples.length - 1] = 1.0;
    } else {
      for (int i = 0; i < _samples.length - 1; i++) {
        final x0 = _samples[i].x;
        final x1 = _samples[i + 1].x;
        if (_currentParameter >= x0 && _currentParameter <= x1) {
          final span = x1 - x0;
          final t = span > 1e-8 ? (_currentParameter - x0) / span : 0.0;
          _sampleWeights[i] = 1.0 - t;
          _sampleWeights[i + 1] = t;
          break;
        }
      }
    }

    double totalDur = 0.0;
    for (int i = 0; i < _samples.length; i++) {
      totalDur += _sampleWeights[i] * _samples[i].clip.duration;
    }
    _phaseDuration = totalDur > 1e-6 ? totalDur : 1.0;
  }

  @override
  void advance(double deltaTime) {
    if (interpolationTime > 0.0 && deltaTime > 0.0) {
      final step = math.min(1.0, deltaTime / interpolationTime);
      _currentParameter += (_targetParameter - _currentParameter) * step;
    } else {
      _currentParameter = _targetParameter;
    }

    _computeWeights();

    if (_phaseDuration > 1e-8 && deltaTime > 0.0) {
      _normalizedPhase = (_normalizedPhase + deltaTime / _phaseDuration) % 1.0;
      if (_normalizedPhase < 0.0) _normalizedPhase += 1.0;
    }
  }

  @override
  void samplePhase(
    double normalizedPhase,
    List<Matrix4> outLocalPose, {
    double weight = 1.0,
  }) {
    double accumulatedWeight = 0.0;
    for (int i = 0; i < _samples.length; i++) {
      final w = _sampleWeights[i];
      if (w <= 0.0) continue;

      if (accumulatedWeight <= 0.0) {
        _samples[i].clip.samplePose(
          normalizedPhase * _samples[i].clip.duration,
          outLocalPose,
          looping: true,
          weight: weight,
        );
        accumulatedWeight = w;
      } else {
        final blendFraction = w / (accumulatedWeight + w);
        _samples[i].clip.samplePose(
          normalizedPhase * _samples[i].clip.duration,
          outLocalPose,
          looping: true,
          weight: blendFraction * weight,
        );
        accumulatedWeight += w;
      }
    }
  }

  @override
  void samplePose(
    double time,
    List<Matrix4> outLocalPose, {
    bool looping = true,
    double weight = 1.0,
  }) {
    final p = _phaseDuration > 1e-8 ? (time / _phaseDuration) % 1.0 : 0.0;
    samplePhase(p, outLocalPose, weight: weight);
  }
}

class _GridVertexWeights {
  final List<int> sampleIndices;
  final List<double> weights;

  _GridVertexWeights(this.sampleIndices, this.weights);
}

/// 2D Parametric blend space interpolating along a continuous 2D plane (e.g. Direction, Speed).
class LuminaBlendSpace2D implements AnimPoseSource {
  final List<BlendSample> _samples;
  final Vector2 minAxis;
  final Vector2 maxAxis;
  final int gridDivisionsX;
  final int gridDivisionsY;
  final double interpolationTime;

  Vector2 _targetParameter;
  Vector2 _currentParameter;
  double _normalizedPhase = 0.0;
  double _phaseDuration = 1.0;
  final List<double> _sampleWeights;
  late final List<_GridVertexWeights> _bakedGrid;

  LuminaBlendSpace2D({
    required List<BlendSample> samples,
    required this.minAxis,
    required this.maxAxis,
    this.gridDivisionsX = 8,
    this.gridDivisionsY = 8,
    this.interpolationTime = 0.0,
  })  : _samples = List.of(samples),
        _sampleWeights = List.filled(samples.length, 0.0),
        _targetParameter = Vector2(samples.first.x, samples.first.y),
        _currentParameter = Vector2(samples.first.x, samples.first.y) {
    if (samples.isEmpty) {
      throw ArgumentError('BlendSpace2D requires at least 1 sample');
    }
    if (minAxis.x >= maxAxis.x || minAxis.y >= maxAxis.y) {
      throw ArgumentError('minAxis ($minAxis) must be strictly less than maxAxis ($maxAxis)');
    }

    _bakeGrid();
    _computeWeights();
  }

  List<BlendSample> get samples => _samples;
  List<double> get sampleWeights => _sampleWeights;
  Vector2 get currentParameter => _currentParameter;
  double get normalizedPhase => _normalizedPhase;

  @override
  double get phaseDuration => _phaseDuration;

  @override
  double get duration => _phaseDuration;

  void _bakeGrid() {
    final cols = gridDivisionsX + 1;
    final rows = gridDivisionsY + 1;
    final stepX = (maxAxis.x - minAxis.x) / gridDivisionsX;
    final stepY = (maxAxis.y - minAxis.y) / gridDivisionsY;

    _bakedGrid = List.generate(cols * rows, (index) {
      final gx = index % cols;
      final gy = index ~/ cols;
      final px = minAxis.x + gx * stepX;
      final py = minAxis.y + gy * stepY;

      // 1. Exact match test
      for (int s = 0; s < _samples.length; s++) {
        final dx = _samples[s].x - px;
        final dy = _samples[s].y - py;
        if (dx * dx + dy * dy < 1e-8) {
          return _GridVertexWeights([s], [1.0]);
        }
      }

      // 2. Boundary segment match test (samples share same x or same y)
      for (int a = 0; a < _samples.length; a++) {
        for (int b = a + 1; b < _samples.length; b++) {
          if ((_samples[a].x - _samples[b].x).abs() > 1e-6 && (_samples[a].y - _samples[b].y).abs() > 1e-6) {
            continue; // Ignore diagonal interior lines
          }
          final da = math.sqrt((_samples[a].x - px) * (_samples[a].x - px) + (_samples[a].y - py) * (_samples[a].y - py));
          final db = math.sqrt((_samples[b].x - px) * (_samples[b].x - px) + (_samples[b].y - py) * (_samples[b].y - py));
          final dab = math.sqrt((_samples[a].x - _samples[b].x) * (_samples[a].x - _samples[b].x) + (_samples[a].y - _samples[b].y) * (_samples[a].y - _samples[b].y));
          if (dab > 1e-6 && (da + db - dab).abs() < 1e-5) {
            final wa = db / dab;
            final wb = da / dab;
            return _GridVertexWeights([a, b], [wa, wb]);
          }
        }
      }

      // 3. Compute distances to all samples
      final distances = <({int index, double dist})>[];
      for (int s = 0; s < _samples.length; s++) {
        final dx = _samples[s].x - px;
        final dy = _samples[s].y - py;
        distances.add((index: s, dist: math.sqrt(dx * dx + dy * dy)));
      }
      distances.sort((a, b) => a.dist.compareTo(b.dist));

      // Take nearest (including ties)
      int count = math.min(3, distances.length);
      final maxDist = distances[count - 1].dist;
      while (count < distances.length && (distances[count].dist - maxDist).abs() < 1e-6) {
        count++;
      }
      final chosen = distances.sublist(0, count);

      double sumInv = 0.0;
      for (final c in chosen) {
        sumInv += 1.0 / c.dist;
      }

      final indices = <int>[];
      final weights = <double>[];
      for (final c in chosen) {
        indices.add(c.index);
        weights.add((1.0 / c.dist) / sumInv);
      }

      return _GridVertexWeights(indices, weights);
    });
  }

  /// Sets raw 2D target parameters (e.g. direction, speed).
  void setParameters(double x, double y) {
    _targetParameter.x = x.clamp(minAxis.x, maxAxis.x);
    _targetParameter.y = y.clamp(minAxis.y, maxAxis.y);
  }

  void _computeWeights() {
    for (int i = 0; i < _sampleWeights.length; i++) {
      _sampleWeights[i] = 0.0;
    }

    final spanX = maxAxis.x - minAxis.x;
    final spanY = maxAxis.y - minAxis.y;

    final normX = spanX > 1e-8 ? ((_currentParameter.x - minAxis.x) / spanX).clamp(0.0, 1.0) : 0.0;
    final normY = spanY > 1e-8 ? ((_currentParameter.y - minAxis.y) / spanY).clamp(0.0, 1.0) : 0.0;

    final gxFloat = normX * gridDivisionsX;
    final gyFloat = normY * gridDivisionsY;

    final gx0 = math.min(gxFloat.floor(), gridDivisionsX - 1);
    final gy0 = math.min(gyFloat.floor(), gridDivisionsY - 1);
    final gx1 = gx0 + 1;
    final gy1 = gy0 + 1;

    final tx = (gxFloat - gx0).clamp(0.0, 1.0);
    final ty = (gyFloat - gy0).clamp(0.0, 1.0);

    final cols = gridDivisionsX + 1;
    final v00 = _bakedGrid[gy0 * cols + gx0];
    final v10 = _bakedGrid[gy0 * cols + gx1];
    final v01 = _bakedGrid[gy1 * cols + gx0];
    final v11 = _bakedGrid[gy1 * cols + gx1];

    final b00 = (1.0 - tx) * (1.0 - ty);
    final b10 = tx * (1.0 - ty);
    final b01 = (1.0 - tx) * ty;
    final b11 = tx * ty;

    void accumulate(_GridVertexWeights v, double factor) {
      for (int i = 0; i < v.sampleIndices.length; i++) {
        _sampleWeights[v.sampleIndices[i]] += v.weights[i] * factor;
      }
    }

    accumulate(v00, b00);
    accumulate(v10, b10);
    accumulate(v01, b01);
    accumulate(v11, b11);

    // Renormalize
    double sum = 0.0;
    for (int i = 0; i < _sampleWeights.length; i++) {
      sum += _sampleWeights[i];
    }
    if (sum > 1e-8) {
      for (int i = 0; i < _sampleWeights.length; i++) {
        _sampleWeights[i] /= sum;
      }
    }

    double totalDur = 0.0;
    for (int i = 0; i < _samples.length; i++) {
      totalDur += _sampleWeights[i] * _samples[i].clip.duration;
    }
    _phaseDuration = totalDur > 1e-6 ? totalDur : 1.0;
  }

  @override
  void advance(double deltaTime) {
    if (interpolationTime > 0.0 && deltaTime > 0.0) {
      final step = math.min(1.0, deltaTime / interpolationTime);
      _currentParameter.x += (_targetParameter.x - _currentParameter.x) * step;
      _currentParameter.y += (_targetParameter.y - _currentParameter.y) * step;
    } else {
      _currentParameter.x = _targetParameter.x;
      _currentParameter.y = _targetParameter.y;
    }

    _computeWeights();

    if (_phaseDuration > 1e-8 && deltaTime > 0.0) {
      _normalizedPhase = (_normalizedPhase + deltaTime / _phaseDuration) % 1.0;
      if (_normalizedPhase < 0.0) _normalizedPhase += 1.0;
    }
  }

  @override
  void samplePhase(
    double normalizedPhase,
    List<Matrix4> outLocalPose, {
    double weight = 1.0,
  }) {
    double accumulatedWeight = 0.0;
    for (int i = 0; i < _samples.length; i++) {
      final w = _sampleWeights[i];
      if (w <= 0.0) continue;

      if (accumulatedWeight <= 0.0) {
        _samples[i].clip.samplePose(
          normalizedPhase * _samples[i].clip.duration,
          outLocalPose,
          looping: true,
          weight: weight,
        );
        accumulatedWeight = w;
      } else {
        final blendFraction = w / (accumulatedWeight + w);
        _samples[i].clip.samplePose(
          normalizedPhase * _samples[i].clip.duration,
          outLocalPose,
          looping: true,
          weight: blendFraction * weight,
        );
        accumulatedWeight += w;
      }
    }
  }

  @override
  void samplePose(
    double time,
    List<Matrix4> outLocalPose, {
    bool looping = true,
    double weight = 1.0,
  }) {
    final p = _phaseDuration > 1e-8 ? (time / _phaseDuration) % 1.0 : 0.0;
    samplePhase(p, outLocalPose, weight: weight);
  }
}
