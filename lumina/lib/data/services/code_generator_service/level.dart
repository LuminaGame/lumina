part of '../code_generator_service.dart';

/// The generated level library: data layers, game mode binding and every
/// placed actor with its components.
mixin _LevelCodegen on _DartCodeGeneratorServiceState {

  /// Generates the Dart level class for [levelName] (`L_Main` → class
  /// `LMain`, written to `lib/levels/l_main.dart` — [dartTypeName],
  /// [dartFileName]).
  ///
  /// [actors] carries the legacy name/type list (metadata `type`); when
  /// [actorMaps] is given it takes precedence and holds the full editor actor
  /// maps (`EditorActorNode.toMap()`: type, location, rotation, scale,
  /// lightIntensity, lightColorHex, castShadows, meshAssetPath, components…)
  /// so lights, meshes, pawns and sky components are emitted as real runtime
  /// objects. [environment] is the level's `metadata.environment` section
  /// written by the Environment Lighting mixer (`sun`, `sky`, `postProcess`);
  /// its post-process values are applied from the level script actor's
  /// `onBeginPlay`, mirroring what the editor viewport shows.
  /// [worldPartition] is the level's `metadata.worldPartition` section
  /// (`enabled`, `cellSize`, `loadingRange`, `maxCellTransitionsPerTick`,
  /// `dataLayers`) authored by the New Level dialog's Open World template and
  /// the details panel's World Partition section. When it is absent — or
  /// present with `enabled: false` — this method emits byte-for-byte what it
  /// emitted before world partition existed.
  /// A `Mesh`/`StaticMesh` actor whose mesh asset carries imported collision
  /// hulls becomes a `LuminaStaticMeshActor` with the hulls
  /// baked in as constants — read here, from the `.lmas` at [meshAssetPath]
  /// (absolute, or `contents/…` under [projectDir]), never by the game.
  String generateLevelDart({
    required String levelName,
    required List<LuminaAsset> actors,
    List<Map<String, dynamic>>? actorMaps,
    Map<String, dynamic>? environment,
    Map<String, dynamic>? worldPartition,
    String? projectDir,
    LuminaLevelBlueprintDocument? levelBlueprint,
  }) {
    // The level's class follows Dart's naming rules (`L_Main` → `LMain`, in
    // `levels/l_main.dart`, which main.dart imports); the level keeps its
    // authored name at run time.
    final className = dartTypeName(levelName);
    final maps = actorMaps ??
        actors
            .map((a) => <String, dynamic>{
                  'id': a.assetId,
                  'name': a.name,
                  'type': a.metadata['type'] ?? 'actor',
                  'location': [0.0, 0.0, 0.0],
                })
            .toList();

    final hasPlayerStart = maps.any((a) => (a['type'] ?? '').toString() == 'PlayerStart');
    final gameModeBlueprint = _gameModeBlueprintBinding(maps);
    final usesBlueprints = gameModeBlueprint != null ||
        maps.any((a) => a['blueprintClass'] is String && (a['blueprintClass'] as String).isNotEmpty);
    final gameModeBinding = gameModeBlueprint != null ? null : _gameModeBinding(maps);
    final partition = (worldPartition != null && worldPartition['enabled'] == true)
        ? Map<String, dynamic>.from(worldPartition)
        : null;
    // Streaming sources inherit the section's loading range unless the
    // component authored its own radius.
    final sectionLoadingRange = _num(partition?['loadingRange'], kWorldPartitionDefaultLoadingRange);
    final streamingStartClass = '_${className}StreamingPlayerStart';
    final emitsStreamingStart = partition != null &&
        maps.any((a) =>
            (a['type'] ?? '').toString() == 'PlayerStart' &&
            _componentOfType(a, 'LuminaStreamingSourceComponent') != null);

    final buffer = StringBuffer();
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Lumina Engine $kLuminaEngineVersion Auto-Generated Level Code');
    buffer.writeln('// ignore_for_file: unused_import, prefer_const_constructors');
    buffer.writeln();
    buffer.writeln("import 'package:flutter/foundation.dart' show ValueKey;");
    buffer.writeln("import 'package:lumina/lumina_runtime.dart';");
    buffer.writeln("import 'package:vector_math/vector_math_64.dart';");
    if (gameModeBinding != null) {
      buffer.writeln("import '${_escape(gameModeBinding.$2)}';");
    }
    if (usesBlueprints) buffer.writeln("import '../actors/actors.g.dart';");
    buffer.writeln();
    buffer.writeln('/// Level `$levelName` as authored in Lumina Studio.');
    buffer.writeln('class $className extends LuminaLevel {');
    buffer.writeln('  $className({super.key})');
    buffer.writeln("      : super(name: '${_escape(levelName)}', scriptActor: _${className}Script(), children: [");
    for (final map in maps) {
      final emitted = _emitActor(
        map,
        streamingStartClass: emitsStreamingStart ? streamingStartClass : null,
        sectionLoadingRange: sectionLoadingRange,
        projectDir: projectDir,
        environment: environment,
      );
      if (emitted == null) continue;
      final label = (map['name'] ?? '').toString().replaceAll(RegExp(r'[\r\n]'), ' ');
      buffer.writeln('          // ${label.isEmpty ? map['id'] : label}');
      buffer.writeln('          $emitted');
    }
    buffer.writeln('        ]);');
    buffer.writeln();
    // What Load Level preloads for this level.
    buffer.writeln("  /// Every asset this level's actors load, for Load Level / Change Level.");
    buffer.writeln('  static const List<LuminaAssetRef> assetManifest = '
        '${LuminaLevelAssetManifest.toDartLiteral(LuminaLevelAssetManifest.fromActorMaps(maps, projectDir: projectDir), indent: '  ')};');
    buffer.writeln('}');
    buffer.writeln();
    // The script's begin-play body, its members and its tick, shared by the
    // plain script and the one a Level Blueprint compiles to.
    final begin = <String>[];
    final pp = environment?['postProcess'];
    final needsWorld = hasPlayerStart || pp is Map || partition != null;
    if (needsWorld) {
      begin.add('final w = world;');
    }
    if (pp is Map) {
      begin.add('if (w != null && w.hasNativeContext) {');
      begin.add('  w.postProcess.apply(${_emitPostProcess(Map<String, dynamic>.from(pp))});');
      begin.add('}');
    } else if (!hasPlayerStart && partition == null) {
      begin.add('// No environment section authored for this level.');
    }
    if (partition != null) {
      final cellSize = _num(partition['cellSize'], kWorldPartitionDefaultCellSize);
      final maxTransitions = partition['maxCellTransitionsPerTick'] is num
          ? (partition['maxCellTransitionsPerTick'] as num).toInt()
          : 10;
      final layers = partition['dataLayers'] is List
          ? (partition['dataLayers'] as List).whereType<Map>().toList()
          : const <Map>[];
      begin.add('// World Partition as authored in Lumina Studio.');
      begin.add('if (w != null) {');
      begin.add('  if (w.getSubsystem<LuminaWorldPartitionSubsystem>() == null) {');
      begin.add('    w.registerSubsystem(LuminaWorldPartitionSubsystem('
          'cellSize: ${_f(cellSize)}, maxCellTransitionsPerTick: $maxTransitions));');
      begin.add('  }');
      begin.add('  final partition = w.getSubsystem<LuminaWorldPartitionSubsystem>()!;');
      for (final layer in layers) {
        final name = (layer['name'] ?? '').toString();
        if (name.isEmpty) continue;
        final state = _dataLayerState(layer['initialState']);
        final runtime = layer['isRuntime'] is bool ? layer['isRuntime'] as bool : true;
        begin.add("  partition.dataLayerManager.registerLayer('${_escape(name)}', "
            'initialState: DataLayerState.$state, bIsRuntime: $runtime);');
      }
      begin.add('  for (final actor in w.actors) {');
      begin.add('    partition.addActor(actor, actor.actorLocation);');
      begin.add('    for (final component in actor.components) {');
      begin.add('      if (component is LuminaStreamingSourceComponent) {');
      begin.add('        partition.registerSource(component);');
      begin.add('      }');
      begin.add('    }');
      begin.add('  }');
      begin.add('}');
    }
    if (hasPlayerStart) {
      begin.add('if (w == null) return;');
      begin.add('if (w.getSubsystem<LuminaCollisionSubsystem>() == null) {');
      begin.add('  w.registerSubsystem(LuminaCollisionSubsystem());');
      begin.add('}');
      begin.add('if (w.getSubsystem<LuminaInputSubsystem>() == null) {');
      begin.add('  w.registerSubsystem(LuminaInputSubsystem());');
      begin.add('}');
      begin.add('var mode = w.gameMode;');
      begin.add('if (mode == null) {');
      if (gameModeBlueprint != null) {
        begin.add("  mode = luminaGameModeFactories['${_escape(gameModeBlueprint)}']!();");
      } else if (gameModeBinding != null) {
        begin.add('  mode = ${gameModeBinding.$1}();');
      } else {
        begin.add('  mode = LuminaGameMode();');
      }
      begin.add('  w.gameMode = mode;');
      begin.add('  mode.initGame(w);');
      begin.add('}');
      begin.add('playerController = mode.login();');
    }

    // The level's Blueprint, stored in its `.lmas`.
    final blueprint = levelBlueprint ??
        (projectDir == null ? null : LuminaLevelRepository(projectDir).load('contents/levels/$levelName.lmas')?.levelBlueprint);
    String? blueprintScript;
    if (blueprint != null && !blueprint.isEmpty) {
      final owners = _levelActorClasses(maps, projectDir);
      final result = const BlueprintDartGenerator().generateLevelScript(
        blueprint,
        className: '_${className}Script',
        levelName: levelName,
        levelActors: LuminaBlueprintLevelActorRef.fromActorMaps(maps),
        inputActions: projectDir == null ? const [] : DartCodeGeneratorService.projectInputActions(projectDir),
        actorParents: owners.parents,
        customEventOwners: owners.events,
        members: [
          if (hasPlayerStart) ...[
            '/// The controller created by the game mode at begin play.',
            'LuminaPlayerController? playerController;',
            '',
          ],
          '/// Applies the level environment (post-process) when play begins and,',
          '/// when the level authors a PlayerStart, logs the local player in.',
          'void _setUpLevel() {',
          for (final line in begin) '  $line',
          '}',
        ],
        beginPlay: const ['_setUpLevel();'],
        tick: [if (hasPlayerStart) 'playerController?.onTick(deltaSeconds);'],
      );
      if (result.ok) {
        blueprintScript = result.code;
        for (final i in result.imports) {
          if (!buffer.toString().contains(i)) {
            final text = buffer.toString();
            final at = text.indexOf("import 'package:vector_math/vector_math_64.dart';\n");
            buffer
              ..clear()
              ..write(text.substring(0, at))
              ..writeln(i)
              ..write(text.substring(at));
          }
        }
      } else {
        // The level still plays; the editor's compiler results name the errors.
        buffer.writeln('// Level Blueprint not generated: ${result.errors.map((e) => e.message.replaceAll(RegExp(r'[\r\n]'), ' ')).join('; ')}');
        buffer.writeln();
      }
    }

    if (blueprintScript != null) {
      // The compiled graph's names and locals follow the Blueprint's, not Dart's style.
      final text = buffer.toString().replaceFirst('// ignore_for_file: unused_import, prefer_const_constructors\n',
          '// ignore_for_file: unused_import, prefer_const_constructors, camel_case_types, non_constant_identifier_names, '
              'unnecessary_this, dead_code, unused_local_variable, dead_null_aware_expression\n');
      buffer
        ..clear()
        ..write(text)
        ..write(blueprintScript);
    } else {
      buffer.writeln('/// Applies the level environment (post-process) when play begins,');
      buffer.writeln('/// and — when the level authors a PlayerStart — makes sure the game');
      buffer.writeln('/// mode is installed and the local player is logged in and possessed.');
      buffer.writeln('class _${className}Script extends LuminaLevelScriptActor {');
      buffer.writeln('  _${className}Script() : super(key: const ValueKey(\'${_escape(levelName)}_script\'));');
      buffer.writeln();
      if (hasPlayerStart) {
        buffer.writeln('  /// The controller created by the game mode at begin play.');
        buffer.writeln('  LuminaPlayerController? playerController;');
        buffer.writeln();
      }
      buffer.writeln('  @override');
      buffer.writeln('  void onBeginPlay() {');
      buffer.writeln('    super.onBeginPlay();');
      for (final line in begin) {
        buffer.writeln('    $line');
      }
      buffer.writeln('  }');
      if (hasPlayerStart) {
        buffer.writeln();
        buffer.writeln('  @override');
        buffer.writeln('  void onTick(double deltaTime) {');
        buffer.writeln('    super.onTick(deltaTime);');
        buffer.writeln('    playerController?.onTick(deltaTime);');
        buffer.writeln('  }');
      }
      buffer.writeln('}');
    }
    if (emitsStreamingStart) {
      buffer.writeln();
      buffer.writeln('/// A `PlayerStart` that carries a real');
      buffer.writeln('/// [LuminaStreamingSourceComponent], so the world partition streams');
      buffer.writeln('/// cells around wherever the player spawns.');
      buffer.writeln('class $streamingStartClass extends LuminaPlayerStart {');
      buffer.writeln('  final LuminaStreamingSourceComponent streamingSource;');
      buffer.writeln();
      buffer.writeln('  $streamingStartClass({');
      buffer.writeln('    super.key,');
      buffer.writeln('    super.location,');
      buffer.writeln('    super.rotation,');
      buffer.writeln('    required double loadingRadius,');
      buffer.writeln('    int priority = 1,');
      buffer.writeln('    bool bShapesCellLoading = true,');
      buffer.writeln('    LuminaStreamingSourceTargetState targetState =');
      buffer.writeln('        LuminaStreamingSourceTargetState.activated,');
      buffer.writeln('  }) : streamingSource = LuminaStreamingSourceComponent(');
      buffer.writeln('          loadingRadius: loadingRadius,');
      buffer.writeln('          priority: priority,');
      buffer.writeln('          bShapesCellLoading: bShapesCellLoading,');
      buffer.writeln('          targetState: targetState,');
      buffer.writeln('        ) {');
      buffer.writeln('    addComponent(streamingSource);');
      buffer.writeln('  }');
      buffer.writeln('}');
    }
    return buffer.toString();
  }

  /// The `.lmas` path of the GameMode Blueprint a level actor's
  /// `LuminaGameModeBinding` names (`gameModeBlueprint`), or null.
  String? _gameModeBlueprintBinding(List<Map<String, dynamic>> maps) {
    for (final a in maps) {
      final comp = _componentOfType(a, 'LuminaGameModeBinding');
      final props = comp?['properties'];
      final path = props is Map ? props['gameModeBlueprint'] : null;
      if (path is String && path.isNotEmpty) return path;
    }
    return null;
  }

  /// `(className, importPath)` of the game mode a level actor binds, or null.
  ///
  /// The binding lives on the PlayerStart's `LuminaGameModeBinding` component
  /// so it is part of `metadata.actors` — which means an editor save, which
  /// regenerates this file from the actor maps alone, cannot unwire it.
  (String, String)? _gameModeBinding(List<Map<String, dynamic>> maps) {
    for (final a in maps) {
      final comp = _componentOfType(a, 'LuminaGameModeBinding');
      if (comp == null) continue;
      final props = comp['properties'] is Map
          ? Map<String, dynamic>.from(comp['properties'] as Map)
          : const <String, dynamic>{};
      final cls = props['gameModeClass'];
      final imp = props['gameModeImport'];
      if (cls is String && cls.isNotEmpty && imp is String && imp.isNotEmpty) {
        return (cls, imp);
      }
    }
    return null;
  }

  /// One declarative runtime object per editor actor; null for folders.
  /// The material [a] assigns ([LuminaLevelActorMaterial]) as a
  /// `materialOverrideAsset: '…'` argument, or '' — with a comment line
  /// saying why when the assigned material cannot be drawn (the mesh then
  /// keeps its own).
  (String, String) _materialArgument(Map<String, dynamic> a, String? projectDir) {
    final path = LuminaLevelActorMaterial.pathOf(a);
    if (path == null) return ('', '');
    final problem = LuminaLevelActorMaterial.problem(path, projectDir: projectDir);
    if (problem != null) {
      return ('', '// Material not drawn, the mesh keeps its own: ${problem.replaceAll('\n', ' ')}\n          ');
    }
    return ("materialOverrideAsset: '${_escape(path)}'", '');
  }

  String? _emitActor(
    Map<String, dynamic> a, {
    String? streamingStartClass,
    double sectionLoadingRange = kWorldPartitionDefaultLoadingRange,
    String? projectDir,
    Map<String, dynamic>? environment,
  }) {
    final type = (a['type'] ?? 'actor').toString();
    if (type == 'Folder') return null;
    final id = (a['id'] ?? a['name'] ?? 'actor').toString();
    final loc = _vec3(a['location'], [0, 0, 0]);
    final rot = _vec3(a['rotation'], [0, 0, 0]);
    final scale = _vec3(a['scale'], [1, 1, 1]);
    final castShadows = a['castShadows'] is bool ? a['castShadows'] as bool : true;
    final visible = a['isVisible'] is bool ? a['isVisible'] as bool : true;
    final key = "key: const ValueKey('${_escape(id)}')";
    // Stored transforms are authored Z-up (the editor's); the
    // runtime is Y-up: convert once, here.
    final transform = 'location: ${_vector3(LuminaAxes.location(loc).storage)}, '
        'rotation: luminaAuthoringRotation(${_f(rot[0])}, ${_f(rot[1])}, ${_f(rot[2])})';
    final scaleCode = _vector3(LuminaAxes.scale(scale).storage);

    // A placed Blueprint keeps its class — the compiled
    // Blueprint's constructor, by its `.lmas` path.
    final blueprint = a['blueprintClass'];
    if (blueprint is String && blueprint.isNotEmpty) {
      final create = "luminaBlueprintFactories['${_escape(blueprint)}']!($key, $transform)";
      // The instance's collision overrides (the level Details),
      // applied as PIE applies them.
      final overrides = LuminaBlueprintCollisionOverrides.fromActorMap(a);
      if (overrides.isEmpty) return '$create,';
      final literal = [for (final e in overrides.entries) '${DartCodeGeneratorService._dartString(e.key)}: ${DartCodeGeneratorService._dartLiteral(e.value)}'].join(', ');
      return 'luminaWithCollisionOverrides($create, const <String, Map<String, dynamic>>{$literal}),';
    }

    switch (type) {
      case 'PlayerStart':
        final source = streamingStartClass == null
            ? null
            : _componentOfType(a, 'LuminaStreamingSourceComponent');
        if (source != null) {
          final props = source['properties'] is Map
              ? Map<String, dynamic>.from(source['properties'] as Map)
              : const <String, dynamic>{};
          final radius = _num(props['loadingRadius'], sectionLoadingRange);
          final priority = props['priority'] is num ? (props['priority'] as num).toInt() : 1;
          final shapes = props['bShapesCellLoading'] is bool ? props['bShapesCellLoading'] as bool : true;
          final target = props['targetState'] == 'loaded' ? 'loaded' : 'activated';
          return '$streamingStartClass($key, $transform, loadingRadius: ${_f(radius)}, '
              'priority: $priority, bShapesCellLoading: $shapes, '
              'targetState: LuminaStreamingSourceTargetState.$target),';
        }
        return 'LuminaPlayerStart($key, $transform),';
      case 'Primitive':
        final meshComp = _componentOfType(a, 'LuminaProceduralMeshComponent');
        final meshProps = meshComp?['properties'] is Map
            ? Map<String, dynamic>.from(meshComp!['properties'] as Map)
            : const <String, dynamic>{};
        final shape = (meshProps['shape'] ?? 'box').toString();
        // Stored Z up (sizeZ is the height), emitted as the runtime Y-up extent.
        final primSize = luminaPrimitiveSize(meshProps);
        final primColor = _hexRgb(meshProps['colorHex'], [0.6, 0.63, 0.68]);
        final (primMaterial, primNote) = _materialArgument(a, projectDir);
        return "${primNote}LuminaPrimitiveActor($key, $transform, scale: $scaleCode, "
            "shape: luminaPrimitiveShapeFrom('${_escape(shape)}'), "
            "size: ${_vector3(primSize.storage)}, "
            "color: ${_vector3(primColor)}${primMaterial.isEmpty ? '' : ', $primMaterial'}),";
      case 'TriggerVolume':
        // A trigger a Level Blueprint binds OnActorBeginOverlap
        // on; a 100 cm cube at scale 1 (runtime half extents, Y up).
        final half = [for (final v in LuminaAxes.scale(scale).storage) v.abs() * 50.0];
        return 'LuminaTriggerVolume($key, $transform, extent: ${_vector3(half)}),';
      case 'Pawn':
        // A bare, unpossessed pawn: a level that really wants one gets one.
        // The First/Third Person templates deliberately do NOT use this — they
        // place a `PlayerStart` and let the game mode spawn and possess the
        // generated character, so the pawn class stays user-editable source.
        return 'LuminaPawn($key, $transform),';
      case 'Landscape':
        // The terrain the Landscape sub-editor authored: the `.lmas` carries
        // the heightmap and the foliage layers, and the runtime component
        // rebuilds both from it — the same drawing code the editor preview
        // and the level viewport use.
        final landscapePath = a['landscapeAssetPath'] ?? a['meshAssetPath'];
        if (landscapePath is String && landscapePath.isNotEmpty) {
          return 'LuminaActor($key, root: LuminaLandscapeComponent(assetPath: \'${_escape(_bundlePath(landscapePath))}\', '
              '$transform, scale: $scaleCode, isVisible: $visible)),';
        }
        return 'LuminaActor($key, root: LuminaSceneComponent($transform, scale: $scaleCode, isVisible: $visible)),';
      case 'Mesh':
      case 'StaticMesh':
      case 'SkeletalMesh':
        final meshPath = a['meshAssetPath'];
        if (meshPath is String && meshPath.isNotEmpty) {
          // The material assigned to the placed mesh, drawn on every section.
          final (material, materialNote) = _materialArgument(a, projectDir);
          // 06: imported UCX_ hulls and the Static Mesh
          // editor's authored shapes are the mesh's simple collision
          // (skeletal meshes collide through a physics asset instead).
          final collision = type == 'SkeletalMesh'
              ? MeshSimpleCollision.none
              : MeshCollisionService.simpleCollisionForMeshAsset(meshPath, projectDir: projectDir);
          if (!collision.isEmpty) {
            final note = collision.complexity == MeshSimpleCollision.complexityComplexAsSimple
                ? '// Collision Complexity is Use Complex As Simple: the runtime has no per-triangle\n'
                    '          // collision yet, so this mesh plays with its simple collision.\n          '
                : '';
            final hullList = collision.hulls.isEmpty
                ? ''
                : 'collisionHulls: const [\n${collision.hulls.map(_emitCollisionHull).join()}          ], ';
            final primitiveList = collision.primitives.isEmpty
                ? ''
                : 'collisionPrimitives: const [\n${collision.primitives.map(_emitCollisionPrimitive).join()}          ], ';
            return '$materialNote${note}LuminaStaticMeshActor($key, meshAssetPath: \'${_escape(_bundlePath(meshPath))}\', '
                '$transform, scale: $scaleCode, castShadows: $castShadows, visible: $visible, '
                '${material.isEmpty ? '' : '$material, '}$hullList$primitiveList),';
          }
          return '${materialNote}LuminaActor($key, root: LuminaStaticMeshComponent(meshAssetPath: \'${_escape(_bundlePath(meshPath))}\', '
              '$transform, scale: $scaleCode, castShadows: $castShadows, visible: $visible'
              '${material.isEmpty ? '' : ', $material'})),';
        }
        return 'LuminaActor($key, root: LuminaSceneComponent($transform, scale: $scaleCode, isVisible: $visible)),';
      case 'Light':
      case 'DirectionalLight':
      case 'PointLight':
      case 'SpotLight':
        final ctor = switch (type) {
          'PointLight' => 'LuminaPointLightComponent',
          'SpotLight' => 'LuminaSpotLightComponent',
          _ => 'LuminaDirectionalLightComponent',
        };
        // The light's own component (the editor's Details "Light" section,
        // the Environment mixer's sun), else the actor-level fields.
        final lightComp = _componentOfType(a, ctor) ?? _componentOfType(a, 'LuminaDirectionalLightComponent');
        final props = lightComp?['properties'] is Map ? Map<String, dynamic>.from(lightComp!['properties'] as Map) : const <String, dynamic>{};
        final intensity = _num(props['intensity'], _num(a['lightIntensity'], type == 'DirectionalLight' || type == 'Light' ? 100000.0 : 10000.0));
        // The mixer derives effectiveColorHex from kelvin unless the colour is
        // overridden; a colour typed in Details is colorHex.
        final colorHex = props['colorOverride'] == false && props['effectiveColorHex'] is String
            ? props['effectiveColorHex']
            : (props['colorHex'] ?? props['effectiveColorHex'] ?? a['lightColorHex']);
        // The hex is sRGB (the colour picker's); Filament lights take linear
        // RGB.
        final linear = luminaLightColorFromHex(colorHex is String ? colorHex : null);
        final color = [linear.x, linear.y, linear.z];
        final shadows = props['castShadows'] is bool ? props['castShadows'] as bool : castShadows;
        final extra = switch (type) {
          // Attenuation radius in cm; cone angles in degrees.
          'PointLight' => 'falloffRadius: ${_f(_num(props['attenuationRadius'], 1000.0))}, ',
          'SpotLight' => 'falloffRadius: ${_f(_num(props['attenuationRadius'], 1000.0))}, '
              'innerConeAngleDegrees: ${_f(_num(props['innerConeAngle'], 30.0).clamp(0.01, 90.0))}, '
              'outerConeAngleDegrees: ${_f(_num(props['outerConeAngle'], 45.0).clamp(_num(props['innerConeAngle'], 30.0).clamp(0.01, 90.0), 90.0))}, ',
          _ => 'sunAngularRadius: ${_f(_num(props['sunAngularRadius'], 0.545))}, ',
        };
        return 'LuminaActor($key, root: $ctor($transform, color: ${_vector3(color)}, '
            'intensity: ${_f(intensity)}, ${extra}castShadows: $shadows, visible: $visible)),';
      case 'ExponentialHeightFog':
        // Exponential Height Fog over Filament's per-view fog:
        // every field maps, the actor's Z is the height.
        final fogComp = _componentOfType(a, 'LuminaExponentialHeightFogComponent');
        final fog = LuminaHeightFogSettings.fromProperties(
            fogComp?['properties'] is Map ? Map<String, dynamic>.from(fogComp!['properties'] as Map) : null);
        return 'LuminaActor($key, root: LuminaExponentialHeightFogComponent('
            '$transform, '
            'enabled: ${fog.enabled}, '
            'fogDensity: ${_f(fog.fogDensity)}, '
            'fogHeightFalloff: ${_f(fog.fogHeightFalloff)}, '
            'startDistance: ${_f(fog.startDistance)}, '
            'fogCutoffDistance: ${_f(fog.fogCutoffDistance)}, '
            'fogMaxOpacity: ${_f(fog.fogMaxOpacity)}, '
            'inscatteringColor: ${_vector3([fog.inscatteringColor.x, fog.inscatteringColor.y, fog.inscatteringColor.z])}, '
            'useSkyColor: ${fog.useSkyColor}, '
            'visible: $visible)),';
      case 'PostProcessVolume':
        // A Post Process Volume: the properties map goes
        // through verbatim so the runtime and the editor share one parser.
        final ppv = _componentOfType(a, 'LuminaPostProcessVolumeComponent');
        return 'LuminaActor($key, root: LuminaPostProcessVolumeComponent.fromProperties('
            '${_emitPropertyMap(ppv?['properties'])}, $transform, scale: $scaleCode, visible: $visible)),';
      case 'LocalFogVolume':
        // A Local Fog Volume: a fog-shell approximation —
        // Filament has no volumetric scattering.
        final lfv = _componentOfType(a, 'LuminaLocalFogVolumeComponent');
        return 'LuminaActor($key, root: LuminaLocalFogVolumeComponent.fromProperties('
            '${_emitPropertyMap(lfv?['properties'])}, $transform, scale: $scaleCode, visible: $visible)),';
      case 'ProceduralSky':
        // The Procedural Sky & Ocean: atmospheric scattering, FBM clouds, a
        // day/night cycle and an ocean reflection, all in one shader. It is a
        // renderable, not a Filament Skybox, so a level can carry both it and
        // an `Environment` actor (which supplies the image-based lighting a
        // procedural sky cannot).
        final procSky = _componentOfType(a, 'LuminaProceduralSkyComponent');
        final p = procSky?['properties'] is Map
            ? Map<String, dynamic>.from(procSky!['properties'] as Map)
            : const <String, dynamic>{};
        return 'LuminaActor($key, root: LuminaProceduralSkyComponent('
            'timeOfDay: ${_f(_num(p['timeOfDay'], 12.0))}, '
            'turbidity: ${_f(_num(p['turbidity'], 2.0))}, '
            'rayleigh: ${_f(_num(p['rayleigh'], 1.0))}, '
            'mieCoefficient: ${_f(_num(p['mieCoefficient'], 1.0))}, '
            'mieG: ${_f(_num(p['mieG'], 0.8))}, '
            'cloudCoverage: ${_f(_num(p['cloudCoverage'], 0.4))}, '
            'cloudDensity: ${_f(_num(p['cloudDensity'], 0.15))}, '
            'waterStrength: ${_f(_num(p['waterStrength'], 30.0))}, '
            'waterSpeed: ${_f(_num(p['waterSpeed'], 1.0))}, '
            'dayCycleSpeed: ${_f(_num(p['dayCycleSpeed'], 0.0))}, '
            'visible: $visible)),';
      case 'Environment':
      case 'SkyAtmosphere':
      case 'SkyLight':
      case 'Sky':
        final sky = _componentOfType(a, 'LuminaSkyComponent') ?? environment?['sky'];
        final props = sky is Map
            ? (sky['properties'] is Map
                ? Map<String, dynamic>.from(sky['properties'] as Map)
                : Map<String, dynamic>.from(sky))
            : const <String, dynamic>{};
        final skyIntensity = _num(props['skyIntensity'], 30000.0);
        final iblIntensity = _num(props['iblIntensity'], 30000.0);
        final env = props['sky_environment'];
        final envPath = env is Map ? env['asset_path'] : props['environmentAssetPath'];
        if ((props['mode'] == 'environment' || envPath is String) && envPath is String && envPath.isNotEmpty) {
          final showSun = props['showSun'] is bool ? props['showSun'] as bool : false;
          return 'LuminaActor($key, root: LuminaSkyComponent.environment(environmentAssetPath: \'${_escape(_bundlePath(envPath))}\', '
              '$transform, showSun: $showSun, skyIntensity: ${_f(skyIntensity)}, iblIntensity: ${_f(iblIntensity)})),';
        }
        final c = _hexRgb(props['colorHex'], [0.3608, 0.4980, 0.7216]);
        return 'LuminaActor($key, root: LuminaSkyComponent.color(color: Vector4(${_f(c[0])}, ${_f(c[1])}, ${_f(c[2])}, 1.0), '
            '$transform, skyIntensity: ${_f(skyIntensity)}, iblIntensity: ${_f(iblIntensity)})),';
      default:
        return 'LuminaActor($key, root: LuminaSceneComponent($transform, scale: $scaleCode, isVisible: $visible)),';
    }
  }
}
