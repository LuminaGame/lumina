import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/animation_editor_view_model.dart';

/// A Third Person project's clip assets carry no GLB of their
/// own; they reference the mannequin that holds all nine clips. The animation
/// editor must open them on that mesh.
///
/// The project is scaffolded for real by [ProjectRepository]; only the two
/// external commands are replaced by their filesystem effects (no network
/// `pub get`, no full `flutter create`).
void main() {
  late Directory root;
  late Directory configDir;
  late String projectDir;

  Future<ProcessResult> runner(String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
    if (args.isNotEmpty && args.first == 'create') {
      final target = args.last;
      final name = args[args.indexOf('--project-name') + 1];
      Directory('$target/lib').createSync(recursive: true);
      File('$target/pubspec.yaml').writeAsStringSync(
        'name: $name\nenvironment:\n  sdk: ^3.12.0\ndependencies:\n  flutter:\n    sdk: flutter\nflutter:\n  uses-material-design: true\n',
      );
      File('$target/lib/main.dart').writeAsStringSync('void main() {}\n');
    }
    return ProcessResult(0, 0, '', '');
  }

  setUpAll(() async {
    root = Directory.systemTemp.createTempSync('lumina_anim_ref_');
    configDir = Directory.systemTemp.createTempSync('lumina_anim_ref_cfg_');
    await ProjectRepository(configDir: configDir, processRunner: runner)
        .createProject(projectName: 'anim_ref_game', projectLocation: root.path, template: kThirdPersonTemplateId);
    projectDir = '${root.path}/anim_ref_game';
  });

  tearDownAll(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
    if (configDir.existsSync()) configDir.deleteSync(recursive: true);
  });

  test('a clip asset that references the mannequin opens on it, with its own clip selected', () async {
    const clip = 'Walk_Right_Loop';
    final vm = AnimationEditorViewModel(
      assetPath: '$projectDir/${LuminaThirdPersonContent.projectAnimationDir}/$clip.lmas',
    );
    addTearDown(vm.dispose);
    await vm.load();

    expect(vm.hasError, isFalse);
    expect(vm.clips.map((c) => c.name).toList(), LuminaThirdPersonContent.clipNames);
    expect(vm.clips[vm.selectedClip].name, clip);
    expect(vm.previewMeshPath, LuminaThirdPersonContent.projectMeshAssetPath);
    expect(vm.glbMesh, isNotNull, reason: 'the mannequin must be loaded as the preview');
    expect(vm.glbMesh!.triangleCount, greaterThan(1000));
    expect(vm.glbMesh!.animations.map((a) => a.name), contains(clip));
  });

  test('the idle clip asset selects the idle', () async {
    final vm = AnimationEditorViewModel(
      assetPath: '$projectDir/${LuminaThirdPersonContent.projectAnimationDir}/${LuminaThirdPersonContent.idleClip}.lmas',
    );
    addTearDown(vm.dispose);
    await vm.load();
    expect(vm.clips[vm.selectedClip].name, LuminaThirdPersonContent.idleClip);
  });
}
