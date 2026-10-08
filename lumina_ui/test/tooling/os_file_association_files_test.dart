import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart' show ModelFileThumbnailer, ModelThumbnailCommand;
import 'package:path/path.dart' as p;

/// What the installers register for 3D model files and Lumina assets, read
/// from the real installer sources: Lumina Studio in the file managers' "Open
/// with" (never as the default program of a model type; the default of its
/// own `.lmas` when nothing else is) and the thumbnailer that renders the
/// files' previews with the editor (`lumina_ui --lumina-thumbnail`).
void main() {
  final repo = Directory.current.parent.path;
  String read(String relative) => File(p.joinAll([repo, ...relative.split('/')])).readAsStringSync();

  final iss = read('installer/windows/lumina-studio.iss');
  final provider = read('installer/windows/thumbnail_provider/lumina_thumbnail_provider.cpp');
  final desktop = read('installer/linux/io.github.luminagame.LuminaStudio.desktop');
  final thumbnailer = read('installer/linux/lumina-studio.thumbnailer');
  final thumbnailerScript = read('installer/linux/lumina-thumbnailer');
  final mime = read('installer/linux/lumina-studio-models.xml');
  final nfpm = read('installer/linux/nfpm.yaml');

  const extensions = ['.glb', '.gltf', '.fbx', '.obj'];
  const mimeTypes = ['model/gltf-binary', 'model/gltf+json', 'model/x-fbx', 'model/obj', 'application/x-lumina-asset'];
  final registry = iss.split(RegExp(r'\r?\n')).where((l) => l.startsWith('Root: HKA;')).toList();
  Iterable<String> linesFor(String subkey) => registry.where((l) => l.contains('Subkey: "$subkey"'));

  test('the editor and the thumbnailer handle the same file types', () {
    expect(ModelFileThumbnailer.supportedExtensions, extensions.toSet());
    expect(ModelThumbnailCommand.supportedExtensions, {...extensions, '.lmas'});
    for (final e in [...extensions, '.lmas']) {
      expect(provider, contains('L"$e"'), reason: 'the shell provider lists $e');
    }
    expect(provider, contains('memcmp(head, "LMAS", 4) == 0) return L".lmas"'), reason: 'an LMAS stream without a name');
  });

  group('Windows setup', () {
    test('a ProgID opens the file with the editor', () {
      expect(iss, contains('#define ModelProgId "LuminaStudio.Model"'));
      expect(linesFor(r'Software\Classes\{#ModelProgId}\shell\open\command').single,
          contains(r'ValueData: """{app}\{#AppExe}"" ""%1"""'));
      expect(linesFor(r'Software\Classes\{#ModelProgId}').single, contains('uninsdeletekey'));
    });

    test('every type lists the ProgID under OpenWithProgids, removed on uninstall', () {
      for (final e in extensions) {
        final value = linesFor('Software\\Classes\\$e\\OpenWithProgids').where((l) => l.contains('ValueName: "{#ModelProgId}"'));
        expect(value.single, allOf(contains('ValueType: none'), contains('uninsdeletevalue'), contains('Tasks: modelfiles')));
      }
    });

    test('the editor lists every type as supported, under one key removed on uninstall', () {
      expect(linesFor(r'Software\Classes\Applications\{#AppExe}').single, contains('uninsdeletekey'));
      for (final e in extensions) {
        expect(linesFor(r'Software\Classes\Applications\{#AppExe}\SupportedTypes').where((l) => l.contains('ValueName: "$e"')),
            hasLength(1));
      }
    });

    test('no default program is changed and no extension key gets a handler', () {
      for (final e in extensions) {
        final own = linesFor('Software\\Classes\\$e');
        expect(own.where((l) => l.contains('ValueType')), isEmpty, reason: 'the default value of $e is never written');
        expect(own.single, contains('uninsdeletekeyifempty'));
        expect(registry.where((l) => l.contains('Software\\Classes\\$e\\ShellEx')), isEmpty);
      }
    });

    test('Explorer is told about the change', () {
      expect(iss, contains('ChangesAssociations=yes'));
    });

    test('the thumbnail provider class is the one the DLL implements', () {
      final define = RegExp(r'#define ThumbnailClsid "\{\{([0-9A-F-]+)\}"').firstMatch(iss);
      expect(define, isNotNull);
      expect(provider, contains('kClsidString[] = L"{${define!.group(1)}}"'));
      expect(linesFor(r'Software\Classes\CLSID\{#ThumbnailClsid}').single, contains('uninsdeletekey'));
      final inproc = linesFor(r'Software\Classes\CLSID\{#ThumbnailClsid}\InprocServer32').toList();
      expect(inproc.any((l) => l.contains(r'ValueData: "{app}\setup\shell\{#ProviderDll}"')), isTrue);
      expect(inproc.any((l) => l.contains('ValueName: "ThreadingModel"; ValueData: "Apartment"')), isTrue);
      expect(iss, contains('#define ThumbnailHandler "{{e357fccd-a995-4576-b01f-234630154e96}"'));
    });

    test('each type gets the thumbnail handler under SystemFileAssociations, removed on uninstall', () {
      for (final e in extensions) {
        final handler = linesFor('Software\\Classes\\SystemFileAssociations\\$e\\ShellEx\\{#ThumbnailHandler}').single;
        expect(handler, allOf(contains('ValueData: "{#ThumbnailClsid}"'), contains('uninsdeletekey')));
      }
    });

    test('.lmas opens with Lumina Studio, its own default program unless another one is', () {
      expect(iss, contains('#define AssetProgId "LuminaStudio.Asset"'));
      expect(iss, contains('Name: "luminaassets"'));
      expect(linesFor(r'Software\Classes\{#AssetProgId}\shell\open\command').single,
          allOf(contains(r'ValueData: """{app}\{#AppExe}"" ""%1"""'), contains('Tasks: luminaassets')));
      final own = linesFor(r'Software\Classes\.lmas').toList();
      expect(own.where((l) => l.contains('ValueData: "{#AssetProgId}"')).single,
          allOf(contains('createvalueifdoesntexist'), contains('uninsdeletevalue')));
      expect(linesFor(r'Software\Classes\.lmas\OpenWithProgids').where((l) => l.contains('ValueName: "{#AssetProgId}"')).single,
          contains('uninsdeletevalue'));
      expect(linesFor(r'Software\Classes\Applications\{#AppExe}\SupportedTypes').where((l) => l.contains('ValueName: ".lmas"')),
          hasLength(1));
      expect(linesFor(r'Software\Classes\SystemFileAssociations\.lmas\ShellEx\{#ThumbnailHandler}').single,
          allOf(contains('ValueData: "{#ThumbnailClsid}"'), contains('uninsdeletekey'), contains('Tasks: luminaassets')));
      // The provider and its class serve both tasks.
      expect(linesFor(r'Software\Classes\CLSID\{#ThumbnailClsid}').single, contains('Tasks: modelfiles or luminaassets'));
      expect(iss, contains(r'DestDir: "{app}\setup\shell"; Flags: ignoreversion; Tasks: modelfiles or luminaassets'));
    });

    test('the provider DLL ships only when build.ps1 built it', () {
      final files = iss.substring(iss.indexOf('[Files]'), iss.indexOf('[Registry]'));
      expect(files, contains('#ifdef ThumbnailProviderDir'));
      expect(files, contains(r'Source: "{#ThumbnailProviderDir}\{#ProviderDll}"; DestDir: "{app}\setup\shell"'));
      expect(read('installer/windows/build.ps1'), contains(r'/DThumbnailProviderDir=$providerOut'));
    });
  });

  group('Linux package', () {
    test('the .desktop entry opens files and names the four types', () {
      expect(desktop, contains('\nExec=lumina-studio %F\n'));
      final line = desktop.split('\n').firstWhere((l) => l.startsWith('MimeType='));
      expect(line.substring('MimeType='.length).split(';').where((t) => t.isNotEmpty), mimeTypes);
    });

    test('the MIME package defines each type with its glob', () {
      final globs = {
        'model/gltf-binary': '*.glb',
        'model/gltf+json': '*.gltf',
        'model/x-fbx': '*.fbx',
        'model/obj': '*.obj',
        'application/x-lumina-asset': '*.lmas',
      };
      for (final entry in globs.entries) {
        final start = mime.indexOf('<mime-type type="${entry.key}">');
        expect(start, greaterThanOrEqualTo(0), reason: entry.key);
        final block = mime.substring(start, mime.indexOf('</mime-type>', start));
        expect(block, contains('<glob pattern="${entry.value}"'));
      }
      expect(mime, contains('value="Kaydara FBX Binary"'));
      expect(mime, contains('<match type="string" value="LMAS" offset="0"/>'));
    });

    test('the MIME package is well-formed XML', () async {
      final file = p.join(repo, 'installer', 'linux', 'lumina-studio-models.xml');
      final r = await Process.run('powershell', ['-NoProfile', '-Command', "[xml](Get-Content -Raw -LiteralPath '$file') | Out-Null"]);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    }, skip: Platform.isWindows ? false : 'checked with Windows PowerShell');

    test('the thumbnailer entry runs lumina-thumbnailer for the same types', () {
      expect(thumbnailer, contains('[Thumbnailer Entry]'));
      expect(thumbnailer, contains('Exec=lumina-thumbnailer %i %o %s'));
      final line = thumbnailer.split('\n').firstWhere((l) => l.startsWith('MimeType='));
      expect(line.substring('MimeType='.length).split(';').where((t) => t.isNotEmpty), mimeTypes);
      expect(thumbnailerScript, contains('${ModelThumbnailCommand.flag} "\$input" "\$output" --size "\$size"'));
    });

    test('the package installs all three', () {
      for (final pair in const [
        ('lumina-studio-models.xml', '/usr/share/mime/packages/lumina-studio-models.xml'),
        ('lumina-thumbnailer', '/usr/bin/lumina-thumbnailer'),
        ('lumina-studio.thumbnailer', '/usr/share/thumbnailers/lumina-studio.thumbnailer'),
      ]) {
        expect(nfpm, contains('- src: ./installer/linux/${pair.$1}\n    dst: ${pair.$2}\n'));
      }
    });
  });

  group('the runners start the thumbnail mode without a window', () {
    test('Windows and Linux know the flag', () {
      expect(read('lumina_ui/windows/runner/main.cpp'), contains('"${ModelThumbnailCommand.flag}"'));
      expect(read('lumina_ui/linux/runner/my_application.cc'), contains('"${ModelThumbnailCommand.flag}"'));
    });
  });
}
