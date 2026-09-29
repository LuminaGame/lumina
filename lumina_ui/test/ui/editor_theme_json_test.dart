import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_data.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_store.dart';
import 'package:lumina/lumina.dart' show EngineLoggerService;
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/plugin_extension_registry.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The editor theme is a JSON document.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(EditorTheme.resetForTest);

  group('built-in themes', () {
    for (final theme in EditorThemeData.builtIns) {
      test('${theme.name} parses, validates and round-trips byte-stable', () {
        final text = theme.encode();
        final back = EditorThemeData.decode(text);
        expect(back.warnings, isEmpty, reason: back.warnings.join('\n'));
        expect(back.name, theme.name);
        expect(back.encode(), text, reason: 'decode → encode gives the same bytes');
        expect(back, theme);
        // Every token is written, in token order.
        final colors = (jsonDecode(text) as Map)['colors'] as Map;
        expect(colors.keys.toList(), [for (final t in EditorThemeData.tokens) t.key]);
        expect(text.endsWith('}\n'), isTrue);
      });
    }

    test('Lumina Dark is the grey ramp and Lumina Classic the prototype\'s near-black', () {
      expect(EditorThemeData.luminaDark.color('background').toARGB32(), 0xFF1C1C1C);
      expect(EditorThemeData.luminaDark.color('card').toARGB32(), 0xFF373737);
      expect(EditorThemeData.luminaClassic.color('background').toARGB32(), 0xFF020202);
      expect(EditorThemeData.luminaClassic.color('mutedForeground').toARGB32(), 0xFF696969);
      expect(EditorThemeData.luminaLight.brightness, Brightness.light);
    });

    test('the asset-type strip colours are an Asset types group, tuned per theme', () {
      final keys = [for (final t in EditorThemeData.tokens) if (t.group == EditorThemeData.assetTypes) t.key];
      expect(keys, hasLength(15));
      expect(keys, everyElement(startsWith('assetType')));
      for (final k in keys) {
        expect(EditorThemeData.luminaClassic.color(k).toARGB32(), EditorThemeData.luminaDark.color(k).toARGB32(), reason: k);
        expect(EditorThemeData.luminaLight.color(k).toARGB32(), isNot(EditorThemeData.luminaDark.color(k).toARGB32()), reason: k);
      }
      expect(EditorThemeData.luminaDark.color('assetTypeSkeletalMesh').toARGB32(), 0xFFE040E0);
      expect(EditorThemeData.luminaLight.color('assetTypeStaticMesh').toARGB32(), 0xFF00989B);
      // Every theme's strip colours are distinct from one another.
      for (final theme in EditorThemeData.builtIns) {
        expect({for (final k in keys) theme.color(k).toARGB32()}, hasLength(keys.length), reason: theme.name);
      }
    });

    test('every EditorColors token is a theme slot with Lumina Dark\'s value as its const default', () {
      for (final t in EditorThemeData.tokens) {
        final Color token = EditorColors.token(t.key);
        expect(token.toARGB32(), EditorThemeData.luminaDark.color(t.key).toARGB32(), reason: t.key);
      }
    });
  });

  test('a theme with an invalid card colour loads with the default card and names it in a warning', () {
    final json = jsonDecode(EditorThemeData.luminaLight.encode()) as Map<String, dynamic>;
    (json['colors'] as Map)['card'] = 'not-a-colour';
    json['name'] = 'Broken Card';
    final theme = EditorThemeData.fromJson(json);
    expect(theme.name, 'Broken Card');
    expect(theme.color('card'), EditorThemeData.luminaDark.color('card'), reason: 'the default card');
    expect(theme.color('background'), EditorThemeData.luminaLight.color('background'), reason: 'the rest is kept');
    expect(theme.warnings, hasLength(1));
    expect(theme.warnings.single, contains('colors.card'));
    expect(theme.warnings.single, contains('not-a-colour'));
  });

  test('missing tokens take the default silently; unknown ones and bad numbers warn', () {
    final theme = EditorThemeData.fromJson({
      'name': 'Tiny',
      'colors': {'primary': '#22C55E', 'sparkle': '#FFFFFF'},
      'radius': 'round',
      'density': 9,
    });
    expect(theme.color('primary').toARGB32(), 0xFF22C55E);
    expect(theme.color('background'), EditorThemeData.luminaDark.color('background'));
    expect(theme.radius, EditorThemeData.defaultRadius);
    expect(theme.density, 1.0);
    expect(theme.warnings.join('\n'), allOf(contains('sparkle'), contains('radius'), contains('density')));
  });

  test('colours are CSS hex, #RRGGBB or #RRGGBBAA', () {
    expect(EditorThemeData.parseColor('#1C1C1C')!.toARGB32(), 0xFF1C1C1C);
    expect(EditorThemeData.parseColor('#FFFFFF1F')!.toARGB32(), 0x1FFFFFFF);
    expect(EditorThemeData.parseColor('1C1C1C'), isNull);
    expect(EditorThemeData.formatColor(const Color(0x1FFFFFFF)), '#FFFFFF1F');
    expect(EditorThemeData.formatColor(const Color(0xFF1C1C1C)), '#1C1C1C');
  });

  test('applying a theme recolours every EditorColors token and the shadcn theme', () {
    EditorTheme.apply(EditorThemeData.luminaLight);
    expect(EditorColors.background.toARGB32(), EditorThemeData.luminaLight.color('background').toARGB32());
    expect(EditorColors.foreground.toARGB32(), EditorThemeData.luminaLight.color('foreground').toARGB32());
    final theme = luminaEditorTheme();
    expect(theme.colorScheme.brightness, Brightness.light);
    expect(theme.colorScheme.background.toARGB32(), EditorThemeData.luminaLight.color('background').toARGB32());
    EditorTheme.apply(EditorThemeData.luminaDark);
    expect(EditorColors.background.toARGB32(), 0xFF1C1C1C);
    expect(luminaEditorTheme().colorScheme.brightness, Brightness.dark);
  });

  test('radius, density and fonts reach the shadcn theme', () {
    EditorTheme.apply(EditorThemeData.luminaDark.copyWith(name: 'Round', radius: 0.5, density: 0.9, monoFamily: 'GeistMono'));
    final theme = luminaEditorTheme();
    expect(theme.radius, 0.5);
    expect(theme.scaling, 0.9);
    expect(theme.typography.mono.fontFamily, contains('GeistMono'));
  });

  test('plugins read the active theme, read-only, through EditorThemeHost and hear it change', () {
    final LuminaEditorContext context = PluginExtensionRegistry(logger: EngineLoggerService());
    expect(context, isA<EditorThemeHost>());
    final EditorThemeAccess theme = (context as EditorThemeHost).theme;
    expect(theme.name, 'Lumina Dark');
    expect(theme.color('card').toARGB32(), 0xFF373737);
    expect(theme.tokens, contains('pinExec'));
    expect(() => theme.color('sparkle'), throwsArgumentError);
    var heard = 0;
    void listener() => heard++;
    theme.addListener(listener);
    EditorTheme.apply(EditorThemeData.luminaLight);
    expect(heard, 1);
    expect(theme.name, 'Lumina Light');
    expect(theme.brightness, Brightness.light);
    expect(theme.color('card').toARGB32(), 0xFFFFFFFF);
    theme.removeListener(listener);
  });

  group('store', () {
    late Directory config;
    setUp(() => config = Directory.systemTemp.createTempSync('lumina_theme_store_'));
    tearDown(() => config.deleteSync(recursive: true));

    test('the active theme persists in editor_preferences.json and user themes in themes/<name>.json', () {
      final c = EditorThemeController(store: EditorThemeStore(configDir: config));
      expect(c.activeName, 'Lumina Dark');
      final copy = c.duplicate('Lumina Classic', newName: 'My Classic');
      expect(File('${config.path}/themes/My_Classic.json').existsSync(), isTrue);
      c.activate(copy.name);
      final prefs = jsonDecode(File('${config.path}/editor_preferences.json').readAsStringSync()) as Map;
      expect(prefs['theme'], 'My Classic');
      expect(EditorColors.background.toARGB32(), 0xFF020202);

      // A new controller (the next start) comes back on it.
      EditorTheme.resetForTest();
      final again = EditorThemeController(store: EditorThemeStore(configDir: config));
      expect(again.activeName, 'My Classic');
      expect(EditorColors.background.toARGB32(), 0xFF020202);
      expect(again.rename('My Classic', 'Old School'), isTrue);
      expect(again.activeName, 'Old School');
      expect(File('${config.path}/themes/Old_School.json').existsSync(), isTrue);
      expect(again.delete('Old School'), isTrue);
      expect(again.activeName, 'Lumina Dark', reason: 'deleting the active theme falls back to the default');
      expect(again.delete('Lumina Dark'), isFalse, reason: 'built-ins cannot be deleted');
    });
  });
}
