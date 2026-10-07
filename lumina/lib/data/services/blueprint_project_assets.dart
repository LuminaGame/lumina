import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:lumina/src/blueprint/blueprint.dart';
import 'package:lumina/src/components/particles/particle_emitter_config.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina/data/services/asset_index.dart';

/// A Blueprint class asset of a project: its project-relative `.lmas` path,
/// its class name (the file name, what `Actor:<name>` pins and `Spawn Actor
/// from Class` use) and its parent class.
class LuminaProjectBlueprintClass {
  final String path;
  final String name;
  final String parentClass;
  const LuminaProjectBlueprintClass({required this.path, required this.name, required this.parentClass});

  bool get isGameMode => parentClass == 'LuminaGameMode';
}

/// Every asset the Blueprint runtime resolves through a registry, read from
/// a project's `contents/`: enum, interface, save-game and
/// montage `.lmas` payloads (by their `kind`), particle systems (the first
/// enabled emitter of `metadata['particle_system']`) and the actor Blueprint
/// classes. The code generator writes `lib/blueprint_registry.g.dart` from it;
/// Play-In-Editor registers it straight into lumina's registries.
class LuminaProjectBlueprintAssets {
  final List<({String path, LuminaBlueprintEnumDocument document})> enums;
  final List<({String path, LuminaBlueprintInterfaceDocument document})> interfaces;
  final List<({String path, LuminaBlueprintSaveGameDocument document})> saveGameClasses;
  final List<({String path, LuminaBlueprintMontageDocument document})> montages;

  /// Particle system path → its emitter config as the particle editor stores
  /// it ([LuminaParticleEmitterConfig.toJson] shape).
  final List<({String path, Map<String, dynamic> config})> particleTemplates;
  final List<LuminaProjectBlueprintClass> classes;

  const LuminaProjectBlueprintAssets({
    this.enums = const [],
    this.interfaces = const [],
    this.saveGameClasses = const [],
    this.montages = const [],
    this.particleTemplates = const [],
    this.classes = const [],
  });

  /// The `LuminaAsset.metadata` key a particle system is stored under (the
  /// particle editor's `ParticleSystemDocument.metadataKey`).
  static const String particleSystemMetadataKey = 'particle_system';

  /// The actor classes `Spawn Actor from Class` may make: no GameMode
  /// Blueprints.
  List<LuminaProjectBlueprintClass> get actorClasses => [for (final c in classes) if (!c.isGameMode) c];

  /// Whether nothing needs registering beyond what the actor factories give.
  bool get hasRegistryAssets =>
      enums.isNotEmpty || interfaces.isNotEmpty || saveGameClasses.isNotEmpty || montages.isNotEmpty || particleTemplates.isNotEmpty;

  /// Every registry asset of `<projectDir>/contents`, found through the
  /// project's asset index: only the Blueprint documents
  /// that are enums, interfaces, save games or montages are read in full;
  /// classes and particle systems come from their summaries. Unreadable
  /// files are skipped; every list is sorted by path so generated code is
  /// stable.
  static LuminaProjectBlueprintAssets scan(String projectDir) {
    final contents = Directory('$projectDir/contents');
    if (!contents.existsSync()) return const LuminaProjectBlueprintAssets();
    final index = LuminaAssetIndex.open(projectDir)..refreshSync();
    return fromIndex(index);
  }

  /// [scan] in a background isolate (its own index instance reads the
  /// persisted index file), for callers that must not block the UI.
  static Future<LuminaProjectBlueprintAssets> scanAsync(String projectDir) async {
    final root = projectDir;
    final json = await Isolate.run(() => scan(root).toJson());
    return LuminaProjectBlueprintAssets.fromJson(json);
  }

  /// The registry assets of an up-to-date [index].
  static LuminaProjectBlueprintAssets fromIndex(LuminaAssetIndex index) {
    final enums = <({String path, LuminaBlueprintEnumDocument document})>[];
    final interfaces = <({String path, LuminaBlueprintInterfaceDocument document})>[];
    final saves = <({String path, LuminaBlueprintSaveGameDocument document})>[];
    final montages = <({String path, LuminaBlueprintMontageDocument document})>[];
    final particles = <({String path, Map<String, dynamic> config})>[];
    final classes = <LuminaProjectBlueprintClass>[];
    for (final e in index.entries) {
      final rel = e.path;
      final base = e.baseName;
      final summary = e.summary;
      if (summary.type == AssetType.particle) {
        final config = _firstEmitter(e.metadataValue(particleSystemMetadataKey));
        if (config != null) particles.add((path: rel, config: config));
        continue;
      }
      if (summary.type != AssetType.actor) continue;
      var kind = summary.blueprintKind;
      Map<String, dynamic>? json;
      if (kind == null) {
        // A payload too large to inspect while indexing: read it now.
        if ((summary.payloadRange?.length ?? 0) <= LuminaAssetSummary.maxInspectedPayload) continue;
        json = _readPayload(e.file);
        if (json == null) continue;
        kind = luminaBlueprintDocumentKind(json);
      }
      if (kind == 'class') {
        if (json != null) {
          if (json['eventGraph'] == null && json['parentClass'] == null) continue;
          classes.add(LuminaProjectBlueprintClass(path: rel, name: base, parentClass: json['parentClass'] as String? ?? 'LuminaActor'));
        } else {
          if (!summary.hasEventGraph && summary.documentParentClass == null) continue;
          classes.add(LuminaProjectBlueprintClass(path: rel, name: base, parentClass: summary.documentParentClass ?? 'LuminaActor'));
        }
        continue;
      }
      if (kind != LuminaBlueprintEnumDocument.kind &&
          kind != LuminaBlueprintInterfaceDocument.kind &&
          kind != LuminaBlueprintSaveGameDocument.kind &&
          kind != LuminaBlueprintMontageDocument.kind) {
        continue;
      }
      json ??= _readPayload(e.file);
      if (json == null) continue;
      switch (kind) {
        case LuminaBlueprintEnumDocument.kind:
          final doc = LuminaBlueprintEnumDocument.fromJson(json);
          enums.add((path: rel, document: doc.name.isEmpty ? LuminaBlueprintEnumDocument(name: base, values: doc.values) : doc));
        case LuminaBlueprintInterfaceDocument.kind:
          final doc = LuminaBlueprintInterfaceDocument.fromJson(json);
          interfaces.add((
            path: rel,
            document: doc.name.isEmpty ? LuminaBlueprintInterfaceDocument(name: base, functions: doc.functions) : doc,
          ));
        case LuminaBlueprintSaveGameDocument.kind:
          final doc = LuminaBlueprintSaveGameDocument.fromJson(json);
          saves.add((path: rel, document: doc.name.isEmpty ? LuminaBlueprintSaveGameDocument(name: base, fields: doc.fields) : doc));
        case LuminaBlueprintMontageDocument.kind:
          final doc = LuminaBlueprintMontageDocument.fromJson(json);
          montages.add((path: rel, document: doc.name.isEmpty ? LuminaBlueprintMontageDocument.fromJson({...json, 'name': base}) : doc));
      }
    }
    return LuminaProjectBlueprintAssets(
      enums: enums,
      interfaces: interfaces,
      saveGameClasses: saves,
      montages: montages,
      particleTemplates: particles,
      classes: classes,
    );
  }

  Map<String, dynamic> toJson() => {
        'enums': [for (final e in enums) {'path': e.path, 'document': e.document.toJson()}],
        'interfaces': [for (final e in interfaces) {'path': e.path, 'document': e.document.toJson()}],
        'save_games': [for (final e in saveGameClasses) {'path': e.path, 'document': e.document.toJson()}],
        'montages': [for (final e in montages) {'path': e.path, 'document': e.document.toJson()}],
        'particles': [for (final p in particleTemplates) {'path': p.path, 'config': p.config}],
        'classes': [for (final c in classes) {'path': c.path, 'name': c.name, 'parent': c.parentClass}],
      };

  factory LuminaProjectBlueprintAssets.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) =>
        [for (final e in (json[key] as List? ?? const [])) Map<String, dynamic>.from(e as Map)];
    Map<String, dynamic> doc(Map<String, dynamic> e) => Map<String, dynamic>.from(e['document'] as Map);
    return LuminaProjectBlueprintAssets(
      enums: [for (final e in list('enums')) (path: e['path'] as String, document: LuminaBlueprintEnumDocument.fromJson(doc(e)))],
      interfaces: [
        for (final e in list('interfaces')) (path: e['path'] as String, document: LuminaBlueprintInterfaceDocument.fromJson(doc(e))),
      ],
      saveGameClasses: [
        for (final e in list('save_games')) (path: e['path'] as String, document: LuminaBlueprintSaveGameDocument.fromJson(doc(e))),
      ],
      montages: [for (final e in list('montages')) (path: e['path'] as String, document: LuminaBlueprintMontageDocument.fromJson(doc(e)))],
      particleTemplates: [
        for (final p in list('particles')) (path: p['path'] as String, config: Map<String, dynamic>.from(p['config'] as Map)),
      ],
      classes: [
        for (final c in list('classes'))
          LuminaProjectBlueprintClass(path: c['path'] as String, name: c['name'] as String, parentClass: c['parent'] as String),
      ],
    );
  }

  static Map<String, dynamic>? _readPayload(File file) {
    try {
      return _payload(LuminaAsset.fromBytes(file.readAsBytesSync()));
    } catch (_) {
      return null;
    }
  }

  /// Registers the enums, interfaces, save-game classes, montages (by name
  /// and path) and particle templates into lumina's registries — what the
  /// generated `registerProjectBlueprints()` does, for Play-In-Editor. Actor
  /// classes are the caller's: PIE compiles them through its class registry.
  void registerRuntime() {
    LuminaBlueprintEnums.registerAll([for (final e in enums) e.document]);
    LuminaBlueprintInterfaces.registerAll([for (final i in interfaces) i.document]);
    LuminaBlueprintSaveGameClasses.registerAll([for (final s in saveGameClasses) s.document]);
    for (final m in montages) {
      LuminaBlueprintMontages.register(m.document, path: m.path);
    }
    for (final p in particleTemplates) {
      LuminaBlueprintParticleTemplates.register(p.path, LuminaParticleEmitterConfig.fromJson(p.config));
    }
  }

  static Map<String, dynamic>? _payload(LuminaAsset asset) {
    final payload = asset.rawPayload;
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(payload));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  /// The first enabled emitter's config of a stored particle system
  /// (`{"v": 1, "emitters": [{"name", "enabled", "config"}]}`), or null.
  static Map<String, dynamic>? _firstEmitter(String? stored) {
    if (stored == null || stored.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map) return null;
      final emitters = decoded['emitters'];
      if (emitters is! List) return null;
      for (final e in emitters.whereType<Map>()) {
        if (e['enabled'] == false) continue;
        final config = e['config'];
        return config is Map ? Map<String, dynamic>.from(config) : <String, dynamic>{};
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
