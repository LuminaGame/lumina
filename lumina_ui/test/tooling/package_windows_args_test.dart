import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/tooling/windows_packaging/windows_packaging.dart';

/// `tool/package-windows.sh` argument parsing and the
/// MSIX version derived from `pubspec.yaml`.
void main() {
  group('PackageWindowsOptions.parse', () {
    test('no arguments: self-signed, version from pubspec, build/msix', () {
      final o = PackageWindowsOptions.parse(const []);
      expect(o.mode, PackagingMode.selfSigned);
      expect(o.version, isNull, reason: 'the version comes from pubspec.yaml when not given');
      expect(o.output, 'build/msix');
      expect(o.skipBuild, isFalse);
      expect(o.dryRun, isFalse);
      expect(o.appInstaller, isNull);
      expect(o.help, isFalse);
      // The version the plan uses: the pubspec version through the Store
      // scheme, e.g. `version: 0.0.1-dev.10+10` → 1.0.1010.0.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final semver = RegExp(r'^version:\s*(\S+)$', multiLine: true).firstMatch(pubspec)!.group(1)!;
      expect(o.resolveVersion(pubspec), storeMsixVersion(semver));
      expect(o.resolveVersion('version: 0.0.1-dev.10+10\n'), '1.0.1010.0');
    });

    test('--store: unsigned Store mode, exclusive with --publish and --appinstaller', () {
      final o = PackageWindowsOptions.parse(const ['--store', '--skip-build']);
      expect(o.mode, PackagingMode.store);
      expect(o.resolveVersion('version: 0.0.1-dev.10+10\n'), '1.0.1010.0');
      for (final args in const [
        ['--store', '--publish'],
        ['--publish', '--store'],
        ['--store', '--appinstaller', 'D:/feed'],
      ]) {
        expect(() => PackageWindowsOptions.parse(args), throwsA(isA<PackagingException>().having((e) => e.exitCode, 'exitCode', 64)),
            reason: args.join(' '));
      }
    });

    test('--store --version must follow the Store rules (fourth section 0, first not 0)', () {
      expect(PackageWindowsOptions.parse(const ['--store', '--version', '1.0.1010.0']).version, '1.0.1010.0');
      expect(
        () => PackageWindowsOptions.parse(const ['--store', '--version', '1.2.3.4']),
        throwsA(isA<PackagingException>()
            .having((e) => e.exitCode, 'exitCode', 64)
            .having((e) => e.message, 'message', contains('fourth section'))),
      );
      expect(
        () => PackageWindowsOptions.parse(const ['--store', '--version', '0.1.2.0']),
        throwsA(isA<PackagingException>()
            .having((e) => e.exitCode, 'exitCode', 64)
            .having((e) => e.message, 'message', contains('first section'))),
      );
    });

    test('--publish --version 1.2.3.4 --output D:/out', () {
      final o = PackageWindowsOptions.parse(const ['--publish', '--version', '1.2.3.4', '--output', 'D:/out']);
      expect(o.mode, PackagingMode.publish);
      expect(o.version, '1.2.3.4');
      expect(o.resolveVersion('version: 9.9.9+9'), '1.2.3.4');
      expect(o.output, 'D:/out');
    });

    test('--version=… and --output=… forms, --skip-build, --dry-run, -h', () {
      final o = PackageWindowsOptions.parse(const ['--version=2.0.0.7', '--output=out', '--skip-build', '--dry-run']);
      expect(o.version, '2.0.0.7');
      expect(o.output, 'out');
      expect(o.skipBuild, isTrue);
      expect(o.dryRun, isTrue);
      expect(PackageWindowsOptions.parse(const ['-h']).help, isTrue);
      expect(PackageWindowsOptions.parse(const ['--help']).help, isTrue);
    });

    test('--version 1.2 is a usage error naming the a.b.c.d format', () {
      expect(
        () => PackageWindowsOptions.parse(const ['--version', '1.2']),
        throwsA(isA<PackagingException>()
            .having((e) => e.exitCode, 'exitCode', 64)
            .having((e) => e.message, 'message', contains('a.b.c.d'))),
      );
    });

    test('--appinstaller without --publish is a usage error', () {
      expect(
        () => PackageWindowsOptions.parse(const ['--appinstaller', 'D:/feed']),
        throwsA(isA<PackagingException>()
            .having((e) => e.exitCode, 'exitCode', 64)
            .having((e) => e.message, 'message', allOf(contains('--appinstaller'), contains('--publish')))),
      );
      final o = PackageWindowsOptions.parse(const ['--publish', '--appinstaller', 'D:/feed']);
      expect(o.appInstaller, 'D:/feed');
    });

    test('an unknown option or a missing value is a usage error', () {
      expect(() => PackageWindowsOptions.parse(const ['--sign']),
          throwsA(isA<PackagingException>().having((e) => e.message, 'message', contains('--sign'))));
      expect(() => PackageWindowsOptions.parse(const ['--output']),
          throwsA(isA<PackagingException>().having((e) => e.exitCode, 'exitCode', 64)));
    });

    test('the usage text lists every option', () {
      for (final option in ['--publish', '--store', '--version', '--output', '--skip-build', '--appinstaller', '--dry-run', '--help']) {
        expect(PackageWindowsOptions.usage, contains(option));
      }
    });
  });

  group('msixVersionFromPubspec', () {
    test('the pubspec version through the Store scheme (the +build is ignored)', () {
      expect(msixVersionFromPubspec('name: a\nversion: 0.0.1+1\n'), '1.0.1999.0');
      expect(msixVersionFromPubspec('version: 1.0.0-dev.1+2\n'), '2.0.1.0');
      expect(msixVersionFromPubspec('version: 3.4.5\n'), '4.4.5999.0');
    });

    test('a pubspec without a usable version is an error', () {
      expect(() => msixVersionFromPubspec('name: a\n'), throwsA(isA<PackagingException>()));
      expect(() => msixVersionFromPubspec('version: 1.0.0-beta.1+2\n'), throwsA(isA<PackagingException>()));
    });
  });

  group('MsixConfig', () {
    test('reads the identity from lumina_ui/pubspec.yaml msix_config', () {
      final config = MsixConfig.fromPubspec(File('pubspec.yaml').readAsStringSync());
      expect(config.identityName, 'LuminaEngine.LuminaEngine');
      expect(config.displayName, 'Lumina Engine');
      expect(config.publisherDisplayName, 'Lumina Engine');
      expect(config.outputName, 'LuminaEngine');
      expect(config.executionAlias, 'lumina-studio');
      expect(config.architecture, 'x64');
      expect(config.logoPath, 'assets/logo_color.png');
      expect(File(config.logoPath!).existsSync(), isTrue, reason: 'the colour logo is in the repo');
      expect(config.capabilities, containsAll(['internetClient', 'privateNetworkClientServer']));
      expect(config.storePublisher, 'CN=76408633-2846-4256-BED6-0DF8748A95C6', reason: 'the Partner Center publisher');
      expect(config.osMinVersion, '10.0.19041.0');
    });

    test('a pubspec without msix_config is an error naming it', () {
      expect(() => MsixConfig.fromPubspec('name: a\nversion: 1.0.0\n'),
          throwsA(isA<PackagingException>().having((e) => e.message, 'message', contains('msix_config'))));
    });
  });
}
