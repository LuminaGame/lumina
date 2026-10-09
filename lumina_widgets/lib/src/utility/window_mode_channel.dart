import 'package:flutter/services.dart';

import 'package:lumina/lumina_runtime.dart';

/// The generated runner's window ([LuminaWindowModeBackend]) over the
/// `lumina/game_window` method channel. The Windows runner
/// (`windows/runner/lumina_window_mode.cpp`) and the Linux runner
/// (`linux/runner/lumina_window_mode.cc`) answer:
/// - `getMode` → `windowed` | `borderless_fullscreen`;
/// - `setMode {mode}` → whether it was applied;
/// - `getInfo` → the window and monitor rectangles in physical pixels
///   (diagnostics);
///
/// and call `modeChanged {mode}` when the player toggles with Alt+Enter or F11.
/// A runner without them (the editor, older generated runners) throws
/// [MissingPluginException]: no mode, nothing applied.
class LuminaWindowModeChannel implements LuminaWindowModeBackend {
  LuminaWindowModeChannel({MethodChannel? channel}) : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_onCall);
  }

  static const String channelName = 'lumina/game_window';

  final MethodChannel _channel;
  void Function(LuminaWindowMode mode)? _listener;

  @override
  set onModeChanged(void Function(LuminaWindowMode mode)? listener) => _listener = listener;

  Future<Object?> _onCall(MethodCall call) async {
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
