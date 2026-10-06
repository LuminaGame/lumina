// Fetches the NVIDIA DLSS SDK files flutter_filament's DLSS support compiles and
// links against, into build/dlss-sdk/ (gitignored).
//
//   dart run tool/dlss/fetch_sdk.dart            # download, verify, report
//   dart run tool/dlss/fetch_sdk.dart --check    # only verify what is there
//   dart run tool/dlss/fetch_sdk.dart --force    # download again
//
// The release tag is pinned in tool/dlss/VERSION and every file's SHA-256 and
// size in tool/dlss/manifest.txt; a mismatch fails the run and leaves no
// partial file behind. The files come from github.com/NVIDIA/DLSS at that tag.
//
// Licence: the SDK and the nvngx_dlss runtime are covered by NVIDIA's DLSS
// SDK licence (LICENSE.txt in the download, also at
// https://github.com/NVIDIA/DLSS/blob/main/LICENSE.txt). It is not
// GPL-compatible, so nothing fetched here is committed, packaged into a
// Lumina release archive or installer, or loaded other than from this
// folder, LUMINA_DLSS_DIR or next to the executable on the user's machine.
// Read the licence before using the files.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const repository = 'NVIDIA/DLSS';

Future<void> main(List<String> args) async {
  final check = args.contains('--check');
  final force = args.contains('--force');
  final root = _packageRoot();
  final tag = File('${root.path}/tool/dlss/VERSION').readAsStringSync().trim();
  final entries = _readManifest(File('${root.path}/tool/dlss/manifest.txt'));
  final out = Directory('${root.path}/build/dlss-sdk');
  stdout.writeln('DLSS SDK $tag -> ${out.path}');

  final client = HttpClient();
  var downloaded = 0;
  var verified = 0;
  try {
    for (final e in entries) {
      final target = File('${out.path}/${e.path}');
      if (!force && target.existsSync() && await _matches(target, e)) {
        verified++;
        continue;
      }
      if (check) {
        stderr.writeln('missing or stale: ${e.path}');
        exitCode = 1;
        continue;
      }
      final url = Uri.parse('https://raw.githubusercontent.com/$repository/$tag/${e.path}');
      stdout.writeln('  ${e.path} (${(e.size / 1024).toStringAsFixed(0)} KiB)');
      await target.parent.create(recursive: true);
      final tmp = File('${target.path}.part');
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw StateError('HTTP ${response.statusCode} for $url');
      }
      final sink = tmp.openWrite();
      await response.pipe(sink);
      if (!await _matches(tmp, e)) {
        tmp.deleteSync();
        throw StateError('${e.path}: checksum or size mismatch against tool/dlss/manifest.txt');
      }
      if (target.existsSync()) target.deleteSync();
      tmp.renameSync(target.path);
      downloaded++;
    }
  } finally {
    client.close(force: true);
  }
  if (check && exitCode != 0) {
    stderr.writeln('run without --check to fetch');
    return;
  }
  stdout.writeln('$verified verified, $downloaded downloaded; licence: ${out.path}${Platform.pathSeparator}LICENSE.txt');
  stdout.writeln('The next flutter_filament native build picks the SDK up (hook/build.dart, FLUTTER_FILAMENT_DLSS).');
}

class _Entry {
  _Entry(this.sha256, this.size, this.path);
  final String sha256;
  final int size;
  final String path;
}

List<_Entry> _readManifest(File file) {
  final entries = <_Entry>[];
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length != 3) throw FormatException('bad manifest line: $raw');
    entries.add(_Entry(parts[0].toLowerCase(), int.parse(parts[1]), parts[2]));
  }
  return entries;
}

Future<bool> _matches(File file, _Entry e) async {
  if (file.lengthSync() != e.size) return false;
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString() == e.sha256;
}

Directory _packageRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync() || !Directory('${dir.path}/tool/dlss').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('run from the flutter_filament package (no tool/dlss found above ${Directory.current.path})');
    }
    dir = parent;
  }
  return dir;
}

// Keeps the json import meaningful for tools that print the manifest.
// ignore: unused_element
final _encoder = const JsonEncoder.withIndent('  ');
