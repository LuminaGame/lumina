import 'package:lumina/src/components/camera/camera_component.dart';

/// A camera's authored settings as one property map, read the one way every
/// consumer agrees on: the level editor's Camera section (a placed `Camera`
/// actor's `LuminaCameraComponent`), Play, the generated game, MCP and the
/// Blueprint camera component all use these names and units.
///
/// | Property | Unit | Default |
/// |---|---|---|
/// | `fieldOfView` | degrees, vertical | 60 |
/// | `projectionMode` | `Perspective` / `Orthographic` | `Perspective` |
/// | `orthoWidth` | cm, the view's width (orthographic) | 1000 |
/// | `nearClipPlane` / `farClipPlane` | cm | 10 / 100000 |
/// | `autoExposure` | metered from the level's lights | true |
/// | `aperture` | f-stops | 16 |
/// | `shutterSpeed` | seconds | 1/125 |
/// | `sensitivity` | ISO | 100 |
/// | `autoActivateForPlayer` | a placed camera becomes the player's view target | false |
///
/// The aspect ratio is the viewport's; aperture, shutter speed and ISO only
/// set the exposure (Filament's camera has no depth of field of its own: a
/// Post Process Volume sets that).
class LuminaCameraSettings {
  const LuminaCameraSettings({
    this.fieldOfView = defaultFieldOfView,
    this.projectionMode = CameraProjectionMode.perspective,
    this.orthoWidth = 1000.0,
    this.nearClipPlane = 10.0,
    this.farClipPlane = 100000.0,
    this.autoExposure = true,
    this.aperture = 16.0,
    this.shutterSpeed = 1.0 / 125.0,
    this.sensitivity = 100.0,
    this.autoActivateForPlayer = false,
  });

  /// The component type a placed camera's settings live on.
  static const String componentType = 'LuminaCameraComponent';

  static const double defaultFieldOfView = 60.0;
  static const double minFieldOfView = 5.0;
  static const double maxFieldOfView = 170.0;

  /// The property values `projectionMode` takes.
  static const List<String> projectionModes = ['Perspective', 'Orthographic'];

  final double fieldOfView;
  final CameraProjectionMode projectionMode;
  final double orthoWidth;
  final double nearClipPlane;
  final double farClipPlane;
  final bool autoExposure;
  final double aperture;
  final double shutterSpeed;
  final double sensitivity;
  final bool autoActivateForPlayer;

  /// Reads [properties]; a missing, mistyped or out-of-range value keeps the
  /// default (the field of view is clamped to 5–170°, the far plane kept
  /// beyond the near one).
  factory LuminaCameraSettings.fromProperties(Map<String, dynamic>? properties) {
    final p = properties ?? const <String, dynamic>{};
    const d = LuminaCameraSettings();
    double positive(String key, double fallback) {
      final v = p[key];
      return v is num && v.isFinite && v > 0 ? v.toDouble() : fallback;
    }

    bool flag(String key, bool fallback) => p[key] is bool ? p[key] as bool : fallback;

    final fovRaw = p['fieldOfView'] ?? p['fov'];
    final fov = fovRaw is num && fovRaw.isFinite ? fovRaw.toDouble().clamp(minFieldOfView, maxFieldOfView) : d.fieldOfView;
    final near = positive('nearClipPlane', d.nearClipPlane);
    var far = positive('farClipPlane', d.farClipPlane);
    if (far <= near) far = near * 10.0 > d.farClipPlane ? near * 10.0 : d.farClipPlane;
    final mode = p['projectionMode'];
    return LuminaCameraSettings(
      fieldOfView: fov,
      projectionMode: mode is String && mode.toLowerCase() == 'orthographic'
          ? CameraProjectionMode.orthographic
          : CameraProjectionMode.perspective,
      orthoWidth: positive('orthoWidth', d.orthoWidth),
      nearClipPlane: near,
      farClipPlane: far,
      autoExposure: flag('autoExposure', d.autoExposure),
      aperture: positive('aperture', d.aperture),
      shutterSpeed: positive('shutterSpeed', d.shutterSpeed),
      sensitivity: positive('sensitivity', d.sensitivity),
      autoActivateForPlayer: flag('autoActivateForPlayer', d.autoActivateForPlayer),
    );
  }

  /// The property map [fromProperties] reads back.
  Map<String, dynamic> toProperties() => <String, dynamic>{
        'fieldOfView': fieldOfView,
        'projectionMode': projectionMode == CameraProjectionMode.orthographic ? 'Orthographic' : 'Perspective',
        'orthoWidth': orthoWidth,
        'nearClipPlane': nearClipPlane,
        'farClipPlane': farClipPlane,
        'autoExposure': autoExposure,
        'aperture': aperture,
        'shutterSpeed': shutterSpeed,
        'sensitivity': sensitivity,
        'autoActivateForPlayer': autoActivateForPlayer,
      };

  /// Writes the settings onto [camera] (not its activation).
  void applyTo(LuminaCameraComponent camera) {
    camera
      ..fieldOfViewInDegrees = fieldOfView
      ..projectionMode = projectionMode
      ..orthographicWidth = orthoWidth
      ..nearClipPlane = nearClipPlane
      ..farClipPlane = farClipPlane
      ..autoExposure = autoExposure
      ..aperture = aperture
      ..shutterSpeed = shutterSpeed
      ..sensitivity = sensitivity;
  }
}
