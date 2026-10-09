// Reports whether an NVIDIA SDK exposes a Neural Rendering ("DLSS 5") feature
// that flutter_filament could plug into its external post pass.
//
//   dart tool/dlss/check_neural_rendering.dart                 # the fetched SDK (build/dlss-sdk/include)
//   dart tool/dlss/check_neural_rendering.dart --dir <folder>  # any folder of headers
//   dart tool/dlss/check_neural_rendering.dart --remote        # NVIDIA/DLSS at tool/dlss/VERSION and the
//                                                              # latest NVIDIA-RTX/Streamline release, on GitHub
//
// It looks for Neural Rendering identifiers (feature ids, headers, runtime
// names) and prints "found" or "absent" per source; it always exits 0. Run it
// on every bump of tool/dlss/VERSION (see the DLSS documentation page).
// Plain dart: `dart tool/dlss/check_neural_rendering.dart`.
import 'dart:convert';
import 'dart:io';

/// Identifiers a Neural Rendering feature would bring: an NGX feature id, the
/// runtime (nvngx_dlssnr), a Streamline plugin header (sl_dlss_nr.h) or the
/// spelled-out name.
final RegExp neuralRenderingPattern = RegExp(
  r'NVSDK_NGX_Feature_Neural\w*|neural[ _]?render\w*|\bdlss[_-]?nr\b|dlssnr|nvngx_dlssnr|sl_dlss_nr|kFeatureDLSS_NR',
  caseSensitive: false,
);

/// The matches in [text] (unique, in order of appearance).
List<String> findNeuralRendering(String text) {
  final out = <String>[];
  for (final m in neuralRenderingPattern.allMatches(text)) {
    final s = m.group(0)!;
    if (!out.contains(s)) out.add(s);
  }
  return out;
}

Future<void> main(List<String> args) async {
  final root = _packageRoot();
  if (args.contains('--remote')) {
    final tag = File(
      '${root.path}/tool/dlss/VERSION',
    ).readAsStringSync().trim();
    await _checkRemote('NVIDIA/DLSS', tag);
    final streamline = await _latestRelease('NVIDIA-RTX/Streamline');
    if (streamline != null) {
      await _checkRemote('NVIDIA-RTX/Streamline', streamline);
    }
    return;
  }
  final dirIndex = args.indexOf('--dir');
  final dir = Directory(
    dirIndex >= 0 && dirIndex + 1 < args.length
        ? args[dirIndex + 1]
        : '${root.path}/build/dlss-sdk/include',
  );
  stdout.write(checkDirectory(dir));
}

/// The report for a folder of headers (its files' names and contents).
String checkDirectory(Directory dir) {
  if (!dir.existsSync()) {
    return '${dir.path}: missing (run tool/dlss/fetch_sdk.dart or pass --dir)\n';
  }
  final hits = <String, List<String>>{};
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final name = entity.path.split(RegExp(r'[\\/]')).last;
    final found = [
      ...findNeuralRendering(name),
      ...findNeuralRendering(entity.readAsStringSync()),
    ];
    if (found.isNotEmpty) hits[name] = found;
  }
  return _format(dir.path, hits);
}

void _report(
  String source,
  Map<String, List<String>> hits, {
  bool fileMatched = true,
}) => stdout.write(_format(source, hits, fileMatched: fileMatched));

String _format(
  String source,
  Map<String, List<String>> hits, {
  bool fileMatched = true,
}) {
  final out = StringBuffer();
  if (hits.isEmpty) {
    out.writeln('$source: Neural Rendering absent');
    return out.toString();
  }
  out.writeln(
    fileMatched
        ? '$source: Neural Rendering found'
        : '$source: Neural Rendering identifiers only (no header or runtime of its own)',
  );
  for (final e in hits.entries) {
    out.writeln('  ${e.key}: ${e.value.join(', ')}');
  }
  return out.toString();
}

Future<String?> _latestRelease(String repo) async {
  final json = await _getJson(
    'https://api.github.com/repos/$repo/releases/latest',
  );
  return json is Map ? json['tag_name'] as String? : null;
}

Future<void> _checkRemote(String repo, String tag) async {
  final tree = await _getJson(
    'https://api.github.com/repos/$repo/git/trees/$tag?recursive=1',
  );
  if (tree is! Map || tree['tree'] is! List) {
    stdout.writeln('$repo@$tag: could not list the repository');
    return;
  }
  final hits = <String, List<String>>{};
  var fileMatched = false;
  for (final node in tree['tree'] as List) {
    final path = (node as Map)['path'] as String;
    final found = findNeuralRendering(path);
    if (found.isNotEmpty) {
      hits[path] = found;
      fileMatched = true;
    }
    // the feature ids live in the NGX defs header and Streamline's public headers
    if (path == 'include/nvsdk_ngx_defs.h' ||
        (path.startsWith('include/sl') && path.endsWith('.h'))) {
      final text = await _getText(
        'https://raw.githubusercontent.com/$repo/$tag/$path',
      );
      final inText = text == null
          ? const <String>[]
          : findNeuralRendering(text);
      if (inText.isNotEmpty) hits[path] = [...?hits[path], ...inText];
    }
  }
  _report('$repo@$tag', hits, fileMatched: fileMatched);
}

Future<Object?> _getJson(String url) async {
  final text = await _getText(url);
  return text == null ? null : jsonDecode(text);
}

Future<String?> _getText(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', 'lumina-check-neural-rendering');
    final response = await request.close();
    if (response.statusCode != 200) return null;
    return await response.transform(utf8.decoder).join();
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

Directory _packageRoot() {
  var dir = Directory.current;
  while (!Directory('${dir.path}/tool/dlss').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'run from the flutter_filament package (no tool/dlss found above ${Directory.current.path})',
      );
    }
    dir = parent;
  }
  return dir;
}
