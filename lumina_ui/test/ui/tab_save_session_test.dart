import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_core/lumina_core.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

class _FakeSubEditorVm extends ChangeNotifier {
  bool dirty = true;
  int saveCalls = 0;
  bool saveResult = true;

  Future<bool> save() async {
    saveCalls++;
    if (saveResult) {
      dirty = false;
      notifyListeners();
    }
    return saveResult;
  }
}

void main() {
  late EditorViewModel vm;

  setUp(() {
    vm = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'TabSession'),
      projectLocation: '/tmp',
      enableTimers: false,
      autoInitAssets: false,
    );
  });

  tearDown(() => vm.dispose());

  test('the level tab is named after the level that is open, not a literal', () {
    // It used to read 'L_OpenWorld_Main' whatever the project held, so the
    // breadcrumb named a level that did not exist.
    final levelVm = EditorViewModel(
      initialProject: const LuminaProject(
        projectName: 'TabSession',
        activeLevel: 'contents/levels/L_Arena.lmas',
      ),
      projectLocation: '/tmp',
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(levelVm.dispose);

    expect(levelVm.openTabs.first.title, 'L_Arena');
    expect(levelVm.currentTab.title, 'L_Arena');
    expect(levelVm.openTabs.first.title, levelVm.activeLevelName);
    expect(levelVm.openTabs.map((t) => t.title), isNot(contains('L_OpenWorld_Main')));
  });

  test('bound sub-editor session drives isTabDirty and saveTab', () async {
    vm.openSubEditorTab('Material', title: 'M_Test');
    final index = vm.openTabs.length - 1;
    final tabId = vm.openTabs[index].id;

    // Without a session the tab falls back to its own flag (clean).
    expect(vm.isTabDirty(index), isFalse);
    expect(await vm.saveTab(index), isFalse, reason: 'no handler bound');

    final fake = _FakeSubEditorVm();
    vm.bindTabSession(tabId, notifier: fake, save: fake.save, isDirty: () => fake.dirty);
    expect(vm.hasTabSession(tabId), isTrue);
    expect(vm.isTabDirty(index), isTrue);

    var notified = 0;
    vm.addListener(() => notified++);
    fake.notifyListeners();
    await Future<void>.delayed(Duration.zero); // propagation is deferred to a microtask
    expect(notified, greaterThan(0), reason: 'sub-editor changes propagate to the shell');

    expect(await vm.saveTab(index), isTrue);
    expect(fake.saveCalls, equals(1));
    expect(vm.isTabDirty(index), isFalse);

    vm.closeTab(index);
    expect(vm.hasTabSession(tabId), isFalse);
  });

  test('failed save keeps the tab dirty', () async {
    vm.openSubEditorTab('Texture', title: 'T_Test');
    final index = vm.openTabs.length - 1;
    final fake = _FakeSubEditorVm()..saveResult = false;
    vm.bindTabSession(vm.openTabs[index].id, notifier: fake, save: fake.save, isDirty: () => fake.dirty);

    expect(await vm.saveTab(index), isFalse);
    expect(vm.isTabDirty(index), isTrue);
  });
}
