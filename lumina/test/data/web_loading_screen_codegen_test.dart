import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/lumina.dart';

/// The web build's plain HTML loading
/// screen, generated from `packaging.web_loading_style` in the `.lmproject`.

/// A URL that would make the page load something from another origin: an
/// `http(s)://` or protocol-relative `//host.tld` reference.
final _externalUrl = RegExp(r'(?:https?:)?//[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}');

Uint8List _png(int size, img.Color color) => img.encodePng(img.Image(width: size, height: size)..clear(color));

/// A project folder with the `web/` a `flutter create` leaves behind: an
/// index.html and the app icons (which packaging rewrites from the project
/// icon).
Directory _projectWithWeb(Directory root) {
  final project = Directory('${root.path}/my_game')..createSync();
  Directory('${project.path}/web/icons').createSync(recursive: true);
  File('${project.path}/web/index.html').writeAsStringSync('<!DOCTYPE html><html><body>'
      '<script src="flutter_bootstrap.js" async></script></body></html>');
  File('${project.path}/web/icons/Icon-512.png').writeAsBytesSync(_png(512, img.ColorRgb8(251, 124, 1)));
  return project;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('wls_codegen_'));
  tearDown(() => root.deleteSync(recursive: true));

  group('ProjectWebLoadingStyle', () {
    test('a manifest without a style reads the defaults', () {
      final project = LuminaProject.fromMap({
        'project_name': 'my_game',
        'packaging': {'targets': ['web'], 'output_dir': 'build'},
      });
      final style = project.packaging.webLoadingStyle;
      expect(style.background, '');
      expect(style.gradient, '');
      expect(style.accent, ProjectWebLoadingStyle.defaultAccent);
      expect(style.text, ProjectWebLoadingStyle.defaultText);
      expect(style.logo, ProjectWebLoadingStyle.logoFromIcon);
      expect(style.title, '');
      expect(style.progressStyle, 'bar');
      expect(style.fadeMs, ProjectWebLoadingStyle.defaultFadeMs);
    });

    test('round-trips through the .lmproject JSON', () {
      const style = ProjectWebLoadingStyle(
        background: '#101820',
        gradient: '#303848',
        accent: '#FB7C01',
        text: '#EEEEEE',
        logo: 'branding/splash.png',
        title: 'My Game',
        subtitle: 'A tale of barrels',
        progressStyle: 'ring',
        fadeMs: 900,
      );
      final project = LuminaProject(
        projectName: 'my_game',
        packaging: const ProjectPackagingSettings(targets: ['linux', 'web'], webLoadingStyle: style),
      );
      final map = jsonDecode(jsonEncode(project.toMap())) as Map<String, dynamic>;
      expect((map['packaging'] as Map)['web_loading_style'], {
        'background': '#101820',
        'gradient': '#303848',
        'accent': '#FB7C01',
        'text': '#EEEEEE',
        'logo': 'branding/splash.png',
        'title': 'My Game',
        'subtitle': 'A tale of barrels',
        'progress_style': 'ring',
        'fade_ms': 900,
      });
      final back = LuminaProject.fromMap(map).packaging;
      expect(back.targets, ['linux', 'web']);
      expect(back.webLoadingStyle.toMap(), style.toMap());
      // Other packaging edits keep the style.
      expect(back.withTarget('web', false).webLoadingStyle.toMap(), style.toMap());
      expect(back.copyWith(outputDir: 'out').webLoadingStyle.toMap(), style.toMap());
    });

    test('empty fields resolve from the project branding and name', () {
      const project = LuminaProject(
        projectName: 'barrel_run',
        branding: ProjectBrandingSettings(iconBackground: '#223344'),
      );
      final resolved = project.packaging.webLoadingStyle.resolve(project);
      expect(resolved.background, '#223344', reason: 'the background defaults to the Icon Background');
      expect(resolved.title, 'barrel_run', reason: 'the title defaults to the project name');
      expect(resolved.gradient, isNull);
      expect(resolved.accent, '#FB7C01');
    });

    test('colours that are not #RRGGBB fall back instead of reaching the CSS', () {
      const project = LuminaProject(
        projectName: 'p',
        packaging: ProjectPackagingSettings(
          webLoadingStyle: ProjectWebLoadingStyle(accent: 'red;} body{display:none', gradient: 'nope', progressStyle: 'spinner'),
        ),
      );
      final style = project.packaging.webLoadingStyle;
      expect(style.problems(), hasLength(3));
      final resolved = style.resolve(project);
      expect(resolved.accent, ProjectWebLoadingStyle.defaultAccent);
      expect(resolved.gradient, isNull);
      expect(resolved.progressStyle, 'bar');
    });
  });

  group('WebLoadingScreenService', () {
    test('accent #FB7C01, title "My Game" and the default logo: index.html has the title, links loading.css/js, no external URL, and the logo is in web/', () {
      final dir = _projectWithWeb(root);
      const project = LuminaProject(
        projectName: 'my_game',
        packaging: ProjectPackagingSettings(
          targets: ['web'],
          webLoadingStyle: ProjectWebLoadingStyle(accent: '#FB7C01', title: 'My Game'),
        ),
      );
      final report = WebLoadingScreenService.write(projectDir: dir.path, project: project);

      final web = '${dir.path}/web';
      final index = File('$web/index.html').readAsStringSync();
      final css = File('$web/loading.css').readAsStringSync();
      final js = File('$web/loading.js').readAsStringSync();
      final bootstrap = File('$web/flutter_bootstrap.js').readAsStringSync();
      expect(index, contains('<title>My Game</title>'));
      expect(index, contains('<h1 class="lumina-loading-title">My Game</h1>'));
      expect(index, contains('<link rel="stylesheet" href="loading.css">'));
      expect(index, contains('<script src="loading.js"></script>'));
      expect(index, contains('<script src="flutter_bootstrap.js" async></script>'));
      expect(index, contains(r'<base href="$FLUTTER_BASE_HREF">'), reason: 'flutter build web still sets the base href');
      expect(index.indexOf('loading.js'), lessThan(index.indexOf('flutter_bootstrap.js')),
          reason: 'loading.js wraps fetch and the loader before the bootstrap runs');
      expect(css, contains('#FB7C01'));
      for (final (name, text) in [('index.html', index), ('loading.css', css), ('loading.js', js), ('flutter_bootstrap.js', bootstrap)]) {
        expect(_externalUrl.firstMatch(text)?.group(0), isNull, reason: '$name loads nothing from another origin');
        expect(text, isNot(contains('@import')), reason: '$name pulls in no stylesheet or font');
      }

      // The default logo is the project icon: packaging wrote it as the web app icon.
      expect(report.logoFile, 'loading_logo.png');
      final logo = File('$web/loading_logo.png');
      expect(logo.existsSync(), isTrue);
      expect(logo.readAsBytesSync(), File('$web/icons/Icon-512.png').readAsBytesSync());
      expect(index, contains('src="loading_logo.png"'));
      expect(report.files, containsAll(['web/index.html', 'web/loading.css', 'web/loading.js', 'web/flutter_bootstrap.js', 'web/loading_logo.png']));
    });

    test('loading.js exposes window.luminaLoading.progress, wraps _flutter.loader.load and hides on flutter-first-frame', () {
      final js = WebLoadingScreenService.loadingJs(const LuminaProject(projectName: 'p').packaging.webLoadingStyle.resolve(const LuminaProject(projectName: 'p')));
      expect(js, contains('window.luminaLoading = '));
      expect(js, contains('progress: progress'));
      expect(js, contains("addEventListener('flutter-first-frame'"));
      expect(js, contains('attach: attach'));
      expect(js, contains('loader.load = function'));
      expect(js, contains('onEntrypointLoaded'));
      expect(js, contains('window.fetch = function'), reason: 'download progress comes from the real byte stream');
      expect(js, contains('flutter_filament'), reason: 'the renderer wasm is tracked');
      // The phase boundaries the generated main() reports against.
      expect(js, contains('renderer: [${LuminaWebLoading.rendererStart}, ${LuminaWebLoading.rendererEnd}]'));
      expect(js, contains('assets: [${LuminaWebLoading.rendererEnd}, 1]'));

      final bootstrap = WebLoadingScreenService.flutterBootstrapJs();
      expect(bootstrap, contains('{{flutter_js}}'));
      expect(bootstrap, contains('{{flutter_build_config}}'));
      expect(bootstrap.indexOf('window.luminaLoading.attach(_flutter.loader)'), lessThan(bootstrap.indexOf('_flutter.loader.load(')));
    });

    test('the generated scripts parse (node --check, when Node is installed)', () {
      final node = Process.runSync('which', ['node']);
      if (node.exitCode != 0) {
        markTestSkipped('node is not installed');
        return;
      }
      const project = LuminaProject(projectName: 'p');
      final resolved = project.packaging.webLoadingStyle.resolve(project);
      for (final (name, js) in [
        ('loading.js', WebLoadingScreenService.loadingJs(resolved)),
        ('preview_loading.js', WebLoadingScreenService.loadingJs(resolved, preview: true)),
      ]) {
        final file = File('${root.path}/$name')..writeAsStringSync(js);
        final check = Process.runSync((node.stdout as String).trim(), ['--check', file.path]);
        expect(check.exitCode, 0, reason: '$name: ${check.stderr}');
      }
    });

    test('the style reaches the CSS and the markup: gradient, colours, fade, progress style', () {
      const project = LuminaProject(
        projectName: 'p',
        packaging: ProjectPackagingSettings(
          webLoadingStyle: ProjectWebLoadingStyle(background: '#101820', gradient: '#304050', text: '#ABCDEF', fadeMs: 750, progressStyle: 'ring'),
        ),
      );
      final resolved = project.packaging.webLoadingStyle.resolve(project);
      final css = WebLoadingScreenService.loadingCss(resolved);
      expect(css, contains('--lumina-bg: #101820;'));
      expect(css, contains('linear-gradient(180deg, #101820, #304050)'));
      expect(css, contains('--lumina-text: #ABCDEF;'));
      expect(css, contains('--lumina-fade: 750ms;'));
      expect(WebLoadingScreenService.loadingJs(resolved), contains('var FADE_MS = 750;'));

      final ring = WebLoadingScreenService.indexHtml(resolved, logoFile: null);
      expect(ring, contains('class="lumina-loading-ring"'));
      expect(ring, isNot(contains('class="lumina-loading-bar"')));
      expect(ring, isNot(contains('<img')), reason: 'no logo, no image tag');

      final bar = WebLoadingScreenService.indexHtml(
          const ProjectWebLoadingStyle().resolve(project), logoFile: 'loading_logo.png');
      expect(bar, contains('class="lumina-loading-bar"'));
      final percent = WebLoadingScreenService.indexHtml(
          const ProjectWebLoadingStyle(progressStyle: 'percentage').resolve(project), logoFile: null);
      expect(percent, contains('class="lumina-loading-percent lumina-loading-percent-large"'));
      expect(percent, isNot(contains('class="lumina-loading-bar"')));
      expect(percent, isNot(contains('class="lumina-loading-ring"')));
    });

    test('title and subtitle are HTML-escaped', () {
      const project = LuminaProject(
        projectName: 'p',
        packaging: ProjectPackagingSettings(
          webLoadingStyle: ProjectWebLoadingStyle(title: '<script>alert(1)</script>', subtitle: 'Tom & "Jerry"'),
        ),
      );
      final html = WebLoadingScreenService.indexHtml(project.packaging.webLoadingStyle.resolve(project), logoFile: null);
      expect(html, isNot(contains('<script>alert')));
      expect(html, contains('&lt;script&gt;alert(1)&lt;/script&gt;'));
      expect(html, contains('Tom &amp; &quot;Jerry&quot;'));
    });

    test('logo: the rasterized project icon, the icon file, a chosen image, or none', () {
      final dir = _projectWithWeb(root);
      final web = '${dir.path}/web';
      // The editor hands over its rasterized project icon.
      final icon = _png(256, img.ColorRgb8(10, 200, 30));
      var report = WebLoadingScreenService.write(projectDir: dir.path, project: const LuminaProject(projectName: 'p'), iconPng: icon);
      expect(report.logoFile, 'loading_logo.png');
      expect(File('$web/loading_logo.png').readAsBytesSync(), icon);

      // A project icon file (an SVG shows as it is in a browser).
      Directory('${dir.path}/branding').createSync();
      File('${dir.path}/branding/app_icon.svg').writeAsStringSync('<svg viewBox="0 0 10 10"><rect width="10" height="10" fill="#f00"/></svg>');
      report = WebLoadingScreenService.write(
          projectDir: dir.path, project: const LuminaProject(projectName: 'p', branding: ProjectBrandingSettings(icon: 'branding/app_icon.svg')));
      expect(report.logoFile, 'loading_logo.svg');
      expect(File('$web/loading_logo.svg').existsSync(), isTrue);
      expect(File('$web/loading_logo.png').existsSync(), isFalse, reason: 'a stale logo with another extension goes');

      // A chosen image.
      File('${dir.path}/branding/splash.jpg').writeAsBytesSync(img.encodeJpg(img.Image(width: 8, height: 8)));
      report = WebLoadingScreenService.write(
          projectDir: dir.path,
          project: const LuminaProject(
              projectName: 'p', packaging: ProjectPackagingSettings(webLoadingStyle: ProjectWebLoadingStyle(logo: 'branding/splash.jpg'))));
      expect(report.logoFile, 'loading_logo.jpg');
      expect(File('$web/loading_logo.jpg').lengthSync(), File('${dir.path}/branding/splash.jpg').lengthSync());

      // A chosen image that is gone: no logo, and the report says why.
      report = WebLoadingScreenService.write(
          projectDir: dir.path,
          project: const LuminaProject(
              projectName: 'p', packaging: ProjectPackagingSettings(webLoadingStyle: ProjectWebLoadingStyle(logo: 'branding/gone.png'))));
      expect(report.logoFile, isNull);
      expect(report.warnings.single, contains('branding/gone.png'));
      expect(File('$web/index.html').readAsStringSync(), isNot(contains('<img')));
    });

    test('a project without a web folder is reported, not created', () {
      final dir = Directory('${root.path}/desktop_only')..createSync();
      final report = WebLoadingScreenService.write(projectDir: dir.path, project: const LuminaProject(projectName: 'p'));
      expect(report.written, isFalse);
      expect(report.skippedReason, contains('web'));
      expect(Directory('${dir.path}/web').existsSync(), isFalse);
    });

    test('a browser preview writes the same page without the Flutter bootstrap into its own folder', () {
      final dir = _projectWithWeb(root);
      final out = '${root.path}/preview';
      final report = WebLoadingScreenService.write(projectDir: dir.path, project: const LuminaProject(projectName: 'p'), outDir: out, preview: true);
      expect(report.written, isTrue);
      final index = File('$out/index.html').readAsStringSync();
      expect(index, contains('data-lumina-preview'));
      expect(index, isNot(contains('flutter_bootstrap.js')));
      expect(File('$out/loading.js').existsSync(), isTrue);
      expect(File('${dir.path}/web/loading.js').existsSync(), isFalse, reason: "the preview leaves the game's web/ alone");
    });
  });

  group('generated main()', () {
    test('loads the renderer and the bundle behind the loading screen before runApp', () {
      final code = DartCodeGeneratorService().generateMainDart(projectName: 'my_game');
      expect(code, contains('Future<void> main() async {'));
      final prepare = code.indexOf('await LuminaWebLoading.prepareGame();');
      expect(prepare, greaterThan(code.indexOf('LuminaAssets.defaultProvider = ')),
          reason: 'the preload serves through the bundle provider');
      expect(prepare, lessThan(code.indexOf('runApp(')));
      expect(code, isNot(contains('dart:js_interop')), reason: 'the web hook lives behind a conditional import in lumina');
    });
  });

  group('LuminaWebLoading', () {
    test('native builds skip the web preparation', () async {
      final before = LuminaAssets.defaultProvider;
      await LuminaWebLoading.prepareGame();
      expect(LuminaWebLoading.isWeb, isFalse);
      expect(identical(LuminaAssets.defaultProvider, before), isTrue);
    });

    test('preloadAssets reads every bundled asset under a prefix, reports the count and serves the bytes once', () async {
      final previous = LuminaAssets.defaultProvider;
      addTearDown(() => LuminaAssets.defaultProvider = previous);
      final requested = <String>[];
      LuminaAssets.defaultProvider = (path) async {
        requested.add(path);
        final data = await rootBundle.load(path);
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      };
      final reports = <(int, int)>[];
      final count = await LuminaWebLoading.preloadAssets(rootBundle, prefix: 'assets/sky/', onProgress: (d, t) => reports.add((d, t)), keepFor: null);
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final sky = manifest.listAssets().where((a) => a.startsWith('assets/sky/')).toList();
      expect(sky, isNotEmpty);
      expect(count, sky.length);
      expect(reports.first, (0, sky.length));
      expect(reports.last, (sky.length, sky.length));
      expect(LuminaWebLoading.preloadedCount, sky.length);

      final moon = sky.firstWhere((a) => a.endsWith('moon_disk.png'));
      final expected = await rootBundle.load(moon);
      final bytes = await LuminaAssets.resolve(null)(moon);
      expect(bytes, expected.buffer.asUint8List(expected.offsetInBytes, expected.lengthInBytes));
      expect(requested, isEmpty, reason: 'the first load is served from the preload');
      await LuminaAssets.resolve(null)(moon);
      expect(requested, [moon], reason: 'a preloaded asset is handed out once, then read from the bundle again');
      LuminaWebLoading.releasePreloaded();
      expect(LuminaWebLoading.preloadedCount, 0);
    });
  });
}
