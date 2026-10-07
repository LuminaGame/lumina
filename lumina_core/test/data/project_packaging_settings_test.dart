import 'dart:convert';

import 'package:test/test.dart';
import 'package:lumina_core/lumina_core.dart';

/// Several packaging targets and a project icon in the
/// `.lmproject` manifest.
void main() {
  LuminaProject roundTrip(LuminaProject p) => LuminaProject.fromMap(jsonDecode(jsonEncode(p.toMap())) as Map<String, dynamic>);

  group('packaging targets', () {
    test('a legacy target_os label migrates to the target list; no section reads [linux]', () {
      ProjectPackagingSettings legacy(String label) =>
          LuminaProject.fromMap({'project_name': 'g', 'packaging': {'target_os': label, 'output_dir': 'dist'}}).packaging;
      expect(legacy('Android APK').targets, ['android']);
      expect(legacy('Windows x64').targets, ['windows']);
      expect(legacy('Linux x64').targets, ['linux']);
      expect(legacy('Linux x64').outputDir, 'dist');
      expect(LuminaProject.fromMap({'project_name': 'g'}).packaging.targets, ['linux']);

      final written = LuminaProject.fromMap({'project_name': 'g', 'packaging': {'target_os': 'Android APK'}}).toMap();
      final packaging = written['packaging'] as Map<String, dynamic>;
      expect(packaging['targets'], ['android']);
      expect(packaging.containsKey('target_os'), isFalse, reason: 'the migrated manifest stores only the list');
    });

    test('the list and the output dir round-trip', () {
      const p = LuminaProject(projectName: 'g', packaging: ProjectPackagingSettings(targets: ['linux', 'web'], outputDir: 'out'));
      final back = roundTrip(p);
      expect(back.packaging.targets, ['linux', 'web']);
      expect(back.packaging.outputDir, 'out');
      expect(roundTrip(const LuminaProject(projectName: 'g', packaging: ProjectPackagingSettings(targets: []))).packaging.targets, isEmpty,
          reason: 'an empty selection stays empty');
    });

    test('withTarget keeps platform order and no duplicates; unknown ids survive', () {
      var s = const ProjectPackagingSettings(targets: ['android']);
      s = s.withTarget('web', true).withTarget('linux', true);
      expect(s.targets, ['linux', 'android', 'web']);
      expect(s.withTarget('android', false).targets, ['linux', 'web']);
      expect(s.withTarget('web', true).targets, ['linux', 'android', 'web']);
      expect(s.isSelected('android'), isTrue);
      expect(s.isSelected('ios'), isFalse);

      final odd = LuminaProject.fromMap({
        'project_name': 'g',
        'packaging': {
          'targets': ['web', 'ps5', 'linux', 'web'],
        },
      });
      expect(odd.packaging.targets, ['linux', 'web', 'ps5']);
      expect(roundTrip(odd).packaging.targets, ['linux', 'web', 'ps5']);
    });

    test('platform ids, labels, flutter build subcommands and package folders', () {
      expect(kPackagingPlatforms, ['linux', 'windows', 'macos', 'android', 'ios', 'web']);
      expect(flutterBuildSubcommand('android'), 'apk');
      expect(flutterBuildSubcommand('web'), 'web');
      expect(flutterBuildSubcommand('linux'), 'linux');
      expect(packagingPlatformLabel('macos'), 'macOS');
      expect(packagingPlatformLabel('ios'), 'iOS');
      const s = ProjectPackagingSettings();
      expect(s.outputDirIn('/p'), '/p/build');
      expect(s.packageDirFor('/p', 'linux'), '/p/build/package/linux');
      const abs = ProjectPackagingSettings(outputDir: '/tmp/out/');
      expect(abs.packageDirFor('/p', 'web'), '/tmp/out/package/web');
      expect(const ProjectPackagingSettings(outputDir: '').outputDirIn('/p/'), '/p/build');
    });
  });

  group('branding', () {
    test('round-trips; a missing section reads the Lumina logo on black', () {
      const p = LuminaProject(projectName: 'g', branding: ProjectBrandingSettings(icon: 'branding/app_icon.svg', iconBackground: '#1E90FF'));
      final map = p.toMap();
      expect(map['branding'], {'icon': 'branding/app_icon.svg', 'icon_background': '#1E90FF'});
      final back = roundTrip(p);
      expect(back.branding.icon, 'branding/app_icon.svg');
      expect(back.branding.iconBackground, '#1E90FF');
      expect(back.branding.usesDefaultIcon, isFalse);

      final legacy = LuminaProject.fromMap({'project_name': 'g'});
      expect(legacy.branding.icon, '');
      expect(legacy.branding.iconBackground, '#000000');
      expect(legacy.branding.usesDefaultIcon, isTrue);
    });

    test('iconBackgroundArgb parses #RRGGBB and rejects anything else', () {
      expect(const ProjectBrandingSettings(iconBackground: '#1E90FF').iconBackgroundArgb, 0xFF1E90FF);
      expect(const ProjectBrandingSettings(iconBackground: '#1e90ff').iconBackgroundArgb, 0xFF1E90FF);
      expect(const ProjectBrandingSettings(iconBackground: 'blue').iconBackgroundArgb, isNull);
      expect(const ProjectBrandingSettings(iconBackground: '#12345').iconBackgroundArgb, isNull);
      expect(const ProjectBrandingSettings().copyWith(icon: 'branding/app_icon.png').icon, 'branding/app_icon.png');
    });
  });
}
