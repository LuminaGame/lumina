import 'package:lumina_core/lumina_core.dart';

/// Service for parsing Wavefront OBJ 3D model geometry.
class ObjParserService {
  static final EngineLoggerService _logger = EngineLoggerService();

  /// Parses OBJ format text content into engine [GlbMeshData].
  static GlbMeshData? parseObj(String objText, {List<double>? baseColor}) {
    try {
      final List<double> posList = [];
      final List<double> normList = [];
      final List<int> indexList = [];

      final lines = objText.split('\n');

      double minX = double.infinity, maxX = -double.infinity;
      double minY = double.infinity, maxY = -double.infinity;
      double minZ = double.infinity, maxZ = -double.infinity;

      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;

        if (line.startsWith('v ')) {
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final x = double.tryParse(parts[1]) ?? 0.0;
            final y = double.tryParse(parts[2]) ?? 0.0;
            final z = double.tryParse(parts[3]) ?? 0.0;
            posList.addAll([x, y, z]);

            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
            if (z < minZ) minZ = z;
            if (z > maxZ) maxZ = z;
          }
        } else if (line.startsWith('vn ')) {
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 4) {
            final nx = double.tryParse(parts[1]) ?? 0.0;
            final ny = double.tryParse(parts[2]) ?? 0.0;
            final nz = double.tryParse(parts[3]) ?? 1.0;
            normList.addAll([nx, ny, nz]);
          }
        } else if (line.startsWith('f ')) {
          final parts = line.split(RegExp(r'\s+')).sublist(1);
          final indices = <int>[];
          for (final p in parts) {
            final subParts = p.split('/');
            if (subParts.isNotEmpty && subParts[0].isNotEmpty) {
              final idx = int.tryParse(subParts[0]);
              if (idx != null) {
                indices.add(idx > 0 ? idx - 1 : idx);
              }
            }
          }
          if (indices.length == 3) {
            indexList.addAll(indices);
          } else if (indices.length == 4) {
            indexList.addAll([indices[0], indices[1], indices[2]]);
            indexList.addAll([indices[0], indices[2], indices[3]]);
          }
        }
      }

      if (posList.isEmpty) {
        _logger.log('OBJ parse failed: No valid "v " vertex positions found in text.', level: 'error', source: 'ObjParserService');
        return null;
      }

      final indices = indexList.isNotEmpty
          ? indexList
          : List<int>.generate(posList.length ~/ 3, (i) => i);

      _logger.log('Parsed OBJ model successfully (${posList.length ~/ 3} vertices, ${indices.length ~/ 3} triangles).', level: 'success', source: 'ObjParserService');

      return GlbMeshData(
        positions: posList,
        indices: indices,
        minBounds: [minX, minY, minZ],
        maxBounds: [maxX, maxY, maxZ],
        baseColor: baseColor ?? [0.0, 0.9, 0.46], // Emerald Material Shading
      );
    } catch (e, st) {
      _logger.log('OBJ parsing exception: $e\n$st', level: 'error', source: 'ObjParserService');
      return null;
    }
  }
}
