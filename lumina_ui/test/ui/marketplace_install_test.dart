import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart';
import 'package:lumina_ui/ui/core/services/user_plugin_dir.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_install_dirs.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_installer.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_license_records.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_service.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_session_store.dart';
import 'package:lumina_ui/ui/features/marketplace/view_models/marketplace_view_model.dart';

import '../helpers/marketplace_test_backend.dart';

/// The Marketplace session, catalogue and installer against a
/// real marketplace server (its own process, temp SQLite DB and storage,
/// seeded with the sample CC0 listings from test-assets/), installing into a
/// real temp project, plugin directory and editor config directory.
void main() {
  final skip = MarketplaceTestBackend.unavailableReason;
  MarketplaceTestBackend? started;
  MarketplaceTestBackend backend() => started!;
  late Directory temp;

  setUpAll(() async {
    if (skip != null) return;
    MarketplaceViewModel.httpClientFactory = realHttpClient;
    started = await MarketplaceTestBackend.start();
  });
  tearDownAll(() async {
    await started?.stop();
  });
  setUp(() {
    temp = Directory.systemTemp.createTempSync('lumina_ui_marketplace_test_');
    UserPluginDir.override = Directory('${temp.path}/user_plugins')..createSync();
  });
  tearDown(() {
    UserPluginDir.override = null;
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  EditorViewModel openEditor(String name) {
    createMarketplaceTestProject(temp, name);
    final editor = EditorViewModel(
      initialProject: LuminaProject(projectName: name, activeLevel: 'contents/levels/L_Main.lmas'),
      projectLocation: temp.path,
      enableTimers: false,
      autoInitAssets: false,
    );
    // Editor Preferences → Marketplace Server: the test's server.
    expect(editor.editorPreferences.setMarketplaceUrl(backend().url.toString()), isTrue);
    return editor;
  }

  MarketplaceService service({MarketplaceSessionStore? store}) => MarketplaceService(
        serverUrl: backend().url,
        httpClient: realHttpClient(),
        sessionStore: store ?? MarketplaceSessionStore(configDir: Directory('${temp.path}/config')),
      );

  Future<Listing> barrel(MarketplaceService s) async =>
      (await s.search(const SearchQuery(q: 'barrel'))).items.singleWhere((l) => l.slug == 'barrel');

  test('signing in and searching "barrel" lists the seeded barrel model; its detail shows the CC0 license', () async {
    final vm = MarketplaceViewModel(
      serverUrl: backend().url,
      sessionStore: MarketplaceSessionStore(configDir: Directory('${temp.path}/config')),
      dirs: MarketplaceInstallDirs.resolve(configDir: Directory('${temp.path}/config')),
    );
    addTearDown(vm.dispose);
    final account = await backend().signUpUser(backend().client());
    expect(await vm.signIn(account.user.username, 'correct horse battery'), isTrue, reason: vm.sessionError);
    expect(vm.user!.username, account.user.username);

    await vm.search(query: 'barrel');
    expect(vm.searchError, isNull);
    final hit = vm.results.firstWhere((l) => l.slug == 'barrel');
    expect(hit.title, 'Barrel');
    expect(hit.category, ListingCategory.model);
    expect(hit.publisher.username, 'lumina');

    await vm.select(hit);
    final detail = vm.selected!;
    expect(detail.licenses.content, 'CC0-1.0');
    expect(licenseById(detail.licenses.content)!.attributionRequired, isFalse);
    expect(detail.latestVersion!.version, '1.0.0');
  }, skip: skip);

  test('the session survives a restart in an encrypted, owner-only file that opens only on this machine', () async {
    final config = Directory('${temp.path}/config');
    final first = service(store: MarketplaceSessionStore(configDir: config));
    final account = await backend().signUpUser(backend().client());
    await first.signIn(login: account.user.username, password: 'correct horse battery');
    final token = first.client.refreshToken!;
    final file = File('${config.path}/marketplace/session.json');
    expect(file.existsSync(), isTrue);
    first.close();
    final text = file.readAsStringSync();
    expect(text.contains(token), isFalse, reason: 'the refresh token is encrypted');
    expect((jsonDecode(text) as Map)['server'], first.serverUrl.toString());
    if (Platform.isWindows) {
      // Windows has no file mode; the store relies on the per-user
      // profile's ACL, so nobody but the user (and the system) may read it.
      final acl = (await Process.run('icacls', [file.path])).stdout.toString();
      expect(acl, contains(Platform.environment['USERNAME']));
      for (final group in ['Everyone:', r'BUILTIN\Users:', 'Authenticated Users:']) {
        expect(acl.contains(group), isFalse, reason: '$group must not read the session: $acl');
      }
    } else {
      final mode = (await Process.run('stat', ['-c', '%a', file.path])).stdout.toString().trim();
      expect(mode, '600');
    }

    final elsewhere = MarketplaceSessionStore(configDir: config, machineSecret: utf8.encode('another machine'));
    expect(await elsewhere.load(first.serverUrl.toString()), isNull, reason: 'another machine cannot decrypt it');

    final second = service(store: MarketplaceSessionStore(configDir: config));
    addTearDown(second.close);
    final restored = await second.restoreSession();
    expect(restored?.username, account.user.username);
    await second.signOut();
    expect(file.existsSync(), isFalse, reason: 'signing out forgets the stored session');
  }, skip: skip);

  test('Add to Project installs Barrel under contents/Marketplace/lumina/Barrel/ with LICENSE-Barrel.txt, a licenses.json '
      'entry, and the assets in the Content Browser (and its Marketplace smart view)', () async {
    final editor = openEditor('MarketGame');
    addTearDown(editor.dispose);
    final vm = editor.marketplace;
    final account = await backend().signUpUser(backend().client());
    expect(vm.serverUrl.toString(), startsWith(backend().url.toString()));
    expect(await vm.signIn(account.user.username, 'correct horse battery'), isTrue, reason: vm.sessionError);
    final listing = await barrel(vm.service);

    final progress = <MarketplaceInstallProgress>[];
    vm.addListener(() {
      final p = vm.job(listing.id)?.progress;
      if (p != null) progress.add(p);
    });
    final record = await vm.install(listing);
    expect(record, isNotNull, reason: vm.job(listing.id)?.error);
    expect(progress.where((p) => p.phase == MarketplaceInstallPhase.downloading && p.received > 0 && p.total > 0), isNotEmpty,
        reason: 'download progress was reported');
    expect(progress.map((p) => p.phase), contains(MarketplaceInstallPhase.importing));

    final project = editor.projectDirPath;
    const folder = 'contents/Marketplace/lumina/Barrel';
    expect(record!.installedTo, folder);
    final meshes = Directory('${MarketplaceTestBackend.testAssetsDir}/Props/Barrels')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.glb'))
        .map((f) => f.uri.pathSegments.last.replaceAll('.glb', '.lmas'))
        .toList();
    for (final lmas in meshes) {
      expect(File('$project/$folder/$lmas').existsSync(), isTrue, reason: lmas);
    }
    final bent = LuminaAsset.fromBytes(File('$project/$folder/bent_barrel.lmas').readAsBytesSync());
    expect(bent.rawPayload!.sublist(0, 4), [0x67, 0x6C, 0x54, 0x46], reason: 'the GLB was imported into the .lmas');

    final notice = File('$project/$folder/LICENSE-Barrel.txt').readAsStringSync();
    expect(notice, contains('Barrel 1.0.0'));
    expect(notice, contains('CC0-1.0'));
    expect(notice, contains('Lumina Samples'));
    expect(notice, contains(backend().url.resolve('listings/barrel').toString()));

    final entries = MarketplaceLicenseRecords(File('$project/contents/Marketplace/licenses.json')).read();
    final entry = entries.singleWhere((e) => e.listingId == listing.id);
    expect(entry.licenses.single.id, 'CC0-1.0');
    expect(entry.licenseFile, '$folder/LICENSE-Barrel.txt');
    expect(entry.version, '1.0.0');
    expect(entry.files, containsAll(['$folder/bent_barrel.lmas', '$folder/radbarrel.lmas']));

    expect(editor.realAssets.map((a) => a.relativePath), containsAll([for (final m in meshes) '$folder/$m']));
    editor.selectedFolder = folder;
    expect(editor.visibleAssets.map((a) => a.fileName), containsAll(meshes));
    editor.showMarketplaceAssets = true;
    // The meshes and the materials / textures their import extracted, all
    // under the listing folder.
    final smart = editor.visibleAssets.map((a) => a.relativePath).toList();
    expect(smart, containsAll([for (final m in meshes) '$folder/$m']));
    expect(smart.every((p) => p.startsWith('$folder/')), isTrue, reason: '$smart');
    expect(editor.showsFolderTiles, isFalse);

    // Uninstall removes the folder and the license entry.
    expect(await vm.uninstall(vm.installedRecord(listing.id)!), isTrue);
    expect(Directory('$project/$folder').existsSync(), isFalse);
    expect(MarketplaceLicenseRecords(File('$project/contents/Marketplace/licenses.json')).byListing(listing.id), isNull);
    expect(editor.realAssets.where((a) => a.relativePath.startsWith('$folder/')), isEmpty);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 5)));

  test('a plugin listing installs into the plugin dir and shows in the Plugin Manager; a theme listing lands in the '
      'editor themes dir', () async {
    final editor = openEditor('PluginGame');
    addTearDown(editor.dispose);
    await editor.rescanPlugins();
    final publisher = backend().client();
    await backend().signUpUser(publisher);
    final plugin = await backend().publishPlugin(publisher, package: 'marketplace_spin_tools', title: 'Spin Tools');
    expect(plugin.licenses.code, 'MIT');

    final vm = editor.marketplace;
    final account = await backend().signUpUser(backend().client());
    expect(await vm.signIn(account.user.username, 'correct horse battery'), isTrue);
    final record = await vm.install(plugin);
    expect(record, isNotNull, reason: vm.job(plugin.id)?.error);
    final pluginDir = '${UserPluginDir.override!.path}/marketplace_spin_tools';
    expect(record!.installedTo, pluginDir);
    expect(File('$pluginDir/marketplace_spin_tools.lmplugin').existsSync(), isTrue, reason: 'the top-level folder was stripped');
    expect(File('$pluginDir/lib/marketplace_spin_tools.dart').existsSync(), isTrue);
    expect(File('$pluginDir/LICENSE-Spin_Tools.txt').readAsStringSync(), contains('MIT'));
    final entry = editor.pluginRegistry.entries.where((e) => e.descriptor.name == 'marketplace_spin_tools').single;
    expect(entry.descriptor.friendlyName, 'Spin Tools');
    expect(entry.descriptor.origin, PluginOrigin.user);
    expect(entry.enabled, isFalse, reason: 'enabling is the Plugin Manager\'s job');

    final ember = (await vm.service.search(const SearchQuery(category: ListingCategory.theme))).items.singleWhere((l) => l.slug == 'lumina-ember');
    final theme = await vm.install(ember);
    expect(theme, isNotNull, reason: vm.job(ember.id)?.error);
    final themeFile = File('${LuminaConfigDir.resolve().path}/themes/lumina_ember.json');
    expect(theme!.installedTo, themeFile.path);
    final json = jsonDecode(themeFile.readAsStringSync()) as Map<String, dynamic>;
    expect(json['name'], 'Lumina Ember');
    expect((json['colors'] as Map)['primary'], '#FF7A1A');
    final editorRecords = MarketplaceLicenseRecords(File('${LuminaConfigDir.resolve().path}/marketplace/licenses.json')).read();
    expect(editorRecords.map((r) => r.slug), containsAll([plugin.slug, 'lumina-ember']));
    vm.refreshInstalled();
    expect(vm.installed.map((r) => r.title), containsAll(['Spin Tools', 'Lumina Ember']));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));

  test('cancelling a download leaves no partial files; a manifest with ../ is refused', () async {
    final project = createMarketplaceTestProject(temp, 'CancelGame');
    final staging = Directory('${temp.path}/staging')..createSync();
    final s = service();
    addTearDown(s.close);
    final account = await backend().signUpUser(backend().client());
    await s.signIn(login: account.user.username, password: 'correct horse battery');
    final manifest = await s.prepareInstall(await barrel(s));
    expect(manifest.targetRoot, 'contents/Marketplace/lumina/Barrel/');
    expect(manifest.folderName, 'Barrel');

    final installer = MarketplaceInstaller(
      dirs: MarketplaceInstallDirs.resolve(projectRoot: project.path, configDir: Directory('${temp.path}/config')),
      openDownload: s.openDownload,
      serverUrl: backend().url,
      importRunner: (requests) => fail('nothing may be imported after a cancel'),
      stagingRoot: staging,
    );
    final cancel = MarketplaceCancelToken();
    var chunks = 0;
    await expectLater(
      installer.install(manifest, cancel: cancel, onProgress: (p) {
        if (p.phase == MarketplaceInstallPhase.downloading && ++chunks == 1) cancel.cancel();
      }),
      throwsA(isA<MarketplaceInstallException>().having((e) => e.code, 'code', 'cancelled')),
    );
    expect(chunks, greaterThanOrEqualTo(1), reason: 'it was cancelled mid-download');
    expect(Directory('${project.path}/contents/Marketplace').existsSync(), isFalse);
    expect(staging.listSync(), isEmpty, reason: 'the staged download was removed');

    // A tampered manifest (a target that climbs out of the listing folder)
    // is refused before anything is downloaded.
    final tampered = manifest.toJson();
    final files = [for (final f in tampered['files'] as List) Map<String, Object?>.from(f as Map)];
    files.first['target'] = 'contents/Marketplace/lumina/Barrel/../../../../lib/main.dart';
    tampered['files'] = files;
    final evil = InstallManifest.fromJson(tampered);
    expect(() => MarketplaceInstaller.validateManifest(evil),
        throwsA(isA<MarketplaceInstallException>().having((e) => e.code, 'code', 'unsafe_manifest')));
    await expectLater(installer.install(evil), throwsA(isA<MarketplaceInstallException>()));
    final escapedRoot = InstallManifest.fromJson({...manifest.toJson(), 'targetRoot': '../outside/'});
    expect(() => MarketplaceInstaller.validateManifest(escapedRoot), throwsA(isA<MarketplaceInstallException>()));
    expect(Directory('${project.path}/contents/Marketplace').existsSync(), isFalse);
    expect(File('${project.path}/lib/main.dart').existsSync(), isFalse);
    expect(staging.listSync(), isEmpty);
  }, skip: skip);
}
