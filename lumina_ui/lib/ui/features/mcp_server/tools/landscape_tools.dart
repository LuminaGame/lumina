import 'dart:io';
import 'dart:math' as math;

import 'package:lumina/lumina.dart' show AssetType, FoliageRules, LandscapeData, LuminaUnits;

import '../../main_editor/view_models/editor_view_model.dart';
import '../../sub_editors/models/landscape_brush.dart';
import '../../sub_editors/view_models/landscape_editor_view_model.dart';
import '../services/mcp_editor_sessions.dart';
import '../services/mcp_protocol.dart';
import '../services/mcp_tool.dart';

/// The Landscape editor as MCP tools: create a terrain,
/// import a heightmap, set the sculpt and foliage brushes, replay stroke
/// lists (each stroke one entry on the landscape's own undo stack, which
/// 04's `undo` reaches with the asset), foliage layers and paint / erase
/// strokes, save.
///
/// The agent speaks centimetres and terrain-local `[x, y]` (Z up, origin at
/// the terrain's centre); the `LANDSCAPE` payload is terrain metres, Y up,
/// so every point converts here once: `worldX = x / 100`,
/// `worldZ = −y / 100`, heights `/ 100` — as the panel's sliders do.
void registerLandscapeTools(McpToolRegistry registry, EditorViewModel vm, McpEditorSessions sessions) {
  const groups = {McpToolGroups.landscape, McpToolGroups.assetEditors};
  const maxStrokes = 64;
  const maxPoints = 512;
  final toolNames = [for (final t in LandscapeTool.values) t.name];
  final falloffNames = [for (final f in LandscapeFalloffType.values) f.name];
  double cm(double metres) => LuminaUnits.metres(metres);
  double m(double centimetres) => LuminaUnits.toMetres(centimetres);

  final assetArg = McpSchema.string('The landscape asset (list_assets type "landscape"): project-relative path or unique file name.');
  const pointsNote = 'Points are [x, y] in cm relative to the terrain\'s centre (Z up), not level coordinates: '
      'subtract the landscape actor\'s location (get_actor) from a level point.';
  const noUndoNote = 'Not on the landscape\'s undo stack; close the tab without saving to discard.';

  Future<LandscapeEditorViewModel> editorFor(McpArgs args) =>
      sessions.landscape(sessions.resolveAsset(args.string('asset'), type: AssetType.landscape));

  Never bad(String message) => throw JsonRpcException(JsonRpcErrorCode.invalidParams, message);

  Map<String, Object?> rulesJson(FoliageRules r) => {
        'density': r.density,
        'min_spacing_cm': cm(r.minSpacing),
        'scale_min': r.scaleMin,
        'scale_max': r.scaleMax,
        'random_yaw': r.randomYaw,
        'align_to_normal': r.alignToNormal,
        'slope_min_deg': r.slopeMinDegrees,
        'slope_max_deg': r.slopeMaxDegrees,
      };

  /// [rules] over [base], clamped as the layer panel's sliders clamp.
  FoliageRules parseRules(Object? raw, FoliageRules base) {
    if (raw == null) return base;
    if (raw is! Map) bad('"rules" must be an object');
    const known = {'density', 'min_spacing_cm', 'scale_min', 'scale_max', 'random_yaw', 'align_to_normal', 'slope_min_deg', 'slope_max_deg'};
    final unknown = raw.keys.where((k) => !known.contains(k)).toList();
    if (unknown.isNotEmpty) bad('Unknown rule(s) ${unknown.join(', ')}. Rules: ${known.join(', ')}.');
    double? n(String key, double lo, double hi) {
      final v = raw[key];
      if (v == null) return null;
      if (v is! num) bad('rules.$key must be a number');
      return v.toDouble().clamp(lo, hi).toDouble();
    }

    bool? b(String key) {
      final v = raw[key];
      if (v == null) return null;
      if (v is! bool) bad('rules.$key must be a boolean');
      return v;
    }

    final spacing = n('min_spacing_cm', 5, 2000);
    return base.copyWith(
      density: n('density', 1, 500),
      minSpacing: spacing == null ? null : m(spacing),
      scaleMin: n('scale_min', 0.05, 5),
      scaleMax: n('scale_max', 0.05, 5),
      randomYaw: b('random_yaw'),
      alignToNormal: b('align_to_normal'),
      slopeMinDegrees: n('slope_min_deg', 0, 90),
      slopeMaxDegrees: n('slope_max_deg', 0, 90),
    );
  }

  final rulesSchema = McpSchema.object({
    'density': McpSchema.number('Instances per 1000 × 1000 cm (1–500).'),
    'min_spacing_cm': McpSchema.number('Minimum distance between instances in cm (5–2000).'),
    'scale_min': McpSchema.number('Smallest random scale (0.05–5).'),
    'scale_max': McpSchema.number('Largest random scale (0.05–5).'),
    'random_yaw': McpSchema.boolean('Random rotation about the up axis.'),
    'align_to_normal': McpSchema.boolean('Tilt instances onto the terrain normal.'),
    'slope_min_deg': McpSchema.number('Place only on slopes at least this steep (0–90°).'),
    'slope_max_deg': McpSchema.number('Place only on slopes at most this steep (0–90°).'),
  });

  Map<String, Object?> sculptBrush(LandscapeEditorViewModel e) => {
        'tool': e.tool.name,
        'radius_cm': cm(e.brushRadius),
        'strength': e.brushStrength,
        'falloff': e.brushFalloff,
        'falloff_type': e.falloffType.name,
      };

  Map<String, Object?> foliageBrush(LandscapeEditorViewModel e) => {
        'radius_cm': cm(e.foliageBrushRadius),
        'falloff': e.foliageBrushFalloff,
        'paint_density': e.paintDensity,
        'erase_density': e.eraseDensity,
      };

  Map<String, Object?> layerJson(LandscapeEditorViewModel e, int i) {
    final l = e.data.layers[i];
    return {'index': i, 'name': l.name, 'mesh': l.meshAssetPath, 'rules': rulesJson(l.rules), 'instance_count': l.instanceCount};
  }

  Map<String, Object?> landscapeJson(LandscapeEditorViewModel e, String asset) => {
        'asset': asset,
        'grid_resolution': e.data.gridResolution,
        'world_size_cm': cm(e.data.worldSize),
        'max_height_cm': cm(e.data.maxHeight),
        'height_min_cm': cm(e.heightMin),
        'height_max_cm': cm(e.heightMax),
        'section_count': e.sectionCount,
        'foliage_layers': [for (var i = 0; i < e.data.layers.length; i++) layerJson(e, i)],
        'selected_foliage_layer': e.selectedFoliageLayer,
        'foliage_instance_count': e.foliageInstanceCount,
        'sculpt_brush': sculptBrush(e),
        'foliage_brush': foliageBrush(e),
        'is_dirty': e.isDirty,
        'can_undo': e.canUndo,
        'undo_label': e.undoLabel,
        'can_redo': e.canRedo,
        'redo_label': e.redoLabel,
        'status': e.statusMessage,
      };

  /// The payload's metres of point [p] (`[x, y]` cm, terrain-local, Z up).
  (double, double) toWorld(List<double> p) => (m(p[0]), -m(p[1]));

  List<List<double>> parsePoints(Object? raw, String where) {
    if (raw is! List || raw.isEmpty) bad('$where.points must be a non-empty array of [x, y] in cm');
    if (raw.length > maxPoints) bad('$where has ${raw.length} points; at most $maxPoints per stroke.');
    return [
      for (final p in raw)
        if (p is List && p.length == 2 && p[0] is num && p[1] is num)
          [(p[0] as num).toDouble(), (p[1] as num).toDouble()]
        else
          bad('$where: each point is [x, y] in cm; got $p'),
    ];
  }

  List<Map<Object?, Object?>> parseStrokes(McpArgs args) {
    final raw = args['strokes'];
    if (raw is! List || raw.isEmpty) bad('"strokes" must be a non-empty array of strokes');
    if (raw.length > maxStrokes) bad('${raw.length} strokes; at most $maxStrokes strokes per call.');
    return [
      for (final s in raw)
        if (s is Map) s else bad('Each stroke is an object with "points"; got $s'),
    ];
  }

  int layerIndex(LandscapeEditorViewModel e, Object? raw) {
    final layers = e.data.layers;
    final names = layers.isEmpty ? 'none (add_foliage_layer first)' : [for (var i = 0; i < layers.length; i++) '$i "${layers[i].name}"'].join(', ');
    if (raw is num && raw == raw.roundToDouble()) {
      final i = raw.toInt();
      if (i >= 0 && i < layers.length) return i;
    } else if (raw is String) {
      final i = layers.indexWhere((l) => l.name == raw);
      if (i >= 0) return i;
    } else {
      bad('"layer" is a layer index or name');
    }
    bad('No foliage layer $raw. Layers: $names.');
  }

  registry.registerAll([
    McpTool(
      name: 'get_landscape',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Get landscape',
      description: 'The Landscape editor\'s terrain (opens its tab): grid resolution, world size, max height and '
          'height min / max in cm, section count, foliage layers (name, mesh, rules, instance count), the sculpt and '
          'foliage brushes, unsaved changes, undo / redo with their labels, and the status line. $pointsNote',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        return McpToolResult.json(landscapeJson(e, args.string('asset')));
      },
    ),
    McpTool(
      name: 'create_landscape',
      risk: McpToolRisk.destructive,
      groups: groups,
      title: 'Create landscape terrain',
      description: 'Manage → New Terrain: replaces the landscape\'s terrain with a flat grid (its foliage and its '
          'undo history go with it; not undoable — close the tab without saving to keep the old one). '
          'grid_resolution is n × 64 + 1 vertices per side (65, 129, 257, … 8129); world size and max height in cm '
          '(default: the current terrain\'s).',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'grid_resolution': McpSchema.integer('Vertices per side: n × 64 + 1, 65 … 8129.'),
        'world_size_cm': McpSchema.number('Side length in cm.'),
        'max_height_cm': McpSchema.number('Height range in cm.'),
      }, required: ['asset', 'grid_resolution']),
      handler: (args) async {
        final res = args.integer('grid_resolution');
        if (!LandscapeData.isValidResolution(res)) {
          final (lo, hi) = LandscapeData.nearestValidResolutions(res);
          return McpToolResult.error('grid_resolution $res does not tile into 64-quad sections: it must be n × 64 + 1 '
              '(65 … ${LandscapeData.maxGridResolution}); the nearest valid ones are $lo and ${hi ?? lo}.');
        }
        final e = await editorFor(args);
        final size = args.optionalNumber('world_size_cm');
        final height = args.optionalNumber('max_height_cm');
        if ((size != null && size <= 0) || (height != null && height <= 0)) {
          return McpToolResult.error('world_size_cm and max_height_cm must be positive.');
        }
        e.setTab(LandscapeEditorTab.manage);
        e.setNewTerrainResolution(res);
        e.setNewTerrainWorldSize(size == null ? e.data.worldSize : m(size));
        e.setNewTerrainMaxHeight(height == null ? e.data.maxHeight : m(height));
        e.createTerrainFromForm();
        return McpToolResult.json(landscapeJson(e, args.string('asset')));
      },
    ),
    McpTool(
      name: 'import_landscape_heightmap',
      risk: McpToolRisk.mutating,
      groups: groups,
      title: 'Import heightmap',
      description: 'Manage → Import Heightmap: replaces the terrain with a grayscale PNG (8- or 16-bit, square, a side '
          'of n × 64 + 1 pixels). Black is the terrain\'s floor, white its max height. world_size_cm / max_height_cm '
          'default to the current terrain\'s. A rejected image leaves the terrain as it was. Clears the landscape\'s '
          'undo history; close the tab without saving to discard.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'path': McpSchema.string('Absolute path of the PNG on disk.'),
        'world_size_cm': McpSchema.number('Side length in cm.'),
        'max_height_cm': McpSchema.number('Height of pure white in cm.'),
      }, required: ['asset', 'path']),
      handler: (args) async {
        final path = args.string('path');
        if (!File(path).existsSync()) return McpToolResult.error('No heightmap at $path.');
        final e = await editorFor(args);
        final size = args.optionalNumber('world_size_cm');
        final height = args.optionalNumber('max_height_cm');
        if ((size != null && size <= 0) || (height != null && height <= 0)) {
          return McpToolResult.error('world_size_cm and max_height_cm must be positive.');
        }
        e.setTab(LandscapeEditorTab.manage);
        e.setNewTerrainWorldSize(size == null ? e.data.worldSize : m(size));
        e.setNewTerrainMaxHeight(height == null ? e.data.maxHeight : m(height));
        if (!await e.importHeightmapFileAsync(path)) return McpToolResult.error(e.statusMessage ?? 'The heightmap import failed.');
        return McpToolResult.json(landscapeJson(e, args.string('asset')));
      },
    ),
    McpTool(
      name: 'set_landscape_brush',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set sculpt brush',
      description: 'The Sculpt panel\'s brush: tool (${toolNames.join(', ')}), radius in cm (100–20 000), strength '
          '(0.01–1), falloff (0–1) and falloff_type (${falloffNames.join(', ')}), clamped as the sliders clamp. Saved '
          'as the user\'s brush in the project\'s .lumina/landscape_brush.json, like the panel.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'tool': McpSchema.string('The sculpt tool.', enumValues: toolNames),
        'radius_cm': McpSchema.number('Brush radius in cm.'),
        'strength': McpSchema.number('Brush strength 0.01–1.'),
        'falloff': McpSchema.number('Soft edge 0–1.'),
        'falloff_type': McpSchema.string('The falloff curve.', enumValues: falloffNames),
      }, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        e.setTab(LandscapeEditorTab.sculpt);
        final tool = args.optionalString('tool');
        if (tool != null) e.setTool(LandscapeTool.values.byName(tool));
        final radius = args.optionalNumber('radius_cm');
        if (radius != null) e.setBrushRadius(m(radius));
        final strength = args.optionalNumber('strength');
        if (strength != null) e.setBrushStrength(strength);
        final falloff = args.optionalNumber('falloff');
        if (falloff != null) e.setBrushFalloff(falloff);
        final type = args.optionalString('falloff_type');
        if (type != null) e.setFalloffType(LandscapeFalloffType.values.byName(type));
        return McpToolResult.json({'sculpt_brush': sculptBrush(e)});
      },
    ),
    McpTool(
      name: 'set_foliage_brush',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set foliage brush',
      description: 'The Foliage panel\'s brush: radius in cm (100–20 000), falloff (0–1), paint_density (share of a '
          'layer\'s density one pass lays down, 0–1) and erase_density (what an erase pass leaves, 0 clears). Saved '
          'as the user\'s brush in .lumina/landscape_brush.json.',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'radius_cm': McpSchema.number('Brush radius in cm.'),
        'falloff': McpSchema.number('Soft edge 0–1.'),
        'paint_density': McpSchema.number('Paint Density 0–1.'),
        'erase_density': McpSchema.number('Erase Density 0–1.'),
      }, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        e.setTab(LandscapeEditorTab.foliage);
        final radius = args.optionalNumber('radius_cm');
        if (radius != null) e.setFoliageBrushRadius(m(radius));
        final falloff = args.optionalNumber('falloff');
        if (falloff != null) e.setFoliageBrushFalloff(falloff);
        final paint = args.optionalNumber('paint_density');
        if (paint != null) e.setPaintDensity(paint);
        final erase = args.optionalNumber('erase_density');
        if (erase != null) e.setEraseDensity(erase);
        return McpToolResult.json({'foliage_brush': foliageBrush(e)});
      },
    ),
    McpTool(
      name: 'sculpt_landscape',
      risk: McpToolRisk.mutating,
      groups: groups,
      title: 'Sculpt landscape',
      description: 'Replays brush strokes as a mouse drag would: each stroke starts at its first point and stamps the '
          'brush every ¼ radius along the rest (sculpt raises, invert lowers; smooth, flatten to the height under '
          'the first point, noise). Each stroke is one undo entry "<tool> stroke" on the landscape\'s stack (undo '
          'with this asset). Per-stroke tool / radius_cm / strength / falloff / falloff_type apply to that stroke '
          'only; the saved brush is left as it was. At most $maxStrokes strokes × $maxPoints points. Returns per '
          'stroke the height range of the cells it touched, and the terrain\'s new height min / max (cm). '
          '$pointsNote',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'strokes': {
          'type': 'array',
          'description': 'The strokes, in order.',
          'items': McpSchema.object({
            'points': {
              'type': 'array',
              'description': '[[x, y], …] in cm, terrain-local.',
              'items': {'type': 'array', 'items': {'type': 'number'}},
            },
            'invert': McpSchema.boolean('Lower instead of raise (Shift).'),
            'tool': McpSchema.string('This stroke\'s tool.', enumValues: toolNames),
            'radius_cm': McpSchema.number('This stroke\'s radius in cm.'),
            'strength': McpSchema.number('This stroke\'s strength 0.01–1.'),
            'falloff': McpSchema.number('This stroke\'s falloff 0–1.'),
            'falloff_type': McpSchema.string('This stroke\'s falloff curve.', enumValues: falloffNames),
          }, required: ['points']),
        },
      }, required: ['asset', 'strokes']),
      handler: (args) async {
        final raw = parseStrokes(args);
        final strokes = <({List<List<double>> points, bool invert, LandscapeTool? tool, double? radius, double? strength, double? falloff, LandscapeFalloffType? type})>[];
        for (var i = 0; i < raw.length; i++) {
          final s = raw[i];
          final where = 'strokes[$i]';
          final tool = s['tool'];
          if (tool != null && (tool is! String || !toolNames.contains(tool))) {
            bad('$where.tool "$tool" is not a landscape tool. Tools: ${toolNames.join(', ')} (there are no paint layers).');
          }
          final type = s['falloff_type'];
          if (type != null && (type is! String || !falloffNames.contains(type))) {
            bad('$where.falloff_type "$type" is not one of ${falloffNames.join(', ')}.');
          }
          double? number(String key) {
            final v = s[key];
            if (v == null) return null;
            if (v is! num) bad('$where.$key must be a number');
            return v.toDouble();
          }

          final invert = s['invert'];
          if (invert != null && invert is! bool) bad('$where.invert must be a boolean');
          strokes.add((
            points: parsePoints(s['points'], where),
            invert: invert == true,
            tool: tool == null ? null : LandscapeTool.values.byName(tool as String),
            radius: number('radius_cm'),
            strength: number('strength'),
            falloff: number('falloff'),
            type: type == null ? null : LandscapeFalloffType.values.byName(type as String),
          ));
        }
        final e = await editorFor(args);
        e.setTab(LandscapeEditorTab.sculpt);
        final results = <Map<String, Object?>>[];
        e.withoutPersistingBrush(() {
          for (final s in strokes) {
            final saved = (e.tool, e.brushRadius, e.brushStrength, e.brushFalloff, e.falloffType);
            if (s.tool != null) e.setTool(s.tool!);
            if (s.radius != null) e.setBrushRadius(m(s.radius!));
            if (s.strength != null) e.setBrushStrength(s.strength!);
            if (s.falloff != null) e.setBrushFalloff(s.falloff!);
            if (s.type != null) e.setFalloffType(s.type!);
            final depth = e.undoDepth;
            final used = e.tool.name;
            final (x0, z0) = toWorld(s.points.first);
            e.beginStroke(x0, z0, invert: s.invert);
            for (final p in s.points.skip(1)) {
              final (x, z) = toWorld(p);
              e.strokeTo(x, z);
            }
            e.endStroke();
            final rect = e.undoDepth > depth ? e.lastStrokeRect : null;
            double? lo, hi;
            if (rect != null) {
              final res = e.data.gridResolution;
              for (var r = rect.minRow; r <= rect.maxRow; r++) {
                for (var c = rect.minCol; c <= rect.maxCol; c++) {
                  final h = e.data.heightAtIndex(r * res + c);
                  lo = lo == null ? h : math.min(lo, h);
                  hi = hi == null ? h : math.max(hi, h);
                }
              }
            }
            results.add({
              'tool': used,
              'invert': s.invert,
              'points': s.points.length,
              'undo_entry': rect != null,
              if (rect != null) 'touched_cells': rect.cellCount,
              if (lo != null) 'touched_height_min_cm': cm(lo),
              if (hi != null) 'touched_height_max_cm': cm(hi),
            });
            e.setTool(saved.$1);
            e.setBrushRadius(saved.$2);
            e.setBrushStrength(saved.$3);
            e.setBrushFalloff(saved.$4);
            e.setFalloffType(saved.$5);
          }
        });
        return McpToolResult.json({
          'strokes': results,
          'height_min_cm': cm(e.heightMin),
          'height_max_cm': cm(e.heightMax),
          'undo_depth': e.undoDepth,
          'undo_label': e.undoLabel,
        });
      },
    ),
    McpTool(
      name: 'add_foliage_layer',
      risk: McpToolRisk.mutating,
      groups: groups,
      title: 'Add foliage layer',
      description: 'Foliage → Mesh Palette: adds a layer painting a static mesh (list_assets type "filamesh"), '
          'selected for paint_foliage, with optional placement rules (density per 1000 × 1000 cm, min_spacing_cm, '
          'scale_min / scale_max, random_yaw, align_to_normal, slope_min_deg / slope_max_deg; clamped as the '
          'panel\'s sliders). A mesh already on a layer is refused, as the palette disables it. $noUndoNote',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'mesh': McpSchema.string('The static mesh asset (project-relative path or unique file name).'),
        'name': McpSchema.string('The layer name; default the mesh\'s name.'),
        'rules': rulesSchema,
      }, required: ['asset', 'mesh']),
      handler: (args) async {
        final mesh = sessions.resolveAsset(args.string('mesh'), type: AssetType.filamesh);
        final e = await editorFor(args);
        final path = mesh.lmasPath ?? mesh.relativePath;
        if (e.data.layers.any((l) => l.meshAssetPath == path)) {
          return McpToolResult.error('${mesh.relativePath} already has a foliage layer; set its rules with set_foliage_rules.');
        }
        final rules = parseRules(args['rules'], const FoliageRules());
        e.setTab(LandscapeEditorTab.foliage);
        final index = e.addFoliageLayer(
          meshAssetId: mesh.assetId ?? mesh.fileName,
          meshAssetPath: path,
          name: args.optionalString('name') ?? mesh.fileName.replaceAll('.lmas', ''),
        );
        if (args.has('rules')) e.setLayerRules(index, rules);
        return McpToolResult.json({'layer': layerJson(e, index), 'foliage_layers': e.data.layers.length});
      },
    ),
    McpTool(
      name: 'set_foliage_rules',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Set foliage rules',
      description: 'A foliage layer\'s placement rules (the layer card\'s sliders and switches); rules not given keep '
          'their values. Applies to instances painted from now on. $noUndoNote',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'layer': McpSchema.any('The layer index or name (get_landscape).'),
        'rules': rulesSchema,
      }, required: ['asset', 'layer', 'rules']),
      handler: (args) async {
        final e = await editorFor(args);
        final index = layerIndex(e, args['layer']);
        e.setTab(LandscapeEditorTab.foliage);
        e.setLayerRules(index, parseRules(args['rules'], e.data.layers[index].rules));
        return McpToolResult.json({'layer': layerJson(e, index)});
      },
    ),
    McpTool(
      name: 'remove_foliage_layer',
      risk: McpToolRisk.destructive,
      groups: groups,
      title: 'Remove foliage layer',
      description: 'Removes a foliage layer and every instance painted with it. $noUndoNote',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'layer': McpSchema.any('The layer index or name (get_landscape).'),
      }, required: ['asset', 'layer']),
      handler: (args) async {
        final e = await editorFor(args);
        final index = layerIndex(e, args['layer']);
        final name = e.data.layers[index].name;
        final instances = e.data.layers[index].instanceCount;
        e.removeFoliageLayer(index);
        return McpToolResult.json({'removed': name, 'instances_removed': instances, 'foliage_layers': e.data.layers.length});
      },
    ),
    McpTool(
      name: 'paint_foliage',
      risk: McpToolRisk.mutating,
      groups: groups,
      title: 'Paint foliage',
      description: 'Drags the foliage brush along each stroke on a layer: paint scatters instances by the layer\'s '
          'rules and the brush\'s paint density; erase: true removes them (thinned by the erase density). Each '
          'stroke is one undo entry "foliage <layer>" on the landscape\'s stack. At most $maxStrokes strokes × '
          '$maxPoints points. Returns the instances placed and erased. $pointsNote',
      inputSchema: McpSchema.object({
        'asset': assetArg,
        'layer': McpSchema.any('The layer index or name (get_landscape).'),
        'strokes': {
          'type': 'array',
          'description': 'The strokes, in order.',
          'items': McpSchema.object({
            'points': {
              'type': 'array',
              'description': '[[x, y], …] in cm, terrain-local.',
              'items': {'type': 'array', 'items': {'type': 'number'}},
            },
            'erase': McpSchema.boolean('Erase instead of paint.'),
          }, required: ['points']),
        },
      }, required: ['asset', 'layer', 'strokes']),
      handler: (args) async {
        final raw = parseStrokes(args);
        final strokes = [
          for (var i = 0; i < raw.length; i++) (points: parsePoints(raw[i]['points'], 'strokes[$i]'), erase: raw[i]['erase'] == true),
        ];
        final e = await editorFor(args);
        final index = layerIndex(e, args['layer']);
        e.setTab(LandscapeEditorTab.foliage);
        e.selectFoliageLayer(index);
        final layer = e.data.layers[index];
        var placed = 0, erased = 0;
        for (final s in strokes) {
          final before = layer.instanceCount;
          final (x0, z0) = toWorld(s.points.first);
          e.beginFoliageStroke(x0, z0, erase: s.erase);
          for (final p in s.points.skip(1)) {
            final (x, z) = toWorld(p);
            e.foliageStrokeTo(x, z);
          }
          e.endFoliageStroke();
          final delta = layer.instanceCount - before;
          if (delta > 0) placed += delta;
          if (delta < 0) erased -= delta;
        }
        return McpToolResult.json({
          'layer': layerJson(e, index),
          'instances_placed': placed,
          'instances_erased': erased,
          'undo_depth': e.undoDepth,
          'status': e.statusMessage,
        });
      },
    ),
    McpTool(
      name: 'save_landscape',
      risk: McpToolRisk.mutating,
      groups: groups,
      idempotent: true,
      title: 'Save landscape',
      description: 'The Landscape tab\'s Save: writes the heights and foliage layers to the .lmas (a large terrain\'s '
          'heights to its sidecar).',
      inputSchema: McpSchema.object({'asset': assetArg}, required: ['asset']),
      handler: (args) async {
        final e = await editorFor(args);
        if (!await e.save()) return McpToolResult.error(e.statusMessage ?? 'Save failed; see the Output Log.');
        return McpToolResult.json({'saved': args.string('asset'), 'status': e.statusMessage, 'is_dirty': e.isDirty});
      },
    ),
  ]);
}
