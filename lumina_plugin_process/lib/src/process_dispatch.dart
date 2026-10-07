import 'dart:async';
import 'dart:io';

import 'package:lumina_plugin_protocol/lumina_plugin_protocol.dart';

import 'package:lumina_plugin_process/src/mcp/mcp_types.dart';
import 'package:lumina_plugin_process/src/plugin_storage.dart';
import 'package:lumina_plugin_process/src/plugin_process.dart';
import 'package:lumina_plugin_process/src/process_context.dart';

/// Installs the `core.*` request and notification handlers of a plugin
/// process on [context]'s connection. Every handler that throws answers its
/// request with an error and writes the error to the editor's log; the
/// process loop goes on. [onShutdown] runs after `core.shutdown` is answered.
void installPluginProcessHandlers(
  ConnectedPluginProcessContext context,
  LuminaPluginProcess process, {
  required void Function() onShutdown,
}) {
  final c = context.connection;

  void on(String method, FutureOr<Object?> Function(Map<String, Object?> args) handler) {
    c.onRequest(method, (args) async {
      try {
        return await handler(args);
      } on PluginRemoteError catch (e) {
        if (e.code != PluginErrorCodes.unknownMethod && e.code != PluginErrorCodes.badArguments) {
          context.log('$method failed: ${e.message}', level: 'error');
        }
        rethrow;
      } catch (e, s) {
        context.log('$method failed: $e\n$s', level: 'error');
        rethrow;
      }
    });
  }

  String str(Map<String, Object?> args, String key) {
    final v = args[key];
    if (v is String) return v;
    throw PluginRemoteError(code: PluginErrorCodes.badArguments, message: '"$key" must be a string');
  }

  PluginProcessCommand command(Map<String, Object?> args) {
    final id = str(args, 'commandId');
    return context.commands[id] ??
        (throw PluginRemoteError(code: PluginErrorCodes.badArguments, message: 'no command "$id"'));
  }

  on(PluginMethods.ping, (_) => const <String, Object?>{});

  on(PluginMethods.call, (args) {
    final method = str(args, 'method');
    final handler = context.handlers[method];
    if (handler == null) {
      throw PluginRemoteError(
        code: PluginErrorCodes.unknownMethod,
        message: '${context.pluginName} has no handler for "$method"',
      );
    }
    final a = args['args'];
    return handler(a is Map ? a.cast<String, Object?>() : <String, Object?>{});
  });

  on(PluginMethods.command, (args) async {
    await command(args).run();
    return null;
  });

  on(PluginMethods.canExecute, (args) async {
    final check = command(args).canExecute;
    return check == null ? true : await check();
  });

  on(PluginMethods.mcpTool, (args) async {
    final name = str(args, 'tool');
    final prefix = '${context.pluginName}.';
    final tool = context.mcpTools[name] ??
        (name.startsWith(prefix) ? context.mcpTools[name.substring(prefix.length)] : null) ??
        (throw PluginRemoteError(code: PluginErrorCodes.badArguments, message: 'no MCP tool "$name"'));
    final a = args['arguments'];
    McpToolResult result;
    try {
      result = await tool.handler(McpArgs(a is Map ? a.cast<String, Object?>() : <String, Object?>{}));
    } on JsonRpcException catch (e) {
      throw PluginRemoteError(code: PluginErrorCodes.badArguments, message: e.message);
    } catch (e, s) {
      context.log('MCP tool $name failed: $e\n$s', level: 'error');
      result = McpToolResult.error('$name failed: $e');
    }
    return result.toJson();
  });

  on(PluginMethods.import, (args) async {
    final id = str(args, 'importerId');
    final importer = context.importers[id] ??
        (throw PluginRemoteError(code: PluginErrorCodes.badArguments, message: 'no importer "$id"'));
    try {
      final path = await importer.import(File(str(args, 'sourcePath')), str(args, 'targetDirectory'));
      return {'success': true, 'assetPath': path};
    } catch (e) {
      final message = e is PluginImportError ? e.message : '$e';
      context.log('import with $id failed: $message', level: 'error');
      return {'success': false, 'error': message};
    }
  });

  on(PluginMethods.console, (args) async {
    final name = str(args, 'name');
    final cmd = context.consoleCommands[name] ??
        (throw PluginRemoteError(code: PluginErrorCodes.badArguments, message: 'no console command "$name"'));
    await cmd.handler([...((args['args'] as List?) ?? const []).map((e) => '$e')]);
    return null;
  });

  on(PluginMethods.viewEvent, (args) async {
    final event = PluginViewEvent.fromJson(args);
    final view = context.views[event.viewId] ??
        (throw PluginRemoteError(code: PluginErrorCodes.badArguments, message: 'no view "${event.viewId}"'));
    await view.panel.onEvent(event, view);
    return null;
  });

  on(PluginMethods.projectOpened, (args) async {
    final project = EditorProjectInfo(name: str(args, 'name'), dir: str(args, 'dir'));
    context.projectOpened(project, storeDir: args['storageDir'] as String?);
    await context.level.refresh();
    await process.onProjectOpened(project);
    return null;
  });

  on(PluginMethods.projectClosing, (_) async {
    try {
      await process.onProjectClosing();
    } finally {
      context.projectClosed();
    }
    return null;
  });

  on(PluginMethods.shutdown, (_) async {
    try {
      await process.onShutdown();
    } finally {
      // After the answer is written: the handler's return value is sent in
      // the microtask that follows, the shutdown runs in a later event.
      Timer.run(onShutdown);
    }
    return null;
  });

  c.onNotification(PluginMethods.settings, (args) {
    final s = args['settings'];
    context.settingsChanged(s is Map ? s.cast<String, Object?>() : const {});
  });

  c.onNotification(PluginMethods.levelChanged, (_) {
    context.level.levelChanged();
  });
}

/// Thrown by a [PluginProcessImporter.import] to fail with [message] as the
/// error the editor shows (any other exception is shown as its `toString`).
class PluginImportError implements Exception {
  const PluginImportError(this.message);
  final String message;

  @override
  String toString() => message;
}
