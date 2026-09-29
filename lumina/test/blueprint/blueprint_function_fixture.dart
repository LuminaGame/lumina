import 'dart:convert';
import 'dart:io';

import 'package:lumina/lumina.dart';

/// The fixture project whose `lib/` holds annotated functions
/// (`test/blueprint/fixtures/project_functions/`), and the Blueprint that calls
/// them.

/// The committed fixture sources, laid out as a project's `lib/`.
const String blueprintFunctionFixtureLib = 'test/blueprint/fixtures/project_functions';

/// The committed registration golden: what the scanner generates for the
/// fixture, at the path it takes in a project (`lib/blueprint/`), so its
/// relative imports reach the fixture sources and the suite compiles it.
const String blueprintFunctionRegistrationGolden = '$blueprintFunctionFixtureLib/blueprint/blueprint_functions.g.dart';

const String applyDamageId = 'fn:package:fixture/health.dart#applyDamage';
const String healthStateId = 'fn:package:fixture/health.dart#healthState';
const String spawnMarkerId = 'fn:package:fixture/markers.dart#spawnMarker';
const String markerRingId = 'fn:package:fixture/markers.dart#markerRing';
const String countCallsId = 'fn:package:fixture/types.dart#countCalls';
const String twiceId = 'fn:package:fixture/types.dart#FixtureMath.twice';
const String describeTypesId = 'fn:package:fixture/types.dart#describeTypes';

/// A real project on disk named `fixture`: the fixture sources under `lib/`
/// (not the generated registration), a pubspec depending on lumina, a
/// `.lmproject`, and the package config `flutter pub get` writes (lumina's
/// own resolution, plus the project itself).
Directory createBlueprintFunctionFixtureProject() {
  final root = Directory.systemTemp.createTempSync('lumina_bp07_');
  final source = Directory(blueprintFunctionFixtureLib);
  for (final f in source.listSync(recursive: true).whereType<File>()) {
    final relative = f.path.substring(source.path.length + 1);
    if (relative.startsWith('blueprint/')) continue;
    File('${root.path}/lib/$relative')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(f.readAsStringSync());
  }
  final lumina = Directory.current.absolute.path;
  File('${root.path}/pubspec.yaml').writeAsStringSync(
      'name: fixture\npublish_to: none\nenvironment:\n  sdk: ^3.12.0\ndependencies:\n  lumina:\n    path: $lumina\n');
  File('${root.path}/fixture.lmproject')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(LuminaProject(projectName: 'fixture').toMap()));
  // The pub workspace's one package config is at its root (the package's
  // parent); its relative rootUris are made absolute for the copy.
  final configFile = File('${Directory.current.parent.absolute.path}/.dart_tool/package_config.json');
  final config = jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
  final base = configFile.parent.absolute.uri;
  final packages = [
    for (final p in (config['packages'] as List).cast<Map<String, dynamic>>())
      if (p['name'] == 'lumina')
        {...p, 'rootUri': Directory.current.absolute.uri.toString()}
      else
        {...p, 'rootUri': base.resolve('${p['rootUri']}').toString()},
    {'name': 'fixture', 'rootUri': '../', 'packageUri': 'lib/', 'languageVersion': '3.12'},
  ];
  File('${root.path}/.dart_tool/package_config.json')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert({...config, 'packages': packages}));
  return root;
}

LuminaBlueprintWire _exec(String id, String from, String to, {String fromPin = 'exec_out'}) =>
    LuminaBlueprintWire(id: id, fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: 'exec_in');

LuminaBlueprintWire _data(String id, String from, String fromPin, String to, String toPin) =>
    LuminaBlueprintWire(id: id, fromNodeId: from, fromPinId: fromPin, toNodeId: to, toPinId: toPin);

/// BeginPlay → Apply Damage(25) → Count Calls(2) → Set Calls(Twice(total))
/// → SetActorLocation(Marker Ring Offset(1)) → Print String: project
/// functions of every shape (a named default left out, an optional
/// positional, a return value, a static pure, a pure with defaults) between
/// built-in nodes. The project functions must be registered or declared.
LuminaBlueprintDocument projectFunctionsBlueprint() => LuminaBlueprintDocument(
      variables: const [LuminaBlueprintVariable(name: 'Calls', typeName: 'Int', defaultValue: 0)],
      eventGraph: LuminaBlueprintGraph(
        nodes: [
          LuminaBlueprintNodeLibrary.place('event_beginplay', nodeId: 'begin'),
          LuminaBlueprintNodeLibrary.place(applyDamageId, nodeId: 'damage', x: 300, literals: {'amount': 25.0}),
          LuminaBlueprintNodeLibrary.place(countCallsId, nodeId: 'count', x: 600, literals: {'times': 2}),
          LuminaBlueprintNodeLibrary.place(twiceId, nodeId: 'twice', x: 800, y: 200),
          LuminaBlueprintNodeLibrary.place(LuminaBlueprintNodeLibrary.variableSet,
              nodeId: 'set_calls',
              x: 1000,
              literals: {'variable': 'Calls'},
              context: const LuminaBlueprintTypeContext(
                  variables: [LuminaBlueprintVariable(name: 'Calls', typeName: 'Int', defaultValue: 0)])),
          LuminaBlueprintNodeLibrary.place(markerRingId, nodeId: 'ring', x: 1100, y: 200, literals: {'index': 1}),
          LuminaBlueprintNodeLibrary.place('set_actor_location', nodeId: 'move', x: 1300),
          LuminaBlueprintNodeLibrary.place('print_string', nodeId: 'print', x: 1600, literals: {'in_string': 'damaged'}),
        ],
        wires: [
          _exec('w1', 'begin', 'damage'),
          _exec('w2', 'damage', 'count'),
          _exec('w3', 'count', 'set_calls'),
          _data('w4', 'count', 'return_value', 'twice', 'value'),
          _data('w5', 'twice', 'return_value', 'set_calls', 'value'),
          _exec('w6', 'set_calls', 'move'),
          _data('w7', 'ring', 'return_value', 'move', 'new_location'),
          _exec('w8', 'move', 'print'),
        ],
      ),
    );
