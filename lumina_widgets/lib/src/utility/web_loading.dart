import 'dart:async';

import 'package:flutter/services.dart';

import 'package:lumina/lumina_runtime.dart';
import 'package:lumina_widgets/src/utility/web_loading_hook_stub.dart' if (dart.library.js_interop) 'web_loading_hook_web.dart' as hook;

/// The generated game's side of the web loading screen.
///
/// A web build's `index.html` shows a plain HTML/CSS screen from the first
/// byte; its `loading.js` tracks the Flutter engine's download itself and
/// exposes `window.luminaLoading.progress(fraction, label)`. Once Dart runs,
/// the generated `main()` calls [prepareGame], which loads the renderer's
/// WebAssembly module and preloads the game's bundled assets, reporting each
/// step there, before `runApp`. The screen fades out on Flutter's first
/// frame, so it covers the whole download.
///
/// Native builds skip all of it: [prepareGame] returns at once and nothing
/// here imports `dart:js_interop` outside the web (conditional import).
abstract final class LuminaWebLoading {
  /// The loading bar's phases: the Flutter engine fills it up to
  /// [engineEnd] (tracked by `loading.js` alone), the renderer's wasm from
  /// [rendererStart] to [rendererEnd] (its bytes mapped by `loading.js`,
  /// which holds the same numbers), the asset preload the rest.
  static const double engineEnd = 0.55;
  static const double rendererStart = 0.6;
  static const double rendererEnd = 0.85;

  /// Whether this is a web build.
  static bool get isWeb => hook.isWeb;

  /// Moves the page's loading screen to [fraction] (0–1, never backwards)
  /// with [label] under it. A no-op on native builds and on pages without the
  /// loading screen.
  static void progress(double fraction, String label) => hook.progress(fraction.clamp(0.0, 1.0), label);

  static final Map<String, Uint8List> _preloaded = {};
  static Timer? _expiry;

  /// Preloaded assets not handed out yet.
  static int get preloadedCount => _preloaded.length;

  /// Web builds: loads the renderer, then every asset under
  /// [contentsPrefix] in [bundle]'s manifest, reporting progress to the
  /// loading screen. Call after `LuminaAssets.defaultProvider` is set and
  /// before `runApp`.
  static Future<void> prepareGame({AssetBundle? bundle, String contentsPrefix = 'contents/'}) async {
    if (!isWeb) return;
    progress(rendererStart, 'Loading the renderer');
    await hook.loadRenderer();
    progress(rendererEnd, 'Loading game assets');
    await preloadAssets(
      bundle ?? rootBundle,
      prefix: contentsPrefix,
      onProgress: (done, total) =>
          progress(rendererEnd + (1 - rendererEnd) * (total == 0 ? 1 : done / total), 'Loading game assets ($done/$total)'),
    );
    progress(1, 'Starting the game');
  }

  /// Loads every asset of [bundle]'s manifest whose key starts with
  /// [prefix], [concurrency] at a time, calling [onProgress] with the count
  /// done (from 0 to the total). The bytes are kept until the runtime first
  /// asks for that path: [LuminaAssets.defaultProvider] is wrapped to hand
  /// each one out once, so the level's meshes and textures do not download
  /// twice. Whatever is not asked for within [keepFor] is dropped (null:
  /// kept until [releasePreloaded]). Returns the number of assets loaded.
  static Future<int> preloadAssets(
    AssetBundle bundle, {
    String prefix = 'contents/',
    int concurrency = 4,
    void Function(int done, int total)? onProgress,
    Duration? keepFor = const Duration(minutes: 2),
  }) async {
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    final keys = manifest.listAssets().where((k) => k.startsWith(prefix)).toList();
    var done = 0;
    onProgress?.call(0, keys.length);
    var next = 0;
    Future<void> worker() async {
      while (next < keys.length) {
        final key = keys[next++];
        final data = await bundle.load(key);
        _preloaded[key] = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        onProgress?.call(++done, keys.length);
      }
    }

    await Future.wait([for (var i = 0; i < concurrency.clamp(1, 16); i++) worker()]);
    final base = LuminaAssets.resolve(null);
    LuminaAssets.defaultProvider = (path) async => _preloaded.remove(path) ?? await base(path);
    _expiry?.cancel();
    _expiry = keepFor == null ? null : Timer(keepFor, releasePreloaded);
    return keys.length;
  }

  /// Drops every preloaded asset not handed out yet.
  static void releasePreloaded() {
    _expiry?.cancel();
    _expiry = null;
    _preloaded.clear();
  }
}
