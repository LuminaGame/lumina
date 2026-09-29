part of '../build_pipeline_service.dart';

// --- 2. navigation build ---------------------------------------------------

class NavBuildOutcome {
  final BuildStepStatus status;
  final String message;
  const NavBuildOutcome(this.status, this.message);
}

/// Delegate seam for the navigation bake so the navigation editor can plug
/// its own build path in; the default reads the level file.
typedef NavigationBuilder = Future<NavBuildOutcome> Function(BuildStepContext ctx);

class NavigationBuildStep implements BuildStep {
  final NavigationBuilder _builder;
  NavigationBuildStep({NavigationBuilder? builder}) : _builder = builder ?? levelFileNavigationBuilder;

  @override
  BuildStepKind get kind => BuildStepKind.buildNavigation;

  @override
  Future<StepResult> execute(BuildStepContext ctx) async {
    final outcome = await _builder(ctx);
    return StepResult(outcome.status, outcome.message);
  }

  /// Reads `NavMeshBoundsVolume` actors (and the level's `navigation`
  /// section) from the active level `.lmas`, then runs the engine's real
  /// grid bake ([LuminaNavigationSystem.buildFromWorld]) on a headless world.
  ///
  /// Units and axes match the navigation editor: stored transforms are
  /// authoring space (cm, Z up) and go through [LuminaAxes] into the
  /// runtime's Y-up grid space; a volume's `scale` is its size in metres (a
  /// 1 m base box), so its size in world units is `scale × unitsPerMetre`.
  /// An explicit `extent` is a half size in cm (a box extent). The
  /// `navigation.config` lengths are cm; missing values fall back to
  /// `NavGridConfig()`.
  static Future<NavBuildOutcome> levelFileNavigationBuilder(BuildStepContext ctx) async {
    final levelFile = ctx.activeLevelFile;
    if (levelFile == null || !levelFile.existsSync()) {
      return const NavBuildOutcome(BuildStepStatus.skipped, 'No active level on disk — no nav volumes to build');
    }
    Map<String, dynamic> map;
    try {
      map = _readLevelMap(levelFile);
    } catch (e) {
      return NavBuildOutcome(BuildStepStatus.failed, 'Level ${levelFile.path} is not readable: $e');
    }
    final metadata = map['metadata'] is Map ? Map<String, dynamic>.from(map['metadata'] as Map) : <String, dynamic>{};
    final navSection = metadata['navigation'] is Map ? Map<String, dynamic>.from(metadata['navigation'] as Map) : <String, dynamic>{};
    final volumes = <Aabb3>[];

    List<double> vec(dynamic v, List<double> fallback) {
      if (v is List && v.length >= 3) return v.take(3).map((e) => (e as num).toDouble()).toList();
      return fallback;
    }

    /// Runtime AABB (cm, Y up) of a box stored at authoring [centre] (cm,
    /// Z up) with authoring half size [halfCm].
    Aabb3 box(List<double> centre, Vector3 halfCm) {
      final c = LuminaAxes.location(centre);
      return Aabb3.minMax(c - halfCm, c + halfCm);
    }

    // Half size of a section volume without an `extent`: 20 × 20 m, 5 m tall.
    final fallbackHalfCm = [LuminaUnits.metres(10), LuminaUnits.metres(10), LuminaUnits.metres(2.5)];
    for (final raw in (navSection['volumes'] as List? ?? const [])) {
      // The navigation editor mirrors volume actors here as `{id, name}`;
      // only entries carrying their own `center` describe a volume.
      if (raw is! Map || raw['center'] == null) continue;
      final c = vec(raw['center'], [0, 0, 0]);
      final e = vec(raw['extent'], fallbackHalfCm);
      volumes.add(box(c, LuminaAxes.scale(e)..absolute()));
    }
    for (final raw in (metadata['actors'] as List? ?? const [])) {
      if (raw is! Map || raw['type'] != 'NavMeshBoundsVolume') continue;
      final c = vec(raw['location'], [0, 0, 0]);
      final extent = raw['extent'];
      final half = extent is List && extent.length >= 3
          ? (LuminaAxes.scale(vec(extent, [0, 0, 0]))..absolute())
          : (LuminaAxes.scale(vec(raw['scale'], [1, 1, 1]))
            ..absolute()
            ..scale(LuminaUnits.unitsPerMetre / 2));
      volumes.add(box(c, half));
    }
    final levelName = ctx.activeLevelName ?? levelFile.path;
    if (volumes.isEmpty) {
      ctx.log('No NavMeshBoundsVolume in level "$levelName" — navigation build skipped');
      return NavBuildOutcome(BuildStepStatus.skipped, 'No nav volumes in "$levelName" — skipped');
    }
    final cfgMap = navSection['config'] is Map ? Map<String, dynamic>.from(navSection['config'] as Map) : const <String, dynamic>{};
    // The navigation editor writes camelCase keys; snake_case is accepted too.
    num? cfg(String camel, String snake) => (cfgMap[camel] ?? cfgMap[snake]) as num?;
    const defaults = NavGridConfig();
    final config = NavGridConfig(
      cellSize: cfg('cellSize', 'cell_size')?.toDouble() ?? defaults.cellSize,
      agentRadius: cfg('agentRadius', 'agent_radius')?.toDouble() ?? defaults.agentRadius,
      agentHeight: cfg('agentHeight', 'agent_height')?.toDouble() ?? defaults.agentHeight,
      maxStepHeight: cfg('maxStepHeight', 'max_step_height')?.toDouble() ?? defaults.maxStepHeight,
      walkableLayerMask: cfg('walkableLayerMask', 'walkable_layer_mask')?.toInt() ?? defaults.walkableLayerMask,
    );
    final bounds = Aabb3.copy(volumes.first);
    for (final v in volumes.skip(1)) {
      bounds.hull(v);
    }
    final size = bounds.max - bounds.min;
    String cm(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    ctx.log('Baking navigation grid for "$levelName": ${volumes.length} volume(s), '
        'area ${cm(size.x)} × ${cm(size.z)} cm, ${cm(size.y)} cm tall, '
        'cell ${cm(config.cellSize)} cm, agent r=${cm(config.agentRadius)} cm');
    final sw = Stopwatch()..start();
    final world = LuminaWorld(worldType: LuminaWorldType.editor);
    final nav = LuminaNavigationSystem();
    world.registerSubsystem<LuminaNavigationSystem>(nav);
    nav.buildFromWorld(bounds: bounds, config: config);
    final collisionCount = world.levels.expand((l) => l.actors).expand((a) => a.components).whereType<LuminaCollisionComponent>().length;
    final cols = (size.x / config.cellSize).ceil();
    final rows = (size.z / config.cellSize).ceil();
    final msg = 'Navigation grid built: ${nav.walkableCellCount} walkable cells (${cols}x$rows @ ${cm(config.cellSize)} cm, $collisionCount collision components) in ${_fmt(sw.elapsed)}';
    if (collisionCount == 0) {
      ctx.log('Level actors carry no collision components — every cell inside the volumes is walkable', level: 'warning');
    }
    return NavBuildOutcome(BuildStepStatus.ok, msg);
  }
}

// --- 3. thumbnail regeneration ---------------------------------------------

class ThumbnailRegenStep implements BuildStep {
  final ThumbnailService _service;
  ThumbnailRegenStep({ThumbnailService? thumbnailService}) : _service = thumbnailService ?? ThumbnailService();

  @override
  BuildStepKind get kind => BuildStepKind.regenerateThumbnails;

  /// Types whose `.lmas` round-trips safely through [LuminaAsset]; level
  /// files are editor-owned JSON documents and are never rewritten here.
  static const Set<AssetType> _renderable = {
    AssetType.filamesh,
    AssetType.filameshSk,
    AssetType.filamat,
    AssetType.texture,
    AssetType.actor,
    AssetType.animation,
    AssetType.particle,
    AssetType.audio,
    AssetType.landscape,
    AssetType.physicsAsset,
    AssetType.sequencer,
    AssetType.widget,
  };

  /// Stale when the asset has no embedded thumbnail, no thumbnail stamp
  /// (`metadata.thumbnail_asset_modified`), or its `.lmas` was modified after
  /// that stamp (there is no `.thumbnails/` sidecar to compare with).
  static bool isStale(AssetIndexEntry entry) {
    final summary = entry.summary;
    if (!summary.hasThumbnailBytes && !(summary.hasThumbnail && summary.thumbnailRange == null && summary.payloadRange == null)) {
      return true;
    }
    final stamp = DateTime.tryParse(summary.metadata[ThumbnailService.assetModifiedKey] ?? '');
    if (stamp == null) return true;
    return entry.modifiedMs > stamp.millisecondsSinceEpoch;
  }

  @override
  Future<StepResult> execute(BuildStepContext ctx) async {
    // The asset index lists the candidates; only stale assets are decoded.
    final index = LuminaAssetIndex.open(ctx.projectDir)..refreshSync();
    final all = [for (final e in index.entries) if (_renderable.contains(e.type)) e];
    final stale = all.where(isStale).toList();
    ctx.log('Thumbnails: ${all.length} asset(s) scanned, ${stale.length} stale or missing');
    if (stale.isEmpty) return StepResult.ok('Thumbnails up to date (${all.length} assets)');
    var done = 0;
    var failed = 0;
    for (final s in stale) {
      if (ctx.token.isCancelled) return StepResult.cancelled('Thumbnail regeneration cancelled after $done/${stale.length}');
      try {
        final a = LuminaAsset.fromBytes(s.file.readAsBytesSync());
        final rendered = a.type == AssetType.filamesh || a.type == AssetType.filamat;
        final png = rendered ? await _service.renderAssetThumbnail(a) : await _service.renderTypeIconThumbnail(a.type);
        // Into the .lmas only, stamped current (no sidecar).
        ThumbnailService.embedThumbnail(
          s.absolutePath,
          png,
          source: rendered ? ThumbnailService.sourceFilament : ThumbnailService.sourceBadge,
        );
        done++;
        ctx.log('${a.name}: thumbnail rendered (${png.length} bytes) — ${s.path}', level: 'success');
      } catch (e) {
        done++;
        failed++;
        ctx.log('${s.baseName}: thumbnail failed — $e', level: 'error');
      }
      ctx.progress(completed: done, total: stale.length, failed: failed, label: 'Thumbnails: $done/${stale.length} rendered, $failed failed');
    }
    final summary = 'Thumbnails: ${done - failed}/${stale.length} regenerated, $failed failed';
    return failed > 0 ? StepResult.failed(summary) : StepResult.ok(summary);
  }
}

// --- 4. asset validation ---------------------------------------------------

class AssetValidationStep implements BuildStep {
  @override
  BuildStepKind get kind => BuildStepKind.validateAssets;

  @override
  Future<StepResult> execute(BuildStepContext ctx) async {
    final assets = _scanLmas(ctx.projectDir, onError: (p, e) => ctx.log('Unreadable asset $p: $e', level: 'warning'));
    final byPath = {for (final a in assets) a.relativePath: a};
    final byId = <String, _ScannedAsset>{for (final a in assets.where((a) => a.asset.assetId.isNotEmpty)) a.asset.assetId: a};
    final issues = <ValidationIssue>[];
    var refs = 0;
    for (final a in assets) {
      if (ctx.token.isCancelled) return const StepResult.cancelled('Validation cancelled');
      for (final ref in a.asset.references) {
        refs++;
        final target = _relative(ctx.projectDir, ref.assetPath);
        void add(ValidationIssueKind kind, ValidationSeverity sev, String msg) {
          issues.add(ValidationIssue(
            assetPath: a.relativePath,
            slotName: ref.slotName,
            targetPath: target,
            assetId: ref.assetId,
            kind: kind,
            severity: sev,
            message: msg,
          ));
        }

        final selfById = ref.assetId.isNotEmpty && ref.assetId == a.asset.assetId;
        if (selfById || target == a.relativePath) {
          add(ValidationIssueKind.selfReference, ValidationSeverity.error, '${a.relativePath} slot "${ref.slotName}" references itself');
          continue;
        }
        final atPath = byPath[target];
        final exists = atPath != null || (target.isNotEmpty && File('${ctx.projectDir}/$target').existsSync());
        final known = ref.assetId.isNotEmpty ? byId[ref.assetId] : null;
        if (!exists) {
          if (known != null) {
            add(ValidationIssueKind.pathMismatch, ValidationSeverity.warning,
                '${a.relativePath} slot "${ref.slotName}": path $target is gone but asset ${ref.assetId} now lives at ${known.relativePath}');
          } else {
            add(ValidationIssueKind.missingTarget, ValidationSeverity.error,
                '${a.relativePath} slot "${ref.slotName}": missing target $target');
          }
          continue;
        }
        if (ref.assetId.isNotEmpty && atPath != null && atPath.asset.assetId.isNotEmpty && atPath.asset.assetId != ref.assetId) {
          if (known != null) {
            add(ValidationIssueKind.pathMismatch, ValidationSeverity.warning,
                '${a.relativePath} slot "${ref.slotName}": $target holds ${atPath.asset.assetId}, but asset ${ref.assetId} lives at ${known.relativePath}');
          } else {
            add(ValidationIssueKind.danglingAssetId, ValidationSeverity.error,
                '${a.relativePath} slot "${ref.slotName}": asset_id ${ref.assetId} does not exist in the project ($target holds ${atPath.asset.assetId})');
          }
          continue;
        }
        if (ref.assetId.isNotEmpty && known == null && atPath != null && atPath.asset.assetId.isEmpty) {
          add(ValidationIssueKind.danglingAssetId, ValidationSeverity.error,
              '${a.relativePath} slot "${ref.slotName}": asset_id ${ref.assetId} does not exist in the project');
        }
      }
    }
    for (final i in issues) {
      ctx.issue(i);
      ctx.log(i.message, level: i.severity == ValidationSeverity.error ? 'error' : 'warning');
    }
    final errors = issues.where((i) => i.severity == ValidationSeverity.error).length;
    final warnings = issues.length - errors;
    final summary = 'Validated ${assets.length} assets / $refs references: $errors error(s), $warnings warning(s)';
    return errors > 0 ? StepResult(BuildStepStatus.failed, summary, issues: issues) : StepResult(BuildStepStatus.ok, summary, issues: issues);
  }
}
