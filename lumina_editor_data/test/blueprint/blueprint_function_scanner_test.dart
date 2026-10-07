import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

import 'blueprint_function_fixture.dart';

/// Dart functions annotated `@BlueprintCallable` /
/// `@BlueprintPure` in a real project's `lib/` become Blueprint nodes — the
/// scanner (lumina's header tool), the generated registration and manifest,
/// the registry, and the code generator's direct call. The registration and
/// the generated Blueprint are compiled and run by
/// blueprint_function_parity_test.dart. Regenerate the goldens with
/// `UPDATE_GOLDENS=1 flutter test test/blueprint/blueprint_function_scanner_test.dart`.
void main() {
  final update = Platform.environment['UPDATE_GOLDENS'] == '1';
  late Directory project;
  late BlueprintFunctionScan scan;

  setUpAll(() async {
    project = createBlueprintFunctionFixtureProject();
    scan = await const BlueprintFunctionScanner().scan(Directory('${project.path}/lib'));
  });
  tearDownAll(() => project.deleteSync(recursive: true));
  tearDown(LuminaBlueprintFunctionRegistry.clear);

  /// Pins as `[id, type, default]`, compared deeply.
  List<List<Object?>> pins(List<LuminaBlueprintPinSpec> list) => [
        for (final p in list) [p.id, p.type, p.defaultValue],
      ];

  group('scanner', () {
    test('@BlueprintCallable applyDamage scans to an impure node with self implicit', () {
      final f = scan.function(applyDamageId);
      expect(f, isNotNull, reason: '${scan.diagnostics}');
      final s = f!.spec;
      expect(s.id, 'fn:package:fixture/health.dart#applyDamage');
      expect(s.title, 'Apply Damage');
      expect(s.category, 'Game|Health');
      expect(s.kind, LuminaBlueprintNodeKind.impure);
      expect(s.keywords, ['hurt', 'hit']);
      expect(pins(s.inputs), [
        ['exec_in', LuminaPinType.exec, null],
        ['amount', LuminaPinType.float, null],
        ['lethal', LuminaPinType.boolean, false],
      ]);
      expect(pins(s.outputs), [['exec_out', LuminaPinType.exec, null]]);
      expect(s.inputs.map((p) => p.name), ['Exec In', 'Amount', 'Lethal']);
      expect(s.tooltip, 'Takes [amount] hit points from the actor running the node.\n[lethal] kills it outright.');
      expect(f.call.method, 'applyDamage');
      expect(f.call.library, 'package:fixture/health.dart');
      expect(f.call.self, isTrue);
      expect(f.call.args, ['amount', 'lethal']);
      expect(f.call.named, {'lethal'});
      expect(f.call.optional, {'lethal'});
      expect(f.path, 'lib/health.dart');
      expect(f.line, 13);
    });

    test('@BlueprintPure healthState: an object input, two record outputs, the doc comment as tooltip', () {
      final s = scan.function(healthStateId)!.spec;
      expect(s.title, 'Health State');
      expect(s.category, 'Project');
      expect(s.kind, LuminaBlueprintNodeKind.pure);
      expect(pins(s.inputs), [['target', LuminaPinType.object, null]]);
      expect(s.inputs.single.required, isTrue, reason: 'a non-nullable object must be wired');
      expect(pins(s.outputs), [['percent', LuminaPinType.float, null], ['dead', LuminaPinType.boolean, null]],
          reason: 'record fields in declaration order');
      expect(s.tooltip, 'How healthy [target] is: its hit points as a fraction of 100, and whether\nit is dead.');
      final call = scan.function(healthStateId)!.call;
      expect(call.self, isFalse);
      expect(call.returnsRecord, isTrue);
      expect(call.outputs, ['percent', 'dead']);
    });

    test('every pin type, defaults, a static function and an optional positional parameter', () {
      final describe = scan.function(describeTypesId)!.spec;
      expect(describe.tooltip, 'Every pin type at once.', reason: 'the annotation wins over the doc comment');
      expect(pins(describe.inputs), [
        ['count', LuminaPinType.integer, null],
        ['label', LuminaPinType.string, null],
        ['size', LuminaPinType.vector2D, null],
        ['at', LuminaPinType.vector, null],
        ['facing', LuminaPinType.rotator, null],
        ['pawn', LuminaPinType.object, null],
        ['scale', LuminaPinType.float, 1.5],
        ['turn', LuminaPinType.rotator, [0.0, 0.0, 90.0]],
        ['other', LuminaPinType.object, null],
      ]);
      expect(describe.inputs.firstWhere((p) => p.id == 'pawn').required, isTrue, reason: 'LuminaPawn is an actor subclass');
      expect(describe.inputs.firstWhere((p) => p.id == 'other').required, isFalse, reason: 'nullable');
      expect(pins(describe.outputs), [['return_value', LuminaPinType.string, null]]);

      final count = scan.function(countCallsId)!;
      expect(count.spec.kind, LuminaBlueprintNodeKind.impure);
      expect(pins(count.spec.inputs), [['exec_in', LuminaPinType.exec, null], ['times', LuminaPinType.integer, 1]]);
      expect(pins(count.spec.outputs), [['exec_out', LuminaPinType.exec, null], ['return_value', LuminaPinType.integer, null]]);
      expect(count.call.named, isEmpty);
      expect(count.call.optional, {'times'});

      final twice = scan.function(twiceId)!;
      expect(twice.spec.title, 'Twice');
      expect(twice.spec.category, 'Fixture|Math');
      expect(twice.call.method, 'FixtureMath.twice');

      final ring = scan.function(markerRingId)!.spec;
      expect(ring.title, 'Marker Ring Offset', reason: 'displayName');
      expect(pins(ring.inputs), [
        ['index', LuminaPinType.integer, null],
        ['radius', LuminaPinType.float, 250.0],
        ['count', LuminaPinType.integer, 3],
      ]);
      expect(pins(ring.outputs), [['return_value', LuminaPinType.vector, null]]);
      expect(pins(scan.function(spawnMarkerId)!.spec.inputs),
          [['exec_in', LuminaPinType.exec, null], ['at', LuminaPinType.vector, null]]);
    });

    test("a project class named Vector3 is not vector_math's Vector3", () {
      expect(scan.function('fn:package:fixture/shadow.dart#shadowLength'), isNull);
      final d = scan.diagnostics.where((d) => d.function == 'shadowLength').single;
      expect(d.parameter, 'v');
      expect(d.path, 'lib/shadow.dart');
      expect(d.message, contains('Vector3 (package:fixture/shadow.dart)'));
    });

    test('a Future return, an Object parameter, a generic and an instance method are errors, with no spec', () {
      BlueprintFunctionDiagnostic one(String function) => scan.diagnostics.where((d) => d.function == function).single;
      final future = one('loadLater');
      expect(future.message, allOf(contains('loadLater'), contains('Future<void>'), contains('async')));
      final object = one('describeObject');
      expect(object.parameter, 'value');
      expect(object.message, allOf(contains('describeObject'), contains("'value'"), contains('Object')));
      final generic = one('pick');
      expect(generic.message, allOf(contains('pick'), contains('generic'), contains('T')));
      final instance = one('Turret.fire');
      expect(instance.message, allOf(contains('Turret.fire'), contains('instance method'), contains('later')));
      for (final d in [future, object, generic, instance]) {
        expect(d.path, 'lib/errors.dart');
        expect(d.line, greaterThan(0));
        expect(d.toString(), startsWith('lib/errors.dart:${d.line}: '));
      }
      expect(scan.functions.where((f) => f.spec.id.contains('errors.dart')), isEmpty);
      expect(scan.diagnostics, hasLength(5), reason: '${scan.diagnostics}');
    });

    test('functions are sorted by id, so the output is byte-stable', () {
      final ids = [for (final f in scan.functions) f.spec.id];
      expect(ids, [...ids]..sort());
      expect(ids, hasLength(7));
    });

    test('a lib/ without annotations scans empty without starting the analyzer', () async {
      final empty = Directory.systemTemp.createTempSync('lumina_bp07_empty_');
      addTearDown(() => empty.deleteSync(recursive: true));
      File('${empty.path}/lib/main.dart')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('void main() {}\n');
      final watch = Stopwatch()..start();
      final result = await const BlueprintFunctionScanner().scan(Directory('${empty.path}/lib'));
      expect(result.functions, isEmpty);
      expect(result.diagnostics, isEmpty);
      expect(watch.elapsedMilliseconds, lessThan(1000));
    });

    test('annotated sources without a package config are one clear error', () async {
      final bare = Directory.systemTemp.createTempSync('lumina_bp07_bare_');
      addTearDown(() => bare.deleteSync(recursive: true));
      File('${bare.path}/lib/health.dart')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(File('$blueprintFunctionFixtureLib/health.dart').readAsStringSync());
      final result = await const BlueprintFunctionScanner().scan(Directory('${bare.path}/lib'));
      expect(result.functions, isEmpty);
      expect(result.diagnostics.single.message, contains('flutter pub get'));
    });
  });

  group('generated registration and manifest', () {
    test('the registration is byte-identical to its golden, and a rescan changes nothing', () async {
      final code = const BlueprintFunctionScanner().generateRegistration(scan, libraryName: 'fixture');
      final golden = File(blueprintFunctionRegistrationGolden);
      if (update) golden.writeAsStringSync(code);
      expect(golden.existsSync(), isTrue, reason: 'run with UPDATE_GOLDENS=1 to create it');
      expect(code, golden.readAsStringSync(), reason: 'the generator changed; review and update the golden');
      expect(code, contains("import '../health.dart' as fn_fixture_health;"));
      expect(code, contains('void registerProjectBlueprintFunctions() {'));
      expect(code, isNot(contains('errors.dart')), reason: 'no library without a valid function');
      final again = await const BlueprintFunctionScanner().scan(Directory('${project.path}/lib'));
      expect(const BlueprintFunctionScanner().generateRegistration(again, libraryName: 'fixture'), code);
    });

    test('a warm scanner sees an edited file on the next scan, within the editor budget of 2 s', () async {
      final warmProject = createBlueprintFunctionFixtureProject();
      final lib = Directory('${warmProject.path}/lib');
      const scanner = BlueprintFunctionScanner(keepWarm: true);
      addTearDown(() async {
        await BlueprintFunctionScanner.release(lib);
        warmProject.deleteSync(recursive: true);
      });
      final first = await scanner.scan(lib);
      final before = first.functions.length;
      final health = File('${lib.path}/health.dart');
      health.writeAsStringSync('''${health.readAsStringSync()}

/// Heals [self] by [amount].
@BlueprintCallable(category: 'Health')
void healWarm(LuminaActor self, double amount) {}
''');
      // A later mtime than the first scan saw.
      health.setLastModifiedSync(DateTime.now().add(const Duration(seconds: 2)));
      final watch = Stopwatch()..start();
      final second = await scanner.scan(lib);
      watch.stop();
      expect(second.functions.length, before + 1);
      expect(second.functions.map((f) => f.spec.title), contains(contains('Heal Warm')));
      expect(watch.elapsed, lessThan(const Duration(seconds: 2)), reason: 'warm rescan took ${watch.elapsed}');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('the registration and the fixture analyze clean', () async {
      final r = await Process.run('dart', ['analyze', '--fatal-infos', '../lumina/test/blueprint/fixtures/project_functions', '../lumina/test/blueprint/generated/bp_project_functions.g.dart'], runInShell: Platform.isWindows);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('writeProjectOutputs writes lib/blueprint/ and project.blueprint_functions.json next to the .lmproject', () {
      const BlueprintFunctionScanner().writeProjectOutputs(project, scan, libraryName: 'fixture');
      final registration = File('${project.path}/lib/blueprint/blueprint_functions.g.dart');
      expect(registration.readAsStringSync(), File(blueprintFunctionRegistrationGolden).readAsStringSync());
      final json = File('${project.path}/${BlueprintFunctionManifest.fileName}');
      expect(json.existsSync(), isTrue);
      expect(File('${project.path}/fixture.lmproject').existsSync(), isTrue, reason: 'next to the manifest');

      final manifest = BlueprintFunctionManifest.read(project)!;
      expect([for (final f in manifest.functions) f.spec.id], [for (final f in scan.functions) f.spec.id]);
      for (final f in scan.functions) {
        final m = manifest.functions.firstWhere((x) => x.spec.id == f.spec.id);
        expect(m.spec.title, f.spec.title);
        expect(m.spec.category, f.spec.category);
        expect(m.spec.kind, f.spec.kind);
        expect(m.spec.tooltip, f.spec.tooltip);
        expect(m.spec.keywords, f.spec.keywords);
        expect(m.spec.headerColor, f.spec.headerColor);
        expect(pins(m.spec.inputs), pins(f.spec.inputs));
        expect(pins(m.spec.outputs), pins(f.spec.outputs));
        expect([for (final p in m.spec.inputs) p.required], [for (final p in f.spec.inputs) p.required]);
        expect(m.call.method, f.call.method);
        expect(m.call.library, f.call.library);
        expect(m.call.args, f.call.args);
        expect(m.call.named, f.call.named);
        expect(m.call.optional, f.call.optional);
        expect(m.call.self, f.call.self);
        expect(m.call.outputs, f.call.outputs);
        expect(m.call.returnsRecord, f.call.returnsRecord);
        expect(m.path, f.path);
        expect(m.line, f.line);
      }
      expect([for (final d in manifest.diagnostics) '$d'], [for (final d in scan.diagnostics) '$d']);
      // Byte-stable too.
      final before = json.readAsStringSync();
      const BlueprintFunctionScanner().writeProjectOutputs(project, scan, libraryName: 'fixture');
      expect(json.readAsStringSync(), before);
      expect(jsonDecode(before), isA<Map<String, dynamic>>());
    });

    test("main.dart registers the project's functions before the world starts", () {
      final generator = DartCodeGeneratorService();
      final code = generator.generateMainDart(projectName: 'fixture', blueprintFunctions: true);
      expect(code, contains("import 'blueprint/blueprint_functions.g.dart';"));
      final register = code.indexOf('registerProjectBlueprintFunctions();');
      expect(register, greaterThan(0));
      expect(register, lessThan(code.indexOf('runApp(')));
      final plain = generator.generateMainDart(projectName: 'fixture');
      expect(plain, isNot(contains('blueprint_functions.g.dart')));
      expect(plain, isNot(contains('registerProjectBlueprintFunctions')));
    });
  });

  group('registry', () {
    LuminaBlueprintNodeSpec spec(String id) => LuminaBlueprintNodeSpec(
          id: id,
          title: 'Custom',
          category: 'Project',
          kind: LuminaBlueprintNodeKind.pure,
          headerColor: 0xFF2E7D32,
          outputs: const [LuminaBlueprintPinSpec('return_value', 'Return Value', LuminaPinType.float)],
        );
    Map<String, Object?> one(LuminaBlueprintCallContext c, Map<String, Object?> i) => {'return_value': 1.0};

    test('an id colliding with a built-in, or registered twice, throws', () {
      expect(() => LuminaBlueprintFunctionRegistry.register(spec('print_string'), one), throwsStateError);
      expect(() => LuminaBlueprintFunctionRegistry.declare(spec('float_add')), throwsStateError);
      LuminaBlueprintFunctionRegistry.register(spec('fn:package:p/a.dart#one'), one);
      expect(() => LuminaBlueprintFunctionRegistry.register(spec('fn:package:p/a.dart#one'), one), throwsStateError);
      expect(() => LuminaBlueprintFunctionRegistry.declare(spec('fn:package:p/a.dart#one')), throwsStateError);
      LuminaBlueprintFunctionRegistry.declare(spec('fn:package:p/a.dart#two'));
      expect(() => LuminaBlueprintFunctionRegistry.register(spec('fn:package:p/a.dart#two'), one), throwsStateError);
      expect(
          () => LuminaBlueprintFunctionRegistry.register(
              const LuminaBlueprintNodeSpec(
                  id: 'fn:package:p/a.dart#event', title: 'E', category: 'P', kind: LuminaBlueprintNodeKind.event, headerColor: 0),
              one),
          throwsArgumentError);
    });

    test('the node library and the function library consult the registry after the built-ins', () {
      final builtIns = LuminaBlueprintNodeLibrary.all.length;
      expect(LuminaBlueprintNodeLibrary.spec('fn:package:p/a.dart#one'), isNull);
      LuminaBlueprintFunctionRegistry.register(spec('fn:package:p/a.dart#one'), one);
      expect(LuminaBlueprintNodeLibrary.all, hasLength(builtIns + 1));
      expect(LuminaBlueprintNodeLibrary.all.last.id, 'fn:package:p/a.dart#one');
      expect(LuminaBlueprintNodeLibrary.all.first.id, 'event_beginplay');
      expect(LuminaBlueprintNodeLibrary.spec('fn:package:p/a.dart#one')!.title, 'Custom');
      expect(LuminaBlueprintFunctionLibrary.functions.containsKey('fn:package:p/a.dart#one'), isTrue);
      expect(LuminaBlueprintFunctionLibrary.functions.keys.last, 'fn:package:p/a.dart#one');
      expect(LuminaBlueprintFunctionLibrary.functions['float_add'], isNotNull);
      final node = LuminaBlueprintNodeLibrary.place('fn:package:p/a.dart#one', nodeId: 'n');
      expect(node.title, 'Custom');
      expect(node.outputs.single.id, 'return_value');
      LuminaBlueprintFunctionRegistry.declare(spec('fn:package:p/a.dart#two'));
      expect(LuminaBlueprintFunctionLibrary.functions.containsKey('fn:package:p/a.dart#two'), isFalse,
          reason: 'declared only: nothing to call');
      expect(LuminaBlueprintNodeLibrary.spec('fn:package:p/a.dart#two'), isNotNull);
      LuminaBlueprintFunctionRegistry.clearDeclared();
      expect(LuminaBlueprintNodeLibrary.spec('fn:package:p/a.dart#two'), isNull);
      expect(LuminaBlueprintNodeLibrary.spec('fn:package:p/a.dart#one'), isNotNull);
      LuminaBlueprintFunctionRegistry.clear();
      expect(LuminaBlueprintNodeLibrary.all, hasLength(builtIns));
      expect(LuminaBlueprintFunctionLibrary.functions.containsKey('fn:package:p/a.dart#one'), isFalse);
    });

    test('the editor declares the manifest: the validator warns, the VM skips the node and plays the rest', () {
      final manifest = BlueprintFunctionManifest.fromJson(scan.manifest.toJson());
      manifest.declareAll();
      final cls = LuminaBlueprintClass.fromDocument(projectFunctionsBlueprint(), name: 'BP_ProjectFunctions');
      expect(cls.hasErrors, isFalse, reason: '${cls.diagnostics}');
      final warnings = cls.diagnostics.where((d) => d.message.contains('requires Play Standalone')).toList();
      expect(warnings.map((d) => d.nodeId).toSet(), {'damage', 'count', 'twice', 'ring'});
      expect(warnings.firstWhere((d) => d.nodeId == 'damage').message, startsWith('Apply Damage '));
      final actor = cls.instantiate() as LuminaBlueprintActor;
      final trace = <LuminaBlueprintTraceEvent>[];
      actor.trace = trace.add;
      final world = LuminaWorld(worldType: LuminaWorldType.game);
      world.persistentLevel.registerActor(actor);
      world.beginPlay();
      expect(trace.map((t) => t.nodeId), containsAllInOrder(['damage', 'count', 'set_calls', 'move', 'print']));
      expect(trace.last.printed, 'damaged', reason: 'the rest of the graph ran');
      expect(actor.variables['Calls'], 0, reason: 'the skipped nodes give their zero values');
    });

    test('the code generator calls a project function directly, never through the registry', () {
      BlueprintFunctionManifest.fromJson(scan.manifest.toJson()).declareAll();
      final result = const BlueprintDartGenerator().generate(
        projectFunctionsBlueprint(),
        className: 'BpProjectFunctions',
        assetPath: 'contents/blueprints/BP_ProjectFunctions.lmas',
        functionImports: const {
          'package:fixture/health.dart': '../fixtures/project_functions/health.dart',
          'package:fixture/markers.dart': '../fixtures/project_functions/markers.dart',
          'package:fixture/types.dart': '../fixtures/project_functions/types.dart',
        },
      );
      expect(result.errors, isEmpty, reason: '${result.issues}');
      final code = result.code!;
      expect(code, contains("import '../fixtures/project_functions/health.dart' as fn_fixture_health;"));
      expect(code, contains('fn_fixture_health.applyDamage(this, 25.0);'));
      expect(code, contains('fn_fixture_types.countCalls(this, 2);'));
      expect(code, contains('fn_fixture_types.FixtureMath.twice('));
      expect(code, contains('fn_fixture_markers.markerRing(1)'), reason: 'defaults left to Dart');
      expect(code, isNot(contains('LuminaBlueprintFunctionRegistry')));
      final golden = File('../lumina/test/blueprint/generated/bp_project_functions.g.dart');
      if (update) golden.writeAsStringSync(code);
      expect(code, golden.readAsStringSync(), reason: 'the generator changed; review and update the golden');
    });
  });
}
