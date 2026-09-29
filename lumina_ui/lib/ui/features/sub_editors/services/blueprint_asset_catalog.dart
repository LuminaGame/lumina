import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina/lumina.dart';

/// The Blueprint-side assets of a project that are not actor Blueprints:
/// enum (`contents/enums/E_*.lmas`) and interface
/// (`contents/interfaces/BPI_*.lmas`) assets — `.lmas` files of
/// [AssetType.actor] whose payload carries lumina's `kind` discriminator —
/// plus the asset paths the literal editors pick from (sounds, montages,
/// materials, particles, levels, save classes). Read from disk, refreshed
/// on [AssetRepository.onAssetsChanged], and registered into lumina's
/// [LuminaBlueprintEnums] / [LuminaBlueprintInterfaces] so the validator,
/// the generator and Play resolve them.
class BlueprintAssetCatalog extends ChangeNotifier {
  final String projectDir;
  List<BlueprintEnumAsset> _enums = const [];
  List<BlueprintInterfaceAsset> _interfaces = const [];
  Map<BlueprintAssetKind, List<String>> _assetPaths = const {};
  StreamSubscription<void>? _subscription;

  BlueprintAssetCatalog(this.projectDir, {bool watch = true}) {
    refresh();
    if (watch) _subscription = AssetRepository.onAssetsChanged.listen((_) => refresh());
  }

  static const String enumsFolder = 'contents/enums';
  static const String interfacesFolder = 'contents/interfaces';

  List<BlueprintEnumAsset> get enumAssets => _enums;
  List<BlueprintInterfaceAsset> get interfaceAssets => _interfaces;
  List<LuminaBlueprintEnumDocument> get enums => [for (final e in _enums) e.document];
  List<LuminaBlueprintInterfaceDocument> get interfaces => [for (final i in _interfaces) i.document];

  LuminaBlueprintEnumDocument? enumeration(String? name) => _enums.where((e) => e.document.name == name).firstOrNull?.document;
  LuminaBlueprintInterfaceDocument? interface(String? name) =>
      _interfaces.where((i) => i.document.name == name).firstOrNull?.document;

  /// Project-relative `.lmas` paths of [kind], for an asset pin's picker.
  List<String> assetPaths(BlueprintAssetKind kind) => _assetPaths[kind] ?? const [];

  /// Re-reads the project; listeners are told when anything changed.
  void refresh() {
    final enums = scanEnums(projectDir);
    final interfaces = scanInterfaces(projectDir);
    final paths = scanAssetPaths(projectDir);
    final changed = jsonEncode(enums.map((e) => e.document.toJson()).toList()) != jsonEncode(_enums.map((e) => e.document.toJson()).toList()) ||
        jsonEncode(interfaces.map((i) => i.document.toJson()).toList()) !=
            jsonEncode(_interfaces.map((i) => i.document.toJson()).toList()) ||
        jsonEncode({for (final e in paths.entries) e.key.name: e.value}) !=
            jsonEncode({for (final e in _assetPaths.entries) e.key.name: e.value});
    _enums = List.unmodifiable(enums);
    _interfaces = List.unmodifiable(interfaces);
    _assetPaths = Map.unmodifiable(paths);
    registerRuntimeAssets();
    if (changed) notifyListeners();
  }

  /// Makes the project's enums and interfaces known to lumina's registries
  /// (the type context, the validator and Play read them there).
  void registerRuntimeAssets() {
    LuminaBlueprintEnums.registerAll(enums);
    LuminaBlueprintInterfaces.registerAll(interfaces);
    // The validator checks Load Level / Change Level
    // names against the project's levels.
    LuminaProjectLevels.clear();
    LuminaProjectLevels.register(assetPaths(BlueprintAssetKind.level));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Disk
  // ---------------------------------------------------------------------------

  /// Reads the `kind` of the Blueprint document in the `.lmas` at [path]:
  /// `class`, `enum`, `interface`, … or null when the file is not a
  /// Blueprint asset.
  static String? documentKindOf(String? path) {
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      // The summary knows an actor Blueprint document's kind without the
      // payload; other assets are read as before.
      final summary = LuminaAsset.readSummary(file);
      if (summary.type == AssetType.actor && summary.blueprintKind != null) return summary.blueprintKind;
      if (summary.payloadRange == null) return null;
      final asset = LuminaAsset.fromBytes(file.readAsBytesSync());
      final payload = asset.rawPayload;
      if (payload == null || payload.isEmpty) return null;
      final json = jsonDecode(utf8.decode(payload));
      if (json is! Map) return null;
      return luminaBlueprintDocumentKind(Map<String, dynamic>.from(json));
    } catch (_) {
      return null;
    }
  }

  static bool isEnumLmas(String? path) => documentKindOf(path) == LuminaBlueprintEnumDocument.kind;
  static bool isInterfaceLmas(String? path) => documentKindOf(path) == LuminaBlueprintInterfaceDocument.kind;

  static Map<String, dynamic>? _payloadOf(File file) {
    try {
      final asset = LuminaAsset.fromBytes(file.readAsBytesSync());
      final payload = asset.rawPayload;
      if (payload == null || payload.isEmpty) return null;
      final json = jsonDecode(utf8.decode(payload));
      return json is Map ? Map<String, dynamic>.from(json) : null;
    } catch (_) {
      return null;
    }
  }

  /// The project's `.lmas` files from its asset index:
  /// stat'ed, never decoded here.
  static List<AssetIndexEntry> _indexed(String projectDir) {
    if (!Directory('$projectDir/contents').existsSync()) return const [];
    return (LuminaAssetIndex.open(projectDir)..refreshSync()).entries;
  }

  /// The Blueprint documents of [kind] (actor assets, found by the index),
  /// each with its payload read.
  static Iterable<({String path, String baseName, Map<String, dynamic> json})> _documents(String projectDir, String kind) sync* {
    for (final e in _indexed(projectDir)) {
      if (e.type != AssetType.actor || e.summary.blueprintKind != kind) continue;
      final json = _payloadOf(e.file);
      if (json == null) continue;
      yield (path: '$projectDir/${e.path}', baseName: e.baseName, json: json);
    }
  }

  /// Every enum asset under `contents/` of [projectDir], by name.
  static List<BlueprintEnumAsset> scanEnums(String projectDir) {
    final out = <BlueprintEnumAsset>[];
    for (final d in _documents(projectDir, LuminaBlueprintEnumDocument.kind)) {
      final doc = LuminaBlueprintEnumDocument.fromJson(d.json);
      final name = doc.name.isEmpty ? d.baseName : doc.name;
      out.add(BlueprintEnumAsset(path: d.path, document: LuminaBlueprintEnumDocument(name: name, values: doc.values)));
    }
    out.sort((a, b) => a.document.name.compareTo(b.document.name));
    return out;
  }

  /// Every interface asset under `contents/` of [projectDir], by name.
  static List<BlueprintInterfaceAsset> scanInterfaces(String projectDir) {
    final out = <BlueprintInterfaceAsset>[];
    for (final d in _documents(projectDir, LuminaBlueprintInterfaceDocument.kind)) {
      final doc = LuminaBlueprintInterfaceDocument.fromJson(d.json);
      final name = doc.name.isEmpty ? d.baseName : doc.name;
      out.add(BlueprintInterfaceAsset(path: d.path, document: LuminaBlueprintInterfaceDocument(name: name, functions: doc.functions)));
    }
    out.sort((a, b) => a.document.name.compareTo(b.document.name));
    return out;
  }

  /// The project-relative paths of every asset a literal editor may pick,
  /// by kind: from the asset's indexed type, Blueprint document kind and
  /// the folder it lives in.
  static Map<BlueprintAssetKind, List<String>> scanAssetPaths(String projectDir) {
    final out = <BlueprintAssetKind, List<String>>{for (final k in BlueprintAssetKind.values) k: <String>[]};
    for (final e in _indexed(projectDir)) {
      final rel = e.path;
      final lower = rel.toLowerCase();
      final type = e.type;
      final kind = e.summary.blueprintKind ?? 'class';
      if (type == AssetType.audio || lower.contains('/audio/') || lower.contains('/sounds/')) out[BlueprintAssetKind.sound]!.add(rel);
      if (kind == 'montage' || lower.contains('/montages/')) out[BlueprintAssetKind.montage]!.add(rel);
      if (type == AssetType.filamat || lower.contains('/materials/')) out[BlueprintAssetKind.material]!.add(rel);
      if (type == AssetType.particle || lower.contains('/particles/')) out[BlueprintAssetKind.particle]!.add(rel);
      if (type == AssetType.level || lower.contains('/levels/')) out[BlueprintAssetKind.level]!.add(rel);
      if (kind == 'savegame' || lower.contains('/savegames/')) out[BlueprintAssetKind.saveGame]!.add(rel);
    }
    for (final list in out.values) {
      list.sort();
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Asset files (the content browser's New Asset entries)
  // ---------------------------------------------------------------------------

  static LuminaAsset _asset(String name, String payloadJson, String kind) => LuminaAsset(
        assetId: '${kind}_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        type: AssetType.actor,
        rawPayload: Uint8List.fromList(utf8.encode(payloadJson)),
        rawMatSource: payloadJson,
        metadata: {'blueprint_kind': kind, 'last_modified': DateTime.now().toIso8601String()},
      );

  /// A name no `.lmas` in [folder] uses yet: [name], else `<name>_<n>`.
  static String uniqueName(String projectDir, String folder, String name) {
    var candidate = name;
    for (var n = 2; File('$projectDir/$folder/$candidate.lmas').existsSync(); n++) {
      candidate = '${name}_$n';
    }
    return candidate;
  }

  /// Writes the enum asset `contents/enums/<name>.lmas` and returns its
  /// project-relative path.
  static String writeEnum(String projectDir, LuminaBlueprintEnumDocument document, {String? path}) {
    final rel = path ?? '$enumsFolder/${document.name}.lmas';
    final file = File('$projectDir/$rel')..parent.createSync(recursive: true);
    file.writeAsBytesSync(_asset(document.name, document.toFormattedJson(), LuminaBlueprintEnumDocument.kind).toProtoBufferBytes());
    return rel;
  }

  /// Writes the interface asset `contents/interfaces/<name>.lmas` and
  /// returns its project-relative path.
  static String writeInterface(String projectDir, LuminaBlueprintInterfaceDocument document, {String? path}) {
    final rel = path ?? '$interfacesFolder/${document.name}.lmas';
    final file = File('$projectDir/$rel')..parent.createSync(recursive: true);
    file.writeAsBytesSync(
        _asset(document.name, document.toFormattedJson(), LuminaBlueprintInterfaceDocument.kind).toProtoBufferBytes());
    return rel;
  }

  /// The enum document stored at [path], or null.
  static LuminaBlueprintEnumDocument? readEnum(String path) {
    final json = _payloadOf(File(path));
    if (json == null || luminaBlueprintDocumentKind(json) != LuminaBlueprintEnumDocument.kind) return null;
    return LuminaBlueprintEnumDocument.fromJson(json);
  }

  /// The interface document stored at [path], or null.
  static LuminaBlueprintInterfaceDocument? readInterface(String path) {
    final json = _payloadOf(File(path));
    if (json == null || luminaBlueprintDocumentKind(json) != LuminaBlueprintInterfaceDocument.kind) return null;
    return LuminaBlueprintInterfaceDocument.fromJson(json);
  }

  /// Rewires every `Switch on <enum>` of [graph] after the enum's values
  /// went from [oldValues] to [newValues]: a case pin follows its value's
  /// name, not its index. Returns how many wires
  /// moved; wires of removed values are dropped.
  static int remapSwitchWires(LuminaBlueprintGraph graph, String enumName, List<String> oldValues, List<String> newValues) {
    if (listEquals(oldValues, newValues)) return 0;
    var moved = 0;
    final switches = {for (final n in graph.nodes) if (n.registryId == LuminaBlueprintNodeLibrary.switchOnEnum && n.literals['enum'] == enumName) n.id};
    if (switches.isEmpty) return 0;
    final rewired = <LuminaBlueprintWire>[];
    for (final w in graph.wires) {
      if (!switches.contains(w.fromNodeId) || !w.fromPinId.startsWith('case_')) {
        rewired.add(w);
        continue;
      }
      final index = int.tryParse(w.fromPinId.substring(5));
      if (index == null || index >= oldValues.length) {
        rewired.add(w);
        continue;
      }
      final value = oldValues[index];
      final next = newValues.indexOf(value);
      if (next < 0) continue; // the value is gone: so is its chain
      if (next == index) {
        rewired.add(w);
        continue;
      }
      moved++;
      rewired.add(LuminaBlueprintWire(id: w.id, fromNodeId: w.fromNodeId, fromPinId: 'case_$next', toNodeId: w.toNodeId, toPinId: w.toPinId));
    }
    graph.wires
      ..clear()
      ..addAll(rewired);
    // The stored pins follow too, so a document saved before its next
    // resolution still names the right cases.
    for (final id in switches) {
      final n = graph.node(id)!;
      n.outputs
        ..clear()
        ..addAll([for (var i = 0; i < newValues.length; i++) LuminaBlueprintPin(id: 'case_$i', name: newValues[i], type: LuminaPinType.exec, isOutput: true)]);
    }
    return moved;
  }

  /// [remapSwitchWires] on every graph of [document].
  static int remapDocumentSwitchWires(LuminaBlueprintDocument document, String enumName, List<String> oldValues, List<String> newValues) {
    var moved = remapSwitchWires(document.eventGraph, enumName, oldValues, newValues);
    for (final f in document.functions) {
      moved += remapSwitchWires(f.graph, enumName, oldValues, newValues);
    }
    for (final m in document.macros) {
      moved += remapSwitchWires(m.graph, enumName, oldValues, newValues);
    }
    return moved;
  }

  /// Rewrites every actor Blueprint `.lmas` of [projectDir] whose switches
  /// name [enumName], after its values were reordered; returns the
  /// project-relative paths touched.
  static List<String> remapProjectSwitchWires(String projectDir, String enumName, List<String> oldValues, List<String> newValues) {
    final touched = <String>[];
    if (listEquals(oldValues, newValues)) return touched;
    for (final e in _indexed(projectDir)) {
      // Only Blueprint classes can hold a switch on the enum (the index knows
      // which files those are without reading the rest).
      if (e.type != AssetType.actor || e.summary.blueprintKind != 'class') continue;
      final f = e.file;
      LuminaAsset asset;
      try {
        asset = LuminaAsset.fromBytes(f.readAsBytesSync());
      } catch (_) {
        continue;
      }
      final json = _payloadOf(f);
      if (asset.type != AssetType.actor || json == null || luminaBlueprintDocumentKind(json) != 'class') continue;
      final doc = LuminaBlueprintDocument.fromJson(json);
      if (remapDocumentSwitchWires(doc, enumName, oldValues, newValues) == 0) continue;
      final payload = doc.toFormattedJson();
      final updated = LuminaAsset(
        assetId: asset.assetId,
        name: asset.name,
        type: asset.type,
        rawPayload: Uint8List.fromList(utf8.encode(payload)),
        rawMatSource: payload,
        metadata: asset.metadata,
        thumbnailPng: asset.thumbnailPng,
        hasThumbnail: asset.hasThumbnail,
        references: asset.references,
      );
      f.writeAsBytesSync(updated.toProtoBufferBytes());
      touched.add(f.path.substring(projectDir.length + 1));
    }
    return touched;
  }
}

/// An enum asset on disk.
class BlueprintEnumAsset {
  final String path;
  final LuminaBlueprintEnumDocument document;
  const BlueprintEnumAsset({required this.path, required this.document});
}

/// An interface asset on disk.
class BlueprintInterfaceAsset {
  final String path;
  final LuminaBlueprintInterfaceDocument document;
  const BlueprintInterfaceAsset({required this.path, required this.document});
}

/// What an asset pin's picker lists.
enum BlueprintAssetKind { sound, montage, material, particle, level, saveGame }
