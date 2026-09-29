import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

/// Solo / Clear Solo recorded undo entries whose undo and redo did
/// nothing: Edit → Undo left the other actors hidden and stepped past the
/// entry. No mocks: a real temp project and real actors.
void main() {
  late Directory tempDir;
  late EditorViewModel vm;
  const project = LuminaProject(projectName: 'SoloGame', activeLevel: 'contents/levels/L_Main.lmas');

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('lumina_solo_undo_');
    final projDir = Directory('${tempDir.path}/SoloGame')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    File('${projDir.path}/SoloGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    vm = EditorViewModel(initialProject: project, projectLocation: tempDir.path, enableTimers: false);
    await vm.ensureDefaultLevelAssets();
  });

  tearDown(() {
    vm.dispose();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Map<String, bool> visibility() => {for (final a in vm.actors) a.id: a.isVisible};

  test('Undo of Solo restores every actor\'s visibility, hidden ones included; Redo solos again', () {
    for (var i = 0; i < 5; i++) {
      vm.spawnNewActor('Primitive');
    }
    final crates = vm.actors.where((a) => a.type == 'Primitive').toList();
    crates[0].isVisible = false;
    crates[1].isVisible = false;
    final initial = visibility();

    vm.toggleSoloWithTransaction(crates[2].id);
    final soloed = visibility();
    expect(soloed[crates[2].id], isTrue);
    expect(soloed.entries.where((e) => e.key != crates[2].id).every((e) => !e.value), isTrue);
    expect(vm.transactions.undoLabel, 'Undo Solo Actor');

    vm.transactions.undo();
    expect(visibility(), initial, reason: 'the two hidden crates stay hidden, the rest come back');

    vm.transactions.redo();
    expect(visibility(), soloed);
  });

  test('Undo of Clear Solo re-solos; Redo clears again', () {
    for (var i = 0; i < 3; i++) {
      vm.spawnNewActor('Primitive');
    }
    final target = vm.actors.where((a) => a.type == 'Primitive').last;
    final initial = visibility();
    vm.toggleSoloWithTransaction(target.id);
    final soloed = visibility();

    vm.toggleSoloWithTransaction(target.id); // Clear Solo
    expect(visibility(), initial);
    expect(vm.transactions.undoLabel, 'Undo Clear Solo');

    vm.transactions.undo();
    expect(visibility(), soloed, reason: 'undoing Clear Solo puts the solo back');

    vm.transactions.redo();
    expect(visibility(), initial);

    // And the pair unwinds to the start.
    vm.transactions.undo();
    vm.transactions.undo();
    expect(visibility(), initial);
  });
}
