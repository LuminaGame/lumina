import 'package:flutter/services.dart';

import 'package:lumina/lumina_runtime.dart';

/// The generated runner's window ([LuminaWindowModeBackend]) and displays
/// ([LuminaDisplayBackend]) over the `lumina/game_window` method channel. The Windows runner
/// (`windows/runner/lumina_window_mode.cpp`) and the Linux runner
/// (`linux/runner/lumina_window_mode.cc`) answer:
/// - `getMode` → `windowed` | `borderless_fullscreen`;
/// - `setMode {mode}` → whether it was applied;
/// - `getInfo` → the window and monitor rectangles in physical pixels
///   (diagnostics);
/// - `getDisplays` → the monitors, their display modes, the current monitor
///   and the client size (`LuminaDisplayInfo.fromMap`);
/// - `setClientSize {width, height}` → the client size `[w, h]` the window
///   got;
/// - `moveToMonitor {index}` → whether the window moved;
///
/// and call `modeChanged {mode}` when the player toggles with Alt+Enter or
/// F11, `displayChanged {displays}` when a display changes or the window
/// moves to another monitor.
/// A runner without them (the editor, older generated runners) throws
/// [MissingPluginException]: no mode, nothing applied.
class LuminaWindowModeChannel implements LuminaWindowModeBackend, LuminaDisplayBackend {
  LuminaWindowModeChannel({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_onCall);
  }

  static const String channelName = 'lumina/game_window';

  final MethodChannel _channel;
  void Function(LuminaWindowMode mode)? _listener;
  void Function(LuminaDisplayInfo info)? _displayListener;

  @override
  set onModeChanged(void Function(LuminaWindowMode mode)? listener) => _listener = listener;

  @override
  set onDisplayChanged(void Function(LuminaDisplayInfo info)? listener) => _displayListener = listener;

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method == 'displayChanged') {
      final args = call.arguments;
      final info = args is Map ? LuminaDisplayInfo.fromMap(args) : null;
      if (info != null) _displayListener?.call(info);
      return null;
    }
    if (call.method != 'modeChanged') return null;
    final args = call.arguments;
    final id = args is Map ? args['mode'] : null;
    final mode = id is String ? LuminaWindowMode.parse(id) : null;
    if (mode != null) _listener?.call(mode);
    return null;
  }

  @override
  Future<LuminaWindowMode?> getMode() async {
    try {
      final id = await _channel.invokeMethod<String>('getMode');
      return id == null ? null : LuminaWindowMode.parse(id);
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> setMode(LuminaWindowMode mode) async {
    try {
      return await _channel.invokeMethod<bool>('setMode', {'mode': mode.id}) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<LuminaDisplayInfo?> queryDisplays() async {
    try {
      final map = await _channel.invokeMethod<Map<Object?, Object?>>('getDisplays');
      return map == null ? null : LuminaDisplayInfo.fromMap(map);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<(int, int)?> setClientSize(int width, int height) async {
    try {
      final size = await _channel.invokeMethod<List<Object?>>('setClientSize', {'width': width, 'height': height});
      if (size == null || size.length < 2 || size[0] is! int || size[1] is! int) return null;
      return (size[0] as int, size[1] as int);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<bool> moveToMonitor(int index) async {
    try {
      return await _channel.invokeMethod<bool>('moveToMonitor', {'index': index}) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// The runner's window facts (`mode`, `window`, `monitor` as
  /// `[left, top, right, bottom]` physical pixels, `client` `[w, h]`,
  /// `popup`), or null without a runner that reports them.
  Future<Map<String, Object?>?> windowInfo() async {
    try {
      final info = await _channel.invokeMethod<Map<Object?, Object?>>('getInfo');
      return info?.map((k, v) => MapEntry(k.toString(), v));
    } on MissingPluginException {
      return null;
    }
  }
}
