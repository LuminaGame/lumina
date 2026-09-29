import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

import '../../blueprint/level_load_blueprint.dart';
import '../../blueprint/level_load_fixture.dart';

/// Load Level, Change Level, Load And Change Level, Cancel
/// Level Load and Is Level Loaded in the VM, on a real project level
/// preloaded from disk and a host that switches worlds.
void main() {
  late Directory project;
  late String dir;
  late List<String> reads;
  late LuminaLevelPreloader saved;

  setUp(() {
    project = Directory.systemTemp.createTempSync('lvl_nodes_');
    dir = project.resolveSymbolicLinksSync();
    writeLevelLoadProject(dir);
    reads = [];
    saved = LuminaLevelPreloader.instance;
    LuminaLevelPreloader.instance = LuminaLevelPreloader(
      manifestResolver: (name) => LuminaLevelAssetManifest.forProjectLevel(dir, name),
      maxConcurrent: 1,
      assetProvider: (path) {
        reads.add(path);
        return File(path).readAsBytes();
      },
    );
  });
  tearDown(() {
    LuminaLevelPreloader.instance.reset();
    LuminaLevelPreloader.instance = saved;
    LuminaGame.onChangeLevelRequested = null;
    LuminaProjectLevels.clear();
    LuminaAssetIndex.close(dir);
    project.deleteSync(recursive: true);
  });

  ({LuminaWorld world, LuminaBlueprintInstance loader, LevelLoadTestHost host, List<String> printed}) play() {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.persistentLevel.levelName = 'L_First';
    final cls = LuminaBlueprintClass.fromDocument(levelLoadBlueprint(), name: 'BP_LevelLoader');
    expect(cls.diagnostics.where((d) => d.isError), isEmpty, reason: '${cls.diagnostics}');
    final loader = cls.instantiate() as LuminaBlueprintInstance;
    final host = LevelLoadTestHost(world)..install();
    final printed = host.log;
    (loader as LuminaBlueprintRuntime).trace = (e) {
      if (e.printed != null) printed.add(e.printed!);
    };
    world.persistentLevel.registerActor(loader as LuminaActor);
    world.beginPlay();
    return (world: world, loader: loader, host: host, printed: printed);
  }

  /// Ticks whatever world plays until [done], letting file reads finish.
  Future<void> until(LevelLoadTestHost host, bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      host.world.tick(1 / 30);
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(done(), isTrue, reason: 'timed out; log: ${host.log}');
  }

  test('Load Level runs On Progress once per asset with fresh values, the bound custom event receives the same, '
      'and Change Level switches without loading again and fires On Success after the new BeginPlay', () async {
    final s = play();
    s.loader.callBlueprint('StartLoading', const {});
    await until(s.host, () => s.printed.contains('changed'));

    final items = [for (final p in s.printed) if (levelSecondAssets.any((a) => a.contains('/$p.'))) p];
    expect(items, ['ac_unit_b_600x600', 'dented_barrel', 'BP_Crate', 'fuel_barrel_red', 'chime', 'sky'],
        reason: 'On Progress ran once per asset, in load order (one at a time)');
    expect([for (final p in s.printed) if (p.startsWith('event ')) p.substring(6)], items,
        reason: 'OnLoadProgress, bound to On Progress Event, got the same Current Content each time');
    expect(s.loader.variables['Updates'], 6);
    expect(s.loader.variables['LastPercent'], 100.0);
    expect(s.loader.variables['EventPercent'], 100.0, reason: 'the custom event got the same Percent');
    expect(s.printed, contains('loaded true'), reason: 'Is Level Loaded after On Success');
    expect(s.printed.indexOf('L_Second BeginPlay'), lessThan(s.printed.indexOf('changed')),
        reason: 'On Success after the new level began play');
    expect(s.printed.indexOf('loaded true'), lessThan(s.printed.indexOf('L_Second BeginPlay')));
    expect(reads, hasLength(6), reason: 'Change Level after Load Level loads nothing again');
    expect(s.host.world, isNot(same(s.world)));
    expect(s.host.world.persistentLevel.levelName, 'L_Second');
    expect(LuminaLevelPreloader.instance.isLoaded('L_Second'), isFalse, reason: 'handed to the new level');
  });

  test('Change Level to an unknown level fires On Error with the message', () async {
    final s = play();
    s.loader.callBlueprint('TryBadLevel', const {});
    await until(s.host, () => s.printed.any((p) => p.startsWith('bad: ')));
    expect(s.printed.firstWhere((p) => p.startsWith('bad: ')), contains("no level named 'L_Nowhere'"));
    expect(s.host.world, same(s.world), reason: 'nothing switched');
  });

  test('Load And Change Level fires On Success once the new level is playing', () async {
    final s = play();
    s.loader.callBlueprint('LoadAndGo', const {});
    await until(s.host, () => s.printed.contains('went'));
    expect(s.printed.indexOf('L_First BeginPlay'), lessThan(s.printed.indexOf('went')));
    expect(s.host.world.persistentLevel.levelName, 'L_First');
    expect(reads.toSet(), {'$dir/$redBarrelPath'}, reason: 'L_First names one asset');
  });

  test('Cancel Level Load stops a running Load Level: no more progress, no Success', () async {
    final s = play();
    s.loader.callBlueprint('StartLoading', const {});
    s.loader.callBlueprint('StopLoading', const {});
    for (var i = 0; i < 20; i++) {
      s.host.world.tick(1 / 30);
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(s.loader.variables['Updates'], 0);
    expect(s.printed, isNot(contains('changed')));
    expect(LuminaLevelPreloader.instance.isLoaded('L_Second'), isFalse);
  });

  test('without a host, Change Level fires On Error', () async {
    final s = play();
    s.host.uninstall();
    s.loader.callBlueprint('TryBadLevel', const {});
    await until(s.host, () => s.printed.any((p) => p.startsWith('bad: ')));
    expect(s.printed.firstWhere((p) => p.startsWith('bad: ')), contains('no game host changes levels'));
  });

  test('the validator warns about a Level Name that is not a project level, and only then', () {
    expect(validateBlueprint(levelLoadBlueprint(), className: 'BP_LevelLoader'), isEmpty,
        reason: 'no project levels registered: nothing to check against');
    LuminaProjectLevels.register(['contents/levels/L_First.lmas', 'L_Second']);
    final issues = validateBlueprint(levelLoadBlueprint(), className: 'BP_LevelLoader');
    expect(issues, hasLength(1));
    expect(issues.single.severity, LuminaBlueprintSeverity.warning);
    expect(issues.single.nodeId, 'bad_change');
    expect(issues.single.message, contains("'L_Nowhere' is not a level of this project"));
  });

  test('the node library declares the level nodes with their pins', () {
    final load = LuminaBlueprintNodeLibrary.spec('load_level')!;
    expect(load.category, 'Game|Level');
    expect(load.kind, LuminaBlueprintNodeKind.latent);
    expect([for (final p in load.outputs) p.id],
        ['exec_out', 'on_progress', 'on_error', 'on_success', 'percent', 'total_count', 'loaded_count', 'current_content', 'error', 'stack_trace']);
    expect([for (final p in load.inputs) p.id], ['exec_in', 'level_name', 'on_progress_event', 'on_error_event', 'on_success_event']);
    for (final id in ['change_level', 'load_and_change_level']) {
      final spec = LuminaBlueprintNodeLibrary.spec(id)!;
      expect([for (final p in spec.outputs) p.id], ['exec_out', 'on_error', 'on_success', 'error', 'stack_trace']);
      expect([for (final p in spec.inputs) p.id], ['exec_in', 'level_name', 'on_error_event', 'on_success_event']);
    }
    expect(LuminaBlueprintNodeLibrary.spec('cancel_level_load')!.kind, LuminaBlueprintNodeKind.impure);
    expect(LuminaBlueprintNodeLibrary.spec('is_level_loaded')!.kind, LuminaBlueprintNodeKind.pure);
  });
}
