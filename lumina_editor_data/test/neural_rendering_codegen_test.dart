import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:test/test.dart';

/// A generated game runs OpenDLSS-NR only when its project opted in, and never
/// carries the editor's machine-local weights path.
void main() {
  final generator = DartCodeGeneratorService();

  test('an opted-in project sets the opt-in with its controls and no weights path', () {
    const settings = ProjectNeuralRenderingSettings(
      enabled: true,
      acknowledgedAt: '2026-10-10T09:00:00.000Z',
      weightsPath: 'C:/Users/someone/weights/manifest.json',
      intensity: 0.5,
      style: ProjectNeuralRenderingSettings.styleNatural,
    );
    final code = generator.generateMainDart(projectName: 'nr_game', neuralRendering: settings);
    expect(code, contains('LuminaNeuralRendering.projectOptIn = const ProjectNeuralRenderingSettings('));
    expect(code, contains('intensity: 0.500'));
    expect(code, contains("style: 'natural'"));
    expect(code, isNot(contains('someone')));
    expect(code, isNot(contains('weightsPath')));
    // set before the game widget asks for the device features
    expect(code.indexOf('projectOptIn'), lessThan(code.indexOf('runApp(')));
  });

  test('a project that did not opt in (or did not accept the warning) has no reference', () {
    for (final settings in [
      null,
      const ProjectNeuralRenderingSettings(),
      const ProjectNeuralRenderingSettings(enabled: true),
    ]) {
      final code = generator.generateMainDart(projectName: 'nr_game', neuralRendering: settings);
      expect(code, isNot(contains('LuminaNeuralRendering')));
    }
  });
}
