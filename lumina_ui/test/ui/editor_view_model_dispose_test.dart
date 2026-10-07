import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// On Windows the project folder stayed in use after `dispose()`
/// (a git probe of source control still ran with it as its working
/// directory), so deleting the project right away failed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('after await vm.close() the temp project deletes at once', () async {
    for (var i = 0; i < 3; i++) {
      final root = Directory.systemTemp.createTempSync('lumina_vm_close_');
      final vm = EditorViewModel(
        initialProject: const LuminaProject(projectName: 'CloseGame', activeLevel: 'contents/levels/L_Main.lmas'),
        projectLocation: root.path,
        enableTimers: false,
        autoInitAssets: false,
      );
      await vm.ensureDefaultLevelAssets();
      await vm.close();
      expect(() => root.deleteSync(recursive: true), returnsNormally, reason: 'run ${i + 1}: nothing holds the project folder');
      expect(root.existsSync(), isFalse);
    }
  });
}
