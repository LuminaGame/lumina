import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';

void main() {
  late Directory tempConfigDir;

  setUp(() {
    tempConfigDir = Directory.systemTemp.createTempSync('lumina_launcher_test_config_');
  });

  tearDown(() {
    if (tempConfigDir.existsSync()) {
      tempConfigDir.deleteSync(recursive: true);
    }
  });

  group('LauncherViewModel Tests', () {
    test('Should initialize with default project form values under user home Lumina Projects folder', () {
      final viewModel = LauncherViewModel(configDir: tempConfigDir);
      expect(viewModel.projectName, equals('MyFirstLuminaGame'));
      expect(viewModel.projectPath, equals(LauncherViewModel.defaultProjectsDir));
    });

    test('Should update project name and path', () {
      final viewModel = LauncherViewModel(configDir: tempConfigDir);
      viewModel.updateProjectName('MyAwesomeGame');
      viewModel.updateProjectPath('/home/user/games');

      expect(viewModel.projectName, equals('MyAwesomeGame'));
      expect(viewModel.projectPath, equals('/home/user/games'));
    });
  });
}
