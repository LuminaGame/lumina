import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart';

/// Shrinks the app window to a fixed, centred, always-on-top splash and puts
/// it back afterwards. A maximized or full-screen window is restored to its
/// normal state first: the platform ignores a size change on such a window,
/// which would leave the splash filling the screen.
class SplashWindow {
  final Size size;

  SplashWindow(this.size);

  bool _wasMaximized = false;
  bool _wasFullScreen = false;
  Rect? _bounds;

  Future<void> enter() => _guard(() async {
        _wasFullScreen = await windowManager.isFullScreen();
        if (_wasFullScreen) await windowManager.setFullScreen(false);
        _wasMaximized = await windowManager.isMaximized();
        if (_wasMaximized) await windowManager.unmaximize();
        _bounds = await windowManager.getBounds();
        await windowManager.setResizable(false);
        await windowManager.setSize(size);
        await windowManager.center();
        await windowManager.setAlwaysOnTop(true);
      });

  Future<void> leave() => _guard(() async {
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setResizable(true);
        if (_bounds != null) await windowManager.setBounds(_bounds!);
        if (_wasMaximized) await windowManager.maximize();
        if (_wasFullScreen) await windowManager.setFullScreen(true);
      });

  static Future<void> _guard(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {
      // No native window (tests) or a platform without that call.
    }
  }
}
