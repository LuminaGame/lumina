import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:lumina/data/services/game_template_service.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart';

/// Game template marketplace fixtures: a real Lumina project, created by
/// [ProjectRepository.createProject] from a built-in template, packed as a
/// game template archive and published to a real marketplace server.

/// Performs the on-disk part of `flutter create` (pubspec, lib/) and skips
/// `flutter pub get`: nothing here resolves packages.
ProcessRunner templateScaffoldRunner() {
  return (String exec, List<String> args, {String? workingDirectory, bool runInShell = false}) async {
    if (args.isNotEmpty && args.first == 'create') {
      final target = args.last;
      final name = args[args.indexOf('--project-name') + 1];
      Directory('$target/lib').createSync(recursive: true);
      Directory('$target/linux').createSync(recursive: true);
      File('$target/linux/CMakeLists.txt').writeAsStringSync('project($name)\n');
      File('$target/.metadata').writeAsStringSync('version: flutter\n');
      File('$target/pubspec.yaml').writeAsStringSync('name: $name\n'
          "publish_to: 'none'\n"
          'environment:\n'
          '  sdk: ^3.12.0\n'
          'dependencies:\n'
          '  flutter:\n'
          '    sdk: flutter\n'
          'flutter:\n'
          '  uses-material-design: true\n');
      File('$target/lib/main.dart').writeAsStringSync('void main() {}\n');
    }
    return ProcessResult(0, 0, '', '');
  };
}

/// A 320×180 PNG: a sky-to-ground gradient with a sun, as a template card.
List<int> templateThumbnailPng() {
  final image = img.Image(width: 320, height: 180);
  for (var y = 0; y < 180; y++) {
    for (var x = 0; x < 320; x++) {
      final ground = y > 120;
      final t = y / 180;
      image.setPixelRgb(x, y, ground ? 70 : (60 + 120 * t).round(), ground ? 110 : (110 + 90 * t).round(), ground ? 60 : 220);
    }
  }
  img.fillCircle(image, x: 250, y: 50, radius: 22, color: img.ColorRgb8(255, 210, 90));
  return img.encodePng(image);
}

/// Creates [name] from the built-in [template] under [root] (a real
/// scaffold: level, lib/, manifest, pubspec) and adds `template.json` and
/// `thumbnail.png` ([thumbnail], or [templateThumbnailPng]).
Future<Directory> createTemplateSourceProject(
  Directory root, {
  required String name,
  required String title,
  String template = kFirstPersonTemplateId,
  String description = 'A starter arena with a player start, a floor and crates.',
  List<int>? thumbnail,
}) async {
  final config = Directory('${root.path}/.source_config')..createSync(recursive: true);
  await ProjectRepository(configDir: config, processRunner: templateScaffoldRunner())
      .createProject(projectName: name, projectLocation: root.path, template: template);
  final dir = Directory('${root.path}/$name');
  File('${dir.path}/template.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
    'format': 1,
    'title': title,
    'description': description,
    'engine_version': kLuminaEngineVersion,
    'thumbnail': 'thumbnail.png',
  }));
  File('${dir.path}/thumbnail.png').writeAsBytesSync(thumbnail ?? templateThumbnailPng());
  return dir;
}

/// [project] packed as a game template archive under one top-level
/// [topFolder]: `template.json`, the thumbnail, the `.lmproject`,
/// `pubspec.yaml`, `contents/` and `lib/`, without dot files (the server
/// accepts none) or the platform folders `flutter create` regenerates.
List<int> zipGameTemplate(Directory project, {required String topFolder}) {
  final zip = Archive();
  for (final f in project.listSync(recursive: true).whereType<File>()) {
    // Archive paths are '/'-separated (Windows listings use '\').
    final rel = f.path.substring(project.path.length + 1).replaceAll(r'\', '/');
    final segments = rel.split('/');
    if (segments.any((s) => s.startsWith('.'))) continue;
    final top = segments.first;
    final include = segments.length == 1
        ? (rel == 'template.json' || rel == 'thumbnail.png' || rel == 'pubspec.yaml' || rel.endsWith('.lmproject'))
        : (top == 'contents' || top == 'lib');
    if (!include) continue;
    zip.addFile(ArchiveFile.bytes('$topFolder/$rel', f.readAsBytesSync()));
  }
  return ZipEncoder().encode(zip);
}

/// Publishes [zip] as a free game template listing (content CC-BY-4.0, code
/// MIT: the server requires both for a game template) with [screenshot].
Future<Listing> publishGameTemplate(
  MarketplaceClient publisher, {
  required List<int> zip,
  required String title,
  required List<int> screenshot,
  String version = '1.0.0',
}) async {
  var listing = await publisher.createListing(NewListing(
    category: ListingCategory.gameTemplate,
    title: title,
    description: '# $title\n\nA game template published by the lumina_ui marketplace tests.',
    tags: const ['template', 'test'],
  ));
  await publisher.addScreenshot(listing.id, screenshot);
  final upload = await publisher.upload(zip, fileName: 'template.zip');
  final terms = await publisher.terms();
  await publisher.publishVersion(
    listing.id,
    NewVersion(
      version: version,
      uploadId: upload.id,
      licenses: const LicenseSelection(content: 'CC-BY-4.0', code: 'MIT'),
      attestation: true,
      termsVersion: terms.version,
    ),
  );
  listing = await publisher.listing(listing.id);
  return listing;
}
