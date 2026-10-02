import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina/lumina.dart' show LuminaProject;
import 'package:lumina_ui/ui/core/services/content_folders.dart';
import 'package:lumina_ui/ui/core/services/file_reveal.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/outliner_widget.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/temp_project.dart';

/// "Show in Explorer" (Windows) / "Reveal in Finder" / "Show in File
/// Manager": the platform file manager opens at a Content Browser folder, an
/// asset's `.lmas`, or a placed actor's asset. The runner that starts the
/// file manager is swapped for one that records the command; everything else
/// is a real temp project on disk.
void main() {
  group('commandFor', () {
    test('Windows selects a file and opens a folder, with backslashes', () {
      expect(FileReveal.commandFor('C:/Lumina Projects/G/contents/SM_Box.lmas', isDirectory: false, os: 'windows'),
          const FileRevealCommand('explorer.exe', ['/select,', r'C:\Lumina Projects\G\contents\SM_Box.lmas']));
      expect(FileReveal.commandFor(r'C:\Lumina Projects\G\contents', isDirectory: true, os: 'windows'),
          const FileRevealCommand('explorer.exe', [r'C:\Lumina Projects\G\contents']));
    });

    test('macOS reveals a file and opens a folder', () {
      expect(FileReveal.commandFor('/Users/a/G/contents/SM_Box.lmas', isDirectory: false, os: 'macos'),
          const FileRevealCommand('open', ['-R', '/Users/a/G/contents/SM_Box.lmas']));
      expect(FileReveal.commandFor('/Users/a/G/contents', isDirectory: true, os: 'macos'),
          const FileRevealCommand('open', ['/Users/a/G/contents']));
    });

    test('Linux opens the folder, the parent folder for a file', () {
      expect(FileReveal.commandFor('/home/a/G/contents/SM_Box.lmas', isDirectory: false, os: 'linux'),
          const FileRevealCommand('xdg-open', ['/home/a/G/contents']));
      expect(FileReveal.commandFor('/home/a/G/contents/props', isDirectory: true, os: 'linux'),
          const FileRevealCommand('xdg-open', ['/home/a/G/contents/props']));
    });

    test('labels per platform', () {
      expect(FileReveal.menuLabel(os: 'windows'), 'Show in Explorer');
      expect(FileReveal.menuLabel(os: 'macos'), 'Reveal in Finder');
      expect(FileReveal.menuLabel(os: 'linux'), 'Show in File Manager');
      expect(FileReveal.menuLabel(subject: 'Asset', os: 'windows'), 'Show Asset in Explorer');
    });
  });

  late Directory root;
  late String dir;
  late List<List<String>> calls;
  const name = 'reveal_proj';

  setUp(() {
    root = Directory.systemTemp.createTempSync('lumina_reveal_');
    dir = '${root.path}/$name';
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.lmproject').writeAsStringSync(jsonEncode({'project_name': name}));
    for (final rel in ['contents/props/barrels', 'contents/blueprints']) {
      ContentFolders.writeMarker((Directory('$dir/$rel')..createSync(recursive: true)).path);
    }
    File('$dir/contents/props/SM_Crate.lmas').writeAsBytesSync(
        const LuminaAsset(assetId: 'crate-id', name: 'SM_Crate', type: AssetType.filamesh).toProtoBufferBytes());
    calls = [];
    FileReveal.runner = (exe, args) async => calls.add([exe, ...args]);
  });
  tearDown(() async {
    await deleteTempProject(root);
  });

  EditorViewModel newVm() => EditorViewModel(
        initialProject: const LuminaProject(projectName: name),
        projectLocation: root.path,
        enableTimers: false,
        autoInitAssets: false,
      )..refreshAssets();

  List<String> expected(String absolute) {
    final c = FileReveal.commandFor(absolute, isDirectory: FileSystemEntity.isDirectorySync(absolute));
    return [c.executable, ...c.arguments];
  }

  Future<void> pumpBrowser(WidgetTester tester, EditorViewModel vm) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: ListenableBuilder(listenable: vm, builder: (_, _) => ContentBrowserWidget(viewModel: vm))),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> chooseReveal(WidgetTester tester, {String? subject}) async {
    final entry = find.text(FileReveal.menuLabel(subject: subject));
    expect(entry, findsOneWidget);
    await tester.tap(entry);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a Sources tree folder opens in the file manager', (tester) async {
    final vm = newVm();
    addTearDown(vm.dispose);
    await pumpBrowser(tester, vm);
    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('source_folder_row_contents/props'))),
        buttons: kSecondaryMouseButton);
    await tester.pump(const Duration(milliseconds: 300));
    await chooseReveal(tester);
    expect(calls, [expected(p.normalize('$dir/contents/props'))]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a folder tile in the grid opens in the file manager', (tester) async {
    final vm = newVm()..selectedFolder = 'contents/props';
    addTearDown(vm.dispose);
    await pumpBrowser(tester, vm);
    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('folder_tile_contents/props/barrels'))),
        buttons: kSecondaryMouseButton);
    await tester.pump(const Duration(milliseconds: 300));
    await chooseReveal(tester);
    expect(calls, [expected(p.normalize('$dir/contents/props/barrels'))]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("an asset tile shows its .lmas in the file manager", (tester) async {
    final vm = newVm()..selectedFolder = 'contents/props';
    addTearDown(vm.dispose);
    await pumpBrowser(tester, vm);
    final tile = find.byWidgetPredicate((w) {
      final k = w.key;
      return k is ValueKey<String> && k.value.startsWith('asset_item_') && k.value.endsWith('SM_Crate.lmas');
    });
    expect(tile, findsOneWidget);
    await tester.tapAt(tester.getCenter(tile), buttons: kSecondaryMouseButton);
    await tester.pump(const Duration(milliseconds: 300));
    await chooseReveal(tester);
    expect(calls, [expected(p.normalize('$dir/contents/props/SM_Crate.lmas'))]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("an outliner actor shows its mesh asset in the file manager", (tester) async {
    final vm = newVm();
    addTearDown(vm.dispose);
    vm.spawnNewActor('Primitive');
    final actor = vm.actors.last..meshAssetPath = '$dir/contents/props/SM_Crate.lmas';
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: ListenableBuilder(listenable: vm, builder: (_, _) => OutlinerWidget(viewModel: vm))),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(tester.getCenter(find.byKey(ValueKey('outliner_row_${actor.id}'))),
        buttons: kSecondaryMouseButton);
    await tester.pump(const Duration(milliseconds: 300));
    await chooseReveal(tester, subject: 'Asset');
    expect(calls, [expected(p.normalize('$dir/contents/props/SM_Crate.lmas'))]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('an actor without an asset has no reveal entry', (tester) async {
    final vm = newVm();
    addTearDown(vm.dispose);
    vm.spawnNewActor('Primitive');
    final actor = vm.actors.last;
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: ListenableBuilder(listenable: vm, builder: (_, _) => OutlinerWidget(viewModel: vm))),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(tester.getCenter(find.byKey(ValueKey('outliner_row_${actor.id}'))),
        buttons: kSecondaryMouseButton);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text(FileReveal.menuLabel(subject: 'Asset')), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
