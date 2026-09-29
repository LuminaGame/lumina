import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/tooling/windows_packaging/windows_packaging.dart';
import 'package:path/path.dart' as p;

/// The `dart run msix:create …` plan of each signing
/// mode (`--dry-run`), and the publish-mode refusals that stop a build before
/// it starts. Real temp folders and, for the `.pfx` checks, real certificates
/// made by PowerShell on Windows.
void main() {
  late Directory temp;
  late Directory devDir;
  late Directory outDir;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('lpw_plan_');
    devDir = Directory(p.join(temp.path, 'dev'));
    outDir = Directory(p.join(temp.path, 'out'));
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  PackagingContext context(Map<String, String> environment, StringBuffer out, StringBuffer err) => PackagingContext(
        packageRoot: Directory.current.path,
        environment: environment,
        devCertificateDir: devDir.path,
        out: out,
        err: err,
      );

  String valueAfter(List<String> argv, String option) {
    final i = argv.indexOf(option);
    expect(i, isNot(-1), reason: '$option is in $argv');
    return argv[i + 1];
  }

  group('dry run', () {
    test('self-signed: the dev certificate, its publisher, no certificate install, the pubspec version', () async {
      final out = StringBuffer(), err = StringBuffer();
      final plan = await PackagingPlanner(context(const {}, out, err))
          .plan(PackageWindowsOptions.parse(['--dry-run', '--output', outDir.path]));
      final argv = plan.msixArguments;
      expect(plan.mode, PackagingMode.selfSigned);
      expect(valueAfter(argv, '--certificate-path'), p.join(devDir.path, 'lumina_dev.pfx'));
      expect(valueAfter(argv, '--publisher'), 'CN=Lumina Studio Dev, O=Lumina, C=TR');
      expect(valueAfter(argv, '--install-certificate'), 'false');
      expect(valueAfter(argv, '--version'), '0.0.1.1');
      expect(valueAfter(argv, '--output-path'), outDir.path);
      expect(valueAfter(argv, '--output-name'), 'LuminaEngine_0.0.1.1_x64');
      expect(valueAfter(argv, '--identity-name'), 'LuminaEngine.LuminaEngine');
      expect(argv, isNot(contains('--signtool-options')));
      expect(argv, isNot(contains('--build-windows')), reason: 'a build unless --skip-build');
      expect(plan.msixPath, p.join(outDir.path, 'LuminaEngine_0.0.1.1_x64.msix'));
      expect(devDir.existsSync(), isFalse, reason: 'a dry run creates no certificate');
    });

    test('--dry-run through the entry point prints the plan and the exact argv, touching nothing', () async {
      final out = StringBuffer(), err = StringBuffer();
      final code = await runPackageWindows(['--dry-run', '--skip-build', '--output', outDir.path], context(const {}, out, err));
      expect(code, 0, reason: '$err');
      final text = out.toString();
      expect(text, contains('dart run msix:create'));
      expect(text, contains('--certificate-path'));
      expect(text, contains('"CN=Lumina Studio Dev, O=Lumina, C=TR"'), reason: 'arguments with spaces are quoted');
      expect(text, contains('--build-windows false'));
      expect(text, contains('self-signed'));
      expect(text, isNot(contains(RegExp(r'--certificate-password (?!\*)'))), reason: 'the password is masked');
      expect(devDir.existsSync(), isFalse);
      expect(outDir.existsSync(), isFalse);
    });

    test('publish with LUMINA_MSIX_SIGNTOOL_OPTIONS: timestamped signtool options, no certificate password', () async {
      final out = StringBuffer(), err = StringBuffer();
      final plan = await PackagingPlanner(context(const {
        'LUMINA_MSIX_PUBLISHER': 'CN=Arbwick Ltd, O=Arbwick Ltd, C=GB',
        'LUMINA_MSIX_SIGNTOOL_OPTIONS': '/sha1 0123456789ABCDEF0123456789ABCDEF01234567 /fd SHA256',
      }, out, err))
          .plan(PackageWindowsOptions.parse(['--publish', '--dry-run', '--output', outDir.path]));
      final argv = plan.msixArguments;
      expect(plan.mode, PackagingMode.publish);
      final options = valueAfter(argv, '--signtool-options');
      expect(options, contains('/sha1 0123456789ABCDEF0123456789ABCDEF01234567'));
      expect(options, contains('/tr http://timestamp.digicert.com /td SHA256'));
      expect(RegExp('/fd').allMatches(options).length, 1, reason: 'the given /fd is kept, not doubled');
      expect(argv, isNot(contains('--certificate-password')));
      expect(argv, isNot(contains('--certificate-path')));
      expect(valueAfter(argv, '--publisher'), 'CN=Arbwick Ltd, O=Arbwick Ltd, C=GB');
      expect(valueAfter(argv, '--install-certificate'), 'false');
    });

    test('publish honours LUMINA_MSIX_TIMESTAMP_URL and --appinstaller', () async {
      final feed = Directory(p.join(temp.path, 'feed'))..createSync();
      final plan = await PackagingPlanner(context({
        'LUMINA_MSIX_PUBLISHER': 'CN=Arbwick Ltd',
        'LUMINA_MSIX_SIGNTOOL_OPTIONS': '/n "Arbwick Ltd"',
        'LUMINA_MSIX_TIMESTAMP_URL': 'http://timestamp.sectigo.com',
      }, StringBuffer(), StringBuffer()))
          .plan(PackageWindowsOptions.parse(['--publish', '--dry-run', '--appinstaller', feed.path]));
      final options = valueAfter(plan.msixArguments, '--signtool-options');
      expect(options, contains('/fd SHA256'));
      expect(options, contains('/tr http://timestamp.sectigo.com /td SHA256'));
      expect(plan.msixCommand, 'publish');
      expect(valueAfter(plan.msixArguments, '--publish-folder-path'), feed.path);
    });
  });

  group('publish refusals (no build started)', () {
    Future<(int, String)> run(Map<String, String> env) async {
      final out = StringBuffer(), err = StringBuffer();
      // Not a dry run: the refusal must come before any build or signing.
      final code = await runPackageWindows(['--publish', '--skip-build', '--output', outDir.path], context(env, out, err));
      expect(outDir.existsSync(), isFalse, reason: 'nothing was built');
      expect(devDir.existsSync(), isFalse, reason: 'never a self-signed fallback');
      return (code, err.toString());
    }

    test('LUMINA_MSIX_PUBLISHER unset → exit 64 naming it', () async {
      final (code, err) = await run(const {'LUMINA_MSIX_SIGNTOOL_OPTIONS': '/sha1 ABC'});
      expect(code, 64);
      expect(err, contains('LUMINA_MSIX_PUBLISHER'));
    });

    test('neither a certificate path nor signtool options → exit 64 naming both', () async {
      final (code, err) = await run(const {'LUMINA_MSIX_PUBLISHER': 'CN=Arbwick Ltd'});
      expect(code, 64);
      expect(err, allOf(contains('LUMINA_MSIX_CERT_PATH'), contains('LUMINA_MSIX_SIGNTOOL_OPTIONS')));
    });

    test('a certificate path without its password → exit 64 naming LUMINA_MSIX_CERT_PASSWORD', () async {
      final pfx = File(p.join(temp.path, 'x.pfx'))..writeAsBytesSync([1, 2, 3]);
      final (code, err) = await run({'LUMINA_MSIX_PUBLISHER': 'CN=Arbwick Ltd', 'LUMINA_MSIX_CERT_PATH': pfx.path});
      expect(code, 64);
      expect(err, contains('LUMINA_MSIX_CERT_PASSWORD'));
    });

    test('a certificate path that does not exist → exit 64 naming the path', () async {
      final missing = p.join(temp.path, 'missing.pfx');
      final (code, err) = await run({
        'LUMINA_MSIX_PUBLISHER': 'CN=Arbwick Ltd',
        'LUMINA_MSIX_CERT_PATH': missing,
        'LUMINA_MSIX_CERT_PASSWORD': 'x',
      });
      expect(code, 64);
      expect(err, contains(missing));
    });

    test('signtool options that do not select a certificate → exit 64 (msix would fall back to its test certificate)', () async {
      final (code, err) = await run(const {'LUMINA_MSIX_PUBLISHER': 'CN=Arbwick Ltd', 'LUMINA_MSIX_SIGNTOOL_OPTIONS': '/fd SHA256'});
      expect(code, 64);
      expect(err, allOf(contains('LUMINA_MSIX_SIGNTOOL_OPTIONS'), contains('/sha1')));
    });

    group('with a real .pfx', () {
      const throwawaySubject = 'CN=Lumina Throwaway Publisher, O=Lumina Test, C=TR';
      late File pfx;

      setUp(() async {
        if (!Platform.isWindows) return;
        pfx = await createSelfSignedPfx(
          subject: throwawaySubject,
          pfx: File(p.join(temp.path, 'certs', 'throwaway.pfx')),
          password: 'right-password',
        );
      });

      test('a wrong password → exit 64 "cannot open certificate"', () async {
        final (code, err) = await run({
          'LUMINA_MSIX_PUBLISHER': throwawaySubject,
          'LUMINA_MSIX_CERT_PATH': pfx.path,
          'LUMINA_MSIX_CERT_PASSWORD': 'wrong-password',
        });
        expect(code, 64);
        expect(err, contains('cannot open certificate'));
        expect(err, isNot(contains('wrong-password')), reason: 'the password is never printed');
      }, skip: Platform.isWindows ? false : 'PowerShell certificates: Windows only');

      test('a subject that differs from LUMINA_MSIX_PUBLISHER → exit 64 showing both', () async {
        final (code, err) = await run({
          'LUMINA_MSIX_PUBLISHER': 'CN=Arbwick Ltd, O=Arbwick Ltd, C=GB',
          'LUMINA_MSIX_CERT_PATH': pfx.path,
          'LUMINA_MSIX_CERT_PASSWORD': 'right-password',
        });
        expect(code, 64);
        expect(err, allOf(contains('CN=Arbwick Ltd, O=Arbwick Ltd, C=GB'), contains(throwawaySubject)));
      }, skip: Platform.isWindows ? false : 'PowerShell certificates: Windows only');

      test('a matching .pfx: the dry run signs with it, timestamped (a throwaway certificate standing in for a real one)', () async {
        final out = StringBuffer(), err = StringBuffer();
        final plan = await PackagingPlanner(context({
          'LUMINA_MSIX_PUBLISHER': throwawaySubject,
          'LUMINA_MSIX_CERT_PATH': pfx.path,
          'LUMINA_MSIX_CERT_PASSWORD': 'right-password',
        }, out, err))
            .plan(PackageWindowsOptions.parse(['--publish', '--dry-run', '--output', outDir.path]));
        expect(valueAfter(plan.msixArguments, '--publisher'), throwawaySubject);
        final options = valueAfter(plan.msixArguments, '--signtool-options');
        expect(options, contains('/f "${pfx.path}"'));
        expect(options, contains('/tr http://timestamp.digicert.com /td SHA256'));
        expect(plan.certificateThumbprint, matches(RegExp(r'^[0-9A-F]{40}$')));
        expect(plan.describeCommand(), isNot(contains('right-password')));
      }, skip: Platform.isWindows ? false : 'PowerShell certificates: Windows only');
    });
  });

  test('a real build off Windows exits 2 with the Windows-only message', () async {
    final out = StringBuffer(), err = StringBuffer();
    final code = await runPackageWindows(['--skip-build', '--output', outDir.path], context(const {}, out, err));
    expect(code, 2);
    expect(err.toString(), contains('MSIX packages are built on Windows'));
  }, skip: Platform.isWindows ? 'runs off Windows' : false);
}
