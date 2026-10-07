import 'package:flutter_filament/filament.dart' show FilamentInfo;

/// What renders Lumina: the Filament release the
/// engine is linked against and its material version, read from the library
/// at runtime, plus Filament's credit. The
/// editor reads these here and never imports flutter_filament for them.
abstract final class LuminaRenderBackendInfo {
  /// The linked Filament release, e.g. `1.77.0`.
  static String get filamentVersion => FilamentInfo.version;

  /// The material package version the linked Filament accepts.
  static int get filamentMaterialVersion => FilamentInfo.materialVersion;

  static const String filamentLicense = 'Apache-2.0';
  static const String filamentUrl = 'https://github.com/google/filament';
}
