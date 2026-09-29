import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/main_editor_view.dart';
import 'package:lumina_ui/ui/features/marketplace/view_models/marketplace_view_model.dart';
import 'package:lumina_ui/ui/features/marketplace/views/marketplace_sign_in_dialog.dart';
import 'package:lumina_ui/ui/features/marketplace/views/marketplace_view.dart';
import 'package:lumina_ui/ui/features/main_editor/views/content_browser_widget.dart';
import 'package:lumina_ui/ui/features/plugin_manager/views/plugin_manager_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/marketplace_test_backend.dart';

/// Window → Marketplace in the real editor shell against a
/// real marketplace server — sign in through the dialog, search "barrel",
/// the listing's CC0 license, drag the card onto a Content Browser folder
/// (manual placement), the Content Browser's Marketplace smart view, and a
/// plugin listing installed and opened in the Plugin Manager.
void main() {
  final skip = MarketplaceTestBackend.unavailableReason;
  MarketplaceTestBackend? started;
  late Directory temp;

  setUpAll(() async {
    if (skip != null) return;
    MarketplaceViewModel.httpClientFactory = realHttpClient;
    started = await MarketplaceTestBackend.start();
  });
  tearDownAll(() async => started?.stop());
  setUp(() {
    temp = Directory.systemTemp.createTempSync('lumina_ui_marketplace_window_');
    UserPluginDir.override = Directory('${temp.path}/user_plugins')..createSync();
  });
  tearDown(() {
    UserPluginDir.override = null;
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// Lets real I/O (HTTP to the server, the import isolates) run and pumps
  /// frames until [until] holds.
  Future<void> settle(WidgetTester tester, bool Function() until, {Duration timeout = const Duration(seconds: 90)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 16));
      if (until()) {
        await tester.pump(const Duration(milliseconds: 100));
        return;
      }
    }
    fail('timed out waiting');
  }

  bool shows(Finder f) => f.evaluate().isNotEmpty;

  testWidgets('Window → Marketplace: sign in, search "barrel", CC0 license, drag onto a folder installs there, smart view, '
      'plugin → Plugin Manager', (tester) async {
    final backend = started!;
    tester.view.physicalSize = const Size(1800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    createMarketplaceTestProject(temp, 'WindowGame');
    final editor = EditorViewModel(
      initialProject: const LuminaProject(projectName: 'WindowGame', activeLevel: 'contents/levels/L_Main.lmas'),
      projectLocation: temp.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    expect(editor.editorPreferences.setMarketplaceUrl(backend.url.toString()), isTrue);
    final publisher = backend.client();
    final account = await tester.runAsync(() async {
      await backend.signUpUser(publisher);
      await backend.publishPlugin(publisher, package: 'marketplace_window_tools', title: 'Window Tools');
      return backend.signUpUser(backend.client());
    });

    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: MainEditorView(viewModel: editor)));
    await tester.pump(const Duration(milliseconds: 200));

    // Window → Marketplace opens the tab.
    expect(editor.commands.byId('window.marketplace'), isNotNull);
    editor.commands.execute('window.marketplace', tester.element(find.byType(MainEditorView)));
    await settle(tester, () => shows(find.byType(MarketplaceView)) && shows(find.byKey(const ValueKey('marketplace_card_barrel'))));
    expect(editor.currentTab.category, EditorViewModel.marketplaceCategory);
    expect(find.text('MARKETPLACE'), findsOneWidget);

    // Sign in through the dialog.
    await tester.tap(find.byKey(const ValueKey('marketplace_sign_in')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byKey(const ValueKey('marketplace_login_field')), account!.user.username);
    await tester.enterText(find.byKey(const ValueKey('marketplace_password_field')), 'correct horse battery');
    await tester.tap(find.byKey(const ValueKey('marketplace_sign_in_submit')));
    await settle(tester,
        () => shows(find.byKey(const ValueKey('marketplace_signed_in_user'))) && !shows(find.byType(MarketplaceSignInDialog)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(account.user.displayName), findsOneWidget);

    // Search "barrel" → the seeded Barrel; its detail shows CC0.
    await tester.enterText(find.byKey(const ValueKey('marketplace_search_field')), 'barrel');
    await tester.tap(find.byKey(const ValueKey('marketplace_search_button')));
    await settle(tester, () => !editor.marketplace.searching && shows(find.byKey(const ValueKey('marketplace_card_barrel'))));
    expect(editor.marketplace.results.map((l) => l.slug), contains('barrel'));
    await tester.tap(find.byKey(const ValueKey('marketplace_card_barrel')));
    await settle(tester, () => shows(find.byKey(const ValueKey('marketplace_license_CC0-1.0'))));
    expect(find.byKey(const ValueKey('marketplace_detail_barrel')), findsOneWidget);
    expect(find.textContaining('Creative Commons'), findsWidgets);
    expect(find.text('No attribution required'), findsOneWidget);
    expect(find.text('Add to Project'), findsOneWidget);

    // Drag the card onto contents/Props: it installs into contents/Props/Barrel/.
    final card = find.byKey(const ValueKey('marketplace_card_barrel'));
    final folder = find.byKey(const ValueKey('marketplace_folder_contents/Props'));
    expect(folder, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(24, 8));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(folder));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    final project = editor.projectDirPath;
    await settle(tester, () => editor.marketplace.installedRecord(editor.marketplace.selected!.id) != null,
        timeout: const Duration(minutes: 3));
    final record = editor.marketplace.installedRecord(editor.marketplace.selected!.id)!;
    expect(record.installedTo, 'contents/Props/Barrel');
    expect(File('$project/contents/Props/Barrel/bent_barrel.lmas').existsSync(), isTrue);
    expect(File('$project/contents/Props/Barrel/LICENSE-Barrel.txt').existsSync(), isTrue);
    expect(File('$project/contents/Marketplace/licenses.json').readAsStringSync(), contains('contents/Props/Barrel'));
    expect(find.byKey(const ValueKey('marketplace_installed_note')), findsOneWidget);
    expect(find.byKey(const ValueKey('marketplace_card_installed_barrel')), findsOneWidget);
    expect(editor.realAssets.map((a) => a.relativePath), contains('contents/Props/Barrel/bent_barrel.lmas'));

    // Installed view lists it with its license.
    await tester.tap(find.byKey(const ValueKey('marketplace_tab_installed')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('marketplace_installed_barrel')), findsOneWidget);
    expect(find.textContaining('CC0-1.0'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('marketplace_tab_browse')));
    await tester.pump(const Duration(milliseconds: 200));

    // A plugin listing: install, then "Enable in Plugin Manager" shows it there.
    await tester.enterText(find.byKey(const ValueKey('marketplace_search_field')), 'Window Tools');
    await tester.tap(find.byKey(const ValueKey('marketplace_search_button')));
    await settle(tester, () => shows(find.byKey(const ValueKey('marketplace_card_window-tools'))));
    await tester.tap(find.byKey(const ValueKey('marketplace_card_window-tools')));
    await settle(tester, () => shows(find.byKey(const ValueKey('marketplace_license_MIT'))));
    expect(find.text('Install Plugin'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('marketplace_install')));
    await settle(tester, () => shows(find.byKey(const ValueKey('marketplace_open_plugin_manager'))));
    expect(File('${UserPluginDir.override!.path}/marketplace_window_tools/marketplace_window_tools.lmplugin').existsSync(), isTrue);
    await tester.tap(find.byKey(const ValueKey('marketplace_open_plugin_manager')));
    await settle(tester, () => shows(find.byType(PluginManagerView)));
    expect(editor.currentTab.category, 'plugins');
    expect(find.text('Window Tools'), findsWidgets);

    // Back in the level tab, the Content Browser's Marketplace smart view.
    editor.selectTab(0);
    await tester.pump(const Duration(milliseconds: 200));
    final smartView = find.byKey(const ValueKey('content_browser_smart_view_marketplace'));
    await tester.scrollUntilVisible(smartView, 60,
        scrollable: find.descendant(of: find.byType(ContentBrowserWidget), matching: find.byType(Scrollable)).first);
    await tester.tap(smartView);
    await tester.pump(const Duration(milliseconds: 200));
    expect(editor.showMarketplaceAssets, isTrue);
    // (Barrel went into contents/Props by hand, so the smart view, which
    // lists contents/Marketplace/, is empty; a default install fills it —
    // marketplace_install_test.dart.)
    expect(editor.visibleAssets.where((a) => !a.relativePath.startsWith('contents/Marketplace/')), isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async => editor.dispose());
  }, skip: skip != null, timeout: const Timeout(Duration(minutes: 6)));
}
