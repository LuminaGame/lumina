import 'dart:io';

/// Serves a `flutter build web` output on `127.0.0.1` for "Launch in
/// Browser". A page opened as `file://` cannot fetch its
/// `.wasm`, so the preview goes through HTTP. Single-threaded WebAssembly
/// needs no COOP/COEP headers.
class WebPreviewServer {
  HttpServer? _server;
  String? _root;

  bool get isRunning => _server != null;

  /// The served address, while running.
  Uri? get url => _server == null ? null : Uri(scheme: 'http', host: '127.0.0.1', port: _server!.port, path: '/');

  /// Serves [rootDir] on a free port, replacing a previous root.
  Future<Uri> start(String rootDir) async {
    await stop();
    _root = Directory(rootDir).absolute.path;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle);
    return url!;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final file = _resolve(request.uri);
      if (request.method != 'GET' && request.method != 'HEAD' || file == null) {
        response.statusCode = HttpStatus.notFound;
      } else {
        response.headers.contentType = contentTypeFor(file.path);
        response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
        response.contentLength = file.lengthSync();
        if (request.method == 'GET') await response.addStream(file.openRead());
      }
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
    }
    await response.close();
  }

  /// The file [uri] names inside the root, or null (missing, or outside it).
  File? _resolve(Uri uri) {
    final root = _root;
    if (root == null) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.any((s) => s == '..' || s == '.' || s.contains('/') || s.contains(r'\'))) return null;
    final path = segments.isEmpty ? 'index.html' : segments.join('/');
    final file = File('$root/$path');
    if (!file.existsSync()) return null;
    return file.resolveSymbolicLinksSync().startsWith('${Directory(root).resolveSymbolicLinksSync()}/') ? file : null;
  }

  static ContentType contentTypeFor(String path) => switch (path.split('.').last.toLowerCase()) {
        'html' => ContentType.html,
        'js' || 'mjs' => ContentType('text', 'javascript', charset: 'utf-8'),
        'wasm' => ContentType('application', 'wasm'),
        'json' => ContentType.json,
        'css' => ContentType('text', 'css', charset: 'utf-8'),
        'png' => ContentType('image', 'png'),
        'jpg' || 'jpeg' => ContentType('image', 'jpeg'),
        'svg' => ContentType('image', 'svg+xml'),
        'ico' => ContentType('image', 'x-icon'),
        'otf' => ContentType('font', 'otf'),
        'ttf' => ContentType('font', 'ttf'),
        'glb' => ContentType('model', 'gltf-binary'),
        _ => ContentType.binary,
      };
}
