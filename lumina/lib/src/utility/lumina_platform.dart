import 'package:lumina/src/utility/lumina_platform_stub.dart'
    if (dart.library.io) 'package:lumina/src/utility/lumina_platform_io.dart' as detect;

/// The operating system a game runs on, as the engine sees it (what
/// `Get Platform Name` reports). The engine reads it without Flutter:
/// [current] is detected from `dart:io` (and is [web] in a web build), and
/// the Flutter side of a game (`lumina_widgets`) sets [override] at start-up
/// from Flutter's target platform, so a test that overrides Flutter's
/// platform sees the same one here.
enum LuminaPlatform {
  android,
  fuchsia,
  iOS,
  linux,
  macOS,
  windows,
  web;

  /// Whether this is a web build (`dart.library.js_interop` is available).
  static const bool isWeb = bool.fromEnvironment('dart.library.js_interop');

  /// Set by the host (`lumina_widgets` at start-up, or a test); null uses
  /// the detected platform.
  static LuminaPlatform? override;

  /// The platform the game runs on: [override], else [web] in a web build,
  /// else the operating system `dart:io` reports.
  static LuminaPlatform get current => override ?? (isWeb ? web : detect.detectPlatform());

  /// [name] as `Get Platform Name` reports it: `Windows`, `Linux`, `MacOS`,
  /// `IOS`, `Android`, `Fuchsia`; `Web` in a web build whatever the browser's
  /// operating system.
  static String get displayName {
    if (isWeb) return 'Web';
    final n = current.name;
    return n == 'iOS' ? 'IOS' : n == 'macOS' ? 'MacOS' : n[0].toUpperCase() + n.substring(1);
  }
}
