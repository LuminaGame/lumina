import 'dart:io';
import 'package:lumina/data/models/lumina_plugin_descriptor.dart';

class PluginHostPatcherService {
  final String beginMarker = '  # BEGIN LUMINA PLUGINS (generated)';
  final String endMarker = '  # END LUMINA PLUGINS';

  Future<void> patchPubspec(Directory hostRoot, List<LuminaPluginDescriptor> enabledCodePlugins) async {
    final pubspecFile = File('${hostRoot.path}/pubspec.yaml');
    if (!pubspecFile.existsSync()) return;

    final backup = File('${pubspecFile.path}.lmbak');
    await backup.writeAsBytes(await pubspecFile.readAsBytes());

    String content = await pubspecFile.readAsString();
    if (!content.endsWith('\n')) content += '\n';

    final pluginBlock = StringBuffer();
    for (final plugin in enabledCodePlugins) {
      if (plugin.isContentOnly) continue;
      pluginBlock.writeln('  ${plugin.name}:');
      pluginBlock.writeln('    path: ${plugin.pluginDir.path}'); // or relative
    }

    final beginIdx = content.indexOf(beginMarker);
    final endIdx = content.indexOf(endMarker);

    if (beginIdx != -1 && endIdx != -1) {
      // Replace existing
      final before = content.substring(0, beginIdx + beginMarker.length + 1);
      final after = content.substring(endIdx);
      content = before + pluginBlock.toString() + after;
    } else {
      // Insert after dependencies:
      final depsIdx = content.indexOf('dependencies:');
      if (depsIdx != -1) {
        final insertIdx = content.indexOf('\n', depsIdx) + 1;
        final before = content.substring(0, insertIdx);
        final after = content.substring(insertIdx);
        content = '$before$beginMarker\n$pluginBlock$endMarker\n$after';
      }
    }

    await pubspecFile.writeAsString(content);
  }

  /// Migration: removes a generated plugin block that an older
  /// editor spliced into the engine's `lumina_ui/pubspec.yaml` (project plugins
  /// now live in each project's editor host). Keeps a `.lmbak` backup.
  /// Returns whether a block was removed.
  Future<bool> removeEnginePluginBlock(File pubspec) async {
    if (!pubspec.existsSync()) return false;
    final content = await pubspec.readAsString();
    final begin = content.indexOf(beginMarker);
    final end = content.indexOf(endMarker);
    if (begin == -1 || end == -1 || end < begin) return false;
    await File('${pubspec.path}.lmbak').writeAsString(content);
    var lineStart = content.lastIndexOf('\n', begin) + 1;
    var afterEnd = content.indexOf('\n', end);
    afterEnd = afterEnd == -1 ? content.length : afterEnd + 1;
    // The blank line the patcher put before the block goes too.
    if (lineStart >= 2 && content.substring(lineStart - 2, lineStart) == '\n\n') lineStart -= 1;
    await pubspec.writeAsString(content.substring(0, lineStart) + content.substring(afterEnd));
    return true;
  }

  Future<void> generateRegistrar(Directory hostRoot, List<LuminaPluginDescriptor> enabledCodePlugins) async {
    final libDir = Directory('${hostRoot.path}/lib/generated');
    if (!libDir.existsSync()) {
      libDir.createSync(recursive: true);
    }
    await File('${libDir.path}/plugin_registrar.dart').writeAsString(registrarSource(enabledCodePlugins));
  }

  /// The registrar library: `kEnabledPlugins` (one instance per editor module)
  /// and `registerAllPlugins`. Deterministic for a given plugin list (it is
  /// written into each project's editor host).
  String registrarSource(List<LuminaPluginDescriptor> enabledCodePlugins) {
    final sb = StringBuffer();
    sb.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    sb.writeln();
    sb.writeln("import 'package:lumina_editor_api/lumina_editor_api.dart';");
    sb.writeln();
    
    final modules = <PluginModuleDescriptor>[];
    for (final plugin in enabledCodePlugins) {
      if (plugin.isContentOnly) continue;
      for (final module in plugin.modules) {
        if (module.type == PluginModuleType.editor) {
          var entry = module.entryLibrary;
          if (entry.startsWith('lib/')) {
            entry = entry.substring(4);
          }
          if (entry.endsWith('.dart')) {
            entry = entry.substring(0, entry.length - 5);
          }
          sb.writeln("import 'package:${plugin.name}/$entry.dart' as ${plugin.name}_plugin;");
          modules.add(module);
        }
      }
    }
    
    sb.writeln();
    sb.writeln('final List<LuminaEditorPlugin> kEnabledPlugins = [');
    for (final module in modules) {
      // Find the plugin for this module to get the prefix
      final plugin = enabledCodePlugins.firstWhere((p) => p.modules.contains(module));
      sb.writeln('  ${plugin.name}_plugin.${module.registrationClass}(),');
    }
    sb.writeln('];');
    sb.writeln();
    sb.writeln('void registerAllPlugins(LuminaEditorContext context) {');
    sb.writeln('  for (final p in kEnabledPlugins) {');
    sb.writeln('    final dyn = context as dynamic;');
    sb.writeln('    try {');
    sb.writeln('      dyn.beginRegistration(p.pluginName);');
    sb.writeln('    } catch (_) {}');
    sb.writeln('    try {');
    sb.writeln('      p.register(context);');
    sb.writeln('    } finally {');
    sb.writeln('      try {');
    sb.writeln('        dyn.endRegistration();');
    sb.writeln('      } catch (_) {}');
    sb.writeln('    }');
    sb.writeln('  }');
    sb.writeln('}');
    return sb.toString();
  }
}
