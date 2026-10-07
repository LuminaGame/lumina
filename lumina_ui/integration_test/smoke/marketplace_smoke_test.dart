import 'dart:io';

import 'package:flutter/gestures.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_install_dirs.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_session_store.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget.dart';
import 'package:lumina_ui/ui/features/marketplace/view_models/marketplace_view_model.dart';
import 'package:lumina_ui/ui/features/marketplace/views/marketplace_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../test/helpers/game_template_fixture.dart';
import '../../test/helpers/marketplace_test_backend.dart';
import '../helpers/shared_editor_preferences.dart';

/// Marketplace smoke:
/// the real editor on a temp project and a real Lumina Marketplace server
/// (its own process on 127.0.0.1, temp SQLite DB and storage, seeded with the
/// CC0 sample listings zipped from test-assets/Props). Window → Marketplace,
/// sign in, search "barrel", open the listing (CC0), Add to Project — the
/// eight barrel GLBs download, verify and import on the background queue
/// into contents/Marketplace/lumina/Barrel/ with their real thumbnails —
/// and the Content Browser's Marketplace smart view shows them. PNGs of the
/// tab, the listing and the installed assets, plus a video, land in
/// build/smoke_report.html.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Marketplace Smoke: add to project', (tester) async {
    final unavailable = MarketplaceTestBackend.unavailableReason;
    if (unavailable != null) {
      // ignore: avoid_print
      print('SKIPPED: $unavailable');
      return;
    }
    const testName = 'Marketplace Smoke: add to project';
    final barrels = Directory('${SmokeArtifacts.testAssetsDir.path}/Props/Barrels')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.glb'))
        .map((f) => 'Props/Barrels/${f.uri.pathSegments.last}')
        .toList()
      ..sort();

    final backend = (await tester.runAsync(MarketplaceTestBackend.start))!;
    final temp = Directory.systemTemp.createTempSync('lumina_smoke_marketplace_');
    UserPluginDir.override = Directory('${temp.path}/user_plugins')..createSync();
    MarketplaceViewModel.httpClientFactory = realHttpClient;
    addTearDown(() async {
      UserPluginDir.override = null;
      await backend.stop();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final account = (await tester.runAsync(() => backend.signUpUser(backend.client(), username: 'smoke_studio')))!;

    createMarketplaceTestProject(temp, 'MarketSmoke');
    const project = LuminaProject(projectName: 'MarketSmoke', activeLevel: 'contents/levels/L_Main.lmas');
    final vm = EditorViewModel(initialProject: project, projectLocation: temp.path, enableTimers: false);
    // Editor Preferences → Marketplace Server: the smoke's local server.
    expect(vm.editorPreferences.setMarketplaceUrl(backend.url.toString()), isTrue);
    await tester.runAsync(() => vm.ensureDefaultLevelAssets());

    // A tall Content Browser, so the installed barrels show with their
    // extracted materials and textures.
    vm.setPaneSize(bottomHeight: 520);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: vm)),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    final rec = SmokeRecorder(tester, boundary: find.byKey(boundaryKey));
    final boundary = find.byKey(boundaryKey);

    /// Lets the server round trips and import isolates run, recording the
    /// screen as it changes, until [until] holds.
    Future<void> waitFor(bool Function() until, {Duration timeout = const Duration(minutes: 3), String Function()? state}) async {
      final end = DateTime.now().add(timeout);
      while (!until()) {
        if (DateTime.now().isAfter(end)) fail('timed out${state == null ? '' : ': ${state()}'}');
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 16));
        await rec.captureIfChanged();
      }
      await rec.hold(const Duration(milliseconds: 300));
    }

    bool shows(Finder f) => f.evaluate().isNotEmpty;

    await rec.hold(const Duration(milliseconds: 800));

    // 1. Window → Marketplace: the catalogue with its screenshots.
    vm.commands.execute('window.marketplace', tester.element(find.byType(MainEditorView)));
    await waitFor(() =>
        shows(find.byType(MarketplaceView)) &&
        vm.marketplace.results.length >= 6 &&
        vm.marketplace.results.where((l) => l.screenshots.isNotEmpty).every((l) => vm.marketplace.media(l.screenshots.first) != null));
    SmokeArtifacts.saveScreenshot('marketplace_tab',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: boundary), usedAssets: barrels);
    await rec.hold(const Duration(milliseconds: 1200));

    // 2. Sign in.
    await tester.tap(find.byKey(const ValueKey('marketplace_sign_in')));
    await rec.hold(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('marketplace_login_field')));
    await rec.typeText(find.byKey(const ValueKey('marketplace_login_field')), account.user.username,
        perCharacter: const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const ValueKey('marketplace_password_field')));
    await rec.typeText(find.byKey(const ValueKey('marketplace_password_field')), 'correct horse battery',
        perCharacter: const Duration(milliseconds: 30));
    await tester.tap(find.byKey(const ValueKey('marketplace_sign_in_submit')));
    await waitFor(() => shows(find.byKey(const ValueKey('marketplace_signed_in_user'))));

    // 3. Search "barrel" and open the listing: CC0.
    await tester.tap(find.byKey(const ValueKey('marketplace_search_field')));
    await rec.typeText(find.byKey(const ValueKey('marketplace_search_field')), 'barrel',
        perCharacter: const Duration(milliseconds: 80));
    await tester.tap(find.byKey(const ValueKey('marketplace_search_button')));
    await waitFor(() => !vm.marketplace.searching && shows(find.byKey(const ValueKey('marketplace_card_barrel'))));
    await tester.tap(find.byKey(const ValueKey('marketplace_card_barrel')));
    await waitFor(() {
      final l = vm.marketplace.selected;
      return shows(find.byKey(const ValueKey('marketplace_license_CC0-1.0'))) &&
          l != null &&
          l.screenshots.every((s) => vm.marketplace.media(s) != null);
    });
    expect(find.text('Add to Project'), findsOneWidget);
    SmokeArtifacts.saveScreenshot('marketplace_listing',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: boundary), usedAssets: barrels);
    await rec.hold(const Duration(milliseconds: 1200));

    // 4. Add to Project: download (progress), verify, import on the queue.
    final listing = vm.marketplace.selected!;
    await tester.tap(find.byKey(const ValueKey('marketplace_install')));
    await waitFor(() => vm.marketplace.installedRecord(listing.id) != null && !vm.isBatchImporting);
    final record = vm.marketplace.installedRecord(listing.id)!;
    const folder = 'contents/Marketplace/lumina/Barrel';
    expect(record.installedTo, folder);
    final dir = vm.projectDirPath;
    for (final b in barrels) {
      final lmas = '$folder/${b.split('/').last.replaceAll('.glb', '.lmas')}';
      expect(File('$dir/$lmas').existsSync(), isTrue, reason: lmas);
    }
    expect(File('$dir/$folder/LICENSE-Barrel.txt').readAsStringSync(), contains('CC0-1.0'));
    expect(File('$dir/contents/Marketplace/licenses.json').readAsStringSync(), contains('"CC0-1.0"'));
    expect(find.byKey(const ValueKey('marketplace_installed_note')), findsOneWidget);
    await rec.hold(const Duration(milliseconds: 1200));

    // 5. The level tab's Content Browser: the Marketplace smart view.
    vm.selectTab(0);
    await rec.hold(const Duration(milliseconds: 600));
    final smartView = find.byKey(const ValueKey('content_browser_smart_view_marketplace'));
    await tester.scrollUntilVisible(smartView, 60,
        scrollable: find.descendant(of: find.byType(ContentBrowserWidget), matching: find.byType(Scrollable)).first);
    await rec.hold(const Duration(milliseconds: 400));
    await tester.tap(smartView);
    // The eight meshes, plus the materials and textures their import
    // extracted, each with its thumbnail.
    final meshes = {for (final b in barrels) '$folder/${b.split('/').last.replaceAll('.glb', '.lmas')}'};
    await waitFor(
      () => meshes.every((m) => vm.visibleAssets.any((a) => a.relativePath == m && a.thumbnailBytes != null)),
      timeout: const Duration(minutes: 2),
      state: () => 'smart view ${vm.showMarketplaceAssets}, visible '
          '${[for (final a in vm.visibleAssets) '${a.relativePath}:${a.thumbnailBytes != null}']}',
    );
    await tester.runAsync(() => vm.thumbnailQueueIdle.timeout(const Duration(minutes: 2), onTimeout: () {}));
    await waitFor(() => true);
    expect(vm.visibleAssets.map((a) => a.relativePath).every((p) => p.startsWith('$folder/')), isTrue);
    SmokeArtifacts.saveScreenshot('marketplace_installed_assets',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: boundary), usedAssets: barrels);
    await rec.hold(const Duration(milliseconds: 1200));

    rec.save(testName, usedAssets: barrels);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async => vm.dispose());
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('Marketplace Smoke: game template', (tester) async {
    final unavailable = MarketplaceTestBackend.unavailableReason;
    if (unavailable != null) {
      // ignore: avoid_print
      print('SKIPPED: $unavailable');
      return;
    }
    const testName = 'Marketplace Smoke: game template';
    const folder = 'Crate_Arena';
    const title = 'Crate Arena';

    final backend = (await tester.runAsync(MarketplaceTestBackend.start))!;
    final temp = Directory.systemTemp.createTempSync('lumina_smoke_marketplace_template_');
    final config = Directory('${temp.path}/config')..createSync();
    final projects = Directory('${temp.path}/projects')..createSync();
    UserPluginDir.override = Directory('${temp.path}/user_plugins')..createSync();
    MarketplaceViewModel.httpClientFactory = realHttpClient;
    addTearDown(() async {
      UserPluginDir.override = null;
      await backend.stop();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    // A publisher packs a real First Person project as a game template and
    // publishes it (content CC-BY-4.0, code MIT); a user installs it through
    // the Marketplace window's view model into the editor config.
    final listing = (await tester.runAsync(() async {
      final build = Directory('${temp.path}/build')..createSync();
      final source = await createTemplateSourceProject(build, name: 'crate_arena_source', title: title);
      final publisher = backend.client();
      await backend.signUpUser(publisher, username: 'arena_smoke');
      return publishGameTemplate(publisher,
          zip: zipGameTemplate(source, topFolder: folder), title: title, screenshot: templateThumbnailPng());
    }))!;
    final market = MarketplaceViewModel(
      serverUrl: backend.url,
      sessionStore: MarketplaceSessionStore(configDir: config),
      dirs: MarketplaceInstallDirs.resolve(configDir: config),
    );
    addTearDown(market.dispose);
    await tester.runAsync(() async {
      final account = await backend.signUpUser(backend.client(), username: 'template_user');
      expect(await market.signIn(account.user.username, 'correct horse battery'), isTrue, reason: market.sessionError);
      expect(await market.install(listing), isNotNull, reason: market.job(listing.id)?.error);
    });
    expect(Directory('${config.path}/templates/$folder').existsSync(), isTrue);

    // The launcher: real flutter create + pub get for the new project.
    useSharedEditor(config);
    final launcher = LauncherViewModel(configDir: config);
    await launcher.setDefaultProjectsDirectory(projects.path);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: ShadcnApp(theme: luminaEditorTheme(), home: LauncherView(viewModel: launcher)),
    ));
    final boundary = find.byKey(boundaryKey);
    final rec = SmokeRecorder(tester, boundary: boundary);
    Future<void> settle([int frames = 20]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
    }

    Future<void> waitFor(bool Function() until, {Duration timeout = const Duration(minutes: 7), String? what}) async {
      final end = DateTime.now().add(timeout);
      final sinceFrame = Stopwatch()..start();
      while (!until()) {
        if (DateTime.now().isAfter(end)) fail('timed out waiting for ${what ?? 'the condition'}');
        await settle(6);
        if (sinceFrame.elapsedMilliseconds >= 250) {
          await rec.captureIfChanged();
          sinceFrame.reset();
        }
      }
    }

    await settle();
    await rec.hold(const Duration(milliseconds: 800));

    // 1. Templates pane: the built-in templates and the Marketplace one.
    await tester.tap(find.text('Templates'));
    await settle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await settle();
    expect(find.byKey(const ValueKey('launcher_installed_template_$folder')), findsOneWidget);
    SmokeArtifacts.saveScreenshot('marketplace_template_launcher_pane',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: boundary));
    await rec.hold(const Duration(milliseconds: 1200));

    // 2. Use Template: the Create Project dialog's Marketplace group.
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('launcher_installed_template_$folder')), matching: find.text('Use Template')));
    await settle();
    expect(find.byKey(const ValueKey('create_project_marketplace_group')), findsOneWidget);
    final nameField = find.widgetWithText(TextField, 'my_lumina_game').first;
    await tester.tap(nameField);
    await tester.enterText(nameField, '');
    await rec.typeText(nameField, 'templated_game', perCharacter: const Duration(milliseconds: 60));
    await settle(6);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await settle();
    expect(find.text("The project uses the template's own UI widget library and code."), findsOneWidget,
        reason: 'the template is selected');
    // Hovering the license badge names both licenses and the attribution
    // the CC-BY content license asks for.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    final badge = find.descendant(
        of: find.byKey(const ValueKey('installed_template_$folder')), matching: find.text('CC-BY-4.0 + MIT'));
    await mouse.moveTo(tester.getCenter(badge));
    await waitFor(() => find.textContaining('Attribution required').evaluate().isNotEmpty, what: 'the license tooltip',
        timeout: const Duration(seconds: 20));
    await settle();
    SmokeArtifacts.saveScreenshot('marketplace_template_create_dialog',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: boundary));
    await rec.hold(const Duration(milliseconds: 1200));
    await mouse.moveTo(Offset.zero);
    await settle();

    // 3. Create Project: the template's tree, renamed, with its license.
    await tester.tap(find.text('Create Project'));
    await waitFor(() => find.byType(MainEditorView).evaluate().isNotEmpty, what: 'the new project to open');
    final dir = '${projects.path}/templated_game';
    expect(File('$dir/templated_game.lmproject').existsSync(), isTrue);
    expect(File('$dir/contents/Marketplace/LICENSE-$folder.txt').readAsStringSync(), contains('CC-BY-4.0'));
    expect(File('$dir/contents/Marketplace/licenses.json').readAsStringSync(), contains('"MIT"'));
    expect(File('$dir/lib/main.dart').readAsStringSync(), contains('class TemplatedGameGame'));

    // 4. The new project's level, rendered on the GPU.
    await waitFor(() => find.byType(ViewportWidget).evaluate().isNotEmpty, what: 'the viewport');
    dynamic viewport() => tester.state(find.byType(ViewportWidget));
    await waitFor(() => (viewport().editorActorsInSceneForTest as int) >= 5, what: 'the template level in the viewport');
    await settle(60);
    expect(find.text('Crate_A'), findsWidgets, reason: 'the outliner lists the template actors');
    // Walk the template's actors in the outliner, then look around.
    for (final name in ['Crate_A', 'Floor', 'PlayerStart']) {
      await tester.tap(find.text(name).first);
      await settle(6);
      await rec.hold(const Duration(milliseconds: 900));
    }
    final viewportRect = tester.getRect(find.byType(ViewportWidget));
    await rec.drag(viewportRect.center, viewportRect.center + const Offset(220, 30), steps: 40, buttons: kSecondaryMouseButton);
    await settle(20);
    SmokeArtifacts.saveScreenshot('marketplace_template_new_project_level',
        await SmokeArtifacts.captureIntegrationPng(binding, tester, boundary: boundary));
    await rec.hold(const Duration(milliseconds: 1500));

    rec.save(testName);
    await tester.pumpWidget(const SizedBox());
    await settle(10);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
