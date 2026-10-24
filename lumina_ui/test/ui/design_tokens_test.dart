import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';


/// The design system contract.
///
/// Lumina Studio is painted in the Aurora design language the user approved
/// on the design canvas ("Lumina Studio UI Concepts"): the Obsidian ramp,
/// the amber accent, Manrope and JetBrains Mono.
///
/// These tests keep the editor from drifting away from it: the first pins
/// every token to the canvas value, and the rest are lint-style scans over
/// the source so a stray literal or an un-themed test app cannot quietly
/// reintroduce another palette.
void main() {
  final Directory packageRoot = _packageRoot();

  group('the palette is the Aurora design language, token for token', () {
    // The Obsidian ramp and the accents the user approved on the design
    // canvas ("Lumina Studio UI Concepts", artboard 3 · Aurora).
    const Map<String, int> auroraTokens = {
      'rail': 0xFF0F1013,
      'sidebar': 0xFF111215,
      'background': 0xFF141518,
      'cardHeader': 0xFF15171B,
      'card': 0xFF1A1B1F,
      'popover': 0xFF1A1B1F,
      'muted': 0xFF1F2126,
      'secondary': 0xFF24262C,
      'viewportBackdrop': 0xFF1B1D22,
      'graphCanvas': 0xFF0F1013,
      'foreground': 0xFFE6E6E8,
      'secondaryForeground': 0xFFC9CAD0,
      'mutedForeground': 0xFF9A9CA3,
      'primary': 0xFFF2A93B,
      'primaryForeground': 0xFF0B1D22,
      'accent': 0xFF39C6E0,
      'accentForeground': 0xFFF2F2F2,
      'destructive': 0xFFFF7B72,
      'warning': 0xFFE3B341,
      'success': 0xFF7FE0A4,
      'border': 0xFF26282E,
      'fieldBorder': 0xFF2C2E34,
      'input': 0xFF2C2E34,
      'chart3': 0xFF7FE0A4,
      'chart4': 0xFF8688FE,
    };

    test('EditorColors carries every Aurora token', () {
      auroraTokens.forEach((String name, int argb) {
        final Color got = EditorColors.token(name);
        expect(got.toARGB32(), argb,
            reason: '$name is 0x${argb.toRadixString(16).toUpperCase()}, but EditorColors has '
                '0x${got.toARGB32().toRadixString(16).toUpperCase()}');
      });
    });

    test('luminaDarkColorScheme feeds those tokens to shadcn_flutter', () {
      expect(luminaDarkColorScheme.brightness, Brightness.dark);
      expect(luminaDarkColorScheme.background.toARGB32(), 0xFF141518);
      expect(luminaDarkColorScheme.foreground.toARGB32(), 0xFFE6E6E8);
      expect(luminaDarkColorScheme.card.toARGB32(), 0xFF1A1B1F);
      expect(luminaDarkColorScheme.popover.toARGB32(), 0xFF1A1B1F);
      expect(luminaDarkColorScheme.muted.toARGB32(), 0xFF1F2126);
      expect(luminaDarkColorScheme.secondary.toARGB32(), 0xFF24262C);
      expect(luminaDarkColorScheme.mutedForeground.toARGB32(), 0xFF9A9CA3);
      expect(luminaDarkColorScheme.primary.toARGB32(), 0xFFF2A93B);
      expect(luminaDarkColorScheme.primaryForeground.toARGB32(), 0xFF0B1D22);
      expect(luminaDarkColorScheme.accent.toARGB32(), 0xFF39C6E0);
      expect(luminaDarkColorScheme.destructive.toARGB32(), 0xFFFF7B72);
      expect(luminaDarkColorScheme.border.toARGB32(), 0xFF26282E);
      expect(luminaDarkColorScheme.input.toARGB32(), 0xFF2C2E34);
      // The ring is the primary colour.
      expect(luminaDarkColorScheme.ring.toARGB32(), 0xFFF2A93B);
      // The chart ramp: amber, cyan, mint, violet, coral.
      expect(luminaDarkColorScheme.chart1.toARGB32(), 0xFFF2A93B);
      expect(luminaDarkColorScheme.chart2.toARGB32(), 0xFF39C6E0);
      expect(luminaDarkColorScheme.chart3.toARGB32(), 0xFF7FE0A4);
      expect(luminaDarkColorScheme.chart4.toARGB32(), 0xFF8688FE);
      expect(luminaDarkColorScheme.chart5.toARGB32(), 0xFFFF7B72);
    });

    test('borders are solid: islands are separated by a line, not by a lightness step', () {
      expect(EditorColors.border.a, 1.0);
      expect(EditorColors.fieldBorder.a, 1.0);
      expect(EditorColors.borderSolid.toARGB32(), EditorColors.border.toARGB32());
    });

    test('the radius is 0.1875rem', () {
      expect(EditorColors.radius, 0.1875);
    });

    test('luminaEditorTheme() is the dark scheme at that radius', () {
      final ThemeData theme = luminaEditorTheme();
      expect(theme.colorScheme.primary.toARGB32(), 0xFFF2A93B);
      expect(theme.colorScheme.background.toARGB32(), 0xFF141518);
      expect(theme.radius, EditorColors.radius);
    });

    test('light mode is Lumina Light', () {
      final ThemeData theme = luminaEditorTheme(light: true);
      expect(theme.colorScheme.brightness, Brightness.light);
    });
  });

  group('typography and density', () {
    test('the mono family is JetBrains Mono, and it ships', () {
      expect(EditorTypography.monoFamily, 'JetBrains Mono');
      for (final String weight in <String>['Regular', 'Medium', 'Bold']) {
        final File file = File(
            '${packageRoot.path}/assets/fonts/JetBrainsMono-$weight.ttf');
        expect(file.existsSync(), isTrue,
            reason: '${file.path} must be bundled for the mono family to resolve');
      }
      final String pubspec =
          File('${packageRoot.path}/pubspec.yaml').readAsStringSync();
      expect(pubspec, contains("family: JetBrains Mono"));
    });

    test('the UI family is Manrope, bundled, and the theme sets its text in it', () {
      expect(EditorTypography.uiFamily, 'Manrope');
      expect(EditorTypography.sansFamily, 'Manrope');
      expect(luminaEditorTheme().typography.sans.fontFamily, 'Manrope');
      // Geist stays available to a theme JSON that asks for it.
      expect(EditorTypography.geistFamily, 'GeistSans');
      expect(EditorTypography.sansPackage, 'shadcn_flutter');
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
      // Headers sit darker than the card they top, and the rail (menu and
      // tab bars) darker still: the Aurora ramp keeps that order.
      expect(EditorColors.cardHeader.toARGB32(), 0xFF15171B);
      expect(EditorColors.rail.toARGB32(), 0xFF0F1013);
      expect(EditorColors.cardHeaderHover.toARGB32(), 0xFF1C1E23);
      expect(EditorColors.cardHeader.r, lessThan(EditorColors.card.r));
      expect(EditorColors.rail.r, lessThan(EditorColors.cardHeader.r));
      expect(EditorColors.scrollbar.toARGB32(), 0xFF3A3D45);
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
      // The Details panel's vector and rotation rows are shared property
      // editors; the axis labels live there.
      final String source = [
        for (final File f in _dartFilesUnder('${packageRoot.path}/lib/ui/core/property_editors'))
          f.readAsStringSync(),
      ].join('\n');
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
      // main.dart only hands off to editor_entry.dart, which builds the app.
      final String main =
          File('${packageRoot.path}/lib/editor_entry.dart').readAsStringSync();
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
