import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';

// Test implementation
class TestPlugin extends LuminaEditorPlugin {
  @override
  String get pluginName => 'TestPlugin';

  @override
  void register(LuminaEditorContext context) {}
  
  @override
  void unregister(LuminaEditorContext context) {}
}

void main() {
  test('LuminaEditorPlugin API contract exists', () {
    final plugin = TestPlugin();
    expect(plugin.pluginName, 'TestPlugin');
  });

  group('LuminaPluginCrashReporter', () {
    tearDown(() {
      LuminaPluginCrashReporter.setHandler(null);
    });

    test('reportCrash forwards to registered handler', () {
      Object? reportedError;
      StackTrace? reportedStack;
      String? reportedPlugin;
      String? reportedContext;

      LuminaPluginCrashReporter.setHandler((error, stack, {required plugin, context}) {
        reportedError = error;
        reportedStack = stack;
        reportedPlugin = plugin;
        reportedContext = context;
      });

      final err = StateError('FFI memory fault');
      final st = StackTrace.current;
      LuminaPluginCrashReporter.reportCrash(err, st, plugin: 'my_ffi_plugin', context: 'loading native mesh');

      expect(reportedError, err);
      expect(reportedStack, st);
      expect(reportedPlugin, 'my_ffi_plugin');
      expect(reportedContext, 'loading native mesh');
    });

    test('LuminaEditorPlugin.reportCrash binds pluginName automatically', () {
      String? capturedPlugin;
      Object? capturedError;

      LuminaPluginCrashReporter.setHandler((error, stack, {required plugin, context}) {
        capturedPlugin = plugin;
        capturedError = error;
      });

      final plugin = TestPlugin();
      plugin.reportCrash('Native null pointer dereference', StackTrace.empty);

      expect(capturedPlugin, 'TestPlugin');
      expect(capturedError, 'Native null pointer dereference');
    });

    test('reportCrash does not throw when handler is null (fallback)', () {
      LuminaPluginCrashReporter.setHandler(null);
      expect(
        () => LuminaPluginCrashReporter.reportCrash('some error', null, plugin: 'test_plugin'),
        returnsNormally,
      );
    });
  });
}
