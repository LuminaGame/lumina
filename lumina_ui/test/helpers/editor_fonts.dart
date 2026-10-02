import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show FontLoader;
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';

/// Loads the bundled JetBrains Mono (`assets/fonts/`) so a widget test lays
/// mono text out with its real glyph widths and line height instead of the
/// test font's 1 em squares. It is registered under its own family name and
/// under the name shadcn's `TextField` asks for (its theme text style carries
/// the `shadcn_flutter` package, so a merged `fontFamily` becomes
/// `packages/shadcn_flutter/JetBrains Mono`). Call from `setUpAll`; run from
/// the lumina_ui package directory.
Future<void> loadEditorMonoFont() async {
  for (final family in [EditorTypography.monoFamily, 'packages/shadcn_flutter/${EditorTypography.monoFamily}']) {
    final loader = FontLoader(family);
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      final bytes = File('assets/fonts/JetBrainsMono-$weight.ttf').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}
