import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina/lumina.dart';

import '../helpers/analyze_generated_project.dart';

/// Files as the generators wrote them before generated Dart followed Dart's
/// naming rules (asset-named files, `L_Main` / `BPDoor` classes).
void _writeLegacyProject(String dir) {
  void write(String rel, String content) => File('$dir/lib/$rel')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(content);

  write('main.dart', '''
import 'levels/L_Main.dart';
import 'actors/actors.g.dart';
import 'widgets/widget_registry.g.dart';

final Map<String, Object Function()> _projectLevels = {
  'L_Main': () => L_Main(),
};
final Map<String, Object> _manifests = {
  'L_Main': L_Main.assetManifest,
};
class MyGameGame {
  MyGameGame({this.levelName = 'L_Main'});
  final String levelName;
}
''');
  write('levels/L_Main.dart', '''
import '../actors/actors.g.dart';

/// Level `L_Main` as authored in Lumina Studio.
class L_Main extends LuminaLevel {
  L_Main({super.key})
      : super(name: 'L_Main', scriptActor: _L_MainScript(), children: []);
}

class _L_MainScript extends LuminaLevelScriptActor {
  _L_MainScript() : super(key: const ValueKey('L_Main_script'));
  final path = 'contents/levels/L_Main.lmas';
}
''');
  write('actors/BP_Door.dart', '''
// Blueprint contents/blueprints/BP_Door.lmas, compiled by Lumina.
import '../anim/ABP_Character.dart';

class BPDoor extends LuminaActor with LuminaBlueprintRuntime {
  BPDoor({super.key, super.location, super.rotation}) {
    final anim = ABPManny.create;
  }
  // BEGIN USER CODE: class_body
  int opened = 0; // hand-written
  // END USER CODE
}
''');
  write('actors/BP_DoorFrame.dart', '''
class BPDoorFrame extends LuminaActor {}
''');
  write('actors/actors.g.dart', '''
import 'BP_Door.dart';
import 'BP_DoorFrame.dart';

final factories = {
  'contents/blueprints/BP_Door.lmas': () => BPDoor(),
  'BPDoorFrame': () => BPDoorFrame(),
};
''');
  write('anim/ABP_Character.dart', '''
class ABPManny extends LuminaAnimBlueprintInstance {
  static LuminaAnimBlueprintInstance create(Object mesh) => ABPManny(mesh: mesh);
}
''');
  write('widgets/WBP_Hud.dart', '''
/// `WBP_Hud` as designed in Lumina Studio.
class WBPHud extends StatefulWidget {
  const WBPHud({super.key});
  State<WBPHud> createState() => _WBPHudState();
}
class _WBPHudState extends State<WBPHud> {}
class WBPHudGraph extends LuminaUserWidget {}
''');
  write('widgets/widget_registry.g.dart', '''
import 'WBP_Hud.dart';

void registerProjectWidgetClasses() {
  LuminaWidgetBuilderRegistry.register('WBP_Hud', (context, instance) => WBPHud(instance: instance));
  LuminaUserWidgets.register('WBP_Hud', WBPHudGraph.new);
}
''');
  write('game/MyGameGameMode.dart', '''
import '../actors/BP_Door.dart';
class MyGameGameMode {}
''');
}

List<String> _names(String dir) =>
    Directory(dir).listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toList()..sort();

void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('lumina_codegen_migration_'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('renames asset-named generated files to snake_case and their classes to UpperCamelCase', () {
    _writeLegacyProject(temp.path);

    final renamed = LuminaGeneratedCodeMigration.migrate(temp.path);

    expect(renamed, {
      'lib/levels/L_Main.dart': 'lib/levels/l_main.dart',
      'lib/actors/BP_Door.dart': 'lib/actors/bp_door.dart',
      'lib/actors/BP_DoorFrame.dart': 'lib/actors/bp_door_frame.dart',
      'lib/anim/ABP_Character.dart': 'lib/anim/abp_character.dart',
      'lib/widgets/WBP_Hud.dart': 'lib/widgets/wbp_hud.dart',
    });
    // The exact on-disk names (a case-only rename on Windows included).
    expect(_names('${temp.path}/lib/levels'), ['l_main.dart']);
    expect(_names('${temp.path}/lib/actors'), ['actors.g.dart', 'bp_door.dart', 'bp_door_frame.dart']);
    expect(_names('${temp.path}/lib/anim'), ['abp_character.dart']);
    expect(_names('${temp.path}/lib/widgets'), ['wbp_hud.dart', 'widget_registry.g.dart']);
    // User-owned folders keep their file names.
    expect(_names('${temp.path}/lib/game'), ['MyGameGameMode.dart']);

    final main = File('${temp.path}/lib/main.dart').readAsStringSync();
    expect(main, contains("import 'levels/l_main.dart';"));
    expect(main, contains("'L_Main': () => LMain(),"));
    expect(main, contains("'L_Main': LMain.assetManifest,"));
    expect(main, contains("this.levelName = 'L_Main'"));

    final level = File('${temp.path}/lib/levels/l_main.dart').readAsStringSync();
    expect(level, contains('class LMain extends LuminaLevel {'));
    expect(level, contains('LMain({super.key})'));
    expect(level, contains("super(name: 'L_Main', scriptActor: _LMainScript()"));
    expect(level, contains('class _LMainScript extends LuminaLevelScriptActor'));
    expect(level, contains("LuminaObjectKey('L_Main_script')"), reason: 'engine keys move off Flutter');
    expect(level, contains("'contents/levels/L_Main.lmas'"));
    expect(level, contains('Level `L_Main` as authored'));

    final door = File('${temp.path}/lib/actors/bp_door.dart').readAsStringSync();
    expect(door, contains("import '../anim/abp_character.dart';"));
    expect(door, contains('class BpDoor extends LuminaActor'));
    expect(door, contains('BpDoor({super.key'));
    expect(door, contains('AbpCharacter.create'));
    expect(door, contains('int opened = 0; // hand-written'), reason: 'user code regions move with the file');
    expect(door, contains('contents/blueprints/BP_Door.lmas'));

    final registry = File('${temp.path}/lib/actors/actors.g.dart').readAsStringSync();
    expect(registry, contains("import 'bp_door.dart';"));
    expect(registry, contains("import 'bp_door_frame.dart';"));
    expect(registry, contains('() => BpDoor()'));
    // Quoted names are data, not references: the next registry write renames them.
    expect(registry, contains("'BPDoorFrame': () => BpDoorFrame()"));

    final hud = File('${temp.path}/lib/widgets/wbp_hud.dart').readAsStringSync();
    expect(hud, contains('class WbpHud extends StatefulWidget'));
    expect(hud, contains('State<WbpHud> createState() => _WbpHudState();'));
    expect(hud, contains('class WbpHudGraph'));
    expect(hud, contains('`WBP_Hud` as designed'));
    final widgets = File('${temp.path}/lib/widgets/widget_registry.g.dart').readAsStringSync();
    expect(widgets, contains("import 'wbp_hud.dart';"));
    expect(widgets, contains("register('WBP_Hud', (context, instance) => WbpHud(instance: instance))"));
    expect(widgets, contains("register('WBP_Hud', WbpHudGraph.new)"));

    final mode = File('${temp.path}/lib/game/MyGameGameMode.dart').readAsStringSync();
    expect(mode, contains("import '../actors/bp_door.dart';"));
  });

  test('a migrated project migrates to nothing', () {
    _writeLegacyProject(temp.path);
    LuminaGeneratedCodeMigration.migrate(temp.path);
    final before = File('${temp.path}/lib/main.dart').readAsStringSync();
    expect(LuminaGeneratedCodeMigration.migrate(temp.path), isEmpty);
    expect(File('${temp.path}/lib/main.dart').readAsStringSync(), before);
  });

  test('a legacy file next to its regenerated snake_case file is removed', () {
    File('${temp.path}/lib/levels/L_Other.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('class L_Other extends LuminaLevel {}\n');
    File('${temp.path}/lib/levels/l_other.dart').writeAsStringSync('class LOther extends LuminaLevel {}\n');
    // Only a case-sensitive file system can hold both; elsewhere the second
    // write went to the first file.
    final both = _names('${temp.path}/lib/levels').length == 2;

    LuminaGeneratedCodeMigration.migrate(temp.path);

    expect(_names('${temp.path}/lib/levels'), ['l_other.dart']);
    if (both) {
      expect(File('${temp.path}/lib/levels/l_other.dart').readAsStringSync(), contains('class LOther'));
    }
  });

  test('a project without generated code is left alone', () {
    expect(LuminaGeneratedCodeMigration.migrate(temp.path), isEmpty);
    expect(LuminaGeneratedCodeMigration.migrate('${temp.path}/missing'), isEmpty);
  });

  test('engine object keys move from Flutter ValueKey to LuminaObjectKey; widget keys stay', () {
    const level = '''
import 'package:flutter/foundation.dart' show ValueKey;
import 'package:lumina/lumina_runtime.dart';

final a = LuminaActor(key: const ValueKey('act_floor'));
void assign(LuminaActor actor) {
  final key = actor.key;
  if (key is ValueKey<String>) print(key.value);
}
''';
    final migrated = LuminaGeneratedCodeMigration.rewriteObjectKeys(level);
    expect(migrated, isNot(contains('ValueKey')));
    expect(migrated, isNot(contains('package:flutter/foundation.dart')));
    expect(migrated, contains("LuminaActor(key: const LuminaObjectKey('act_floor'))"));
    expect(migrated, contains('if (key is LuminaObjectKey)'));
    expect(LuminaGeneratedCodeMigration.rewriteObjectKeys(migrated), migrated, reason: 'idempotent');
    expect(
      LuminaGeneratedCodeMigration.rewriteObjectKeys("import 'package:flutter/foundation.dart' show Key, kIsWeb;\nT f<T>({Key? key}) => throw 0;\n"),
      "import 'package:flutter/foundation.dart' show kIsWeb;\nT f<T>({LuminaObjectKey? key}) => throw 0;\n",
    );

    // Widgets keep Flutter's keys: lib/widgets is not rewritten.
    const widget = "import 'package:flutter/widgets.dart';\nfinal w = Text('x', key: const ValueKey('title'));\n";
    File('${temp.path}/lib/widgets/wbp_hud.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(widget);
    File('${temp.path}/lib/levels/l_main.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(level);
    expect(LuminaGeneratedCodeMigration.migrateObjectKeys(temp.path), ['lib/levels/l_main.dart']);
    expect(File('${temp.path}/lib/widgets/wbp_hud.dart').readAsStringSync(), widget);
    expect(LuminaGeneratedCodeMigration.migrateObjectKeys(temp.path), isEmpty);
  });

  test('a project whose generated level keys actors with ValueKey is rewritten on open and analyzes clean', () async {
    final root = Directory('${temp.path}/p')..createSync();
    final config = Directory('${temp.path}/cfg')..createSync();
    File('${root.path}/pubspec.yaml').writeAsStringSync('''
name: legacy_keys_game
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
  lumina:
    path: ${Directory.current.path.replaceAll(r'\\', '/')}
  vector_math: ^2.1.4
''');
    File('${root.path}/legacy_keys_game.lmproject').writeAsStringSync('{"project_name": "legacy_keys_game"}');
    File('${root.path}/analysis_options.yaml').writeAsStringSync('');

    // The level and Blueprint registry as the generator wrote them while
    // engine objects carried Flutter's keys.
    final generator = DartCodeGeneratorService();
    final start = luminaTemplatePlayerStart()..['dataLayers'] = ['Gameplay'];
    final current = generator.generateLevelDart(
      levelName: 'L_Main',
      actors: const [],
      actorMaps: [luminaTemplateGroundPlane(), start],
      worldPartition: {
        'enabled': true,
        'dataLayers': [
          {'name': 'Gameplay', 'initialState': 'activated', 'isRuntime': true},
        ],
      },
    );
    expect(current, contains("key: const LuminaObjectKey('act_floor')"));
    expect(current, contains('if (key != null) {'));
    final legacyLevel = current
        .replaceFirst("import 'package:lumina/lumina_runtime.dart';",
            "import 'package:flutter/foundation.dart' show ValueKey;\nimport 'package:lumina/lumina_runtime.dart';")
        .replaceAll('LuminaObjectKey(', 'ValueKey(')
        .replaceAll('if (key != null) {', 'if (key is ValueKey<String>) {');
    final legacyRegistry = generator
        .generateBlueprintRegistryDart(const [])
        .replaceFirst("import 'package:lumina/lumina_runtime.dart';",
            "import 'package:flutter/foundation.dart' show Key;\nimport 'package:lumina/lumina_runtime.dart';")
        .replaceAll('LuminaObjectKey? key', 'Key? key');
    File('${root.path}/lib/levels/l_main.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(legacyLevel);
    File('${root.path}/lib/actors/actors.g.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(legacyRegistry);
    File('${root.path}/lib/main.dart').writeAsStringSync(generator.generateMainDart(projectName: 'legacy_keys_game', levelName: 'L_Main'));

    final project = await ProjectRepository(configDir: config).loadProject('${root.path}/legacy_keys_game.lmproject');
    expect(project, isNotNull);

    final level = File('${root.path}/lib/levels/l_main.dart').readAsStringSync();
    expect(level, contains("key: const LuminaObjectKey('act_floor')"));
    expect(level, contains('if (key is LuminaObjectKey) {'));
    expect(level, isNot(contains('ValueKey')));
    expect(level, isNot(contains('package:flutter/foundation.dart')));
    final registry = File('${root.path}/lib/actors/actors.g.dart').readAsStringSync();
    expect(registry, contains('Function({LuminaObjectKey? key,'));
    expect(registry, isNot(contains('package:flutter/foundation.dart')));

    final pubGet = await Process.run('flutter', ['pub', 'get', '--offline'], workingDirectory: root.path, runInShell: Platform.isWindows);
    expect(pubGet.exitCode, 0, reason: 'pub get: ${pubGet.stdout}${pubGet.stderr}');
    final analyze = await analyzeGeneratedProject(root.path);
    expect(analyze.exitCode, 0, reason: 'the migrated project must analyze clean:\n${analyze.stdout}\n${analyze.stderr}');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
