import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart';
import 'package:lumina_ui/ui/features/launcher/services/installed_template_repository.dart';

/// The launcher lists `<config>/templates/<Folder>/` through the shared game
/// template check (`checkGameTemplate`), so a
/// folder the Marketplace server would refuse is not offered in the Create
/// Project dialog either, and for the same reasons. Real folders on disk.
void main() {
  late Directory config;
  late InstalledTemplateRepository repo;

  setUp(() {
    config = Directory.systemTemp.createTempSync('installed_templates_');
    repo = InstalledTemplateRepository.forConfigDir(config);
  });

  tearDown(() {
    if (config.existsSync()) config.deleteSync(recursive: true);
  });

  /// A template folder as the installer leaves it: the source project's
  /// manifest, `template.json`, a thumbnail, a level under `contents/`, the
  /// license notice. [extra] adds or overwrites files (null deletes).
  Directory writeTemplate(String folder, {Map<String, String?> extra = const {}}) {
    final dir = Directory('${config.path}/templates/$folder')..createSync(recursive: true);
    final files = <String, String?>{
      'arena_source.lmproject': jsonEncode({
        'project_name': 'arena_source',
        'description': 'from the manifest',
        'engine_version': '0.9.0',
      }),
      'template.json': jsonEncode({
        'format': 1,
        'title': 'Arena Starter',
        'description': 'A starter arena.',
        'engine_version': '1.0.0',
        'thumbnail': 'thumbnail.png',
      }),
      'thumbnail.png': 'png',
      'contents/levels/L_DefaultLevel.lmas': '{}',
      'LICENSE-$folder.txt': 'CC-BY-4.0',
      ...extra,
    };
    files.forEach((path, content) {
      final f = File('${dir.path}/$path');
      if (content == null) {
        if (f.existsSync()) f.deleteSync();
        return;
      }
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(content);
    });
    return dir;
  }

  /// What the shared check says about [dir] read as an archive with [dir]'s
  /// name as its top folder.
  List<String> sharedProblems(Directory dir) {
    final name = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final paths = [
      for (final f in dir.listSync(recursive: true).whereType<File>()) '$name/${f.path.substring(dir.path.length + 1)}',
    ];
    return checkGameTemplate(paths, read: (p) => File('${dir.path}/${p.substring(name.length + 1)}').readAsBytesSync())
        .problems
        .map((p) => p.message)
        .toList();
  }

  String reasonFor(String folder) => repo.invalid.singleWhere((i) => i.path.endsWith('/$folder')).reason;

  test('a valid template folder is listed with its manifest, project and thumbnail', () {
    final dir = writeTemplate('Arena_Starter');
    expect(sharedProblems(dir), isEmpty);

    final found = repo.scan();
    expect(found.map((t) => t.folderName), ['Arena_Starter']);
    final t = found.single;
    expect(t.id, 'marketplace:Arena_Starter');
    expect(t.title, 'Arena Starter');
    expect(t.description, 'A starter arena.');
    expect(t.engineVersion, '1.0.0');
    expect(t.thumbnailPath, '${dir.path}/thumbnail.png');
    expect(t.lmprojectPath, '${dir.path}/arena_source.lmproject');
    expect(repo.invalid, isEmpty);
  });

  test('without template.json the single .lmproject names and describes it', () {
    final dir = writeTemplate('Project_Only', extra: {'template.json': null, 'thumbnail.png': null, 'screenshot.jpg': 'jpg'});

    final t = repo.scan().single;
    expect(t.title, 'arena_source');
    expect(t.description, 'from the manifest');
    expect(t.engineVersion, '0.9.0');
    expect(t.thumbnailPath, '${dir.path}/screenshot.jpg', reason: 'the shared card screenshot names');
  });

  test('folders the server would refuse are skipped, with the shared check\'s reasons', () {
    final folders = {
      // Build output and platform folders are not part of a template.
      'With_Build': writeTemplate('With_Build', extra: {'build/linux/x64/app': 'elf'}),
      'With_Platform': writeTemplate('With_Platform', extra: {'linux/CMakeLists.txt': 'project(x)'}),
      // template.json names a thumbnail that is not there.
      'Missing_Thumbnail': writeTemplate('Missing_Thumbnail', extra: {'thumbnail.png': null}),
      // A path dependency pointing at the publisher's machine.
      'Outside_Path_Dep': writeTemplate('Outside_Path_Dep', extra: {
        'pubspec.yaml': 'name: arena_source\ndependencies:\n  helpers:\n    path: ../helpers\n',
      }),
      // contents/ exists but holds no files.
      'Empty_Contents': writeTemplate('Empty_Contents', extra: {'contents/levels/L_DefaultLevel.lmas': null}),
      'Two_Projects': writeTemplate('Two_Projects', extra: {'other.lmproject': jsonEncode({'project_name': 'other'})}),
      'Bad_Format': writeTemplate('Bad_Format', extra: {'template.json': jsonEncode({'format': 2, 'title': 'Next'})}),
    };
    writeTemplate('Good');

    expect(repo.scan().map((t) => t.folderName), ['Good']);
    expect(repo.invalid.map((i) => i.path.split('/').last), unorderedEquals(folders.keys));

    // One rule set: the launcher's reason is exactly what the server's check says.
    folders.forEach((name, dir) {
      final shared = sharedProblems(dir);
      expect(shared, isNotEmpty, reason: name);
      expect(reasonFor(name), shared.join('; '), reason: name);
    });
    expect(reasonFor('With_Build'), contains('build/ must be left out'));
    expect(reasonFor('With_Platform'), contains('linux/ must be left out'));
    expect(reasonFor('Missing_Thumbnail'), contains('which is not a file in the archive'));
    expect(reasonFor('Outside_Path_Dep'), contains('points outside the template'));
    expect(reasonFor('Empty_Contents'), contains('no contents/ folder with files'));
    expect(reasonFor('Two_Projects'), contains('a template is one project'));
    expect(reasonFor('Bad_Format'), contains('"format" is 2'));
  });

  test('a reinstall backup (dot folder) is not a template and not reported', () {
    writeTemplate('.Arena.marketplace-previous', extra: {'build/x': 'y'});
    expect(repo.scan(), isEmpty);
    expect(repo.invalid, isEmpty);
  });
}
