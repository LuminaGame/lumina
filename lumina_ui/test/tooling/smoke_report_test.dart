// Lumina Studio's configuration of the shared smoke report
// (tool/smoke_report.dart). The runner and the report are tested in
// lumina_smoke.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_smoke/report.dart';

import '../../tool/smoke_report.dart';

void main() {
  test('tests are grouped by feature area from their file names, then their names', () {
    String cat(String suite, [String name = 'x']) => studioSmokeConfig.categoryOf(suite, name);
    expect(cat('test/ui/material_editor_test.dart'), 'Material & Texture');
    expect(cat('integration_test/smoke/static_mesh_editor_smoke_test.dart'), 'Mesh & Physics');
    expect(cat('test/ui/viewport_picker_test.dart'), 'Editor UI');
    expect(cat('test/ui/launcher_graphics_device_test.dart'), 'Launcher & Project');
    expect(cat('integration_test/smoke/blueprint_editor_smoke_test.dart'), 'Blueprint');
    expect(cat(r'D:\w\lumina_ui\integration_test\smoke\blueprint_editor_smoke_test.dart'), 'Blueprint',
        reason: 'Windows suite paths');
    expect(cat('test/other/unrelated_test.dart'), 'Other');
    expect(cat('test/other/unrelated_test.dart', 'pie_session restores'), 'Play In Editor');
    expect(studioSmokeConfig.categoryOrder('Material & Texture'), lessThan(studioSmokeConfig.categoryOrder('Editor UI')));
  });

  test('the index, pages and the page of unmatched artifacts carry the Studio title', () {
    final dir = Directory.systemTemp.createTempSync('studio_smoke_report_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/lone.json').writeAsStringSync(jsonEncode({'test': 'nobody runs this', 'file': 'lone.png'}));
    File('${dir.path}/lone.png').writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    final generator = SmokeReportGenerator(studioSmokeConfig);
    final model = generator.processEvents([
      {'type': 'suite', 'suite': {'id': 0, 'path': 'test/ui/material_editor_test.dart'}, 'time': 1},
      {'type': 'testStart', 'test': {'id': 1, 'name': 'compiles', 'suiteID': 0}, 'time': 2},
      {'type': 'testDone', 'testID': 1, 'result': 'failure', 'time': 3},
      {'type': 'suite', 'suite': {'id': 1, 'path': 'test/ui/gizmo_test.dart'}, 'time': 4},
      {'type': 'testStart', 'test': {'id': 2, 'name': 'drags', 'suiteID': 1}, 'time': 5},
      {'type': 'testDone', 'testID': 2, 'result': 'success', 'time': 6},
    ], artifactsDir: dir);
    expect(model.categories, ['Material & Texture', 'Editor UI', 'Artifacts without a matching test']);
    final pages = generator.renderPages(model, reportDir: dir.path);
    expect(pages.keys, [
      'smoke_report.html',
      'smoke_report/material_texture.html',
      'smoke_report/editor_ui.html',
      'smoke_report/artifacts_without_a_matching_test.html',
    ]);
    expect(pages['smoke_report.html'], contains('<h1>Lumina Studio Smoke & Test Report'));
    expect(pages['smoke_report.html'], contains('Studio UI'));
    expect(pages['smoke_report/artifacts_without_a_matching_test.html'], contains('nobody runs this'));
    expect(RegExp(r'https?://', caseSensitive: false).hasMatch(pages.values.join()), isFalse);
  });

  test('the smokes run test/smoke, then each integration smoke on the desktop device, with the pointer uncaptured', () {
    final phases = planSmokeRuns(smokeRunMode(const []), studioSmokeConfig);
    expect(phases.first.kind, SmokePhaseKind.smoke);
    expect(phases.first.targets, ['test/smoke']);
    expect(phases.skip(1).every((p) => p.kind == SmokePhaseKind.integration && p.targets.single.startsWith('integration_test/smoke/')),
        isTrue);
    expect(phases.length, greaterThan(1));
    expect(smokeRunEnvironment(studioSmokeConfig, artifactsDir: 'a')['LUMINA_MOUSE_CAPTURE'], 'off');
  });
}
