import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_data.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_store.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Aurora design language's tokens and type: the Obsidian ramp, the amber
/// accent with dark-on-accent text, Manrope for UI text and JetBrains Mono
/// for numbers, the 9/10/11/12/15 scale; text keeps its contrast on every
/// surface, and a theme JSON still overrides a token.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  double channel(double c) => c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) => 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  double contrast(Color a, Color b) {
    final la = luminance(a), lb = luminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  final root = _packageRoot();

  setUp(() => EditorTheme.apply(EditorThemeData.luminaDark));
  tearDownAll(() => EditorTheme.apply(EditorThemeData.luminaDark));

  test('the Aurora tokens', () {
    expect(EditorColors.primary.toARGB32(), 0xFFF2A93B);
    expect(EditorColors.primaryForeground.toARGB32(), 0xFF0B1D22);
    expect(EditorColors.rail.toARGB32(), 0xFF0F1013, reason: 'menu and tab bars');
    expect(EditorColors.sidebar.toARGB32(), 0xFF111215, reason: 'islands');
    expect(EditorColors.background.toARGB32(), 0xFF141518);
    expect(EditorColors.card.toARGB32(), 0xFF1A1B1F, reason: 'fields');
    expect(EditorColors.border.toARGB32(), 0xFF26282E);
    expect(EditorColors.fieldBorder.toARGB32(), 0xFF2C2E34);
    expect(EditorColors.foreground.toARGB32(), 0xFFE6E6E8);
    expect(EditorColors.mutedForeground.toARGB32(), 0xFF9A9CA3);
    expect(EditorColors.accent.toARGB32(), 0xFF39C6E0);
    expect(EditorColors.success.toARGB32(), 0xFF7FE0A4);
    expect(EditorColors.warning.toARGB32(), 0xFFE3B341);
    expect(EditorColors.destructive.toARGB32(), 0xFFFF7B72);
    expect(EditorColors.viewportBackdrop.toARGB32(), 0xFF1B1D22);
    expect(EditorColors.graphCanvas.toARGB32(), 0xFF0F1013);
    expect(EditorColors.hudSurface.toARGB32(), 0xE0111215, reason: 'viewport pills');
    // The shadcn scheme carries the same values to the widgets that theme themselves.
    expect(luminaDarkColorScheme.primary.toARGB32(), 0xFFF2A93B);
    expect(luminaDarkColorScheme.border.toARGB32(), 0xFF26282E);
    expect(luminaEditorTheme().colorScheme.background.toARGB32(), 0xFF141518);
  });

  test('every token has a theme slot with the same default, in Lumina Dark and the JSON round trip', () {
    for (final entry in EditorColors.all.entries) {
      expect(EditorThemeData.tokenKeys, contains(entry.key), reason: '${entry.key} is not a theme token');
      expect(EditorThemeData.luminaDark.colors[entry.key]!.toARGB32(), entry.value.toARGB32(),
          reason: '${entry.key}: EditorColors and Lumina Dark disagree');
    }
    final back = EditorThemeData.fromJson(jsonDecode(jsonEncode(EditorThemeData.luminaDark.toJson())));
    expect(back.colors['fieldBorder']!.toARGB32(), 0xFF2C2E34);
    expect(back.colors['success']!.toARGB32(), 0xFF7FE0A4);
    expect(back.sansFamily, 'Manrope');
  });

  test('foreground reaches 7:1 and mutedForeground 4.5:1 on every Aurora surface; text on amber is dark', () {
    final surfaces = {
      'rail': EditorColors.rail,
      'sidebar': EditorColors.sidebar,
      'background': EditorColors.background,
      'cardHeader': EditorColors.cardHeader,
      'card': EditorColors.card,
      'muted': EditorColors.muted,
      'secondary': EditorColors.secondary,
      'viewportBackdrop': EditorColors.viewportBackdrop,
    };
    final failures = <String>[];
    surfaces.forEach((name, c) {
      if (contrast(EditorColors.foreground, c) < 7) failures.add('foreground on $name');
      if (contrast(EditorColors.mutedForeground, c) < 4.5) failures.add('mutedForeground on $name');
    });
    expect(failures, isEmpty, reason: failures.join(', '));
    expect(contrast(EditorColors.primaryForeground, EditorColors.primary), greaterThan(7));
    // The ramp is ordered: rail < sidebar < background < cardHeader < card < muted < secondary.
    final ramp = ['rail', 'sidebar', 'background', 'cardHeader', 'card', 'muted', 'secondary'];
    for (var i = 1; i < ramp.length; i++) {
      expect(luminance(surfaces[ramp[i]]!), greaterThan(luminance(surfaces[ramp[i - 1]]!)),
          reason: '${ramp[i - 1]} must be darker than ${ramp[i]}');
    }
  });

  test('a custom theme JSON that overrides primary still wins; an old JSON without the new tokens loads', () {
    final custom = EditorThemeData.fromJson({
      'name': 'Custom',
      'version': 1,
      'brightness': 'dark',
      'colors': {'primary': '#3366FF'},
    });
    expect(custom.warnings, isEmpty);
    expect(custom.color('primary').toARGB32(), 0xFF3366FF);
    expect(custom.color('fieldBorder').toARGB32(), 0xFF2C2E34, reason: 'a missing token takes the default');
    EditorTheme.apply(custom);
    expect(EditorColors.primary.toARGB32(), 0xFF3366FF, reason: 'the const token follows the applied theme');
    expect(EditorColors.success.toARGB32(), 0xFF7FE0A4);
  });

  test('typography: Manrope for UI text, JetBrains Mono for numbers, both bundled; the 9/10/11/12/15 scale', () {
    expect(EditorTypography.uiFamily, 'Manrope');
    expect(EditorTypography.sansFamily, 'Manrope');
    expect(EditorTypography.monoFamily, 'JetBrains Mono');
    expect(EditorThemeData.defaultSans, 'Manrope');
    expect(EditorThemeData.sansFamilies, contains('Manrope'));
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final file = File('${root.path}/assets/fonts/Manrope-$weight.ttf');
      expect(file.existsSync(), isTrue, reason: '${file.path} must be bundled');
      final bytes = file.openSync().readSync(4);
      expect(bytes, [0, 1, 0, 0], reason: '${file.path} is a TrueType font, not a download error page');
    }
    expect(File('${root.path}/assets/fonts/Manrope-OFL.txt').existsSync(), isTrue, reason: 'the licence ships beside the files');
    final pubspec = File('${root.path}/pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: Manrope'));
    expect(pubspec, contains('weight: 800'));
    expect(EditorTypography.scale, [9, 10, 11, 12, 15]);
    expect(EditorTypography.ui().fontFamily, 'Manrope');
    expect(EditorTypography.ui(fontSize: 12, fontWeight: FontWeight.w700).fontWeight, FontWeight.w700);
    expect(EditorTypography.mono().fontFamily, 'JetBrains Mono');
    final theme = luminaEditorTheme();
    expect(theme.typography.sans.fontFamily, 'Manrope', reason: 'the app theme sets shadcn text in Manrope');
    expect(theme.typography.mono.fontFamily, 'JetBrains Mono');
  });
}

Directory _packageRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    dir = dir.parent;
  }
  return dir;
}
