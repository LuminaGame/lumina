import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:lumina_core/lumina_core.dart' show FlutterFilamentWebPrebuilt;

/// A loopback HTTP server laid out like GitHub: release downloads under
/// `/download/<tag>/<asset>` and the releases listing at `/releases`. It
/// serves real `flutter-filament-web-<tag>.zip` archives (the release
/// workflow's layout) with their `.sha256` sidecars.
class WebModuleReleaseServer {
  WebModuleReleaseServer._(this._server) : origin = 'http://${_server.address.address}:${_server.port}';

  final HttpServer _server;
  final String origin;
  final Map<String, List<int>> _assets = {};
  final List<Map<String, Object?>> _releases = [];

  /// Every request path, in order.
  final List<String> requests = [];

  /// Holds each response back until it completes, so a test can see the
  /// download running.
  Future<void>? gate;

  String get baseUrl => '$origin/download';
  String get apiUrl => '$origin/releases';

  static Future<WebModuleReleaseServer> start() async {
    final server = WebModuleReleaseServer._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    server._server.listen(server._handle);
    return server;
  }

  Future<void> _handle(HttpRequest request) async {
    requests.add(request.uri.path);
    await gate;
    final body = request.uri.path == '/releases' ? utf8.encode(jsonEncode(_releases)) : _assets[request.uri.path];
    if (body == null) {
      request.response.statusCode = HttpStatus.notFound;
    } else {
      request.response.contentLength = body.length;
      request.response.add(body);
    }
    await request.response.close();
  }

  /// The archive of [tag]: `flutter_filament.js`, `flutter_filament.wasm`
  /// (a valid empty WebAssembly module) and a README in one folder.
  static List<int> buildZip(String tag) {
    final folder = FlutterFilamentWebPrebuilt.baseName(tag);
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('$folder/flutter_filament.js', utf8.encode('// flutter_filament web module $tag\n')))
      ..addFile(ArchiveFile.bytes('$folder/flutter_filament.wasm', [0, 0x61, 0x73, 0x6d, 1, 0, 0, 0]))
      ..addFile(ArchiveFile.bytes('$folder/README.md', utf8.encode('# flutter_filament web module $tag\n')));
    return ZipEncoder().encode(archive);
  }

  /// Attaches the archive of [tag] to its release (with [sha] in the
  /// sidecar instead of the real hash) and lists the release.
  void publish(String tag, {String? sha, String published = '2026-10-01T00:00:00Z'}) {
    final name = FlutterFilamentWebPrebuilt.archiveName(tag);
    final bytes = buildZip(tag);
    _assets['/download/$tag/$name'] = bytes;
    _assets['/download/$tag/$name.sha256'] = utf8.encode('${sha ?? sha256.convert(bytes)}  $name\n');
    _releases.add({
      'tag_name': tag,
      'draft': false,
      'published_at': published,
      'assets': [
        {'name': name},
        {'name': '$name.sha256'},
      ],
    });
  }

  Future<void> close() => _server.close(force: true);
}
