import 'dart:convert';
import 'dart:io';

import 'package:lumina_core/lumina_core.dart';
import 'package:test/test.dart';

/// Project Settings ▸ Neural rendering in the `.lmproject`: the OpenDLSS-NR
/// opt-in, its acknowledgement, the weights path and the controls.
void main() {
  test('a manifest without neural_rendering reads off and is written unchanged', () {
    final project = LuminaProject.fromMap({'project_name': 'Demo'});
    expect(project.neuralRendering, const ProjectNeuralRenderingSettings());
    expect(project.neuralRendering.active, isFalse);
    expect(project.toMap().containsKey('neural_rendering'), isFalse);
  });

  test('enabled without the acknowledgement is not active', () {
    const s = ProjectNeuralRenderingSettings(enabled: true);
    expect(s.active, isFalse);
    expect(s.copyWith(acknowledgedAt: '2026-10-10T09:00:00.000Z').active, isTrue);
  });

  test('every field survives a real .lmproject round trip', () async {
    final dir = await Directory.systemTemp.createTemp('neural_rendering_settings');
    try {
      const settings = ProjectNeuralRenderingSettings(
        enabled: true,
        acknowledgedAt: '2026-10-10T09:00:00.000Z',
        weightsPath: 'D:/models/nr/manifest.json',
        intensity: 0.6,
        localTone: 0.4,
        localStructure: 0.7,
        autoMask: false,
        style: ProjectNeuralRenderingSettings.styleCinematic,
        paperWhite: 1.5,
        colorStrength: 0.25,
      );
      final project = const LuminaProject(projectName: 'Demo').copyWith(neuralRendering: settings);
      final file = File('${dir.path}/Demo.lmproject');
      await file.writeAsString(jsonEncode(project.toMap()));
      final read = LuminaProject.fromMap(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
      expect(read.neuralRendering, settings);
      expect(read.neuralRendering.weightsDirectory, 'D:/models/nr');
      expect(read.extraFields.containsKey('neural_rendering'), isFalse);
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('out-of-range and mistyped values fall back or clamp', () {
    final s = ProjectNeuralRenderingSettings.fromMap({
      'enabled': true,
      'acknowledged_at': 7,
      'intensity': 3.0,
      'paper_white': 'bright',
      'style': 'dlss',
      'color_strength': -1,
    });
    expect(s.acknowledgedAt, '');
    expect(s.intensity, 1.0);
    expect(s.paperWhite, 1.0);
    expect(s.style, ProjectNeuralRenderingSettings.styleNone);
    expect(s.colorStrength, 0.0);
  });

  test('a folder path stays a folder; a manifest path names its folder', () {
    expect(ProjectNeuralRenderingSettings.weightsDirectoryOf(r'C:\nr\manifest.json'), r'C:\nr');
    expect(ProjectNeuralRenderingSettings.weightsDirectoryOf('/data/nr'), '/data/nr');
    expect(ProjectNeuralRenderingSettings.weightsDirectoryOf('  '), '');
  });
}
