/// Callback signature invoked when a plugin reports an error or native crash.
typedef PluginCrashReportHandler = void Function(
  Object error,
  StackTrace? stack, {
  required String plugin,
  String? context,
});

/// Central crash reporting bridge for Lumina plugins.
///
/// Lumina Studio installs a global crash reporter during startup.
/// Plugins executing FFI, native C/C++ libraries, or background tasks
/// must wrap risky call sites in `try-catch` blocks and report caught
/// exceptions via [LuminaPluginCrashReporter.reportCrash].
abstract final class LuminaPluginCrashReporter {
  static PluginCrashReportHandler? _handler;

  /// Sets the host editor's crash reporting handler.
  /// Used internally by Lumina Studio when initializing or testing.
  static void setHandler(PluginCrashReportHandler? handler) {
    _handler = handler;
  }

  /// Whether a host crash reporter handler is currently registered.
  static bool get hasHandler => _handler != null;

  /// Reports an error or native exception attributed to [plugin].
  ///
  /// When a host handler is registered, forwards the crash details to the host
  /// crash reporter so a structured crash report tagged with [plugin] is filed
  /// and the user is presented with the crash dialog.
  /// If no handler is installed (e.g. running in isolated unit tests),
  /// the error is printed (stdout of the process, the debug console of a
  /// Flutter app).
  static void reportCrash(
    Object error,
    StackTrace? stack, {
    required String plugin,
    String? context,
  }) {
    final handler = _handler;
    if (handler != null) {
      handler(error, stack, plugin: plugin, context: context);
    } else {
      final ctx = (context != null && context.isNotEmpty) ? ' (while $context)' : '';
      print('[LuminaPluginCrashReporter] Plugin "$plugin" error$ctx: $error\n$stack');
    }
  }
}

