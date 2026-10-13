import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lumina_core/lumina_core.dart';

import 'package:lumina_editor_data/src/packaging/android/android_packaging.dart';
import 'package:lumina_editor_data/src/repositories/asset_repository.dart';
import 'package:lumina_editor_data/src/repositories/project_repository.dart';
import 'package:lumina_editor_data/src/samples/metaxr_posing/metaxr_posing_content.dart';
import 'package:lumina_editor_data/src/samples/metaxr_posing/metaxr_posing_level.dart';
import 'package:lumina_editor_data/src/samples/metaxr_posing/metaxr_posing_widgets.dart';
import 'package:lumina_editor_data/src/services/code_generator_service.dart';

/// What [MetaXrPosingBuilder.build] did, with its timings.
class MetaXrPosingReport {
  final String projectDir;
  final String meshAssetPath;
  final int characterGlbBytes;
  final Duration importTime;
  final Duration contentTime;
  final Duration codeTime;
  final Duration elapsed;
  final List<String> runtimeModules;

  const MetaXrPosingReport({
    required this.projectDir,
    required this.meshAssetPath,
    required this.characterGlbBytes,
    required this.importTime,
    required this.contentTime,
    required this.codeTime,
    required this.elapsed,
    this.runtimeModules = const [],
  });

  Map<String, Object> toJson() => {
        'projectDir': projectDir,
        'meshAssetPath': meshAssetPath,
        'characterGlbBytes': characterGlbBytes,
        'importSeconds': importTime.inMilliseconds / 1000.0,
        'contentSeconds': contentTime.inMilliseconds / 1000.0,
        'codeSeconds': codeTime.inMilliseconds / 1000.0,
        'elapsedSeconds': elapsed.inMilliseconds / 1000.0,
        'runtimeModules': runtimeModules,
      };
}

/// Builds the MetaXR posing example into a Lumina project: the OpenXR and
/// MetaXR plugins enabled, the Android (Meta Quest) target, the character
/// GLB imported as a skeletal mesh, `BP_PosedCharacter`, `BP_XRPlayer`,
/// `BP_RoomPassthrough`, `BP_PosingGameMode`, `W_WristHud`, `L_Room`, the
/// input and Maps & Modes, and the generated game code.
///
/// The character is whatever GLB the caller gives (a mobile MetaHuman
/// export on this machine; the test-assets mannequin in the tests): nothing
/// of it is part of Lumina.
class MetaXrPosingBuilder {
  final String projectDir;

  /// The character's GLB (a skinned mesh with a humanoid skeleton).
  final String characterGlb;

  /// The enabled plugins' descriptors, when known (their runtime modules
  /// become game dependencies and the Android manifest is composed).
  final List<LuminaPluginDescriptor> plugins;
  final void Function(String message)? log;

  MetaXrPosingBuilder({required this.projectDir, required this.characterGlb, this.plugins = const [], this.log});

  static const String applicationId = 'com.lumina.metaxr_posing';
  static const List<String> pluginNames = ['lumina_plugin_metaxr', 'lumina_plugin_openxr'];

  void _log(String m) => log?.call(m);

  /// Creates `<projectsDir>/<name>` through Lumina's project pipeline (the
  /// blank template) unless it exists; returns its folder.
  static Future<String> createProject(String projectsDir, String name, {void Function(ProjectCreationProgress)? onProgress}) async {
    final dir = Directory('$projectsDir/$name');
    if (await File('${dir.path}/$name.lmproject').exists()) return dir.path;
    await ProjectRepository().createProject(
      projectName: name,
      projectLocation: projectsDir,
      template: kBlank3dTemplateId,
      onProgress: onProgress,
    );
    return dir.path;
  }

  /// The project's Android settings: the Meta Quest profile at 72 Hz with
  /// multiview.
  static const ProjectAndroidSettings androidSettings =
      ProjectAndroidSettings.quest(applicationId: applicationId, refreshRate: 72, multiview: true);

  Future<MetaXrPosingReport> build() async {
    final total = Stopwatch()..start();
    // 1. The character.
    final importWatch = Stopwatch()..start();
    final meshAssetPath = await _importCharacter();
    importWatch.stop();
    final glb = File('$projectDir/${meshAssetPath.replaceAll(RegExp(r'\.lmas$'), '.entity.glb')}');
    final glbBytes = await glb.exists() ? await glb.length() : await File(characterGlb).length();
    _log('Character: $meshAssetPath (${(glbBytes / (1024 * 1024)).toStringAsFixed(1)} MB) in ${importWatch.elapsedMilliseconds} ms');

    // 2. Blueprints, widget, level.
    final contentWatch = Stopwatch()..start();
    await _writeDocument(MetaXrPosingContent.characterPath, AssetType.actor,
        MetaXrPosingContent.characterBlueprint(meshAssetPath: meshAssetPath).toJson(), meshAssetPath);
    await _writeDocument(MetaXrPosingContent.playerPath, AssetType.actor, MetaXrPosingContent.playerBlueprint().toJson(), null);
    await _writeDocument(
        MetaXrPosingContent.passthroughPath, AssetType.actor, MetaXrPosingContent.passthroughBlueprint().toJson(), null);
    await _writeDocument(
        MetaXrPosingContent.gameModePath, AssetType.actor, MetaXrPosingContent.gameModeBlueprint.toJson(), null);
    await _writeWidget();
    final level = File('$projectDir/${MetaXrPosingLevel.levelPath}');
    await level.parent.create(recursive: true);
    await level.writeAsString(jsonEncode(MetaXrPosingLevel.levelContainer()));
    contentWatch.stop();

    // 3. The project, the Android app, the game code.
    final codeWatch = Stopwatch()..start();
    final project = await _writeProject();
    final modules = <String>[];
    if (plugins.isNotEmpty && await File(AndroidPackaging.manifestPath(projectDir)).exists()) {
      final prep = await AndroidPackaging.prepare(projectDir, project, plugins);
      modules.addAll(prep.runtimeModules.map((d) => d.package));
      _log('Android app ${prep.applicationId}: ${prep.manifest.summary.join(', ')}; runtime modules ${modules.join(', ')}');
    }
    await _compileAndGenerate(project);
    codeWatch.stop();
    final report = MetaXrPosingReport(
      projectDir: projectDir,
      meshAssetPath: meshAssetPath,
      characterGlbBytes: glbBytes,
      importTime: importWatch.elapsed,
      contentTime: contentWatch.elapsed,
      codeTime: codeWatch.elapsed,
      elapsed: total.elapsed,
      runtimeModules: modules,
    );
    final out = File('$projectDir/Saved/MetaXrPosing/report.json');
    await out.parent.create(recursive: true);
    await out.writeAsString(const JsonEncoder.withIndent('  ').convert(report.toJson()));
    return report;
  }

  /// Imports [characterGlb] once (an existing import of the same name is
  /// kept); returns its project path.
  Future<String> _importCharacter() async {
    final name = characterGlb.replaceAll(r'\', '/').split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
    final existing = 'contents/meshes/skeletal/$name.lmas';
    if (await File('$projectDir/$existing').exists()) return existing;
    final info = await AssetRepository().importExternalFile(projectPath: projectDir, sourceFilePath: characterGlb, targetSkeletonPath: '');
    return info.relativePath;
  }

  Future<void> _writeDocument(String rel, AssetType type, Map<String, dynamic> json, String? targetMesh) async {
    final file = File('$projectDir/$rel');
    await file.parent.create(recursive: true);
    String? id;
    if (await file.exists()) {
      try {
        id = LuminaAsset.fromBytes(await file.readAsBytes()).assetId;
      } catch (_) {}
    }
    final text = const JsonEncoder.withIndent('  ').convert(json);
    await file.writeAsBytes(LuminaAsset(
      assetId: id ?? _uuid(),
      name: rel.split('/').last.replaceAll('.lmas', ''),
      type: type,
      rawPayload: Uint8List.fromList(utf8.encode(text)),
      rawMatSource: text,
      references: targetMesh == null ? const [] : [AssetReference(slotName: 'skeletal_mesh', assetId: '', assetPath: targetMesh)],
      metadata: {
        'payload_format': 'json',
        'target_mesh': ?targetMesh,
        'source': 'metaxr_posing',
        'last_modified': DateTime.now().toIso8601String(),
      },
    ).toProtoBufferBytes());
  }

  Future<void> _writeWidget() async {
    final file = File('$projectDir/${MetaXrPosingWidgets.hudPath}');
    await file.parent.create(recursive: true);
    final text = const JsonEncoder.withIndent('  ').convert(MetaXrPosingWidgets.hudAsset());
    await file.writeAsBytes(LuminaAsset(
      assetId: _uuid(),
      name: MetaXrPosingWidgets.hudName,
      type: AssetType.widget,
      rawPayload: Uint8List.fromList(utf8.encode(text)),
      rawMatSource: text,
      metadata: const {'payload_format': 'json', 'source': 'metaxr_posing'},
    ).toProtoBufferBytes());
  }

  Future<LuminaProject> _writeProject() async {
    final manifest = await Directory(projectDir).list().firstWhere((e) => e is File && e.path.endsWith('.lmproject')) as File;
    final project = LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(await manifest.readAsString()) as Map));
    final now = DateTime.now().toIso8601String();
    final updated = project.copyWith(
      activeLevel: MetaXrPosingLevel.levelPath,
      enabledPlugins: {...?project.enabledPlugins, ...pluginNames}.toList()..sort(),
      input: MetaXrPosingContent.input,
      mapsAndModes: const ProjectMapsAndModes(
        editorStartupMap: MetaXrPosingLevel.levelPath,
        gameDefaultMap: MetaXrPosingLevel.levelPath,
        defaultGameMode: MetaXrPosingContent.gameModePath,
        defaultPawnClass: MetaXrPosingContent.playerPath,
      ),
      packaging: project.packaging.copyWith(targets: const ['android'], android: androidSettings),
      description: 'MetaXR posing: a MetaHuman in your room through passthrough, posed by grabbing it with the controllers',
      lastModifiedTimestamp: now,
      lastCodeGeneratedTimestamp: now,
    );
    await manifest.writeAsString(jsonEncode(updated.toMap()));
    return updated;
  }

  Future<void> _compileAndGenerate(LuminaProject project) async {
    MetaXrPosingContent.declarePluginNodes();
    final codegen = DartCodeGeneratorService();
    final actions = MetaXrPosingContent.inputActions;
    for (final (name, path) in const [
      (MetaXrPosingContent.characterName, MetaXrPosingContent.characterPath),
      (MetaXrPosingContent.passthroughName, MetaXrPosingContent.passthroughPath),
      (MetaXrPosingContent.gameModeName, MetaXrPosingContent.gameModePath),
    ]) {
      final doc = jsonDecode(utf8.decode(LuminaAsset.fromBytes(await File('$projectDir/$path').readAsBytes()).rawPayload!));
      final ok = await codegen.compileAndWriteActor(projectDir, name, Map<String, dynamic>.from(doc as Map),
          assetPath: path, inputActions: actions);
      if (!ok) throw StateError('$name did not compile ($path)');
    }
    _log('Compiled ${MetaXrPosingContent.characterName}, ${MetaXrPosingContent.playerName}, '
        '${MetaXrPosingContent.passthroughName}, ${MetaXrPosingContent.gameModeName}');

    ProjectRepository.ensurePubspecAssets(projectDir);
    final levels = Directory('$projectDir/lib/levels');
    await levels.create(recursive: true);
    await File('${levels.path}/${dartFileName(MetaXrPosingLevel.levelName)}').writeAsString(await codegen.generateLevelDartAsync(
      levelName: MetaXrPosingLevel.levelName,
      actors: const [],
      actorMaps: MetaXrPosingLevel.actors(),
      projectDir: projectDir,
    ));
    codegen.writeProjectInputDart(projectDir, MetaXrPosingContent.input);
    final registry = codegen.writeProjectBlueprintRegistry(projectDir);
    await File('$projectDir/lib/main.dart').writeAsString(codegen.generateMainDart(
      projectName: project.projectName,
      levelName: MetaXrPosingLevel.levelName,
      widgetLibrary: project.ui.widgetLibrary,
      gravityZ: project.physics.gravityZ,
      mapsAndModes: project.mapsAndModes,
      hasBlueprints: true,
      projectInput: true,
      blueprintRegistry: registry,
      levelNames: DartCodeGeneratorService.generatedLevelNames(projectDir),
      pluginRuntimeModules: File('$projectDir/lib/plugin_runtime_modules.g.dart').existsSync(),
    ));
  }

  static String _uuid() {
    final random = math.Random.secure();
    final b = List<int>.generate(16, (_) => random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
