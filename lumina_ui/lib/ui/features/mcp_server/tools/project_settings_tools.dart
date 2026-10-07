import 'dart:convert';

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:lumina_editor_data/lumina_editor.dart';

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_jobs.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';

/// The key an agent names (`W`, `Space`, `KeyW`, `LeftShift`, `MouseX`,
/// `GamepadFaceButtonBottom`), or a `-32602` listing examples.
LuminaKey mcpKeyNamed(String name, {String argument = 'key'}) {
  final key = LuminaKey.fromName(name);
  if (!LuminaKey.values.contains(key)) {
    throw JsonRpcException(JsonRpcErrorCode.invalidParams,
        'Unknown $argument "$name". Key names look like "W", "Space", "KeyW", "LeftShift", "Enter", "F5", "MouseLeft", '
        '"MouseX", "GamepadFaceButtonBottom", "GamepadLeftStickX" (the id, the bare name or Flutter\'s label).');
  }
  return key;
}

/// What the Project Settings key picker stores as a mapping's `key` label.
String mcpKeyLabel(LuminaKey key) {
  final id = key.keyId;
  if (id != null && id > 0) {
    final label = LogicalKeyboardKey.findKeyByKeyId(id)?.keyLabel;
    if (label != null && label.trim().isNotEmpty) return label;
  }
  return key.id;
}

/// A mapping's key as an agent reads it: the runtime key id when there is
/// one, else the manifest's label.
String _mappingKeyName(ProjectInputMapping m) => LuminaKey.fromKeyId(m.keyId)?.id ?? m.keyLabel;

/// Project Settings (Edit → Project Settings) as MCP tools (group
/// `settings`): read every category; stage changes on the Project
/// Settings tab's own working copy (the tab shows them, dirty, as if typed);
/// edit the input actions and mapping contexts; the project icon and the web
/// loading logo; Apply & Save or Revert. Only `apply_project_settings` (and
/// `set_widget_library`) write the `.lmproject`, as the tab's Apply does;
/// plugin settings and unknown manifest keys ride along untouched.
void registerProjectSettingsTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions, McpJobRegistry jobs) {
  const settings = {McpToolGroups.settings};

  Map<String, Object?> input(LuminaProject p) => {
        'actions': [for (final a in p.input.actions) {'name': a.name, 'value_type': a.valueType.name}],
        'mapping_contexts': [
          for (final c in p.input.mappingContexts)
            {
              'name': c.name,
              'priority': c.priority,
              'mappings': [
                for (final m in c.mappings)
                  {
                    'action': m.action,
                    'key': _mappingKeyName(m),
                    'key_label': m.keyLabel,
                    'scale': m.scale,
                    'axis': m.axis,
                    // The manifest has no per-mapping modifiers / triggers yet:
                    // the binder derives the axis placement from scale + axis
                    // and uses the implicit Down trigger.
                    'modifiers': const <Object>[],
                    'triggers': const <Object>[],
                  },
              ],
            },
        ],
      };

  Map<String, Object?> sections(ProjectSettingsViewModel ps, LuminaProject p) {
    final s = p.settings;
    final w = p.packaging.webLoadingStyle;
    return {
      'description': {'project_name': p.projectName, 'description': p.description, 'engine_version': p.engineVersion},
      'scalability': {
        'quality_preset': s.qualityPreset,
        'view_distance': s.scalability.viewDistance,
        'shadow_quality': s.scalability.shadowQuality,
        'anti_aliasing': s.scalability.antiAliasing,
        'post_processing': s.scalability.postProcessing,
        'texture_quality': s.scalability.textureQuality,
        'shading_quality': s.scalability.shadingQuality,
        'target_fps': s.targetFps,
        'vsync': s.vsyncEnabled,
      },
      'input': input(p),
      'maps_and_modes': {
        'editor_startup_map': p.mapsAndModes.editorStartupMap,
        'game_default_map': p.mapsAndModes.gameDefaultMap,
        'default_game_mode': p.mapsAndModes.defaultGameMode,
        'default_pawn_class': p.mapsAndModes.defaultPawnClass,
        'accepted_maps': [for (final l in ps.levels) l.relativePath],
        'accepted_game_modes': ps.gameModeClasses,
        'accepted_pawn_classes': ps.pawnClasses,
      },
      'physics': {'gravity_z': p.physics.gravityZ, 'fixed_timestep': p.physics.fixedTimestep},
      'packaging': {'targets': p.packaging.targets, 'output_dir': p.packaging.outputDir, 'known_targets': kPackagingPlatforms},
      'branding': {'icon': p.branding.icon, 'icon_background': p.branding.iconBackground, 'uses_default_icon': p.branding.usesDefaultIcon},
      'web_loading': {
        'background': w.background,
        'gradient': w.gradient,
        'accent': w.accent,
        'text': w.text,
        'logo': w.logo,
        'title': w.title,
        'subtitle': w.subtitle,
        'progress_style': w.progressStyle,
        'fade_ms': w.fadeMs,
      },
      'ui': {'widget_library': p.ui.widgetLibrary, 'accepted': kUmgWidgetLibraries},
    };
  }

  /// The view model's validation category behind each tool category.
  const categoryOf = {
    'description': ProjectSettingsCategory.description,
    'scalability': ProjectSettingsCategory.graphics,
    'input': ProjectSettingsCategory.input,
    'maps_and_modes': ProjectSettingsCategory.mapsAndModes,
    'physics': ProjectSettingsCategory.physics,
    'packaging': ProjectSettingsCategory.packaging,
    'branding': ProjectSettingsCategory.description,
    'web_loading': ProjectSettingsCategory.packaging,
    'ui': ProjectSettingsCategory.userInterface,
  };

  /// Every category with `dirty` (working copy ≠ disk) and its errors.
  Map<String, Object?> read(ProjectSettingsViewModel ps, {String? only}) {
    final working = sections(ps, ps.project);
    final disk = ps.onDiskProject == null ? working : sections(ps, ps.onDiskProject!);
    final errors = ps.validationErrors;
    final warnings = ps.validationWarnings;
    return {
      for (final e in working.entries)
        if (only == null || only == e.key)
          e.key: {
            ...(e.value as Map<String, Object?>),
            'dirty': jsonEncode(e.value) != jsonEncode(disk[e.key]),
            'validation_errors': errors[categoryOf[e.key]] ?? const <String>[],
            'validation_warnings': warnings[categoryOf[e.key]] ?? const <String>[],
          },
      'dirty': ps.isDirty,
      'manifest_path': ps.manifestPath,
    };
  }

  List<String> allErrors(ProjectSettingsViewModel ps) => ps.validationErrors.values.expand((e) => e).toList();

  // --- set_project_settings keys → the tab's setters ------------------------

  Never bad(String key, String wanted) =>
      throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'set_project_settings: "$key" must be $wanted');
  String str(String key, Object? v) => v is String ? v : bad(key, 'a string');
  num numb(String key, Object? v) => v is num ? v : bad(key, 'a number');
  int integer(String key, Object? v) => v is num && v == v.roundToDouble() ? v.toInt() : bad(key, 'an integer');
  bool flag(String key, Object? v) => v is bool ? v : bad(key, 'true or false');
  String oneOf(String key, Object? v, List<String> allowed) {
    final s = str(key, v).toLowerCase();
    return allowed.contains(s) ? s : bad(key, 'one of ${allowed.join(', ')}');
  }

  const tiers = ['low', 'medium', 'high', 'epic', 'cinematic'];
  const aaModes = ['none', 'fxaa', 'msaa', 'taa'];
  void Function(ProjectSettingsViewModel, Object?) tier(String field, String key) =>
      (ps, v) => ps.setScalabilityField(field, oneOf(key, v, field == 'antiAliasing' ? aaModes : tiers));
  void Function(ProjectSettingsViewModel, Object?) hex(String key, void Function(ProjectSettingsViewModel, String) set,
          {bool allowEmpty = true}) =>
      (ps, v) {
        final s = str(key, v).trim();
        if (!(allowEmpty && s.isEmpty) && ProjectBrandingSettings.parseHexColor(s) == null) bad(key, 'a #RRGGBB colour');
        set(ps, s);
      };

  final setters = <String, void Function(ProjectSettingsViewModel ps, Object? value)>{
    'description.project_name': (ps, v) => ps.setProjectName(str('description.project_name', v)),
    'description.description': (ps, v) => ps.setDescription(str('description.description', v)),
    'scalability.quality_preset': (ps, v) => ps.setQualityPreset(oneOf('scalability.quality_preset', v, tiers)),
    'scalability.view_distance': tier('viewDistance', 'scalability.view_distance'),
    'scalability.shadow_quality': tier('shadowQuality', 'scalability.shadow_quality'),
    'scalability.anti_aliasing': tier('antiAliasing', 'scalability.anti_aliasing'),
    'scalability.post_processing': tier('postProcessing', 'scalability.post_processing'),
    'scalability.texture_quality': tier('textureQuality', 'scalability.texture_quality'),
    'scalability.shading_quality': tier('shadingQuality', 'scalability.shading_quality'),
    'scalability.target_fps': (ps, v) => ps.setTargetFps(integer('scalability.target_fps', v)),
    'scalability.vsync': (ps, v) => ps.setVSync(flag('scalability.vsync', v)),
    'maps_and_modes.editor_startup_map': (ps, v) => ps.setEditorStartupMap(str('maps_and_modes.editor_startup_map', v)),
    'maps_and_modes.game_default_map': (ps, v) => ps.setGameDefaultMap(str('maps_and_modes.game_default_map', v)),
    'maps_and_modes.default_game_mode': (ps, v) {
      final mode = str('maps_and_modes.default_game_mode', v);
      if (!ps.gameModeClasses.contains(mode)) bad('maps_and_modes.default_game_mode', 'one of ${ps.gameModeClasses.join(', ')}');
      ps.setDefaultGameMode(mode);
    },
    'maps_and_modes.default_pawn_class': (ps, v) {
      final pawn = str('maps_and_modes.default_pawn_class', v);
      if (!ps.pawnClasses.contains(pawn)) {
        bad('maps_and_modes.default_pawn_class', '"" (the game mode\'s pawn) or one of ${ps.pawnClasses.where((c) => c.isNotEmpty).join(', ')}');
      }
      ps.setDefaultPawnClass(pawn);
    },
    'physics.gravity_z': (ps, v) => ps.setGravityZ(numb('physics.gravity_z', v).toDouble()),
    'physics.fixed_timestep': (ps, v) => ps.setFixedTimestep(numb('physics.fixed_timestep', v).toDouble()),
    'packaging.targets': (ps, v) {
      if (v is! List || v.any((t) => t is! String || !kPackagingPlatforms.contains(t))) {
        bad('packaging.targets', 'an array of ${kPackagingPlatforms.join(', ')}');
      }
      for (final t in kPackagingPlatforms) {
        ps.setTargetSelected(t, v.contains(t));
      }
    },
    'packaging.output_dir': (ps, v) => ps.setOutputDir(str('packaging.output_dir', v)),
    'branding.icon_background': hex('branding.icon_background', (ps, s) => ps.setIconBackground(s), allowEmpty: false),
    'web_loading.background': hex('web_loading.background', (ps, s) => ps.setWebLoadingBackground(s)),
    'web_loading.gradient': hex('web_loading.gradient', (ps, s) => ps.setWebLoadingGradient(s)),
    'web_loading.gradient_enabled': (ps, v) => ps.setWebLoadingGradientEnabled(flag('web_loading.gradient_enabled', v)),
    'web_loading.accent': hex('web_loading.accent', (ps, s) => ps.setWebLoadingAccent(s), allowEmpty: false),
    'web_loading.text': hex('web_loading.text', (ps, s) => ps.setWebLoadingText(s), allowEmpty: false),
    'web_loading.title': (ps, v) => ps.setWebLoadingTitle(str('web_loading.title', v)),
    'web_loading.subtitle': (ps, v) => ps.setWebLoadingSubtitle(str('web_loading.subtitle', v)),
    'web_loading.progress_style': (ps, v) =>
        ps.setWebLoadingProgressStyle(oneOf('web_loading.progress_style', v, ProjectWebLoadingStyle.progressStyles)),
    'web_loading.fade_ms': (ps, v) {
      final ms = integer('web_loading.fade_ms', v);
      if (ms < 0 || ms > ProjectWebLoadingStyle.maxFadeMs) bad('web_loading.fade_ms', 'between 0 and ${ProjectWebLoadingStyle.maxFadeMs}');
      ps.setWebLoadingFadeMs(ms);
    },
  };

  String? playNote() => vm.isPlaying
      ? 'Play-In-Editor binds input and settings when it starts: this change takes effect on the next start_pie.'
      : null;

  // --- edit_project_input ---------------------------------------------------

  int actionIndex(ProjectSettingsViewModel ps, String name) {
    final i = ps.project.input.actions.indexWhere((a) => a.name == name);
    if (i < 0) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'No input action "$name". Actions: ${ps.project.input.actions.map((a) => a.name).join(', ')}.');
    }
    return i;
  }

  int contextIndex(ProjectSettingsViewModel ps, String name) {
    final i = ps.project.input.mappingContexts.indexWhere((c) => c.name == name);
    if (i < 0) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'No mapping context "$name". Contexts: ${ps.project.input.mappingContexts.map((c) => c.name).join(', ')}.');
    }
    return i;
  }

  ProjectInputValueType valueType(String name) => ProjectInputValueType.values.firstWhere((t) => t.name == name,
      orElse: () => throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'value_type must be one of ${ProjectInputValueType.values.map((t) => t.name).join(', ')}'));

  String axisOf(McpArgs args) {
    final axis = (args.optionalString('axis') ?? '').toUpperCase();
    if (!const ['', 'X', 'Y'].contains(axis)) {
      throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'axis must be "X", "Y" or "" (a digital action)');
    }
    return axis;
  }

  final ops = [
    'add_action', 'update_action', 'remove_action', 'add_context', 'update_context', 'remove_context', //
    'add_mapping', 'update_mapping', 'remove_mapping',
  ];

  McpToolResult staged(ProjectSettingsViewModel ps, {String? category, Map<String, Object?> extra = const {}}) {
    final note = playNote();
    return McpToolResult.json({
      'staged': true,
      ...extra,
      'note': ?note,
      'validation_errors': allErrors(ps),
      'settings': read(ps, only: category),
    });
  }

  registry.registerAll([
    McpTool(
      name: 'get_project_settings',
      risk: McpToolRisk.readOnly,
      groups: settings,
      title: 'Get Project Settings',
      description: 'Every Project Settings category (or one): description, scalability, input (actions; mapping contexts '
          'with priority and mappings {action, key, scale, axis, modifiers, triggers}), maps_and_modes (with the accepted '
          'values), physics (gravity_z cm/s², fixed_timestep s), packaging, branding, web_loading, ui — each with dirty '
          'and validation_errors. Values are the Project Settings tab\'s working copy when it has unapplied edits, else '
          'the .lmproject.',
      inputSchema: McpSchema.object({
        'category': McpSchema.string('Only this category.', enumValues: categoryOf.keys.toList()),
      }),
      handler: (args) async {
        final bound = sessions.boundProjectSettings;
        final ps = bound ?? ProjectSettingsViewModel(projectDirPath: vm.projectDirPath, initialProject: vm.project);
        try {
          if (bound == null) {
            await ps.load();
          } else {
            ps.refreshChoices();
          }
          return McpToolResult.json(read(ps, only: args.optionalString('category')));
        } finally {
          if (bound == null) ps.dispose();
        }
      },
    ),
    McpTool(
      name: 'set_project_settings',
      risk: McpToolRisk.mutating,
      groups: settings,
      idempotent: true,
      title: 'Stage Project Settings',
      description: 'Stages changes on the Project Settings tab (it opens and turns dirty, as if typed); nothing is saved '
          'until apply_project_settings. changes is a flat patch of dotted keys, e.g. {"physics.gravity_z": -490, '
          '"scalability.quality_preset": "high", "packaging.targets": ["linux", "web"], "web_loading.accent": "#FF8800"}. '
          'Keys: ${setters.keys.join(', ')}. The widget library changes only through set_widget_library. Returns the '
          'new validation_errors and the touched categories.',
      inputSchema: McpSchema.object({
        'changes': {'type': 'object', 'description': 'Dotted key → value (see the description for the keys).'},
      }, required: ['changes']),
      handler: (args) async {
        final changes = args.optionalObject('changes')!;
        if (changes.isEmpty) throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'changes is empty');
        for (final key in changes.keys) {
          if (key == 'ui.widget_library') {
            throw const JsonRpcException(JsonRpcErrorCode.invalidParams,
                '"ui.widget_library" is changed by set_widget_library (it runs flutter pub get, so it is its own tool).');
          }
          if (!setters.containsKey(key)) {
            throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'Unknown setting "$key". Accepted keys: ${setters.keys.join(', ')}.');
          }
        }
        final ps = await sessions.projectSettings();
        for (final e in changes.entries) {
          setters[e.key]!(ps, e.value);
        }
        final touched = {for (final k in changes.keys) k.split('.').first};
        final all = read(ps);
        final note = playNote();
        return McpToolResult.json({
          'staged': true,
          'dirty': ps.isDirty,
          'note': ?note,
          'validation_errors': allErrors(ps),
          'settings': {for (final c in touched) c: all[c]},
        });
      },
    ),
    McpTool(
      name: 'edit_project_input',
      risk: McpToolRisk.mutating,
      groups: settings,
      idempotent: false,
      removesContent: true,
      title: 'Edit input actions and mappings',
      description: 'Stages an Enhanced Input edit on the Project Settings tab (Input category). op: add_action {action, '
          'value_type?: digital|axis1D|axis2D}, update_action {action, new_name?, value_type?}, remove_action {action} '
          '(its mappings go too), add_context {context, priority?}, update_context {context, new_name?, priority?}, '
          'remove_context {context}, add_mapping {context, action, key, scale?, axis?: X|Y}, update_mapping {context, '
          'action, key, new_key?, new_action?, scale?, axis?}, remove_mapping {context, action, key}. Actions and '
          'contexts by name, keys by name ("W", "Space", "LeftShift", "MouseX", "GamepadFaceButtonBottom"). Apply with '
          'apply_project_settings; a running PIE picks it up on the next start_pie.',
      inputSchema: McpSchema.object({
        'op': McpSchema.string('The edit.', enumValues: ops),
        'action': McpSchema.string('The input action name (IA_Jump).'),
        'context': McpSchema.string('The mapping context name (Gameplay).'),
        'key': McpSchema.string('The key of the mapping.'),
        'new_name': McpSchema.string('update_action / update_context: the new name.'),
        'new_key': McpSchema.string('update_mapping: the new key.'),
        'new_action': McpSchema.string('update_mapping: the action the mapping drives instead.'),
        'value_type': McpSchema.string('The action\'s value type.', enumValues: [for (final t in ProjectInputValueType.values) t.name]),
        'priority': McpSchema.integer('The context\'s priority (higher wins).'),
        'scale': McpSchema.number('The mapping\'s scale (-1 for S / A on IA_Move).'),
        'axis': McpSchema.string('The axis an axis1D / axis2D mapping drives: "X", "Y" or "".'),
      }, required: ['op']),
      handler: (args) async {
        final op = args.string('op');
        String need(String key) {
          if (!args.has(key)) throw JsonRpcException(JsonRpcErrorCode.invalidParams, '$op needs "$key"');
          return args.string(key);
        }

        // Validate the key names before anything opens.
        LuminaKey? key = args.has('key') ? mcpKeyNamed(args.string('key')) : null;
        final newKey = args.has('new_key') ? mcpKeyNamed(args.string('new_key'), argument: 'new_key') : null;
        final ps = await sessions.projectSettings();
        final extra = <String, Object?>{'op': op};
        switch (op) {
          case 'add_action':
            final name = need('action');
            if (ps.project.input.actions.any((a) => a.name == name)) {
              return McpToolResult.error('Input action "$name" already exists (update_action changes it).');
            }
            ps.addAction(name);
            if (args.has('value_type')) ps.updateAction(actionIndex(ps, name), valueType: valueType(args.string('value_type')));
          case 'update_action':
            final i = actionIndex(ps, need('action'));
            ps.updateAction(i,
                name: args.optionalString('new_name'),
                valueType: args.has('value_type') ? valueType(args.string('value_type')) : null);
          case 'remove_action':
            final name = need('action');
            final i = actionIndex(ps, name);
            final dropped = ps.project.input.mappingContexts.fold<int>(0, (n, c) => n + c.mappings.where((m) => m.action == name).length);
            ps.removeAction(i);
            extra['removed_mappings'] = dropped;
          case 'add_context':
            final name = need('context');
            if (ps.project.input.mappingContexts.any((c) => c.name == name)) {
              return McpToolResult.error('Mapping context "$name" already exists.');
            }
            ps.addMappingContext(name);
            if (args.has('priority')) {
              ps.updateMappingContext(contextIndex(ps, name), priority: args.integer('priority'));
            }
          case 'update_context':
            ps.updateMappingContext(contextIndex(ps, need('context')),
                name: args.optionalString('new_name'), priority: args.has('priority') ? args.integer('priority') : null);
          case 'remove_context':
            ps.removeMappingContext(contextIndex(ps, need('context')));
          case 'add_mapping':
            final ci = contextIndex(ps, need('context'));
            final action = need('action');
            actionIndex(ps, action);
            key ??= mcpKeyNamed(need('key'));
            ps.addMapping(
              ci,
              ProjectInputMapping(
                action: action,
                keyId: key.keyId!,
                keyLabel: mcpKeyLabel(key),
                scale: args.has('scale') ? args.number('scale') : 1.0,
                axis: axisOf(args),
              ),
            );
          case 'update_mapping' || 'remove_mapping':
            final contextName = need('context');
            final ci = contextIndex(ps, contextName);
            final action = need('action');
            key ??= mcpKeyNamed(need('key'));
            final mappings = ps.project.input.mappingContexts[ci].mappings;
            final mi = mappings.indexWhere((m) => m.action == action && m.keyId == key!.keyId);
            if (mi < 0) {
              return McpToolResult.error('No mapping ${key.id} → $action in "$contextName". Its mappings: '
                  '${mappings.map((m) => '${_mappingKeyName(m)} → ${m.action}').join(', ')}.');
            }
            if (op == 'remove_mapping') {
              ps.removeMapping(ci, mi);
            } else {
              final nextAction = args.optionalString('new_action');
              if (nextAction != null) actionIndex(ps, nextAction);
              ps.updateMapping(ci, mi,
                  action: nextAction,
                  keyId: newKey?.keyId,
                  keyLabel: newKey == null ? null : mcpKeyLabel(newKey),
                  scale: args.optionalNumber('scale'),
                  axis: args.has('axis') ? axisOf(args) : null);
            }
          default:
            throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'op must be one of ${ops.join(', ')}');
        }
        return staged(ps, category: 'input', extra: extra);
      },
    ),
    McpTool(
      name: 'set_project_icon',
      risk: McpToolRisk.mutating,
      groups: settings,
      idempotent: true,
      title: 'Set project icon',
      description: 'Stages the project icon: {path} copies an SVG / PNG / JPG / WebP that renders into branding/app_icon.<ext> '
          '(an absolute path, or project-relative), {default: true} goes back to the Lumina logo. Apply & Save writes the '
          'platform icon files.',
      inputSchema: McpSchema.object({
        'path': McpSchema.string('The image file.'),
        'default': McpSchema.boolean('true: the Lumina logo.'),
      }),
      handler: (args) async {
        final useDefault = args.boolean('default');
        if (useDefault == args.has('path')) {
          throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'Pass either {path} or {default: true}.');
        }
        final ps = await sessions.projectSettings();
        if (useDefault) {
          ps.useDefaultIcon();
        } else {
          final problem = await ps.chooseIcon(_absolute(vm, args.string('path')));
          if (problem != null) return McpToolResult.error(problem);
        }
        return staged(ps, category: 'branding', extra: {'status': ps.iconStatus});
      },
    ),
    McpTool(
      name: 'set_web_loading_logo',
      risk: McpToolRisk.mutating,
      groups: settings,
      idempotent: true,
      title: 'Set web loading logo',
      description: 'Stages the web build\'s loading-screen logo: {path} (PNG, JPG, WebP, SVG, GIF; copied into '
          'branding/web_loading_logo.<ext>), {use_project_icon: true} or {none: true}.',
      inputSchema: McpSchema.object({
        'path': McpSchema.string('The image file (absolute or project-relative).'),
        'use_project_icon': McpSchema.boolean('true: the project icon.'),
        'none': McpSchema.boolean('true: no logo.'),
      }),
      handler: (args) async {
        final chosen = [args.has('path'), args.boolean('use_project_icon'), args.boolean('none')].where((b) => b).length;
        if (chosen != 1) {
          throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'Pass exactly one of {path}, {use_project_icon: true}, {none: true}.');
        }
        final ps = await sessions.projectSettings();
        if (args.boolean('use_project_icon')) {
          ps.useProjectIconAsWebLoadingLogo();
        } else if (args.boolean('none')) {
          ps.useNoWebLoadingLogo();
        } else {
          final problem = await ps.chooseWebLoadingLogo(_absolute(vm, args.string('path')));
          if (problem != null) return McpToolResult.error(problem);
        }
        return staged(ps, category: 'web_loading');
      },
    ),
    McpTool(
      name: 'apply_project_settings',
      risk: McpToolRisk.mutating,
      groups: settings,
      idempotent: true,
      title: 'Apply & Save Project Settings',
      description: 'The Project Settings tab\'s Apply & Save: validates every category and writes the .lmproject (and the '
          'app icons / web loading screen when those changed). Refused with the errors while validation fails. Never runs '
          'flutter pub get (set_widget_library does). Returns {saved, validation_errors, manifest_path}.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) async {
        final ps = await sessions.projectSettings();
        final onDiskLibrary = ps.onDiskProject?.ui.widgetLibrary ?? kUmgWidgetLibraryShadcn;
        if (ps.project.ui.widgetLibrary != onDiskLibrary) {
          return McpToolResult.error('The working copy switches the widget library to "${ps.project.ui.widgetLibrary}", '
              'which runs flutter pub get: apply it with set_widget_library, or revert_project_settings.');
        }
        final saved = await ps.apply();
        final errors = allErrors(ps);
        final result = {'saved': saved, 'validation_errors': errors, 'manifest_path': ps.manifestPath};
        if (!saved) return McpToolResult([McpContent.text('Not saved: ${errors.join('; ')}')], structuredContent: result, isError: true);
        return McpToolResult.json(result);
      },
    ),
    McpTool(
      name: 'revert_project_settings',
      risk: McpToolRisk.mutating,
      groups: settings,
      idempotent: true,
      title: 'Revert Project Settings',
      description: 'Discards the Project Settings tab\'s unapplied edits and reloads the .lmproject.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) async {
        final ps = await sessions.projectSettings();
        await ps.revert();
        return McpToolResult.json({'reverted': true, 'dirty': ps.isDirty, 'settings': read(ps)});
      },
    ),
    McpTool(
      name: 'set_widget_library',
      risk: McpToolRisk.external,
      groups: settings,
      idempotent: true,
      openWorld: true,
      title: 'Set UMG widget library',
      description: 'Switches the game\'s UMG widget library (shadcn | flutter) and applies Project Settings as a job '
          '(kind project_settings_apply): pubspec.yaml changes, flutter pub get runs (network), every UMG widget is '
          'regenerated, and the .lmproject is saved with the rest of the working copy. Returns {job_id} at once; '
          'wait_job for the result. A failed pub get restores the pubspec and saves nothing (the job fails with its output).',
      inputSchema: McpSchema.object({
        'library': McpSchema.string('The widget library.', enumValues: kUmgWidgetLibraries),
      }, required: ['library']),
      handler: (args) async {
        final library = args.string('library');
        final ps = await sessions.projectSettings();
        final McpJob job;
        try {
          job = jobs.start('project_settings_apply', title: 'Widget library → $library', exclusive: 'project_settings', run: (job) async {
            job.update(stage: 'Applying Project Settings (widget library $library)');
            ps.setWidgetLibrary(library);
            job.addLog('Widget library set to $library; applying', source: 'ProjectSettings');
            final saved = await ps.apply();
            if (!saved) {
              final why = ps.widgetLibraryError ?? allErrors(ps).join('; ');
              job.addLog(why, level: 'error', source: 'ProjectSettings');
              throw McpJobFailure(why, result: {'saved': false, 'validation_errors': allErrors(ps)});
            }
            final status = ps.widgetLibraryStatus;
            if (status != null) job.addLog(status, level: 'success', source: 'ProjectSettings');
            return {'saved': true, 'widget_library': ps.project.ui.widgetLibrary, 'manifest_path': ps.manifestPath, 'status': status};
          });
        } on McpJobConflict catch (e) {
          return McpToolResult.error(e.message);
        }
        return McpToolResult.json({'job_id': job.id, 'state': job.state.name, 'kind': job.kind});
      },
    ),
  ]);
}

String _absolute(EditorViewModel vm, String path) {
  final p = path.replaceAll(r'\', '/');
  final isAbsolute = p.startsWith('/') || RegExp(r'^[A-Za-z]:/').hasMatch(p);
  return isAbsolute ? path : '${vm.projectDirPath}/$p';
}
