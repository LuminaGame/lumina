import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';

/// The build runs on the editor's UI isolate: its heavy work (copying a
/// packaged bundle of hundreds of megabytes, compiling materials with matc,
/// reading every asset) must not hold that isolate, or the editor stops
/// drawing ("Not Responding") until it is done. A timer on this isolate
/// measures the longest stall while a step runs.
void main() {
  late Directory tempDir;
  late Directory projDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lumina_build_responsive_');
    LuminaDataDir.override = Directory('${tempDir.path}/lumina_data');
    projDir = Directory('${tempDir.path}/resp_game')..createSync(recursive: true);
    Directory('${projDir.path}/contents/materials').createSync(recursive: true);
    const project = LuminaProject(projectName: 'resp_game', activeLevel: 'contents/levels/L_Main.lmas');
    File('${projDir.path}/resp_game.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
  });

  tearDown(() {
    LuminaDataDir.override = null;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  LuminaProject loadProject() => LuminaProject.fromMap(
      jsonDecode(File('${projDir.path}/resp_game.lmproject').readAsStringSync()) as Map<String, dynamic>);

  /// Runs [plan] while a 10 ms timer ticks on this isolate; the longest gap
  /// between ticks, and the events.
  Future<(Duration, List<BuildEvent>)> runMeasured(BuildPlan plan) async {
    var last = DateTime.now();
    var longest = Duration.zero;
    final timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      final now = DateTime.now();
      final gap = now.difference(last);
      if (gap > longest) longest = gap;
      last = now;
    });
    final events = await BuildPipelineService().run(plan, projectDir: projDir.path, project: loadProject()).toList();
    timer.cancel();
    return (longest, events);
  }

  test('copying a large packaged bundle does not stall the UI isolate', () async {
    // A stand-in for `flutter build linux` that leaves a bundle of 3000 files
    // (192 MB): a game's flutter_assets hold every cooked asset.
    final script = File('${tempDir.path}/big_build.dart')
      ..writeAsStringSync(r'''
import 'dart:io';
import 'dart:typed_data';
void main() {
  final bundle = Directory('build/linux/x64/release/bundle/data')..createSync(recursive: true);
  final chunk = Uint8List(64 * 1024);
  for (var i = 0; i < 3000; i++) {
    File('${bundle.path}/blob_$i.bin').writeAsBytesSync(chunk);
  }
  File('build/linux/x64/release/bundle/resp_game').writeAsStringSync('exe');
  stdout.writeln('Built build/linux/x64/release/bundle/resp_game');
}
''');
    final step = PackageTargetsStep(
      targets: const ['linux'],
      reasonsFor: (_) => const [],
      packageDirFor: (t) => '${projDir.path}/build/package/$t',
      processStarter: (exe, args, {workingDirectory}) =>
          Process.start(Platform.resolvedExecutable.contains('flutter_tester') ? 'dart' : Platform.resolvedExecutable,
              [script.path],
              workingDirectory: workingDirectory, runInShell: Platform.isWindows),
      codeGenerator: (ctx) async => const CookCodeGenOutcome(true, 'no code to generate for this stand-in'),
    );
    final (longest, events) = await runMeasured(BuildPlan(steps: [step]));
    final logs = events.whereType<BuildLogEvent>().map((e) => e.message).join('\n');
    expect(events.whereType<BuildStepFinished>().single.status, BuildStepStatus.ok, reason: logs);
    expect(File('${projDir.path}/build/package/linux/data/blob_2999.bin').lengthSync(), 64 * 1024);
    expect(longest, lessThan(const Duration(milliseconds: 300)), reason: 'longest stall $longest');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('compiling materials from source does not stall the UI isolate', () async {
    for (final n in ['M_A', 'M_B', 'M_C', 'M_D']) {
      File('${projDir.path}/contents/materials/$n.lmas').writeAsBytesSync(LuminaAsset(
        assetId: n,
        name: n,
        type: AssetType.filamat,
        rawMatSource: 'material { name : "$n", shadingModel : lit }\n'
            'fragment { void material(inout MaterialInputs material) { prepareMaterial(material); '
            'material.baseColor = float4(0.5, 0.2, 0.1, 1.0); } }\n',
      ).toProtoBufferBytes());
    }
    final compiler = FilamentMaterialCompiler();
    addTearDown(compiler.dispose);
    // Compiled from source with matc, checked without the engine (the
    // engine's own material load is not what this measures).
    final step = MaterialPrecompileStep(compiler: (input) async {
      final result = await compiler.buildPackageFromSource(input.name, input.source);
      return result.ok ? const MaterialCompileOutcome.ok() : MaterialCompileOutcome.failed(result.errorText);
    });
    final (longest, events) = await runMeasured(BuildPlan(steps: [step]));
    final logs = events.whereType<BuildLogEvent>().map((e) => e.message).join('\n');
    expect(events.whereType<BuildStepFinished>().single.status, BuildStepStatus.ok, reason: logs);
    expect(longest, lessThan(const Duration(milliseconds: 300)), reason: 'longest stall $longest');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
