import 'package:lumina/lumina_runtime.dart';
import 'package:lumina_widgets/src/utility/web_display_hook_stub.dart'
    if (dart.library.js_interop) 'package:lumina_widgets/src/utility/web_display_hook_web.dart' as hook;

/// The browser's display ([LuminaDisplayBackend]) for a web build: one
/// monitor, the screen (`window.screen` × `devicePixelRatio`, physical
/// pixels), with its current mode as the only mode (browsers list no modes
/// and no refresh rate), and the page's viewport as the client area.
///
/// The page cannot resize or move its window: `setClientSize` answers null,
/// so `Set Screen Resolution` renders the chosen resolution scaled into the
/// canvas instead.
class LuminaWebDisplayBackend implements LuminaDisplayBackend {
  @override
  Future<LuminaDisplayInfo?> queryDisplays() async {
    final screen = hook.screenSize();
    if (screen == null) return null;
    final client = hook.viewportSize();
    return LuminaDisplayInfo.fromMap({
      'monitors': [
        {
          'name': 'Browser Screen',
          'device': 'screen',
          'primary': true,
          'bounds': [0, 0, screen.$1, screen.$2],
          'current': [screen.$1, screen.$2, 0],
          'modes': [
            [screen.$1, screen.$2, 0],
          ],
          'scale': hook.devicePixelRatio(),
        },
      ],
      'current': 0,
      if (client != null) 'client': [client.$1, client.$2],
    });
  }

  @override
  Future<(int, int)?> setClientSize(int width, int height) async => null;

  @override
  Future<bool> moveToMonitor(int index) async => false;

  @override
  set onDisplayChanged(void Function(LuminaDisplayInfo info)? listener) {}
}
