import 'package:flutter_test/flutter_test.dart';

import 'package_import_walk.dart';

/// The engine package holds no Flutter UI. `lumina.dart` (what engine users
/// import) and `lumina_runtime.dart` (the engine half of what a game imports)
/// are walked through every library they reach, into the packages they
/// import (flutter_filament and lumina_core included), and reach:
/// - no Flutter UI library: `widgets`, `material`, `cupertino`, `rendering`,
///   `gestures`, `painting`, `services`, `scheduler`, `animation`, … — no
///   `package:flutter/` library at all except where it is listed below;
/// - not flutter_filament's view widget (`FilamentWidget`), media_kit,
///   shadcn_flutter, lumina_mouse_capture or lumina_widgets (the game UI
///   lives there).
///
/// `dart:ui` and `package:flutter/foundation.dart` are allowed only in the
/// libraries [_allowed] names, each with its reason; an entry that is no
/// longer used fails too, so the list stays exact.
const Map<String, Map<String, String>> _allowed = {
  'dart:ui': {
    // The Flutter engine's image codec decodes PNG/JPEG textures (the only
    // codec a web build has); no widget library is involved.
    'package:lumina/src/assets/encoded_image_decoder.dart': 'texture decoding (instantiateImageCodec, RootIsolateToken)',
    'package:lumina/src/components/environment/procedural_sky_binding.dart': 'night sky textures (instantiateImageCodec)',
    'package:lumina/src/material/material_textures.dart': 'material textures (instantiateImageCodec)',
  },
  // flutter_filament's Dart API uses no Flutter foundation type, so the
  // engine needs none either.
  'package:flutter/foundation.dart': {},
};

void main() {
  for (final barrel in ['lumina.dart', 'lumina_runtime.dart']) {
    test('$barrel reaches no widget, UI, media or shadcn library', () {
      final walk = PackageImportWalk(PackageConfigRoots.read());
      walk.from(Uri.parse('package:lumina/$barrel'), stop: _forbidden);
      expect(walk.walked, greaterThan(200), reason: 'the walk must cover the engine');
      expect(walk.reached.keys.where((u) => u.startsWith('package:flutter_filament/')), isNotEmpty,
          reason: 'the walk follows the imported packages too');

      final offenders = [for (final u in walk.reached.keys.where(_forbidden)) walk.chain(u)];
      expect(offenders, isEmpty, reason: offenders.join('\n'));

      // dart:ui / foundation only where listed.
      final unlisted = <String>[];
      final used = <String, Set<String>>{for (final k in _allowed.keys) k: {}};
      for (final MapEntry(key: from, value: targets) in walk.edges.entries) {
        for (final target in targets.where(_allowed.containsKey)) {
          used[target]!.add(from);
          if (!_allowed[target]!.containsKey(from)) unlisted.add('$target <- ${walk.chain(from)}');
        }
      }
      expect(unlisted, isEmpty, reason: 'not in the allow-list:\n${unlisted.join('\n')}');
      if (barrel == 'lumina.dart') {
        for (final MapEntry(key: target, value: allowed) in _allowed.entries) {
          expect(used[target], allowed.keys.toSet(), reason: 'the $target allow-list names exactly its users');
        }
      }
    });
  }
}

bool _forbidden(String uri) {
  if (uri.startsWith('package:flutter/')) return uri != 'package:flutter/foundation.dart';
  if (!uri.startsWith('package:')) return false;
  final path = uri.substring('package:'.length);
  final package = path.split('/').first;
  return package == 'media_kit' ||
      package.startsWith('media_kit_') ||
      package == 'shadcn_flutter' ||
      package == 'lumina_mouse_capture' ||
      package == 'lumina_widgets' ||
      package == 'flutter_test' ||
      // FilamentWidget and its platform states.
      RegExp(r'^flutter_filament/src/widget[a-z_]*\.dart$').hasMatch(path) ||
      path == 'flutter_filament/flutter_filament.dart';
}
