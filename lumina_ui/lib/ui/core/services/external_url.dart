import 'dart:io';

/// Opens [url] (http / https only) in the system browser; false when it could
/// not be handed over.
Future<bool> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) return false;
  final text = uri.toString();
  try {
    if (Platform.isWindows) {
      await Process.start('rundll32', ['url.dll,FileProtocolHandler', text], mode: ProcessStartMode.detached);
    } else if (Platform.isMacOS) {
      await Process.start('open', [text], mode: ProcessStartMode.detached);
    } else {
      await Process.start('xdg-open', [text], mode: ProcessStartMode.detached);
    }
    return true;
  } catch (_) {
    return false;
  }
}
