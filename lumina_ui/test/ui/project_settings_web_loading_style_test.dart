import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/build_pipeline_service.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings/web_loading_style_section.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/project_settings_sub_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/flutter_build_stand_in.dart';
import '../helpers/mcp_test_client.dart' show realHttpClient;

/// Packaging & Target → Web Loading Style, against a
/// real temp project and its `.lmproject` on disk.
void main() {
  const host = HostBuildTargets(flutterAvailable: true, flutterVersion: '3.47.0', targets: ['linux', 'web'], operatingSystem: 'linux');
  late Directory tempDir;
  late Directory projDir;
  late File manifest;

  Future<LuminaProject> readManifest() async => LuminaProject.fromMap(jsonDecode(await manifest.readAsString()) as Map<String, dynamic>);

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('wls_project_settings_');
    projDir = Directory('${tempDir.path}/wls_game')..createSync(recursive: true);
    Directory('${projDir.path}/contents/levels').createSync(recursive: true);
    manifest = File('${projDir.path}/wls_game.lmproject')
      ..writeAsStringSync(jsonEncode(const LuminaProject(projectName: 'wls_game', activeLevel: 'contents/levels/L_Main.lmas').toMap()));
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> pumpEditor(WidgetTester tester, ProjectSettingsViewModel vm) async {
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: SizedBox(width: 1200, height: 1400, child: ProjectSettingsSubEditor(assetName: 'Project Settings', viewModel: vm))),
    ));
    await tester.tap(find.byKey(const ValueKey('project_settings_nav_${ProjectSettingsCategory.packaging}')));
    await tester.pump();
  }

  test('edits persist in the .lmproject and reload; a bad colour blocks Apply', () async {
    final vm = ProjectSettingsViewModel(projectDirPath: projDir.path, hostTargets: host);
    await vm.load();
    expect(vm.webLoadingStyle.toMap(), const ProjectWebLoadingStyle().toMap(), reason: 'a manifest without a style reads the defaults');
    vm.setTargetSelected('web', true);
    vm.setWebLoadingBackground('#101418');
    vm.setWebLoadingGradientEnabled(true);
    vm.setWebLoadingAccent('#22C55E');
    vm.setWebLoadingText('#F5F5F5');
    vm.setWebLoadingTitle('My Game');
    vm.setWebLoadingSubtitle('Episode One');
    vm.setWebLoadingProgressStyle('ring');
    vm.setWebLoadingFadeMs(900);
    expect(vm.webLoadingStyle.gradient, '#060708', reason: 'the gradient starts as a darker shade of the background');
    expect(await vm.apply(), isTrue);

    final raw = jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    expect((raw['packaging'] as Map)['web_loading_style'], {
      'background': '#101418',
      'gradient': '#060708',
      'accent': '#22C55E',
      'text': '#F5F5F5',
      'logo': 'icon',
      'title': 'My Game',
      'subtitle': 'Episode One',
      'progress_style': 'ring',
      'fade_ms': 900,
    });
    final reloaded = ProjectSettingsViewModel(projectDirPath: projDir.path, hostTargets: host);
    await reloaded.load();
    expect(reloaded.webLoadingStyle.title, 'My Game');
    expect(reloaded.webLoadingStyle.accent, '#22C55E');
    expect(reloaded.project.packaging.targets, ['linux', 'web']);

    reloaded.setWebLoadingAccent('orange');
    expect(reloaded.validationErrors[ProjectSettingsCategory.packaging], [contains('#RRGGBB')]);
    expect(await reloaded.apply(), isFalse);
    expect((await readManifest()).packaging.webLoadingStyle.accent, '#22C55E', reason: 'nothing saved');
    reloaded.setWebLoadingGradientEnabled(false);
    expect(reloaded.webLoadingStyle.gradient, '');
  });

  test('Apply regenerates the web loading screen of a project with a web platform, logo from the project icon', () async {
    writeFlutterWebPlatform(projDir.path);
    final vm = ProjectSettingsViewModel(projectDirPath: projDir.path, hostTargets: host);
    await vm.load();
    vm.setTargetSelected('web', true);
    vm.setWebLoadingTitle('Barrel Run');
    vm.setWebLoadingAccent('#FB7C01');
    expect(await vm.apply(), isTrue);
    final web = '${projDir.path}/web';
    final index = File('$web/index.html').readAsStringSync();
    expect(index, contains('<title>Barrel Run</title>'));
    expect(index, contains('loading.css'));
    expect(File('$web/loading.js').readAsStringSync(), contains('window.luminaLoading'));
    expect(File('$web/flutter_bootstrap.js').existsSync(), isTrue);
    final logo = img.decodePng(File('$web/loading_logo.png').readAsBytesSync())!;
    expect((logo.width, logo.height), (512, 512), reason: 'the rasterized project icon (the Lumina logo)');
    expect(vm.webLoadingStatus, contains('web/index.html'));
  });

  test('Choose copies a logo into the project; Use Project Icon and No Logo switch back', () async {
    final vm = ProjectSettingsViewModel(projectDirPath: projDir.path, hostTargets: host);
    await vm.load();
    final source = File('${tempDir.path}/splash.png')..writeAsBytesSync(img.encodePng(img.Image(width: 16, height: 16)));
    expect(await vm.chooseWebLoadingLogo(source.path), isNull);
    expect(vm.webLoadingStyle.logo, 'branding/web_loading_logo.png');
    expect(File('${projDir.path}/branding/web_loading_logo.png').readAsBytesSync(), source.readAsBytesSync());
    expect(vm.webLoadingLogoFile!.path, '${projDir.path}/branding/web_loading_logo.png');
    final notes = File('${tempDir.path}/notes.txt')..writeAsStringSync('hi');
    expect(await vm.chooseWebLoadingLogo(notes.path), contains('must be a'));
    expect(vm.webLoadingStyle.logo, 'branding/web_loading_logo.png', reason: 'a refused file changes nothing');
    vm.useNoWebLoadingLogo();
    expect(vm.webLoadingStyle.logo, ProjectWebLoadingStyle.logoNone);
    vm.useProjectIconAsWebLoadingLogo();
    expect(vm.webLoadingStyle.logo, ProjectWebLoadingStyle.logoFromIcon);
    expect(vm.webLoadingLogoFile, isNull);
  });

  test('Open in Browser serves the generated page (preview mode) on localhost', () async {
    writeFlutterWebPlatform(projDir.path);
    final vm = ProjectSettingsViewModel(projectDirPath: projDir.path, hostTargets: host);
    addTearDown(vm.dispose);
    await vm.load();
    vm.setWebLoadingTitle('Preview Me');
    Uri? opened;
    vm.openUrl = (url) async => opened = url;
    final url = await vm.previewWebLoadingInBrowser();
    expect(url, isNotNull, reason: vm.webLoadingError);
    expect(opened, url);
    final client = realHttpClient();
    addTearDown(client.close);
    Future<(int, String)> get(String path) async {
      final response = await (await client.getUrl(url!.resolve(path))).close();
      return (response.statusCode, await response.transform(const Utf8Decoder(allowMalformed: true)).join());
    }

    final (status, html) = await get('/');
    expect(status, 200);
    expect(html, contains('<title>Preview Me</title>'));
    expect(html, contains('data-lumina-preview'));
    expect((await get('/loading.js')).$2, contains('window.luminaLoading'));
    expect((await get('/loading_logo.png')).$1, 200);
    expect(File('${projDir.path}/web/index.html').readAsStringSync(), isNot(contains('Preview Me')),
        reason: "the preview does not touch the game's web/ before Apply");
  });

  test('packaging the web target writes the loading screen before its build', () async {
    writeFlutterWebPlatform(projDir.path);
    File('${projDir.path}/contents/levels/L_Main.lmas').writeAsStringSync(jsonEncode({
      'assetId': 'level_L_Main',
      'name': 'L_Main',
      'type': 'level',
      'relativePath': 'contents/levels/L_Main.lmas',
      'metadata': {'actors': <Map<String, dynamic>>[]},
    }));
    final module = FlutterFilamentWebModule.locate();
    if (module == null) return markTestSkipped('flutter_filament web module not built');
    final recordDir = Directory('${tempDir.path}/record')..createSync();
    final vm = ProjectSettingsViewModel(projectDirPath: projDir.path, hostTargets: host, processStarter: flutterBuildStandIn(recordDir));
    await vm.load();
    vm.setTargetSelected('linux', false);
    vm.setTargetSelected('web', true);
    vm.setWebLoadingTitle('Packaged Title');
    vm.setWebLoadingProgressStyle('percentage');
    expect(await vm.packageProject(), BuildStepStatus.ok, reason: vm.packagingLog.map((l) => '[${l.source}] ${l.message}').join('\n'));
    final index = File('${projDir.path}/web/index.html').readAsStringSync();
    expect(index, contains('<title>Packaged Title</title>'), reason: 'the working copy is packaged, before Apply');
    expect(index, contains('lumina-loading-percent-large'));
    expect(File('${projDir.path}/web/loading_logo.png').existsSync(), isTrue);
    expect(vm.packagingLog.where((l) => l.target == 'web').any((l) => l.message.startsWith('Web loading screen "Packaged Title"')), isTrue,
        reason: vm.packagingLog.map((l) => l.message).join('\n'));
  });

  testWidgets('the Web Loading Style section appears only with the web target; edits reach the preview and persist', (tester) async {
    final vm = ProjectSettingsViewModel(projectDirPath: projDir.path, hostTargets: host, webModulePackageRoots: const []);
    await tester.runAsync(vm.load);
    await pumpEditor(tester, vm);
    expect(find.byKey(const ValueKey('project_settings_web_loading')), findsNothing, reason: 'only Linux is ticked');

    await tester.ensureVisible(find.byKey(const ValueKey('project_settings_target_web')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('project_settings_target_web')));
    await tester.pump();
    expect(vm.project.packaging.targets, ['linux', 'web']);
    expect(find.byKey(const ValueKey('project_settings_web_loading')), findsOneWidget);
    expect(find.text('WEB LOADING STYLE'), findsNothing, reason: 'section titles are not upper-cased');
    expect(find.text('Web Loading Style'), findsOneWidget);
    for (final key in [
      'background',
      'gradient_toggle',
      'accent',
      'text',
      'logo_choose',
      'title',
      'subtitle',
      'progress_style',
      'fade',
      'preview',
      'open_browser',
    ]) {
      expect(find.byKey(ValueKey('project_settings_web_loading_$key')), findsOneWidget, reason: key);
    }
    expect(find.descendant(of: find.byKey(const ValueKey('project_settings_web_loading_fade')), matching: find.byType(SliderField)), findsOneWidget);

    // The preview shows the project name until a title is typed.
    final preview = find.byKey(const ValueKey('project_settings_web_loading_preview'));
    expect(find.descendant(of: preview, matching: find.text('wls_game')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('project_settings_web_loading_title')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('project_settings_web_loading_title')), 'My Game');
    await tester.pump();
    expect(vm.webLoadingStyle.title, 'My Game');
    expect(find.descendant(of: preview, matching: find.text('My Game')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('project_settings_web_loading_gradient_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('project_settings_web_loading_gradient_toggle')));
    await tester.pump();
    expect(vm.webLoadingStyle.gradient, isNotEmpty);
    expect(find.byKey(const ValueKey('project_settings_web_loading_gradient')), findsOneWidget);
    final box = tester.widget<Container>(find.descendant(of: preview, matching: find.byType(Container)).first);
    expect((box.decoration! as BoxDecoration).gradient, isA<LinearGradient>());

    vm.setWebLoadingProgressStyle('percentage');
    await tester.pump();
    expect(find.descendant(of: preview, matching: find.text('42%')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('project_settings_apply')));
    await tester.tap(find.byKey(const ValueKey('project_settings_apply')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    final saved = (await tester.runAsync(readManifest))!;
    expect(saved.packaging.webLoadingStyle.title, 'My Game');
    expect(saved.packaging.webLoadingStyle.progressStyle, 'percentage');

    // Unticking web hides the section again; the style stays in the manifest.
    await tester.ensureVisible(find.byKey(const ValueKey('project_settings_target_web')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('project_settings_target_web')));
    await tester.pump();
    expect(find.byKey(const ValueKey('project_settings_web_loading')), findsNothing);
    expect(vm.webLoadingStyle.title, 'My Game');
  });

  test('WebLoadingPreview labels follow loading.js phases', () {
    expect(WebLoadingPreview.labelFor(0.1), 'Downloading the engine');
    expect(WebLoadingPreview.labelFor(0.57), 'Starting the engine');
    expect(WebLoadingPreview.labelFor(0.7), 'Downloading the renderer');
    expect(WebLoadingPreview.labelFor(0.9), 'Loading game assets');
    expect(WebLoadingPreview.labelFor(1), 'Starting the game');
  });
}
