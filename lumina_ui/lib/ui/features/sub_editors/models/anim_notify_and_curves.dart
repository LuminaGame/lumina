import 'dart:math' as math;

enum AnimNotifyType { footstep, playSound, spawnParticle, custom }

class EditorAnimNotify {
  final String id;
  String name;
  double time; // in seconds
  AnimNotifyType type;
  bool isSyncMarker;

  EditorAnimNotify({
    required this.id,
    required this.name,
    required this.time,
    this.type = AnimNotifyType.custom,
    this.isSyncMarker = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'time': time,
        'type': type.name,
        'isSyncMarker': isSyncMarker,
      };

  factory EditorAnimNotify.fromJson(Map<String, dynamic> json) {
    AnimNotifyType parsedType = AnimNotifyType.custom;
    final tStr = json['type'] as String?;
    if (tStr != null) {
      for (final t in AnimNotifyType.values) {
        if (t.name == tStr) {
          parsedType = t;
          break;
        }
      }
    }
    return EditorAnimNotify(
      id: json['id'] as String? ?? 'notify_${DateTime.now().microsecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Notify',
      time: (json['time'] as num?)?.toDouble() ?? 0.0,
      type: parsedType,
      isSyncMarker: json['isSyncMarker'] as bool? ?? false,
    );
  }
}

class AnimCurveKey {
  double time;
  double value;

  AnimCurveKey({required this.time, required this.value});

  Map<String, dynamic> toJson() => {
        'time': time,
        'value': value,
      };

  factory AnimCurveKey.fromJson(Map<String, dynamic> json) => AnimCurveKey(
        time: (json['time'] as num?)?.toDouble() ?? 0.0,
        value: (json['value'] as num?)?.toDouble() ?? 0.0,
      );
}

class AnimCurveData {
  String name;
  List<AnimCurveKey> keys;

  AnimCurveData({
    required this.name,
    List<AnimCurveKey>? keys,
  }) : keys = keys ?? [];

  void sortKeys() {
    keys.sort((a, b) => a.time.compareTo(b.time));
  }

  double evaluate(double t) {
    if (keys.isEmpty) return 0.0;
    sortKeys();
    if (keys.length == 1) return keys.first.value;
    if (t <= keys.first.time) return keys.first.value;
    if (t >= keys.last.time) return keys.last.value;

    for (int i = 0; i < keys.length - 1; i++) {
      final k0 = keys[i];
      final k1 = keys[i + 1];
      if (t >= k0.time && t <= k1.time) {
        final span = k1.time - k0.time;
        if (span <= 1e-9) return k0.value;
        final alpha = (t - k0.time) / span;
        return k0.value + (k1.value - k0.value) * alpha;
      }
    }
    return keys.last.value;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'keys': keys.map((k) => k.toJson()).toList(),
      };

  factory AnimCurveData.fromJson(Map<String, dynamic> json) {
    final rawKeys = json['keys'] as List? ?? [];
    return AnimCurveData(
      name: json['name'] as String? ?? 'Curve',
      keys: rawKeys.map((k) => AnimCurveKey.fromJson(k as Map<String, dynamic>)).toList(),
    );
  }
}

class BlendSpaceAxis {
  String name;
  double min;
  double max;

  BlendSpaceAxis({
    required this.name,
    required this.min,
    required this.max,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'min': min,
        'max': max,
      };

  factory BlendSpaceAxis.fromJson(Map<String, dynamic> json) => BlendSpaceAxis(
        name: json['name'] as String? ?? 'Axis',
        min: (json['min'] as num?)?.toDouble() ?? 0.0,
        max: (json['max'] as num?)?.toDouble() ?? 100.0,
      );
}

class EditorBlendSample {
  final String id;
  String assetPath;
  String assetName;
  double x;
  double y;

  EditorBlendSample({
    required this.id,
    required this.assetPath,
    required this.assetName,
    required this.x,
    this.y = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetPath': assetPath,
        'assetName': assetName,
        'x': x,
        'y': y,
      };

  factory EditorBlendSample.fromJson(Map<String, dynamic> json) => EditorBlendSample(
        id: json['id'] as String? ?? 'sample_${DateTime.now().microsecondsSinceEpoch}',
        assetPath: json['assetPath'] as String? ?? '',
        assetName: json['assetName'] as String? ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 0.0,
        y: (json['y'] as num?)?.toDouble() ?? 0.0,
      );
}

class BlendSpaceData {
  bool is2D;
  BlendSpaceAxis xAxis;
  BlendSpaceAxis yAxis;
  List<EditorBlendSample> samples;

  BlendSpaceData({
    this.is2D = false,
    BlendSpaceAxis? xAxis,
    BlendSpaceAxis? yAxis,
    List<EditorBlendSample>? samples,
  })  : xAxis = xAxis ?? BlendSpaceAxis(name: 'Direction', min: -180.0, max: 180.0),
        yAxis = yAxis ?? BlendSpaceAxis(name: 'Speed', min: 0.0, max: 600.0),
        samples = samples ?? [];

  Map<String, double> computeWeights(double x, double y) {
    if (samples.isEmpty) return {};
    if (samples.length == 1) return {samples.first.id: 1.0};

    if (!is2D) {
      // 1D bracketing-pair rule
      final sorted = List<EditorBlendSample>.from(samples)..sort((a, b) => a.x.compareTo(b.x));
      if (x <= sorted.first.x) {
        final res = <String, double>{};
        for (final s in sorted) {
          res[s.id] = s.id == sorted.first.id ? 1.0 : 0.0;
        }
        return res;
      }
      if (x >= sorted.last.x) {
        final res = <String, double>{};
        for (final s in sorted) {
          res[s.id] = s.id == sorted.last.id ? 1.0 : 0.0;
        }
        return res;
      }

      for (int i = 0; i < sorted.length - 1; i++) {
        final s0 = sorted[i];
        final s1 = sorted[i + 1];
        if (x >= s0.x && x <= s1.x) {
          final span = s1.x - s0.x;
          final res = <String, double>{};
          for (final s in sorted) {
            res[s.id] = 0.0;
          }
          if (span <= 1e-9) {
            res[s0.id] = 1.0;
            return res;
          }
          final w1 = (x - s0.x) / span;
          final w0 = 1.0 - w1;
          res[s0.id] = w0;
          res[s1.id] = w1;
          return res;
        }
      }
      final res = <String, double>{};
      for (final s in sorted) {
        res[s.id] = s.id == sorted.last.id ? 1.0 : 0.0;
      }
      return res;
    } else {
      // 2D: compute weights using inverse distance weighting with normalization
      for (final s in samples) {
        final dx = s.x - x;
        final dy = s.y - y;
        if (math.sqrt(dx * dx + dy * dy) < 1e-8) {
          final res = <String, double>{};
          for (final smp in samples) {
            res[smp.id] = smp.id == s.id ? 1.0 : 0.0;
          }
          return res;
        }
      }

      final Map<String, double> raw = {};
      double totalWeight = 0.0;
      for (final s in samples) {
        final dx = (s.x - x) / (xAxis.max - xAxis.min).abs().clamp(1e-4, double.infinity);
        final dy = (s.y - y) / (yAxis.max - yAxis.min).abs().clamp(1e-4, double.infinity);
        final dist = math.sqrt(dx * dx + dy * dy);
        final w = 1.0 / (dist * dist);
        raw[s.id] = w;
        totalWeight += w;
      }

      if (totalWeight <= 1e-9) {
        final res = <String, double>{};
        for (final s in samples) {
          res[s.id] = s.id == samples.first.id ? 1.0 : 0.0;
        }
        return res;
      }

      final Map<String, double> normalized = {};
      for (final s in samples) {
        normalized[s.id] = (raw[s.id] ?? 0.0) / totalWeight;
      }
      return normalized;
    }
  }

  Map<String, dynamic> toJson() => {
        'is2D': is2D,
        'xAxis': xAxis.toJson(),
        'yAxis': yAxis.toJson(),
        'samples': samples.map((s) => s.toJson()).toList(),
      };

  factory BlendSpaceData.fromJson(Map<String, dynamic> json) {
    final rawSamples = json['samples'] as List? ?? [];
    return BlendSpaceData(
      is2D: json['is2D'] as bool? ?? false,
      xAxis: json['xAxis'] is Map ? BlendSpaceAxis.fromJson(json['xAxis'] as Map<String, dynamic>) : null,
      yAxis: json['yAxis'] is Map ? BlendSpaceAxis.fromJson(json['yAxis'] as Map<String, dynamic>) : null,
      samples: rawSamples.map((s) => EditorBlendSample.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}
