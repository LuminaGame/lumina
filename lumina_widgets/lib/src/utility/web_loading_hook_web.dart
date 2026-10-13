/// Web builds: the page's HTML loading screen (`web/loading.js`, generated
/// from the project's Web Loading Style), flutter_filament's WebAssembly
/// module and Jolt Physics'. Only compiled for the web (conditional import in
/// `web_loading.dart`).
library;

import 'dart:js_interop';

import 'package:flutter_filament/flutter_filament.dart' show FilamentWeb;
import 'package:lumina/lumina_runtime.dart' show LuminaPhysicsSubsystem;

const bool isWeb = true;

extension type _LuminaLoadingJs._(JSObject _) implements JSObject {
  external void progress(JSNumber fraction, JSString label);
}

@JS('luminaLoading')
external _LuminaLoadingJs? get _luminaLoading;

/// Reports to `window.luminaLoading.progress`; a page without the loading
/// screen (a hand-written index.html) is left alone.
void progress(double fraction, String label) {
  _luminaLoading?.progress(fraction.toJS, label.toJS);
}

/// Downloads and instantiates the renderer's WebAssembly module, then Jolt
/// Physics' (`flutter_jolt.js` + `.wasm` beside the page; without them the
/// game simulates with the Dart solver).
Future<void> loadRenderer() async {
  await FilamentWeb.ensureInitialized();
  await LuminaPhysicsSubsystem.prepareJolt();
}
