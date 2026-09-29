import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The native side of `package:window_manager`'s `window_manager` method
/// channel, for widget tests: the Dart plugin, [LuminaWindow] and every
/// widget above it run for real; only the GTK/Win32/Cocoa window underneath
/// is simulated, and it answers the way the Linux plugin does — a state
/// change is reported back through an `onEvent` call (`maximize`,
/// `enter-full-screen`, …), never assumed by the caller.
class FakeNativeWindow {
  FakeNativeWindow({
    this.bounds = const Rect.fromLTWH(100, 80, 1280, 720),
    this.screen = const Rect.fromLTWH(0, 0, 2560, 1440),
  });

  static const MethodChannel channel = MethodChannel('window_manager');

  /// The restored (un-maximized) bounds, in logical pixels.
  Rect bounds;
  final Rect screen;
  bool maximized = false;
  bool fullScreen = false;
  bool minimized = false;
  bool preventClose = false;
  bool destroyed = false;
  String? titleBarStyle;

  /// Every method the Dart side called, in order.
  final List<MethodCall> calls = <MethodCall>[];

  /// When false the window ignores maximize, the way some tiling window
  /// managers do.
  bool honoursMaximize = true;

  /// When true `getBounds` answers with null fields, as the Windows plugin
  /// does for an integration-test window.
  bool boundsUnavailable = false;

  Iterable<String> get methods => calls.map((MethodCall c) => c.method);

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, _handle);
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  }

  /// Sends a window event to the Dart side, as the native plugin does.
  Future<void> emit(String eventName) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall('onEvent', <String, Object?>{'eventName': eventName})),
      (ByteData? _) {},
    );
  }

  void _later(String eventName) => Future<void>.microtask(() => emit(eventName));

  Future<Object?> _handle(MethodCall call) async {
    calls.add(call);
    final Map<Object?, Object?> args = call.arguments is Map ? call.arguments as Map<Object?, Object?> : const {};
    switch (call.method) {
      case 'isMaximized':
        return maximized;
      case 'isFullScreen':
        return fullScreen;
      case 'isMinimized':
        return minimized;
      case 'isPreventClose':
        return preventClose;
      case 'isVisible':
      case 'isFocused':
        return true;
      case 'setPreventClose':
        preventClose = args['isPreventClose'] == true;
        return null;
      case 'setTitleBarStyle':
        titleBarStyle = args['titleBarStyle'] as String?;
        return null;
      case 'maximize':
        if (honoursMaximize && !maximized) {
          maximized = true;
          _later('maximize');
        }
        return null;
      case 'unmaximize':
        if (maximized) {
          maximized = false;
          _later('unmaximize');
        }
        return null;
      case 'minimize':
        minimized = true;
        _later('minimize');
        return null;
      case 'restore':
        minimized = false;
        return null;
      case 'setFullScreen':
        final bool want = args['isFullScreen'] == true;
        if (want != fullScreen) {
          fullScreen = want;
          _later(want ? 'enter-full-screen' : 'leave-full-screen');
        }
        return null;
      case 'getBounds':
        if (boundsUnavailable) return <String, Object?>{'x': null, 'y': null, 'width': null, 'height': null};
        final Rect r = (maximized || fullScreen) ? screen : bounds;
        return <String, Object?>{'x': r.left, 'y': r.top, 'width': r.width, 'height': r.height};
      case 'setBounds':
        bounds = Rect.fromLTWH(
          (args['x'] as num?)?.toDouble() ?? bounds.left,
          (args['y'] as num?)?.toDouble() ?? bounds.top,
          (args['width'] as num?)?.toDouble() ?? bounds.width,
          (args['height'] as num?)?.toDouble() ?? bounds.height,
        );
        return null;
      case 'close':
        if (preventClose) {
          _later('close');
        } else {
          destroyed = true;
        }
        return null;
      case 'destroy':
        destroyed = true;
        return null;
      default:
        // ensureInitialized, waitUntilReadyToShow, show, focus,
        // startDragging, startResizing, setMinimumSize, setTitle, …
        return null;
    }
  }
}
