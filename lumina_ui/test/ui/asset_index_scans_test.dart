import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/services/widget_blueprint_assets.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/blueprint_asset_catalog.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/widget_class_catalog.dart';

import '../helpers/scaffold_game_project.dart';

/// The editor half: the widget class catalog, the
/// Blueprint asset catalog, widget detection, the UMG code generator and
/// Play-In-Editor's registration read the project's asset index instead of
/// decoding every `.lmas` — with the same results — and Play on a
/// 300-asset project spends well under 300 ms scanning on the UI isolate.
void main() {
  late Directory root;
  late String dir;
  const name = 'index_scans';

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_ui_asset_index_');
    dir = await scaffoldGameProject(root, name: name, widgetLibrary: 'flutter');
    AssetProjectFixture.write(root, name: name, count: 300, writeManifest: false);
    // A real designer document too, so a widget class has elements.
    final doc = UmgDocument.createDefault();
    File('$dir/contents/widgets/WBP_Designer.lmas').writeAsBytesSync(LuminaAsset(
      assetId: 'wbp_designer',
      name: 'WBP_Designer',
      type: AssetType.widget,
      rawPayload: utf8.encode(doc.toFormattedJson()),
      metadata: const {'parent_class': kWidgetBlueprintParentClass},
    ).toProtoBufferBytes());
  });

  tearDownAll(() {
    LuminaAssetIndex.close(dir);
    root.deleteSync(recursive: true);
  });

  List<File> lmasFiles() => Directory('$dir/contents')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.lmas'))
      .toList();

  Map<String, dynamic>? payloadJson(LuminaAsset a) {
    final p = a.rawPayload;
    if (p == null || p.isEmpty) return null;
    try {
      final j = jsonDecode(utf8.decode(p));
      return j is Map ? Map<String, dynamic>.from(j) : null;
    } catch (_) {
      return null;
    }
  }

  test('widget classes, actor parents, enums, interfaces, asset paths and widget documents equal the full-scan results', () {
    // The scans as they were before the asset index: decode every .lmas.
    final decoded = {for (final f in lmasFiles()) f: LuminaAsset.fromBytes(f.readAsBytesSync())};
    final widgetNames = <String>[];
    final parents = <String, String>{};
    final enums = <String>[];
    final interfaces = <String>[];
    final widgetDocs = <String>[];
    decoded.forEach((f, a) {
      final base = f.uri.pathSegments.last.replaceAll('.lmas', '');
      if (a.type == AssetType.widget || a.metadata['parent_class'] == kWidgetBlueprintParentClass) widgetNames.add(base);
      final json = payloadJson(a);
      if (f.path.contains('/contents/blueprints/') && a.type == AssetType.actor) {
        final parent = (json?['parentClass'] as String?) ?? a.metadata['parent_class'];
        if (parent != null && parent.isNotEmpty && parent != kWidgetBlueprintParentClass) parents[base] = parent;
      }
      if (json != null && luminaBlueprintDocumentKind(json) == 'enum') enums.add(f.path);
      if (json != null && luminaBlueprintDocumentKind(json) == 'interface') interfaces.add(f.path);
      if (a.type == AssetType.widget && json != null) {
        try {
          UmgDocument.fromJson(json);
          widgetDocs.add(base);
        } catch (_) {}
      }
    });
    widgetNames.sort();

    final classes = WidgetClassCatalog.scanWidgetClasses(dir);
    expect([for (final c in classes) c.name], widgetNames);
    expect(classes.firstWhere((c) => c.name == 'WBP_Designer').toJson(),
        WidgetClassCatalog.readWidgetClass(File('$dir/contents/widgets/WBP_Designer.lmas'))!.toJson());
    expect(WidgetClassCatalog.scanActorParents(dir), parents);
    expect(BlueprintAssetCatalog.scanEnums(dir).map((e) => e.path).toSet(), enums.toSet());
    expect(BlueprintAssetCatalog.scanInterfaces(dir).map((e) => e.path).toSet(), interfaces.toSet());
    expect(UmgWidgetCodegen.widgetDocuments(dir).keys.toSet(), {for (final n in widgetDocs) UmgWidgetCodegen.fileBaseName(n)});
    final paths = BlueprintAssetCatalog.scanAssetPaths(dir);
    expect(paths[BlueprintAssetKind.montage], isNotEmpty);
    expect(paths[BlueprintAssetKind.saveGame], isNotEmpty);
    expect(paths[BlueprintAssetKind.particle]!.length, 30);

    // Widget detection reads the summary only.
    for (final f in decoded.keys) {
      final a = decoded[f]!;
      expect(isWidgetBlueprintLmas(f.path), a.type == AssetType.widget || a.metadata['parent_class'] == kWidgetBlueprintParentClass,
          reason: f.path);
    }
  });

  testWidgets('Play on a 300-asset project spends < 300 ms scanning on the UI isolate (around createGame)', (tester) async {
    final manifest = LuminaProject.fromMap(Map<String, dynamic>.from(jsonDecode(File('$dir/$name.lmproject').readAsStringSync()) as Map));
    // Opening the project brings the index up to date off the UI isolate.
    await tester.runAsync(() => ProjectRepository(configDir: Directory('${root.path}/.config')).prepareAssetIndex(dir));
    final vm = EditorViewModel(initialProject: manifest, projectLocation: root.path, enableTimers: false, autoInitAssets: false);
    addTearDown(vm.dispose);
    await tester.runAsync(vm.ensureDefaultLevelAssets);
    vm.refreshAssets();
    expect(vm.realAssets.length, greaterThan(300));

    // What those two scans cost before: a full decode of every .lmas.
    final before = Stopwatch()..start();
    for (var pass = 0; pass < 2; pass++) {
      for (final f in lmasFiles()) {
        LuminaAsset.fromBytes(f.readAsBytesSync());
      }
    }
    before.stop();

    final pie = vm.pieController;
    final actors = [for (final a in vm.actors) EditorActorNode.fromMap(a.toMap())];
    final watch = Stopwatch()..start();
    final game = pie.createGame(actors);
    watch.stop();
    expect(game, isNotNull);
    expect(LuminaWidgetClassRegistry.lookup('WBP_Designer'), isNotNull, reason: 'widget classes registered from the index');
    expect(LuminaBlueprintEnums.lookup('E_State_7'), isNotNull, reason: 'enums registered from the index');
    // ignore: avoid_print
    print('[asset index] createGame on ${lmasFiles().length} assets: ${watch.elapsedMilliseconds} ms '
        '(two full-decode passes, as Play did before: ${before.elapsedMilliseconds} ms)');
    expect(watch.elapsedMilliseconds, lessThan(300));
    LuminaBlueprintActorClasses.clear();
    LuminaBlueprintEnums.clear();
    LuminaBlueprintInterfaces.clear();
  });
}
