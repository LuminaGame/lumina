/// The test API of the engine tests that also run in a browser:
/// `package:flutter_test` natively, a small runner of the same functions on
/// the web ([web_test_shim.dart]), so the same test file runs against the
/// web build (example/lib/physics_web_smoke.dart).
library;

export 'package:flutter_test/flutter_test.dart' if (dart.library.js_interop) 'web_test_shim.dart';
