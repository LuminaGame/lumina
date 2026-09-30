// ignore_for_file: avoid_print

/// Downloads a prebuilt Filament archive from its `filament-<version>` GitHub
/// release, verifies it against its `.sha256` sidecar, unpacks it and prints
/// the directory (usable as the hooks' `filament_dir`) on stdout.
///
///   dart run tool/filament/fetch_prebuilt.dart
///       [--tag <release-tag>]  a Lumina release to try when the
///                              filament-<version> release has no such asset
///       [--version <id>]    default: tool/filament/VERSION
///       [--os windows|linux|macos]   default: this one
///       [--dest <dir>]      default: build/filament-prebuilt/cache
///       [--base-url <url>]  default: https://github.com/LuminaGame/lumina/releases/download
///       [--force]           download again even when unpacked
///
/// The folder is `<dest>/<version>`. The logic lives in
/// `package:lumina/data/services/filament_prebuilt.dart` (FilamentPrebuilt.ensure).
library;

import 'dart:io';

import 'package:lumina/data/services/filament_prebuilt.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final repo = File.fromUri(Platform.script).parent.parent.parent.path;
  String? opt(String name) {
    final i = args.indexOf('--$name');
    if (i < 0) return null;
    if (i + 1 >= args.length) _usage('--$name needs a value');
    return args[i + 1];
  }

  if (args.contains('-h') || args.contains('--help')) _usage(null);
  final tag = opt('tag');
  final version = opt('version') ?? File('$repo/tool/filament/VERSION').readAsStringSync().trim();
  final dest = Directory(opt('dest') ?? '$repo/build/filament-prebuilt/cache');
  var shown = -1;
  try {
    final dir = await FilamentPrebuilt.ensure(
      version: version,
      releaseTag: tag,
      cacheRoot: dest,
      operatingSystem: opt('os'),
      baseUrl: opt('base-url'),
      force: args.contains('--force'),
      onProgress: (fraction, message) {
        final percent = (fraction * 100).round();
        if (percent == shown) return; // one line per percent, not per chunk
        shown = percent;
        stderr.writeln('[${percent.toString().padLeft(3)}%] $message');
      },
    );
    print(p.normalize(dir.absolute.path));
  } on FilamentPrebuiltException catch (e) {
    stderr.writeln(e.message);
    exitCode = 1;
  }
}

Never _usage(String? error) {
  if (error != null) stderr.writeln(error);
  stderr.writeln('usage: dart run tool/filament/fetch_prebuilt.dart [--tag <release-tag>] '
      '[--version <id>] [--os windows|linux|macos] [--dest <dir>] [--base-url <url>] [--force]');
  exit(error == null ? 0 : 2);
}
