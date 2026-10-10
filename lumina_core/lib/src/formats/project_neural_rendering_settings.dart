/// Project Settings ▸ Neural rendering (experimental): the project's opt-in to
/// OpenDLSS-NR, a third-party, unofficial re-implementation of NVIDIA's DLSS 5
/// neural rendering network that runs only on model weights the user supplies
/// (`neural_rendering` in the `.lmproject`).
///
/// The feature is [active] only when it is [enabled] and the user accepted
/// the warning ([acknowledgedAt]). [weightsPath] is a path on this machine,
/// used by the editor viewport and Play-In-Editor; packaged games never read
/// it (they take a path from the player's settings or the environment).
class ProjectNeuralRenderingSettings {
  const ProjectNeuralRenderingSettings({
    this.enabled = false,
    this.acknowledgedAt = '',
    this.weightsPath = '',
    this.intensity = 1.0,
    this.localTone = 1.0,
    this.localStructure = 1.0,
    this.autoMask = true,
    this.style = styleNone,
    this.paperWhite = 1.0,
    this.colorStrength = 1.0,
  });

  static const String styleNone = 'none';
  static const String styleNatural = 'natural';
  static const String styleCinematic = 'cinematic';
  static const List<String> styles = [styleNone, styleNatural, styleCinematic];

  /// "Use OpenDLSS-NR".
  final bool enabled;

  /// When the user accepted the warning (ISO-8601 UTC), or empty.
  final String acknowledgedAt;

  /// The model folder (`manifest.json` + `model/`) or its `manifest.json`,
  /// on this machine; empty until the user picks one.
  final String weightsPath;

  /// 0..1: how much of the network's result replaces the frame.
  final double intensity;

  /// Conditioning scalars the network sees.
  final double localTone;
  final double localStructure;
  final bool autoMask;

  /// [styleNone], [styleNatural] or [styleCinematic].
  final String style;

  /// The scene value the network's display proxy shows as paper white.
  final double paperWhite;

  /// 0 keeps the frame's colours (luminance only), 1 takes the network's.
  final double colorStrength;

  bool get acknowledged => acknowledgedAt.isNotEmpty;

  /// Enabled and acknowledged: what the viewport, PIE and built games follow.
  bool get active => enabled && acknowledged;

  /// The model folder [weightsPath] names (a `manifest.json` path names its
  /// folder); empty when none is set.
  String get weightsDirectory => weightsDirectoryOf(weightsPath);

  static String weightsDirectoryOf(String path) {
    final p = path.trim();
    if (p.isEmpty) return '';
    final normalized = p.replaceAll('\\', '/');
    if (normalized.toLowerCase().endsWith('/manifest.json')) {
      return p.substring(0, p.length - '/manifest.json'.length);
    }
    return p;
  }

  ProjectNeuralRenderingSettings copyWith({
    bool? enabled,
    String? acknowledgedAt,
    String? weightsPath,
    double? intensity,
    double? localTone,
    double? localStructure,
    bool? autoMask,
    String? style,
    double? paperWhite,
    double? colorStrength,
  }) {
    return ProjectNeuralRenderingSettings(
      enabled: enabled ?? this.enabled,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      weightsPath: weightsPath ?? this.weightsPath,
      intensity: (intensity ?? this.intensity).clamp(0.0, 1.0),
      localTone: (localTone ?? this.localTone).clamp(0.0, 1.0),
      localStructure: (localStructure ?? this.localStructure).clamp(0.0, 1.0),
      autoMask: autoMask ?? this.autoMask,
      style: styles.contains(style) ? style! : this.style,
      paperWhite: (paperWhite ?? this.paperWhite).clamp(0.25, 4.0),
      colorStrength: (colorStrength ?? this.colorStrength).clamp(0.0, 1.0),
    );
  }

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'acknowledged_at': acknowledgedAt,
        'weights_path': weightsPath,
        'intensity': intensity,
        'local_tone': localTone,
        'local_structure': localStructure,
        'auto_mask': autoMask,
        'style': style,
        'paper_white': paperWhite,
        'color_strength': colorStrength,
      };

  factory ProjectNeuralRenderingSettings.fromMap(Map<String, dynamic> map) {
    double number(String key, double fallback, double min, double max) {
      final v = map[key];
      return v is num && v.isFinite ? v.toDouble().clamp(min, max) : fallback;
    }

    final style = map['style'];
    return ProjectNeuralRenderingSettings(
      enabled: map['enabled'] as bool? ?? false,
      acknowledgedAt: map['acknowledged_at'] is String ? map['acknowledged_at'] as String : '',
      weightsPath: map['weights_path'] is String ? map['weights_path'] as String : '',
      intensity: number('intensity', 1.0, 0.0, 1.0),
      localTone: number('local_tone', 1.0, 0.0, 1.0),
      localStructure: number('local_structure', 1.0, 0.0, 1.0),
      autoMask: map['auto_mask'] as bool? ?? true,
      style: styles.contains(style) ? style as String : styleNone,
      paperWhite: number('paper_white', 1.0, 0.25, 4.0),
      colorStrength: number('color_strength', 1.0, 0.0, 1.0),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProjectNeuralRenderingSettings &&
      other.enabled == enabled &&
      other.acknowledgedAt == acknowledgedAt &&
      other.weightsPath == weightsPath &&
      other.intensity == intensity &&
      other.localTone == localTone &&
      other.localStructure == localStructure &&
      other.autoMask == autoMask &&
      other.style == style &&
      other.paperWhite == paperWhite &&
      other.colorStrength == colorStrength;

  @override
  int get hashCode => Object.hash(enabled, acknowledgedAt, weightsPath, intensity, localTone, localStructure, autoMask,
      style, paperWhite, colorStrength);
}
