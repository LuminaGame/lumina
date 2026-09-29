import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:lumina_ui/ui/core/services/editor_scene_environment.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/details_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  late Directory tempDir;
  setUp(() => tempDir = Directory.systemTemp.createTempSync('lumina_details_sky_'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  EditorViewModel vm() => EditorViewModel(
        initialProject: const LuminaProject(projectName: 'SkyDetails'),
        projectLocation: tempDir.path,
        enableTimers: false,
        autoInitAssets: false,
      );

  Future<void> pumpDetails(WidgetTester tester, EditorViewModel model) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ShadcnApp(
        theme: luminaEditorTheme(),
        home: Scaffold(child: DetailsWidget(viewModel: model)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a placed Environment actor has LuminaSkyComponent and shows Sky & Lighting in Details', (tester) async {
    final model = vm();
    addTearDown(model.dispose);
    model.spawnNewActor('Environment');
    final envActor = model.actors.single;
    expect(envActor.components.any((c) => c.type == EditorSceneEnvironment.skyComponentType), isTrue);

    model.selectActorById(envActor.id);
    await pumpDetails(tester, model);

    for (final label in ['Sky Background', 'Mode', 'Sky Intensity', 'Image-Based Lighting', 'Ambient (IBL) Intensity']) {
      expect(find.text(label, skipOffstage: false), findsWidgets, reason: '$label is in the Details panel');
    }

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a legacy Environment actor with empty components gets seeded with LuminaSkyComponent', (tester) async {
    final model = vm();
    addTearDown(model.dispose);

    // Legacy actor with components: []
    final legacyMap = {
      'id': 'act_env_legacy',
      'name': 'Sky&Atmosphere_1',
      'type': 'Environment',
      'location': [0.0, 0.0, 0.0],
      'rotation': [0.0, 0.0, 0.0],
      'scale': [1.0, 1.0, 1.0],
      'isVisible': true,
      'components': <dynamic>[],
    };

    final node = EditorActorNode.fromMap(legacyMap);
    // fromMap seeds LuminaSkyComponent automatically
    expect(node.components.any((c) => c.type == EditorSceneEnvironment.skyComponentType), isTrue);

    final skyComp = node.components.firstWhere((c) => c.type == EditorSceneEnvironment.skyComponentType);
    expect(skyComp.properties['skyIntensity'], 30000.0);
    expect(skyComp.properties['iblIntensity'], 30000.0);
  });

  test('saveLevelAndGenerateCode saves LuminaSkyComponent into .lmas and emits it in generated level Dart', () async {
    final model = vm();
    addTearDown(model.dispose);

    model.spawnNewActor('Environment');
    await model.saveLevelAndGenerateCode();

    final levelDartFile = File('${model.projectDirPath}/lib/levels/l_default_level.dart');
    expect(levelDartFile.existsSync(), isTrue);
    final dartCode = levelDartFile.readAsStringSync();
    expect(dartCode.contains('LuminaSkyComponent.color'), isTrue, reason: 'Generated code emits LuminaSkyComponent.color');

    final lmasFile = File('${model.projectDirPath}/contents/levels/L_DefaultLevel.lmas');
    expect(lmasFile.existsSync(), isTrue);
    final lmasContent = lmasFile.readAsStringSync();
    expect(lmasContent.contains('LuminaSkyComponent'), isTrue, reason: '.lmas contains LuminaSkyComponent');
  });
}
