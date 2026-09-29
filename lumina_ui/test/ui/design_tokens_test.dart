import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/library_source.dart';

/// The design system contract.
///
/// Lumina Studio's main view is meant to be the Figma Make prototype in
/// `Design Lumina Game Engine UI/`. Its tokens are the `:root` block of
/// `Design Lumina Game Engine UI/src/index.css` — **not** its `.dark` block,
/// which is shadcn's untouched default and is not what the prototype renders.
///
/// These tests are the thing that keeps the two from drifting apart again:
/// the first pins every token to the value the prototype's OKLCH converts to,
/// and the rest are lint-style scans over the source so a stray literal or an
/// un-themed test app cannot quietly reintroduce the old palette.
void main() {
  final Directory packageRoot = _packageRoot();

  group('palette matches the prototype token for token', () {
    // token name → (the prototype's CSS value, the sRGB it converts to).
    //
    // Conversion is OKLCH → Oklab → linear sRGB → sRGB with the sRGB transfer
    // function, rounded to 8 bit, which is what a browser does with these.
    //
    // The grey ramp lifted the *surfaces* (and the two text greys that
    // have to stay readable on them) off the prototype's near-black ramp;
    // those are pinned by the next test instead. The accents, the foreground
    // and the chart ramp are still the prototype's, value for value.
    const Map<String, (String css, int argb)> prototypeTokens = {
      '--foreground': ('oklch(0.875 0 0)', 0xFFD6D6D6),
      '--primary': ('oklch(0.72 0.185 52)', 0xFFFB7C01),
      '--primary-foreground': ('oklch(0.1 0 0)', 0xFF030303),
      '--accent': ('oklch(0.62 0.16 220)', 0xFF0099C8),
      '--accent-foreground': ('oklch(0.96 0 0)', 0xFFF2F2F2),
      '--destructive': ('oklch(0.62 0.22 27)', 0xFFEE3533),
      '--chart-3': ('oklch(0.65 0.15 140)', 0xFF58A547),
      '--chart-4': ('oklch(0.68 0.17 280)', 0xFF8688FE),
    };

    // The grey ramp that replaced the prototype's
    // `oklch(0.086…0.155 0 0)` surfaces (#020202…#0C0C0C), and the text greys
    // and borders lifted with it.
    const Map<String, int> liftedTokens = {
      'rail': 0xFF131313,
      'background': 0xFF1C1C1C,
      'sidebar': 0xFF252525,
      'cardHeader': 0xFF2E2E2E,
      'card': 0xFF373737,
      'popover': 0xFF414141,
      'muted': 0xFF414141,
      'secondary': 0xFF4A4A4A,
      'viewportBackdrop': 0xFF0E0E0E,
      'secondaryForeground': 0xFFC4C4C4,
      'mutedForeground': 0xFFAEAEAE,
      'border': 0x1FFFFFFF,
      'input': 0x26FFFFFF,
    };

    Map<String, Color> lifted() => <String, Color>{
          'rail': EditorColors.rail,
          'background': EditorColors.background,
          'sidebar': EditorColors.sidebar,
          'cardHeader': EditorColors.cardHeader,
          'card': EditorColors.card,
          'popover': EditorColors.popover,
          'muted': EditorColors.muted,
          'secondary': EditorColors.secondary,
          'viewportBackdrop': EditorColors.viewportBackdrop,
          'secondaryForeground': EditorColors.secondaryForeground,
          'mutedForeground': EditorColors.mutedForeground,
          'border': EditorColors.border,
          'input': EditorColors.input,
        };

    test('the lifted surfaces are the grey ramp', () {
      final Map<String, Color> got = lifted();
      liftedTokens.forEach((String name, int argb) {
        expect(got[name]!.toARGB32(), argb,
            reason: '$name is 0x${argb.toRadixString(16).toUpperCase()}, but EditorColors has '
                '0x${got[name]!.toARGB32().toRadixString(16).toUpperCase()}');
      });
    });

    Map<String, Color> actual() => <String, Color>{
          '--foreground': EditorColors.foreground,
          '--primary': EditorColors.primary,
          '--primary-foreground': EditorColors.primaryForeground,
          '--accent': EditorColors.accent,
          '--accent-foreground': EditorColors.accentForeground,
          '--destructive': EditorColors.destructive,
          '--chart-3': EditorColors.chart3,
          '--chart-4': EditorColors.chart4,
        };

    test('EditorColors carries every prototype token', () {
      final Map<String, Color> got = actual();
      for (final MapEntry<String, (String, int)> entry
          in prototypeTokens.entries) {
        final Color? color = got[entry.key];
        expect(color, isNotNull, reason: '${entry.key} has no EditorColors field');
        expect(
          color!.toARGB32(),
          entry.value.$2,
          reason: '${entry.key} is ${entry.value.$1}, which is '
              '0x${entry.value.$2.toRadixString(16).toUpperCase()}, but '
              'EditorColors has 0x${color.toARGB32().toRadixString(16).toUpperCase()}',
        );
      }
    });

    test('luminaDarkColorScheme feeds those tokens to shadcn_flutter', () {
      expect(luminaDarkColorScheme.brightness, Brightness.dark);
      expect(luminaDarkColorScheme.background.toARGB32(), 0xFF1C1C1C);
      expect(luminaDarkColorScheme.foreground.toARGB32(), 0xFFD6D6D6);
      expect(luminaDarkColorScheme.card.toARGB32(), 0xFF373737);
      expect(luminaDarkColorScheme.popover.toARGB32(), 0xFF414141);
      expect(luminaDarkColorScheme.muted.toARGB32(), 0xFF414141);
      expect(luminaDarkColorScheme.secondary.toARGB32(), 0xFF4A4A4A);
      expect(luminaDarkColorScheme.mutedForeground.toARGB32(), 0xFFAEAEAE);
      expect(luminaDarkColorScheme.primary.toARGB32(), 0xFFFB7C01);
      expect(luminaDarkColorScheme.primaryForeground.toARGB32(), 0xFF030303);
      expect(luminaDarkColorScheme.accent.toARGB32(), 0xFF0099C8);
      expect(luminaDarkColorScheme.destructive.toARGB32(), 0xFFEE3533);
      expect(luminaDarkColorScheme.border.toARGB32(), 0x1FFFFFFF);
      expect(luminaDarkColorScheme.input.toARGB32(), 0x26FFFFFF);
      // `--ring` is `--primary` in the prototype.
      expect(luminaDarkColorScheme.ring.toARGB32(), 0xFFFB7C01);
      // The chart ramp, in the prototype's order.
      expect(luminaDarkColorScheme.chart1.toARGB32(), 0xFFFB7C01);
      expect(luminaDarkColorScheme.chart2.toARGB32(), 0xFF0099C8);
      expect(luminaDarkColorScheme.chart3.toARGB32(), 0xFF58A547);
      expect(luminaDarkColorScheme.chart4.toARGB32(), 0xFF8688FE);
      expect(luminaDarkColorScheme.chart5.toARGB32(), 0xFFEE3533);
    });

    test('the border is translucent white, not a solid grey', () {
      // White at 12% (the prototype's `--border` is 9%
      // raised it with the surfaces). If this ever becomes opaque it stops
      // holding its weight over the different surfaces it is drawn on.
      expect(EditorColors.border.a, lessThan(1.0));
      expect(EditorColors.input.a, lessThan(1.0));
      expect(EditorColors.border.r, 1.0);
      expect(EditorColors.border.g, 1.0);
      expect(EditorColors.border.b, 1.0);
    });

    test('the radius is the prototype\'s 0.1875rem', () {
      expect(EditorColors.radius, 0.1875);
    });

    test('luminaEditorTheme() is the dark scheme at that radius', () {
      final ThemeData theme = luminaEditorTheme();
      expect(theme.colorScheme.primary.toARGB32(), 0xFFFB7C01);
      expect(theme.colorScheme.background.toARGB32(), 0xFF1C1C1C);
      expect(theme.radius, EditorColors.radius);
    });

    test('light mode is Lumina Light', () {
      final ThemeData theme = luminaEditorTheme(light: true);
      expect(theme.colorScheme.brightness, Brightness.light);
    });
  });

  group('typography and density come from the prototype', () {
    test('the mono family is the prototype\'s JetBrains Mono, and it ships', () {
      // `--font-mono: 'JetBrains Mono', monospace`.
      expect(EditorTypography.monoFamily, 'JetBrains Mono');
      for (final String weight in <String>['Regular', 'Medium', 'Bold']) {
        final File file = File(
            '${packageRoot.path}/assets/fonts/JetBrainsMono-$weight.ttf');
        expect(file.existsSync(), isTrue,
            reason: '${file.path} must be bundled for the mono family to '
                'resolve to the prototype\'s font');
      }
      final String pubspec =
          File('${packageRoot.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains("family: JetBrains Mono"));
    });

    test('the sans family is Geist, which shadcn_flutter already bundles', () {
      // `--font-sans: 'Geist Variable'`. shadcn_flutter ships the whole Geist
      // family as `GeistSans`, so nothing is shipped here for it.
      expect(EditorTypography.sansFamily, 'GeistSans');
      expect(EditorTypography.sansPackage, 'shadcn_flutter');
      expect(luminaEditorTheme().typography.sans.fontFamily,
          'packages/shadcn_flutter/GeistSans');
    });

    test('the theme routes mono through JetBrains Mono', () {
      final Typography typography = luminaEditorTheme().typography;
      expect(typography.mono.fontFamily, 'JetBrains Mono');
      expect(typography.inlineCode.fontFamily, 'JetBrains Mono');
    });

    test('the measured type scale', () {
      // Measured off `Design Lumina Game Engine UI/src/App.tsx`:
      //   panel headings  text-[10px] font-semibold uppercase tracking-widest
      //   rows / names    text-[11px]
      //   labels          text-[10px] uppercase tracking-wider
      //   captions        text-[9px]
      //   asset sizes     text-[8px]
      expect(EditorTypography.panelTitleSize, 10);
      expect(EditorTypography.bodySize, 11);
      expect(EditorTypography.labelSize, 10);
      expect(EditorTypography.captionSize, 9);
      expect(EditorTypography.microSize, 8);
      expect(EditorTypography.panelTitleWeight, FontWeight.w600);
      // Tailwind's tracking-widest is 0.1em, tracking-wider 0.05em; Flutter's
      // letterSpacing is in logical pixels, so these are em × font size.
      expect(EditorTypography.trackingWidest, closeTo(1.0, 0.001));
      expect(EditorTypography.trackingWider, closeTo(0.5, 0.001));
    });

    test('the panel heading style is that scale, in the muted foreground', () {
      const TextStyle style = EditorTypography.panelHeading;
      expect(style.fontSize, 10);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.letterSpacing, closeTo(1.0, 0.001));
      expect(style.color, EditorColors.mutedForeground);
    });

    test('the measured density', () {
      // h-7 / h-6 / h-5.5 / h-5 at Tailwind's 4px step; px-2 gutter; gap-1;
      // the outliner's 14px indent step; w-36 sources rail; 72px asset tile.
      expect(EditorDensity.panelHeaderHeight, 28);
      expect(EditorDensity.rowHeight, 24);
      expect(EditorDensity.compactRowHeight, 22);
      expect(EditorDensity.chipHeight, 20);
      expect(EditorDensity.fieldHeight, 24);
      expect(EditorDensity.gutter, 8);
      expect(EditorDensity.gap, 4);
      expect(EditorDensity.indentStep, 14);
      expect(EditorDensity.sourcesRailWidth, 144);
      expect(EditorDensity.assetTileMinWidth, 72);
    });

    test('a panel header is still darker than the card under it', () {
      // The prototype draws its panel headers *darker* than the card they sit
      // on (`bg-[oklch(0.105_0_0)]` against `--card: oklch(0.13 0 0)`), and
      // the rails darker still; the grey ramp kept that order on the
      // lifted ramp.
      expect(EditorColors.cardHeader.toARGB32(), 0xFF2E2E2E);
      expect(EditorColors.rail.toARGB32(), 0xFF131313);
      expect(EditorColors.cardHeaderHover.toARGB32(), 0xFF353535);
      expect(EditorColors.cardHeader.r, lessThan(EditorColors.card.r));
      expect(EditorColors.rail.r, lessThan(EditorColors.cardHeader.r));
      expect(EditorColors.scrollbar.toARGB32(), 0xFF5E5E5E);
    });
  });

  group('the transform axes agree with the 3D manipulator', () {
    test('X, Y and Z equal FilamentTransformGizmo.defaultHandleColor', () {
      Color asColor(List<double> rgba) => Color.fromARGB(
            (rgba[3] * 255).round(),
            (rgba[0] * 255).round(),
            (rgba[1] * 255).round(),
            (rgba[2] * 255).round(),
          );
      expect(EditorColors.axisX,
          asColor(FilamentTransformGizmo.defaultHandleColor('TRANSLATE_X')));
      expect(EditorColors.axisY,
          asColor(FilamentTransformGizmo.defaultHandleColor('TRANSLATE_Y')));
      expect(EditorColors.axisZ,
          asColor(FilamentTransformGizmo.defaultHandleColor('TRANSLATE_Z')));
    });

    test('the Details panel labels its vector fields with them', () {
      final String source = librarySource(
        '${packageRoot.path}/lib/ui/features/main_editor/views/details_widget.dart',
      );
      expect(source, contains('EditorColors.axisX'));
      expect(source, contains('EditorColors.axisY'));
      expect(source, contains('EditorColors.axisZ'));
    });
  });

  group('lint: the sweep cannot rot', () {
    test('no widget file re-spells a token as a raw colour literal', () {
      final Map<int, String> tokens = <int, String>{
        EditorColors.background.toARGB32(): 'EditorColors.background',
        EditorColors.sidebar.toARGB32(): 'EditorColors.sidebar',
        EditorColors.card.toARGB32(): 'EditorColors.card',
        EditorColors.popover.toARGB32(): 'EditorColors.popover',
        EditorColors.secondary.toARGB32(): 'EditorColors.secondary',
        EditorColors.foreground.toARGB32(): 'EditorColors.foreground',
        EditorColors.secondaryForeground.toARGB32():
            'EditorColors.secondaryForeground',
        EditorColors.mutedForeground.toARGB32(): 'EditorColors.mutedForeground',
        EditorColors.primaryForeground.toARGB32():
            'EditorColors.primaryForeground',
        EditorColors.accentForeground.toARGB32(): 'EditorColors.accentForeground',
        EditorColors.primary.toARGB32(): 'EditorColors.primary',
        EditorColors.accent.toARGB32(): 'EditorColors.accent',
        EditorColors.destructive.toARGB32(): 'EditorColors.destructive',
        EditorColors.border.toARGB32(): 'EditorColors.border',
        EditorColors.input.toARGB32(): 'EditorColors.input',
        EditorColors.cardHeader.toARGB32(): 'EditorColors.cardHeader',
        EditorColors.rail.toARGB32(): 'EditorColors.rail',
        EditorColors.chart3.toARGB32(): 'EditorColors.chart3',
        EditorColors.chart4.toARGB32(): 'EditorColors.chart4',
        EditorColors.sidebar.toARGB32(): 'EditorColors.sidebar',
        EditorColors.graphCanvas.toARGB32(): 'EditorColors.graphCanvas',
        EditorColors.viewportBackdrop.toARGB32(): 'EditorColors.viewportBackdrop',
      };

      final RegExp literal = RegExp(r'Color\(0x([0-9A-Fa-f]{8})\)');
      final List<String> offences = <String>[];
      for (final File file in _dartFilesUnder('${packageRoot.path}/lib/ui')) {
        if (file.path.endsWith('editor_theme.dart')) continue;
        final List<String> lines = file.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          for (final RegExpMatch m in literal.allMatches(lines[i])) {
            final int value = int.parse(m.group(1)!, radix: 16);
            final String? token = tokens[value];
            if (token != null) {
              offences.add('${_rel(file, packageRoot)}:${i + 1} '
                  '${m.group(0)} is $token');
            }
          }
        }
      }
      expect(offences, isEmpty,
          reason: 'These literals duplicate a design token; read the token '
              'instead:\n${offences.join('\n')}');
    });

    test('every raw colour literal left in lib/ui carries a reason', () {
      // A literal survives the sweep only if the line above it, the line
      // itself, or the enclosing doc comment says why it is not a token.
      final RegExp literal = RegExp(r'Color\(0x[0-9A-Fa-f]{6,8}\)');
      final List<String> offences = <String>[];
      for (final File file in _dartFilesUnder('${packageRoot.path}/lib/ui')) {
        if (file.path.endsWith('editor_theme.dart')) continue;
        final List<String> lines = file.readAsLinesSync();
        final bool fileIsAnnotated = lines.take(40).any(
            (String l) => l.contains('// design-token-exempt:'));
        if (fileIsAnnotated) continue;
        for (int i = 0; i < lines.length; i++) {
          if (!literal.hasMatch(lines[i])) continue;
          final bool annotated = lines[i].contains('//') ||
              (i > 0 && lines[i - 1].trimLeft().startsWith('//'));
          if (!annotated) {
            offences.add('${_rel(file, packageRoot)}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
      expect(offences, isEmpty,
          reason: 'Each of these is either a token (read it from EditorColors) '
              'or a colour with a reason to exist (write the reason next to '
              'it, or mark the whole file `// design-token-exempt: <why>`):\n'
              '${offences.join('\n')}');
    });

    test('every ShadcnApp in test/ and integration_test/ uses the real theme',
        () {
      final List<String> offences = <String>[];
      for (final String dir in <String>['test', 'integration_test']) {
        for (final File file in _dartFilesUnder('${packageRoot.path}/$dir')) {
          final String source = file.readAsStringSync();
          if (!source.contains('ShadcnApp(')) continue;
          if (file.path.endsWith('design_tokens_test.dart')) continue;
          if (!source.contains('luminaEditorTheme') &&
              !source.contains('luminaDarkColorScheme')) {
            offences.add('${_rel(file, packageRoot)}: builds a ShadcnApp '
                'without luminaEditorTheme()');
          }
          final RegExp handRolled =
              RegExp(r'ColorSchemes\.(dark|light)[A-Za-z]*');
          for (final RegExpMatch m in handRolled.allMatches(source)) {
            offences.add('${_rel(file, packageRoot)}: ${m.group(0)} — the '
                'evidence would be of a palette the app does not use');
          }
        }
      }
      expect(offences, isEmpty, reason: offences.join('\n'));
    });

    test('the app itself uses the real theme', () {
      final String main =
          File('${packageRoot.path}/lib/main.dart').readAsStringSync();
      expect(main, contains('luminaEditorTheme'));
      expect(main, isNot(contains('ColorSchemes.darkNeutral')));
    });
  });
}

Directory _packageRoot() {
  Directory dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync() ||
      !File('${dir.path}/pubspec.yaml')
          .readAsStringSync()
          .contains('name: lumina_ui')) {
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('lumina_ui package root not found from '
          '${Directory.current.path}');
    }
    dir = parent;
  }
  return dir;
}

Iterable<File> _dartFilesUnder(String path) sync* {
  final Directory dir = Directory(path);
  if (!dir.existsSync()) return;
  for (final FileSystemEntity e in dir.listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.dart')) yield e;
  }
}

String _rel(File file, Directory root) =>
    file.path.substring(root.path.length + 1);
