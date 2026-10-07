import 'dart:io' show Platform;

import 'package:lumina/src/utility/lumina_platform.dart';

/// The operating system `dart:io` reports.
LuminaPlatform detectPlatform() {
  if (Platform.isWindows) return LuminaPlatform.windows;
  if (Platform.isMacOS) return LuminaPlatform.macOS;
  if (Platform.isIOS) return LuminaPlatform.iOS;
  if (Platform.isAndroid) return LuminaPlatform.android;
  if (Platform.isFuchsia) return LuminaPlatform.fuchsia;
  return LuminaPlatform.linux;
}
