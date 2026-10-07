import 'dart:io';
import 'package:test/test.dart';
import 'package:lumina_core/lumina_core.dart';

void main() {
  group('LuminaThemeDocument', () {
    test('defaultShadcnDark creates valid theme document', () {
      final doc = LuminaThemeDocument.defaultShadcnDark();
      expect(doc.name, 'DefaultTheme');
      expect(doc.baseTheme, 'shadcn_dark');
      expect(doc.colors['background'], 0xFF1C1C1C);
      expect(doc.colors['primary'], 0xFF3B82F6);
      expect(doc.hasComponentStyle('button'), isTrue);
      expect(doc.componentStyles['button']!.backgroundColor, 0xFF3B82F6);
    });

    test('serializes and deserializes to/from JSON and Asset', () {
      final original = LuminaThemeDocument.defaultGameTheme(name: 'MyCustomTheme')
          .copyWith(
            radius: 10.0,
            customStyles: {
              'HeroButton': const LuminaCustomStyle(
                name: 'HeroButton',
                targetComponent: 'button',
                style: LuminaComponentStyle(
                  backgroundColor: 0xFFFF0055,
                  fontSize: 18.0,
                ),
              ),
            },
          );

      final jsonStr = original.toJson();
      final fromJson = LuminaThemeDocument.fromJson(jsonStr);

      expect(fromJson.name, 'MyCustomTheme');
      expect(fromJson.radius, 10.0);
      expect(fromJson.customStyles.containsKey('HeroButton'), isTrue);
      expect(fromJson.customStyles['HeroButton']!.style.backgroundColor, 0xFFFF0055);

      final asset = original.toAsset();
      expect(asset.type, AssetType.theme);
      expect(asset.name, 'MyCustomTheme');

      final fromAsset = LuminaThemeDocument.fromAsset(asset);
      expect(fromAsset.name, 'MyCustomTheme');
      expect(fromAsset.customStyles['HeroButton']!.style.fontSize, 18.0);
    });

    test('LuminaThemeService ensures default theme file exists', () async {
      final tempDir = Directory.systemTemp.createTempSync('lumina_theme_test_');
      try {
        final file = await LuminaThemeService.ensureDefaultTheme(tempDir.path);
        expect(file.existsSync(), isTrue);

        final loaded = await LuminaThemeService.loadTheme(file.path);
        expect(loaded.name, 'DefaultTheme');
        expect(loaded.baseTheme, 'shadcn_dark');

        final updated = loaded.copyWith(radius: 14.0);
        await LuminaThemeService.saveTheme(file.path, updated);

        final reloaded = await LuminaThemeService.loadTheme(file.path);
        expect(reloaded.radius, 14.0);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
