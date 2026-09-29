import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:lumina/lumina.dart' show LuminaUnits;

import '../models/landscape_brush.dart';

/// The Landscape editor's brush settings — the sculpt brush and the foliage
/// brush — as this user left them in this project.
///
/// Stored per project in `<project>/.lumina/landscape_brush.json`, next to the
/// editor's `editor_layout.json`: per-project user settings for the
/// Landscape and Foliage modes (Brush Size / Falloff / Paint Density). They
/// describe how the user likes to
/// paint, not the terrain, so they never enter the `.lmas`. Lengths are
/// written in **centimetres** (the editor's authoring unit) and read back into
/// the view model's terrain metres.
class LandscapeBrushPreferences {
  final LandscapeTool tool;

  /// Sculpt brush radius, terrain metres.
  final double sculptRadius;
  final double sculptStrength;
  final double sculptFalloff;
  final LandscapeFalloffType falloffType;

  /// Foliage brush radius, terrain metres.
  final double foliageRadius;
  final double foliageFalloff;
  final double paintDensity;
  final double eraseDensity;

  const LandscapeBrushPreferences({
    this.tool = LandscapeTool.sculpt,
    this.sculptRadius = 45.0,
    this.sculptStrength = 0.5,
    this.sculptFalloff = 0.5,
    this.falloffType = LandscapeFalloffType.smooth,
    this.foliageRadius = 10.0,
    this.foliageFalloff = 0.5,
    this.paintDensity = 0.5,
    this.eraseDensity = 0.0,
  });

  static const String fileName = 'landscape_brush.json';

  /// The file for the project at [projectDir].
  static File fileFor(String projectDir) => File('$projectDir/.lumina/$fileName');

  /// The project a landscape asset belongs to: the folder above its
  /// `contents/`, or null when the path is not inside a project.
  static String? projectDirOf(String? assetPath) {
    if (assetPath == null) return null;
    final normalised = assetPath.replaceAll('\\', '/');
    final i = normalised.lastIndexOf('/contents/');
    return i <= 0 ? null : normalised.substring(0, i);
  }

  Map<String, dynamic> toJson() => {
        'units': 'cm',
        'sculpt': {
          'tool': tool.name,
          'size_cm': LuminaUnits.metres(sculptRadius),
          'strength': sculptStrength,
          'falloff': sculptFalloff,
          'falloff_type': falloffType.name,
        },
        'foliage': {
          'size_cm': LuminaUnits.metres(foliageRadius),
          'falloff': foliageFalloff,
          'paint_density': paintDensity,
          'erase_density': eraseDensity,
        },
      };

  factory LandscapeBrushPreferences.fromJson(Map<String, dynamic> json) {
    const d = LandscapeBrushPreferences();
    final sculpt = (json['sculpt'] as Map?)?.cast<String, dynamic>() ?? const {};
    final foliage = (json['foliage'] as Map?)?.cast<String, dynamic>() ?? const {};
    double num_(Map<String, dynamic> m, String k, double fallback) => (m[k] as num?)?.toDouble() ?? fallback;
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    return LandscapeBrushPreferences(
      tool: byName(LandscapeTool.values, sculpt['tool'], d.tool),
      sculptRadius: LuminaUnits.toMetres(num_(sculpt, 'size_cm', LuminaUnits.metres(d.sculptRadius))),
      sculptStrength: num_(sculpt, 'strength', d.sculptStrength),
      sculptFalloff: num_(sculpt, 'falloff', d.sculptFalloff),
      falloffType: byName(LandscapeFalloffType.values, sculpt['falloff_type'], d.falloffType),
      foliageRadius: LuminaUnits.toMetres(num_(foliage, 'size_cm', LuminaUnits.metres(d.foliageRadius))),
      foliageFalloff: num_(foliage, 'falloff', d.foliageFalloff),
      paintDensity: num_(foliage, 'paint_density', d.paintDensity),
      eraseDensity: num_(foliage, 'erase_density', d.eraseDensity),
    );
  }

  /// The saved settings of the project at [projectDir], or null when there
  /// are none (or the file cannot be read — the defaults then apply).
  static LandscapeBrushPreferences? load(String projectDir) {
    final file = fileFor(projectDir);
    if (!file.existsSync()) return null;
    try {
      return LandscapeBrushPreferences.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[LandscapeBrushPreferences] ignoring unreadable ${file.path}: $e');
      return null;
    }
  }

  /// Writes the settings for the project at [projectDir].
  void save(String projectDir) {
    try {
      final file = fileFor(projectDir);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(toJson()));
    } catch (e) {
      debugPrint('[LandscapeBrushPreferences] could not save: $e');
    }
  }
}
