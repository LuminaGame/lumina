import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/create_project_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/create_project_dialog.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_install_dirs.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_license_records.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_session_store.dart';
import 'package:lumina_ui/ui/features/marketplace/view_models/marketplace_view_model.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/game_template_fixture.dart';
import '../helpers/marketplace_test_backend.dart';

/// A game template listing, published to a real marketplace
/// server (its own process, temp DB) as a zip of a real project created from
/// the First Person template, installed through the Marketplace window's view
/// model into a temp editor config, is offered by the launcher's Create
/// Project dialog and creates a project with its license notice.
void main() {
  final skip = MarketplaceTestBackend.unavailableReason;
  MarketplaceTestBackend? started;
  MarketplaceTestBackend backend() => started!;
  late Listing listing;
  late String sourcePackage;
  late Directory temp;
  late Directory config;

  const folder = 'Arena_Starter';
  const title = 'Arena Starter';

  setUpAll(() async {
    if (skip != null) return;
    MarketplaceViewModel.httpClientFactory = realHttpClient;
    started = await MarketplaceTestBackend.start();
    final build = Directory.systemTemp.createTempSync('lumina_ui_template_source_');
    try {
      sourcePackage = 'arena_source';
      final source = await createTemplateSourceProject(build, name: sourcePackage, title: title);
      final publisher = backend().client();
      await backend().signUpUser(publisher, username: 'arena_studio');
      listing = await publishGameTemplate(publisher,
          zip: zipGameTemplate(source, topFolder: folder), title: title, screenshot: templateThumbnailPng());
    } finally {
      build.deleteSync(recursive: true);
    }
  });
  tearDownAll(() async {
    await started?.stop();
  });
  setUp(() {
    temp = Directory.systemTemp.createTempSync('lumina_ui_marketplace_templates_');
    config = Directory('${temp.path}/config')..createSync();
    UserPluginDir.override = Directory('${temp.path}/user_plugins')..createSync();
  });
  tearDown(() async {
    UserPluginDir.override = null;
    // On Windows an open project's lib/ watcher (ProjectBlueprintFunctions)
    // holds a handle until its asynchronous cancel completes after
    // EditorViewModel.dispose, so the folder is deleted once it is released.
    for (var attempt = 0; temp.existsSync(); attempt++) {
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        if (!Platform.isWindows || attempt >= 40) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  });

  /// Installs the template through the Marketplace window's view model.
  Future<void> installTemplate() async {
    final vm = MarketplaceViewModel(
      serverUrl: backend().url,
      sessionStore: MarketplaceSessionStore(configDir: config),
      dirs: MarketplaceInstallDirs.resolve(configDir: config),
    );
    try {
      final account = await backend().signUpUser(backend().client());
      expect(await vm.signIn(account.user.username, 'correct horse battery'), isTrue, reason: vm.sessionError);
      final record = await vm.install(listing);
      expect(record, isNotNull, reason: vm.job(listing.id)?.error);
      expect(record!.installedTo, '${config.path}/templates/$folder');
    } finally {
      vm.dispose();
    }
  }

  (LauncherViewModel, CreateProjectViewModel) viewModels() {
    final repo = ProjectRepository(configDir: config, processRunner: templateScaffoldRunner());
    final launcher = LauncherViewModel(configDir: config, projectRepo: repo);
    final create = CreateProjectViewModel(launcherVM: launcher, projectRepo: repo);
    create.updateLocation('${temp.path}/projects');
    Directory('${temp.path}/projects').createSync();
    return (launcher, create);
  }

  Future<void> pumpDialog(WidgetTester tester, CreateProjectViewModel vm) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: CreateProjectDialog(viewModel: vm, onSuccess: () {})),
    ));
    await tester.pump();
  }

  testWidgets('a template listing installed through the Marketplace window shows in the Create Project dialog with its '
      'title, thumbnail, publisher, version and license, and in the Templates pane', (tester) async {
    await tester.runAsync(installTemplate);
    final (launcher, vm) = viewModels();
    addTearDown(launcher.dispose);
    expect(launcher.installedTemplates.map((t) => t.id), ['marketplace:$folder']);
    final t = launcher.installedTemplates.single;
    expect(t.title, title);
    expect(t.publisher, 'User arena_studio');
    expect(t.version, '1.0.0');
    expect(t.licenseLabel, 'CC-BY-4.0 + MIT');
    expect(t.thumbnailPath, '${config.path}/templates/$folder/thumbnail.png');

    await pumpDialog(tester, vm);
    for (final builtIn in launcher.templates) {
      expect(find.text(builtIn.title), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('create_project_marketplace_group')), findsOneWidget);
    final tile = find.byKey(const ValueKey('installed_template_$folder'));
    expect(tile, findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text(title)), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('CC-BY-4.0 + MIT')), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.textContaining('User arena_studio')), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.textContaining('1.0.0')), findsOneWidget);
    expect(find.byKey(const ValueKey('installed_template_thumbnail_$folder')), findsOneWidget);

    await tester.tap(find.descendant(of: tile, matching: find.text(title)));
    await tester.pump();
    expect(vm.template, 'marketplace:$folder');
    expect(vm.selectedInstalledTemplate?.title, title);
    // The template's code is built on its own widget library.
    expect(find.text('UI Widget Library'), findsNothing);

    // The launcher's Templates pane lists it too.
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: LauncherView(viewModel: launcher)));
    await tester.pump();
    await tester.tap(find.text('Templates'));
    await tester.pump();
    expect(find.byKey(const ValueKey('launcher_installed_template_$folder')), findsOneWidget);
    expect(find.text('Marketplace Templates'), findsOneWidget);
  }, skip: skip != null);

  testWidgets('creating templated_game from it copies the template, renames the manifest and package, keeps the license '
      'and opens in the editor', (tester) async {
    await tester.runAsync(installTemplate);
    final (launcher, vm) = viewModels();
    addTearDown(launcher.dispose);
    vm.updateName('templated_game');
    vm.updateTemplate('marketplace:$folder');
    await tester.runAsync(vm.createProject);
    expect(vm.creationError, isNull);

    final dir = '${temp.path}/projects/templated_game';
    final source = '${config.path}/templates/$folder';
    // The template's contents: its level (with the First Person actors) and
    // its gameplay code.
    final level = jsonDecode(File('$dir/contents/levels/L_DefaultLevel.lmas').readAsStringSync()) as Map;
    final actors = [for (final a in level['metadata']['actors'] as List) (a as Map)['name']];
    expect(actors, containsAll(['PlayerStart', 'Floor', 'Crate_A']));
    expect(File('$dir/contents/levels/L_DefaultLevel.lmas').readAsStringSync(),
        File('$source/contents/levels/L_DefaultLevel.lmas').readAsStringSync());
    expect(File('$dir/lib/game/arena_source_game_mode.dart').existsSync(), isTrue);
    expect(File('$dir/lib/pawns/arena_source_character.dart').existsSync(), isTrue);
    expect(File('$dir/linux/CMakeLists.txt').existsSync(), isTrue, reason: 'flutter create wrote the platform folders');
    for (final templateOnly in ['template.json', 'thumbnail.png', '$sourcePackage.lmproject', 'LICENSE-$folder.txt']) {
      expect(File('$dir/$templateOnly').existsSync(), isFalse, reason: templateOnly);
    }

    // The manifest and the Dart package are the new project's.
    final manifest = jsonDecode(File('$dir/templated_game.lmproject').readAsStringSync()) as Map<String, dynamic>;
    expect(manifest['project_name'], 'templated_game');
    expect(manifest['template'], 'first_person', reason: 'the source project\'s template kind drives Play');
    expect(manifest['maps_and_modes']['default_game_mode'], 'ArenaSourceGameMode');
    final pubspec = File('$dir/pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('name: templated_game'));
    // The engine is a git dependency (committable); this machine's checkout
    // comes from the gitignored pubspec_overrides.yaml.
    expect(pubspec, contains('  lumina:\n    git:\n      url: $kLuminaGitUrl\n      path: lumina\n'));
    expect(pubspec, isNot(contains('path: ${ProjectRepository.luminaPackagePath}')));
    expect(File('$dir/pubspec_overrides.yaml').readAsStringSync(),
        contains("  lumina:\n    path: '${ProjectRepository.luminaPackagePath.replaceAll(r'\', '/')}'\n"));
    expect(File('$dir/.gitignore').readAsLinesSync(), contains('pubspec_overrides.yaml'));
    expect(pubspec, contains('- contents/'));
    final dart = [
      for (final f in Directory('$dir/lib').listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart')) f.readAsStringSync(),
    ].join('\n');
    expect(dart, isNot(contains('package:$sourcePackage/')));
    // The normal code generation: main.dart names the new game and installs
    // the template's game mode.
    final main = File('$dir/lib/main.dart').readAsStringSync();
    expect(main, contains('class TemplatedGameGame'));
    expect(main, contains("import 'game/arena_source_game_mode.dart';"));
    expect(File('$dir/lib/levels/l_default_level.dart').existsSync(), isTrue);

    // The license notice travels with the project.
    final notice = File('$dir/contents/Marketplace/LICENSE-$folder.txt').readAsStringSync();
    expect(notice, contains('$title 1.0.0'));
    expect(notice, contains('CC-BY-4.0'));
    expect(notice, contains('MIT'));
    expect(notice, contains('Attribution required'));
    final entry = MarketplaceLicenseRecords(File('$dir/contents/Marketplace/licenses.json')).byListing(listing.id)!;
    expect(entry.installKind, InstallKind.gameTemplate);
    expect(entry.licenses.map((l) => l.id), ['CC-BY-4.0', 'MIT']);
    expect(entry.licenseFile, 'contents/Marketplace/LICENSE-$folder.txt');
    expect(entry.version, '1.0.0');
    expect(vm.processOutput.join('\n'), contains('Kept the template license'));

    // It is a recent project and opens in the editor with the template's level.
    expect(launcher.recentProjects.map((e) => e.projectDir), contains(dir));
    expect(vm.activeProject?.projectName, 'templated_game');
    final editor = EditorViewModel(
      initialProject: vm.activeProject!,
      projectLocation: '${temp.path}/projects',
      enableTimers: false,
      autoInitAssets: false,
    );
    addTearDown(editor.dispose);
    await tester.runAsync(editor.ensureDefaultLevelAssets);
    expect(editor.projectDirPath, dir);
    expect(editor.actors.map((a) => a.name), containsAll(['PlayerStart', 'Floor', 'Crate_A']));
    // The Marketplace window in that project does not treat the template
    // notice as an asset install it could remove.
    expect(editor.marketplace.dirs.projectRoot, dir);
    editor.marketplace.refreshInstalled();
    expect(editor.marketplace.installed.where((r) => r.listingId == listing.id && r.installedTo == dir), isEmpty);
  }, skip: skip != null, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('a template folder without a valid manifest is not listed and is reported in the Output Log', (tester) async {
    await tester.runAsync(installTemplate);
    // Each folder breaks one rule of the shared game template check (a level
    // under contents/ where the rule is not about contents).
    final broken = Directory('${config.path}/templates/Broken_Template/contents')..createSync(recursive: true);
    File('${broken.path}/L_DefaultLevel.lmas').writeAsStringSync('{}');
    File('${broken.parent.path}/template.json').writeAsStringSync('{"title": ');
    final noManifest = Directory('${config.path}/templates/No_Manifest/contents')..createSync(recursive: true);
    File('${noManifest.path}/L_DefaultLevel.lmas').writeAsStringSync('{}');
    Directory('${config.path}/templates/No_Contents').createSync(recursive: true);
    File('${config.path}/templates/No_Contents/template.json').writeAsStringSync('{"title": "No Contents"}');
    final logged = EngineLoggerService().logs.length;

    final (launcher, vm) = viewModels();
    addTearDown(launcher.dispose);
    expect(launcher.installedTemplates.map((t) => t.folderName), [folder]);
    final reasons = {for (final i in launcher.installedTemplateRepo.invalid) i.path.split('/').last: i.reason};
    expect(reasons.keys, containsAll(['Broken_Template', 'No_Manifest', 'No_Contents']));
    final log = EngineLoggerService().logs.skip(logged).where((e) => e.source == 'Templates').map((e) => e.message).join('\n');
    // The shared check's wording (lumina_marketplace_shared checkGameTemplate).
    expect(log, contains('Broken_Template: template.json is not a valid template manifest'));
    expect(log, contains('No_Manifest: it has neither a template.json with a title nor a .lmproject manifest'));
    expect(log, contains('No_Contents: it has no contents/ folder'));

    await pumpDialog(tester, vm);
    expect(find.byKey(const ValueKey('installed_template_Broken_Template')), findsNothing);
    expect(find.byKey(const ValueKey('installed_template_$folder')), findsOneWidget);
  }, skip: skip != null);

  testWidgets('Uninstall in the dialog removes the template folder and its licenses.json entry', (tester) async {
    await tester.runAsync(installTemplate);
    final (launcher, vm) = viewModels();
    addTearDown(launcher.dispose);
    vm.updateTemplate('marketplace:$folder');
    await pumpDialog(tester, vm);
    await tester.tap(find.byKey(const ValueKey('installed_template_uninstall_$folder')));
    await tester.pump();
    expect(Directory('${config.path}/templates/$folder').existsSync(), isFalse);
    expect(MarketplaceLicenseRecords(File('${config.path}/marketplace/licenses.json')).byListing(listing.id), isNull);
    expect(launcher.installedTemplates, isEmpty);
    expect(vm.template, 'blank_3d', reason: 'the selection falls back to a built-in template');
    expect(find.byKey(const ValueKey('installed_template_$folder')), findsNothing);
    expect(find.byKey(const ValueKey('create_project_marketplace_group')), findsNothing);
  }, skip: skip != null);
}
