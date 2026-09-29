import 'dart:convert';
import 'dart:io';
import 'package:lumina/lumina.dart';

/// Prints a summary of every `.lmas` container under a directory (or a single
/// file), optionally filtered by a substring of the path.
///
/// Usage: dart run lumina:inspect_lmas <path> [name-filter]
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run lumina:inspect_lmas <file-or-directory> [name-filter]');
    exitCode = 64;
    return;
  }
  final target = args[0];
  final filter = args.length > 1 ? args[1] : null;

  final Iterable<File> files;
  if (FileSystemEntity.isDirectorySync(target)) {
    files = Directory(target)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.lmas'))
        .where((f) => filter == null || f.path.contains(filter));
  } else if (FileSystemEntity.isFileSync(target)) {
    files = [File(target)];
  } else {
    stderr.writeln('No such file or directory: $target');
    exitCode = 66;
    return;
  }

  var count = 0;
  for (final file in files) {
    count++;
    print('Reading file: ${file.path}');
    try {
      final map = jsonDecode(file.readAsStringSync());
      final asset = LuminaAsset.fromMap(Map<String, dynamic>.from(map as Map));
      print('  Asset Name: ${asset.name}');
      print('  Type: ${asset.type}');
      print('  Payload length: ${asset.rawPayload?.length}');
      final payload = asset.rawPayload;
      if (payload != null && payload.length >= 12) {
        final hdr = payload.sublist(0, 12);
        final isGlb = hdr[0] == 0x67 && hdr[1] == 0x6C && hdr[2] == 0x54 && hdr[3] == 0x46;
        print('  Header bytes: $hdr');
        print('  Is glTF binary header: $isGlb');
      }
    } catch (e) {
      print('  Error parsing: $e');
    }
  }
  print('Inspected $count .lmas file(s)');
}
