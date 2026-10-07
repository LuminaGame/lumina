import 'package:lumina/lumina.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3, Vector4;

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/particle_editor_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_editor_sessions.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';

/// The Particle editor as MCP tools: the emitter stack
/// (add, duplicate, rename, enable, delete), each emitter's stage values
/// (spawn, lifetime and velocity, forces, timing, over-life curves, render),
/// the preview simulation, Save.
///
/// The Particle editor has no undo stack (a dirty flag only): these edits
/// are reverted by not saving (the tab's Discard), never by `undo`. The stage
/// setters act on the selected emitter, so every tool selects the emitter it
/// edits first, as a click in the stack would, and says which one it edited.
void registerParticleTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  const groups = {McpToolGroups.particle};
  const noUndo = 'The Particle editor has no undo stack: the edit marks the tab dirty and is reverted only by not '
      'saving (the tab\'s Discard).';
  const units = 'Values are what the emitter panels show: speeds in cm/s, gravity a vector in cm/s² in the emitter\'s '
      'space (Y up: the default is [0, -980, 0]), angles in degrees, times in seconds, curve t 0…1 over a particle\'s life.';
  final assetArg = McpSchema.string('The particle system: its project-relative .lmas path (list_assets with type '
      '"particle") or its file name when unique.');
  final emitterArg = McpSchema.any('An emitter: its index (0-based) or its unique name (get_particle_system).');
  final indexArg = McpSchema.integer('The entry index (get_particle_system).');
  List<double>? pair(McpArgs args, String key) {
    final v = args[key];
    if (v == null) return null;
    if (v is! List || v.length != 2 || v.any((e) => e is! num)) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams, '"$key" must be [min, max]');
    }
    return [for (final e in v) (e as num).toDouble()];
  }

  Map<String, Object?> numbers(String description, int n) => {
        'type': 'array',
        'description': description,
        'items': {'type': 'number'},
        'minItems': n,
        'maxItems': n,
      };

  Future<ParticleEditorViewModel> editorFor(McpArgs args) async {
    final asset = sessions.resolveAsset(args.string('asset'));
    if (asset.type != AssetType.particle) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          '${asset.relativePath} is a ${asset.type.name}, not a particle system. Call list_assets with type "particle".');
    }
    return sessions.particle(asset);
  }

  /// The emitter [args] name, selected in the stack.
  int emitterOf(ParticleEditorViewModel e, McpArgs args) {
    final ref = args['emitter'];
    final names = e.emitters.map((x) => x.name).toList();
    int? index;
    if (ref is num && ref == ref.roundToDouble()) index = ref.toInt();
    if (ref is String) {
      final hits = [for (var i = 0; i < names.length; i++) if (names[i] == ref) i];
      if (hits.length == 1) index = hits.single;
      if (hits.isEmpty) index = int.tryParse(ref);
    }
    if (index == null || index < 0 || index >= names.length) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'No emitter "$ref". Emitters: ${[for (var i = 0; i < names.length; i++) '$i: ${names[i]}'].join(', ')}.');
    }
    e.selectEmitter(index);
    return index;
  }

  Map<String, Object?> emitterJson(ParticleEditorViewModel e, int i) {
    final entry = e.emitters[i];
    final c = entry.config;
    return {
      'index': i,
      'name': entry.name,
      'enabled': entry.enabled,
      'stages': {
        'spawn': {
          'spawn_rate': c.spawnRate,
          'max_particles': c.maxParticles,
          'bursts': [for (final b in c.bursts) {'time': b.time, 'count': b.count}],
        },
        'lifetime': {
          'lifetime': [c.lifetimeMin, c.lifetimeMax],
          'speed': [c.speedMin, c.speedMax],
          'cone_angle_degrees': c.coneAngleDegrees,
          'inherit_velocity_scale': [c.inheritVelocityScale.x, c.inheritVelocityScale.y, c.inheritVelocityScale.z],
        },
        'forces': {'gravity': [c.gravity.x, c.gravity.y, c.gravity.z], 'drag': c.drag},
        'timing': {'looping': c.looping, 'duration': c.duration},
        'over_life': {
          'color_stops': [for (final s in c.colorOverLife) {'t': s.t, 'rgba': [s.rgba.x, s.rgba.y, s.rgba.z, s.rgba.w]}],
          'size_points': [for (final p in c.sizeOverLife) {'t': p.t, 'scale': p.scale}],
        },
        'render': {'billboard': c.billboard, 'mesh': c.meshAssetPath},
      },
    };
  }

  Map<String, Object?> system(ParticleEditorViewModel e) => {
        'backend': ParticleEditorViewModel.backendLabel,
        'emitters': [for (var i = 0; i < e.emitters.length; i++) emitterJson(e, i)],
        'selected_emitter': e.selectedEmitterIndex,
        'errors': e.errors,
        'is_dirty': e.isDirty,
      };

  Map<String, Object?> edited(ParticleEditorViewModel e, int i, [Map<String, Object?> extra = const {}]) => {
        'edited': e.emitters[i].name,
        'emitter': emitterJson(e, i),
        ...extra,
        'errors': e.errors,
        'is_dirty': e.isDirty,
      };

  /// Runs [edits] (each: the error key it may raise, the edit, and its undo
  /// with the old value). A new error on a key rolls every edit back and is
  /// returned with the editor's own text; null when all were accepted.
  String? applyAll(ParticleEditorViewModel e, List<(String, void Function(), void Function())> edits) {
    final done = <void Function()>[];
    for (final (key, apply, undo) in edits) {
      final had = e.errorFor(key);
      apply();
      done.add(undo);
      final now = e.errorFor(key);
      if (now != null && now != had) {
        for (final u in done.reversed) {
          u();
        }
        return now;
      }
    }
    return null;
  }

  Vector4 rgbaOf(Object? raw) {
    if (raw is! List || raw.length != 4 || raw.any((v) => v is! num)) {
      throw const JsonRpcException(JsonRpcErrorCode.invalidParams, '"rgba" must be [r, g, b, a] with values 0…1');
    }
    final v = [for (final x in raw) (x as num).toDouble()];
    return Vector4(v[0], v[1], v[2], v[3]);
  }

  int entryOf(int count, McpArgs args, String what) {
    final i = args.integer('index');
    if (i < 0 || i >= count) throw JsonRpcException(JsonRpcErrorCode.invalidParams, 'No $what $i; the emitter has $count.');
    return i;
  }

  registry.registerAll([
    McpTool(
      name: 'get_particle_system',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Get particle system',
      description: 'A particle system as the Particle editor shows it: the simulation backend, the emitter stack '
          '[{index, name, enabled, stages: {spawn: {spawn_rate, max_particles, bursts}, lifetime: {lifetime [min, max], '
          'speed [min, max], cone_angle_degrees, inherit_velocity_scale}, forces: {gravity, drag}, timing: {looping, '
          'duration}, over_life: {color_stops [{t, rgba}], size_points [{t, scale}]}, render: {billboard, mesh}}}], the '
          'inline errors that block Save, and is_dirty. $units Opens its tab.',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async => McpToolResult.json(system(await editorFor(args))),
    ),
    McpTool(
      name: 'add_particle_emitter',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Add particle emitter',
      description: 'Adds an emitter with the engine defaults at the end of the stack and selects it; a name in use gets '
          'a number. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'name': McpSchema.string('The emitter name.')}, required: ['asset', 'name']),
      handler: (args) async {
        final e = await editorFor(args);
        final name = args.string('name').trim();
        if (name.isEmpty) return McpToolResult.error('An emitter needs a name.');
        e.addEmitter(name);
        return McpToolResult.json(edited(e, e.emitters.length - 1));
      },
    ),
    McpTool(
      name: 'duplicate_particle_emitter',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Duplicate particle emitter',
      description: 'Copies an emitter below itself ("<name> Copy") and selects the copy. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'emitter': emitterArg}, required: ['asset', 'emitter']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = emitterOf(e, args);
        e.duplicateEmitter(i);
        return McpToolResult.json(edited(e, i + 1));
      },
    ),
    McpTool(
      name: 'rename_particle_emitter',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Rename particle emitter',
      description: 'Renames an emitter. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'emitter': emitterArg, 'name': McpSchema.string('The new name.')},
          required: ['asset', 'emitter', 'name']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = emitterOf(e, args);
        final name = args.string('name').trim();
        if (name.isEmpty) return McpToolResult.error('An emitter needs a name.');
        e.renameEmitter(i, name);
        return McpToolResult.json(edited(e, i));
      },
    ),
    McpTool(
      name: 'set_particle_emitter_enabled',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Enable particle emitter',
      description: 'Enables or disables an emitter (a disabled one is saved but neither previewed nor run). $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'emitter': emitterArg, 'enabled': McpSchema.boolean('Enabled.')},
          required: ['asset', 'emitter', 'enabled']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = emitterOf(e, args);
        e.setEmitterEnabled(i, args.boolean('enabled'));
        return McpToolResult.json(edited(e, i));
      },
    ),
    McpTool(
      name: 'delete_particle_emitter',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      removesContent: true,
      title: 'Delete particle emitter',
      description: 'Deletes an emitter; the last one is kept (a system always has one). $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'emitter': emitterArg}, required: ['asset', 'emitter']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = emitterOf(e, args);
        if (e.emitters.length <= 1) return McpToolResult.error('A particle system keeps at least one emitter; nothing was deleted.');
        final name = e.emitters[i].name;
        e.deleteEmitter(i);
        return McpToolResult.json({'deleted': name, ...system(e)});
      },
    ),
    McpTool(
      name: 'set_particle_emitter',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set particle emitter',
      description: 'Sets an emitter\'s stage values (selecting it first). A value the editor rejects (max_particles < '
          '1, lifetime min ≤ 0 or above max, speed min above max, duration ≤ 0) is a tool error with the editor\'s '
          'message, and the call changes nothing. $units $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'emitter': emitterArg,
        'spawn_rate': McpSchema.number('Particles per second (≥ 0).'),
        'max_particles': McpSchema.integer('Pool size (≥ 1).'),
        'lifetime': numbers('[min, max] seconds.', 2),
        'speed': numbers('[min, max] cm/s.', 2),
        'cone_angle_degrees': McpSchema.number('Emission cone half-angle, 0…180.'),
        'inherit_velocity_scale': McpSchema.vector3('[x, y, z] share of the owner\'s velocity.'),
        'gravity': McpSchema.vector3('[x, y, z] cm/s² (default [0, -980, 0]).'),
        'drag': McpSchema.number('Linear drag.'),
        'looping': McpSchema.boolean('Loop the emitter.'),
        'duration': McpSchema.number('Loop duration in seconds (> 0).'),
      }, required: ['asset', 'emitter']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = emitterOf(e, args);
        final c = e.config;
        final edits = <(String, void Function(), void Function())>[];
        if (args.has('spawn_rate')) edits.add(('spawnRate', () => e.setSpawnRate(args.number('spawn_rate')), () => e.setSpawnRate(c.spawnRate)));
        if (args.has('max_particles')) {
          edits.add(('maxParticles', () => e.setMaxParticles(args.integer('max_particles')), () => e.setMaxParticles(c.maxParticles)));
        }
        final life = pair(args, 'lifetime');
        if (life != null) {
          edits.add(('lifetime', () {
            e.setLifetimeMax(life[1]);
            e.setLifetimeMin(life[0]);
          }, () {
            e.setLifetimeMax(c.lifetimeMax);
            e.setLifetimeMin(c.lifetimeMin);
          }));
        }
        final speed = pair(args, 'speed');
        if (speed != null) {
          edits.add(('speed', () {
            e.setSpeedMax(speed[1]);
            e.setSpeedMin(speed[0]);
          }, () {
            e.setSpeedMax(c.speedMax);
            e.setSpeedMin(c.speedMin);
          }));
        }
        if (args.has('cone_angle_degrees')) {
          edits.add(('cone', () => e.setConeAngleDegrees(args.number('cone_angle_degrees')), () => e.setConeAngleDegrees(c.coneAngleDegrees)));
        }
        final inherit = args.optionalVector3('inherit_velocity_scale');
        if (inherit != null) {
          edits.add(('inherit', () => e.setInheritVelocityScale(Vector3.array(inherit)), () => e.setInheritVelocityScale(c.inheritVelocityScale.clone())));
        }
        final gravity = args.optionalVector3('gravity');
        if (gravity != null) edits.add(('gravity', () => e.setGravity(Vector3.array(gravity)), () => e.setGravity(c.gravity.clone())));
        if (args.has('drag')) edits.add(('drag', () => e.setDrag(args.number('drag')), () => e.setDrag(c.drag)));
        if (args.has('looping')) edits.add(('looping', () => e.setLooping(args.boolean('looping')), () => e.setLooping(c.looping)));
        if (args.has('duration')) edits.add(('duration', () => e.setDuration(args.number('duration')), () => e.setDuration(c.duration)));
        final error = applyAll(e, edits);
        if (error != null) return McpToolResult.error('${e.emitters[i].name}: $error Nothing was changed.');
        return McpToolResult.json(edited(e, i));
      },
    ),
    McpTool(
      name: 'add_particle_burst',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Add particle burst',
      description: 'Adds a burst of `count` particles at `time` seconds into each loop (0 ≤ time < duration, count ≥ '
          '1; otherwise refused and nothing changes). $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'emitter': emitterArg,
        'time': McpSchema.number('Seconds into the loop.'),
        'count': McpSchema.integer('Particles.'),
      }, required: ['asset', 'emitter', 'time', 'count']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = emitterOf(e, args);
        final before = List.of(e.config.bursts);
        final error = applyAll(e, [
          ('bursts', () => e.addBurst(args.number('time'), args.integer('count')), () {
            final added = e.config.bursts.indexWhere((b) => !before.contains(b));
            if (added >= 0) e.removeBurst(added);
          }),
        ]);
        if (error != null) return McpToolResult.error('$error Nothing was changed.');
        return McpToolResult.json(edited(e, i));
      },
    ),
    McpTool(
      name: 'set_particle_burst',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set particle burst',
      description: 'Changes a burst\'s time and / or count (a rejected value changes nothing). $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'emitter': emitterArg,
        'index': indexArg,
        'time': McpSchema.number('Seconds into the loop.'),
        'count': McpSchema.integer('Particles.'),
      }, required: ['asset', 'emitter', 'index']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = emitterOf(e, args);
        final b = entryOf(e.config.bursts.length, args, 'burst');
        final old = e.config.bursts[b];
        final edits = <(String, void Function(), void Function())>[];
        if (args.has('count')) edits.add(('bursts', () => e.setBurstCount(b, args.integer('count')), () => e.setBurstCount(b, old.count)));
        if (args.has('time')) {
          edits.add(('bursts', () => e.setBurstTime(b, args.number('time')), () {
            final at = e.config.bursts.indexWhere((x) => x.time == args.number('time'));
            if (at >= 0) e.setBurstTime(at, old.time);
          }));
        }
        final error = applyAll(e, edits);
        if (error != null) return McpToolResult.error('$error Nothing was changed.');
        return McpToolResult.json(edited(e, i));
      },
    ),
    McpTool(
      name: 'remove_particle_burst',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      removesContent: true,
      title: 'Remove particle burst',
      description: 'Deletes a burst. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'emitter': emitterArg, 'index': indexArg}, required: ['asset', 'emitter', 'index']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = emitterOf(e, args);
        e.removeBurst(entryOf(e.config.bursts.length, args, 'burst'));
        return McpToolResult.json(edited(e, i));
      },
    ),
    McpTool(
      name: 'add_particle_color_stop',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Add particle colour stop',
      description: 'Adds a colour-over-life stop at t (0…1 of a particle\'s life) with [r, g, b, a] 0…1. $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'emitter': emitterArg,
        't': McpSchema.number('0…1 over the particle\'s life.'),
        'rgba': numbers('[r, g, b, a], each 0…1.', 4),
      }, required: ['asset', 'emitter', 't', 'rgba']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = emitterOf(e, args);
        e.addColorStop(args.number('t'), rgbaOf(args['rgba']));
        return McpToolResult.json(edited(e, i));
      },
    ),
    McpTool(
      name: 'set_particle_color_stop',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set particle colour stop',
      description: 'Moves a colour stop to t and / or changes its colour (stops re-sort by t). $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'emitter': emitterArg,
        'index': indexArg,
        't': McpSchema.number('0…1.'),
        'rgba': numbers('[r, g, b, a], each 0…1.', 4),
      }, required: ['asset', 'emitter', 'index']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = emitterOf(e, args);
        final s = entryOf(e.config.colorOverLife.length, args, 'colour stop');
        if (args.has('rgba')) e.setColorStopRgba(s, rgbaOf(args['rgba']));
        if (args.has('t')) e.moveColorStop(s, args.number('t'));
        return McpToolResult.json(edited(e, i));
      },
    ),
    McpTool(
      name: 'remove_particle_color_stop',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      removesContent: true,
      title: 'Remove particle colour stop',
      description: 'Deletes a colour stop. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'emitter': emitterArg, 'index': indexArg}, required: ['asset', 'emitter', 'index']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = emitterOf(e, args);
        e.removeColorStop(entryOf(e.config.colorOverLife.length, args, 'colour stop'));
        return McpToolResult.json(edited(e, i));
      },
    ),
    McpTool(
      name: 'add_particle_size_point',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      title: 'Add particle size point',
      description: 'Adds a size-over-life point: scale at t (0…1 of a particle\'s life). $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'emitter': emitterArg,
        't': McpSchema.number('0…1 over the particle\'s life.'),
        'scale': McpSchema.number('The size multiplier.'),
      }, required: ['asset', 'emitter', 't', 'scale']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = emitterOf(e, args);
        e.addSizePoint(args.number('t'), args.number('scale'));
        return McpToolResult.json(edited(e, i));
      },
    ),
    McpTool(
      name: 'set_particle_size_point',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set particle size point',
      description: 'Moves a size point to t and / or changes its scale (points re-sort by t). $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'emitter': emitterArg,
        'index': indexArg,
        't': McpSchema.number('0…1.'),
        'scale': McpSchema.number('The size multiplier.'),
      }, required: ['asset', 'emitter', 'index']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = emitterOf(e, args);
        final p = entryOf(e.config.sizeOverLife.length, args, 'size point');
        final old = e.config.sizeOverLife[p];
        e.moveSizePoint(p, args.optionalNumber('t') ?? old.t, args.optionalNumber('scale') ?? old.scale);
        return McpToolResult.json(edited(e, i));
      },
    ),
    McpTool(
      name: 'remove_particle_size_point',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: false,
      removesContent: true,
      title: 'Remove particle size point',
      description: 'Deletes a size point. $noUndo',
      inputSchema: McpSchema.object({'asset': assetArg, 'emitter': emitterArg, 'index': indexArg}, required: ['asset', 'emitter', 'index']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = emitterOf(e, args);
        e.removeSizePoint(entryOf(e.config.sizeOverLife.length, args, 'size point'));
        return McpToolResult.json(edited(e, i));
      },
    ),
    McpTool(
      name: 'set_particle_render',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set particle render',
      description: 'The Render stage: billboard: true draws the built-in quad; mesh draws each particle as a static '
          'mesh asset (list_assets type "filamesh"), saved as a reference of the system. $noUndo',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'emitter': emitterArg,
        'billboard': McpSchema.boolean('Draw the built-in billboard quad.'),
        'mesh': McpSchema.string('A static mesh .lmas (project-relative) to draw per particle.'),
      }, required: ['asset', 'emitter']),
      handler: (args) async {
        final e = await editorFor(args);
        final i = emitterOf(e, args);
        if (args.has('mesh')) {
          final mesh = sessions.resolveAsset(args.string('mesh'));
          if (mesh.type != AssetType.filamesh && mesh.type != AssetType.filameshSk) {
            return McpToolResult.error('${mesh.relativePath} is a ${mesh.type.name}; a particle renders a mesh (list_assets type "filamesh").');
          }
          e.setMeshAsset(mesh);
        } else if (args.has('billboard')) {
          e.setBillboard(args.boolean('billboard'));
        }
        return McpToolResult.json(edited(e, i));
      },
    ),
    McpTool(
      name: 'particle_preview',
      risk: McpToolRisk.editorState,
      groups: groups,
      idempotent: false,
      title: 'Particle preview',
      description: 'The preview transport over the real engine simulation (fixed seed): "play" / "pause", "step" '
          '`frames` ticks of 1/60 s (default 1), "reset" the simulation; sim_speed (0.1…2) scales play. With play, '
          '`frames` also advances that many ticks at sim_speed (a tool-created editor has no frame clock until its tab '
          'draws). Returns sim_time and the live particle count. Changes what the tab shows, never the asset.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'action': McpSchema.string('What to do.', enumValues: const ['play', 'pause', 'step', 'reset']),
        'frames': McpSchema.integer('Ticks of 1/60 s (at most 1200).'),
        'sim_speed': McpSchema.number('Simulation speed, 0.1…2.'),
      }, required: ['asset', 'action']),
      handler: (args) async {
        final e = await editorFor(args);
        final frames = args.integer('frames', fallback: args.string('action') == 'step' ? 1 : 0);
        if (frames < 0 || frames > 1200) throw const JsonRpcException(JsonRpcErrorCode.invalidParams, 'frames must be 0..1200');
        if (args.has('sim_speed')) e.setSimSpeed(args.number('sim_speed'));
        switch (args.string('action')) {
          case 'play':
            e.play();
            for (var f = 0; f < frames; f++) {
              e.advance(ParticleEditorViewModel.frameSeconds);
            }
          case 'pause':
            e.pause();
          case 'step':
            for (var f = 0; f < frames; f++) {
              e.stepFrame();
            }
          case 'reset':
            e.resetSimulation();
        }
        return McpToolResult.json({
          'sim_time': e.simTime,
          'active_particles': e.activeParticleCount,
          'particle_budget': e.particleBudget,
          'is_playing': e.isPlaying,
          'sim_speed': e.simSpeed,
        });
      },
    ),
    McpTool(
      name: 'save_particle_system',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Save particle system',
      description: 'Writes the particle system .lmas with its mesh references (the tab\'s Save). Refused while an inline '
          'error remains (get_particle_system errors).',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        if (!e.canSave) return McpToolResult.error('Save is blocked: ${e.errors.values.join(' ')}');
        if (!await e.save()) return McpToolResult.error('The particle system was not saved; see the Output Log.');
        return McpToolResult.json({'saved': sessions.resolveAsset(args.string('asset')).relativePath, 'emitters': e.emitters.length, 'is_dirty': e.isDirty});
      },
    ),
  ]);
}

