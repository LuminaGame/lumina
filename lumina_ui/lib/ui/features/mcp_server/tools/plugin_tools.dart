import 'dart:io';

import 'package:lumina/data/models/lumina_plugin_descriptor.dart' show PluginOrigin;
import 'package:lumina/data/services/plugin_registry_service.dart';
import 'package:lumina/data/services/plugin_template_generator_service.dart';

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/plugin_manager/view_models/plugin_manager_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_jobs.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';

/// What `set_plugin_enabled` says when a code plugin changed: the editor
/// needs a restart the agent must never trigger (the user owns it).
const String kMcpPluginRestartMessage =
    'Restart the editor to load it (the Restart Editor banner). The agent cannot restart it.';

/// Edit → Plugins as MCP tools (group `plugin`): list the
/// plugins with their state, enable / disable one (reporting when a restart
/// is needed, never restarting), and File → New Plugin as a job.
void registerPluginTools(McpToolRegistry registry, EditorViewModel vm, McpJobRegistry jobs) {
  const plugin = {McpToolGroups.plugin};

  PluginManagerViewModel manager() => PluginManagerViewModel(registryService: vm.pluginRegistry);

  Map<String, Object?> entryJson(PluginEntry e) {
    final d = e.descriptor;
    return {
      'name': d.name,
      'friendly_name': d.friendlyName ?? d.name,
      'version': d.version.toString(),
      'category': d.category,
      'origin': d.origin.name,
      'enabled': e.enabled,
      'content_only': d.isContentOnly,
      'restart_pending': e.restartPending,
      'dependencies': [for (final dep in d.dependencies) {'name': dep.name, 'version': dep.version.toString()}],
      'issues': [for (final i in e.issues) {'type': i.type.name, 'message': i.message}],
      'plugin_dir': d.pluginDir.path,
      if (e.overrides.isNotEmpty)
        'overrides': [for (final o in e.overrides) {'origin': o.shadowedOrigin.name, 'manifest': o.shadowedManifestPath}],
    };
  }

  void openPluginManager() => vm.openSubEditorTab('plugins', title: 'Plugins');

  registry.registerAll([
    McpTool(
      name: 'list_plugins',
      risk: McpToolRisk.readOnly,
      groups: plugin,
      title: 'List plugins',
      description: 'The Plugin Manager\'s list: {name, friendly_name, version, category, origin (engine|project|user), '
          'enabled, content_only, restart_pending, dependencies, issues, overrides (the same-named copies of lower roots '
          'this one replaces, when any)}, plus restart_required (a code plugin changed '
          'since the editor started) and scan_errors. Filters as in the manager: group installed (project + user) or '
          'built_in (engine), category, query (name, friendly name, description, author).',
      inputSchema: McpSchema.object({
        'group': McpSchema.string('installed or built_in; default all.', enumValues: const ['installed', 'built_in']),
        'category': McpSchema.string('Only this category, e.g. "Utilities".'),
        'query': McpSchema.string('Case-insensitive text to match.'),
      }),
      handler: (args) async {
        await vm.pluginsScanned;
        final m = manager();
        final group = switch (args.optionalString('group')) {
          'installed' => 'INSTALLED',
          'built_in' => 'BUILT-IN',
          _ => 'ALL',
        };
        m.selectCategory(group, args.optionalString('category') ?? 'ALL PLUGINS');
        m.searchQuery = args.optionalString('query') ?? '';
        final entries = m.entries..sort((a, b) => a.descriptor.name.compareTo(b.descriptor.name));
        final result = {
          'count': entries.length,
          'plugins': [for (final e in entries) entryJson(e)],
          'restart_required': vm.pluginRestartRequired,
          'scan_errors': [for (final e in m.scanErrors) {'file': e.filePath, 'message': e.message}],
        };
        m.dispose();
        return McpToolResult.json(result);
      },
    ),
    McpTool(
      name: 'set_plugin_enabled',
      risk: McpToolRisk.mutating,
      groups: plugin,
      idempotent: true,
      title: 'Set plugin enabled',
      description: 'The Plugin Manager\'s Enabled checkbox: enables (with the dependencies it needs) or disables a '
          'plugin; the choice is saved in the .lmproject. A content-only plugin applies at once (its content/ root '
          'appears in the Content Browser); a code plugin needs an editor restart: restart_required is true and the '
          'Restart Editor banner shows. The agent never restarts the editor — tell the user. Disabling a plugin others '
          'depend on needs cascade: true.',
      inputSchema: McpSchema.object({
        'name': McpSchema.string('The plugin\'s name (list_plugins), e.g. "lumina_plugin_pcg".'),
        'enabled': McpSchema.boolean('true to enable, false to disable.'),
        'cascade': McpSchema.boolean('Disabling: also disable the plugins that depend on it. Default false.'),
      }, required: ['name', 'enabled']),
      handler: (args) async {
        await vm.pluginsScanned;
        final name = args.string('name');
        final names = [for (final e in vm.pluginRegistry.entries) e.descriptor.name]..sort();
        if (!names.contains(name)) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'No plugin "$name". Plugins: ${names.join(', ')}.');
        }
        final enabled = args.boolean('enabled');
        final result = await vm.enablePlugin(name, enabled, cascade: args.boolean('cascade'));
        openPluginManager();
        final issues = [for (final i in result.issues) {'plugin': name, 'type': i.type.name, 'message': i.message}];
        if (issues.isNotEmpty) {
          final requiredBy = result.issues.any((i) => i.type == PluginIssueType.requiredBy);
          return McpToolResult.error('Could not ${enabled ? 'enable' : 'disable'} $name:\n'
              '${result.issues.map((i) => '- ${i.message}').join('\n')}\n'
              '${requiredBy ? 'Pass cascade: true to disable those plugins too, or disable them first.' : 'Install or enable the dependencies listed, then try again.'}');
        }
        final entry = vm.pluginRegistry.entries.firstWhere((e) => e.descriptor.name == name);
        return McpToolResult.json({
          'name': name,
          'enabled': entry.enabled,
          'restart_required': result.restartRequired,
          'issues': issues,
          'message': result.restartRequired
              ? kMcpPluginRestartMessage
              : '${entry.descriptor.friendlyName ?? name} is ${entry.enabled ? 'enabled' : 'disabled'}; no restart needed.',
          'content_root': entry.enabled && entry.descriptor.isContentOnly ? '${entry.descriptor.pluginDir.path}/content' : null,
        });
      },
    ),
    McpTool(
      name: 'remove_plugin',
      risk: McpToolRisk.destructive,
      groups: plugin,
      title: 'Remove plugin',
      description: 'The Plugin Manager\'s Remove: deletes a user or project plugin (never a built-in). Call it with '
          'dry_run: true first and show the user the list: {plugin_dir, linked_from (a symlink / junction: only the '
          'link is removed), file_count, bytes, every_project (a user plugin is removed for every project on this '
          'machine), enabled, also_disabled (enabled plugins that depend on it), restart_required, '
          'loaded_until_restart, marketplace (its license record is removed too), comes_back (a plugin of the same '
          'name that takes its place), data[{kind, path, file_count, bytes}]}. Without dry_run it removes the folder '
          '(set aside, then deleted; nothing is removed when a file in it is locked), disables it and its dependents '
          'in the .lmproject when it was enabled (the Restart Editor banner shows; the agent never restarts), and '
          'deletes the data folders only with delete_data: true. Result {removed, removed_paths, not_removed, '
          'disabled, restart_required}.',
      inputSchema: McpSchema.object({
        'name': McpSchema.string('The plugin\'s name (list_plugins), e.g. "my_tools".'),
        'dry_run': McpSchema.boolean('true: return what would be deleted and delete nothing. Default false.'),
        'delete_data': McpSchema.boolean('Also delete its saved data (the data folders the dry run lists). Default false.'),
      }, required: ['name']),
      handler: (args) async {
        await vm.pluginsScanned;
        final name = args.string('name');
        final entry = vm.pluginRegistry.entries.where((e) => e.descriptor.name == name).firstOrNull;
        if (entry == null) {
          final names = [for (final e in vm.pluginRegistry.entries) e.descriptor.name]..sort();
          throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'No plugin "$name". Plugins: ${names.join(', ')}.');
        }
        if (entry.descriptor.origin == PluginOrigin.engine) {
          throw JsonRpcException(JsonRpcErrorCode.invalidParams,
              '$name is a built-in plugin; it ships with the engine and cannot be removed. Disable it with set_plugin_enabled.');
        }
        final m = PluginManagerViewModel(
          registryService: vm.pluginRegistry,
          onSetEnabled: (n, enabled, {cascade = false}) => vm.enablePlugin(n, enabled, cascade: cascade),
          onPluginsChanged: vm.rescanPlugins,
          isPluginLoaded: vm.isPluginLoaded,
        );
        try {
          final plan = m.planRemoval(entry);
          if (args.boolean('dry_run')) {
            return McpToolResult.json({'dry_run': true, ...plan.toJson()});
          }
          final result = await m.removePlugin(plan, deleteData: args.boolean('delete_data'));
          openPluginManager();
          if (!result.removed) {
            return McpToolResult.error('Nothing was removed: ${result.notRemoved.join('; ')}');
          }
          return McpToolResult.json({
            'name': name,
            ...result.toJson(),
            'message': result.restartRequired
                ? '$name was removed and disabled. $kMcpPluginRestartMessage'
                : plan.loaded
                    ? '$name was removed; its code stays loaded until the editor restarts.'
                    : '$name was removed.',
          });
        } finally {
          m.dispose();
        }
      },
    ),
    McpTool(
      name: 'create_plugin',
      risk: McpToolRisk.external,
      groups: plugin,
      title: 'Create plugin',
      description: 'File → New Plugin (the wizard) as a job (kind create_plugin): generates the plugin under the '
          'project\'s plugins/ from a template — blank / editorPanel / importer are Dart packages (the generator runs '
          'dart pub get and dart analyze), contentOnly a content folder. The job log is the generator\'s; its result '
          '{plugin_dir, success, failure_output}. The plugin is not enabled: call set_plugin_enabled.',
      inputSchema: McpSchema.object({
        'name': McpSchema.string('The package name: lowercase letters, digits and underscores, e.g. "lumina_plugin_tools".'),
        'template': McpSchema.string('The template.', enumValues: [for (final t in PluginTemplateType.values) t.name]),
        'friendly_name': McpSchema.string('The display name; default from the name.'),
        'author': McpSchema.string('The author.'),
        'description': McpSchema.string('What the plugin does.'),
        'category': McpSchema.string('The Plugin Manager category; default "Utilities".'),
        'isolated': McpSchema.boolean('Scaffold it to run in its own process (a supervised process part plus a UI '
            'shell; a crash or hang there never takes the editor down). Not for contentOnly. Default false.'),
      }, required: ['name', 'template']),
      handler: (args) async {
        await vm.pluginsScanned;
        final m = manager();
        final name = args.string('name').trim();
        final invalid = m.validateNewPluginName(name);
        if (invalid != null) {
          m.dispose();
          throw JsonRpcException(JsonRpcErrorCode.invalidParams, invalid);
        }
        final template = PluginTemplateType.values.byName(args.string('template'));
        final isolated = args.boolean('isolated');
        if (isolated && template == PluginTemplateType.contentOnly) {
          m.dispose();
          throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'A contentOnly plugin has no code to isolate: drop "isolated".');
        }
        final friendly = args.optionalString('friendly_name')?.trim();
        final spec = PluginTemplateSpec(
          templateType: template,
          name: name,
          friendlyName: friendly == null || friendly.isEmpty ? PluginTemplateGeneratorService.nameToFriendly(name) : friendly,
          author: args.optionalString('author') ?? '',
          description: args.optionalString('description') ?? '',
          category: args.optionalString('category') ?? 'Utilities',
          isolated: isolated,
        );
        if (template != PluginTemplateType.contentOnly) {
          try {
            PluginManagerViewModel.resolveEditorApiRoot();
          } on StateError catch (e) {
            m.dispose();
            return McpToolResult.error(e.message);
          }
        }
        openPluginManager();
        final job = jobs.start(
          'create_plugin',
          title: 'New Plugin $name (${template.name})',
          exclusive: 'plugin:$name',
          run: (job) async {
            try {
              final result = await m.createPlugin(
                spec,
                projectRoot: Directory(vm.projectDirPath),
                onLog: (line) => job.addLog(line, source: 'PluginWizard'),
              );
              final out = {
                'plugin_dir': result.pluginDir?.path,
                'success': result.success,
                'failure_output': result.failureOutput,
                'enabled': false,
              };
              if (!result.success) throw McpJobFailure(result.failureOutput ?? 'Plugin generation failed.', result: out);
              await vm.rescanPlugins();
              return out;
            } finally {
              m.dispose();
            }
          },
        );
        return McpToolResult.json({'job_id': job.id, 'state': job.state.name, 'name': name, 'template': template.name});
      },
    ),
  ]);
}
