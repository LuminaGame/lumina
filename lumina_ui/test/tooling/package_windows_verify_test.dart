import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/tooling/windows_packaging/windows_packaging.dart';
import 'package:path/path.dart' as p;

/// The read-back check after `msix:create`. A real
/// self-signed `.msix` of Lumina Studio is built once (over the existing
/// Release folder when there is one, else a full build — only with
/// LUMINA_PACKAGING_TESTS=1, as `tool/ci.sh --package` sets), then real
/// copies of it are broken with .NET's ZipArchive.
void main() {
  final release = Directory(p.join('build', 'windows', 'x64', 'runner', 'Release'));
  final hasRelease = File(p.join(release.path, 'lumina_ui.exe')).existsSync();
  final Object skip = !Platform.isWindows
      ? 'MSIX packages are built on Windows'
      : (hasRelease || Platform.environment['LUMINA_PACKAGING_TESTS'] == '1')
          ? false
          : 'no Release build to package: run `flutter build windows` or set LUMINA_PACKAGING_TESTS=1 (tool/ci.sh --package)';

  late Directory temp;
  late File msix;
  late MsixExpectation expected;
  final log = StringBuffer();

  setUpAll(() async {
    if (skip != false) return;
    // A short root: makeappx and MSBuild paths stay below MAX_PATH.
    temp = Directory.systemTemp.createTempSync('lpwv_');
    final out = Directory(p.join(temp.path, 'out'));
    final code = await runPackageWindows(
      [if (hasRelease) '--skip-build', '--output', out.path],
      PackagingContext(
        packageRoot: Directory.current.path,
        environment: Platform.environment,
        devCertificateDir: p.join(temp.path, 'dev'),
        out: log,
        err: log,
      ),
    );
    expect(code, 0, reason: '$log');
    msix = File(p.join(out.path, 'LuminaEngine_0.0.1.1_x64.msix'));
    final dev = await DevCertificate(Directory(p.join(temp.path, 'dev'))).ensure(environment: const {});
    expected = MsixExpectation(
      identityName: 'LuminaEngine.LuminaEngine',
      publisher: DevCertificate.subject,
      version: '0.0.1.1',
      mode: PackagingMode.selfSigned,
      thumbprint: dev.thumbprint,
    );
  });

  tearDownAll(() {
    if (skip == false && temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// Copies the package and edits the copy's zip with .NET (real zip I/O).
  Future<File> brokenCopy(String name, String powershellEdit) async {
    final copy = msix.copySync(p.join(temp.path, name));
    final script = "Add-Type -AssemblyName System.IO.Compression.FileSystem; "
        "\$z = [System.IO.Compression.ZipFile]::Open('${copy.path}', 'Update'); "
        "try { $powershellEdit } finally { \$z.Dispose() }";
    final r = await Process.run('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', script]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    return copy;
  }

  test('the built package passes verification', () async {
    expect(msix.existsSync(), isTrue, reason: '$log');
    expect(log.toString(), contains('LuminaEngine_0.0.1.1_x64.msix'));
    final result = await verifyMsix(msix, expected);
    expect(result.problems, isEmpty);
    expect(result.entries, containsAll(MsixExpectation.requiredFiles));
    expect(result.entries.any((e) => e.startsWith('data/flutter_assets/')), isTrue);
    expect(result.identityName, 'LuminaEngine.LuminaEngine');
    expect(result.publisher, DevCertificate.subject);
    expect(result.version, '0.0.1.1');
    expect(result.signerSubject, DevCertificate.subject);
    expect(result.signerThumbprint, expected.thumbprint);
    expect(result.signatureStatus, anyOf('Valid', 'UnknownError', 'NotTrusted'));
    expect(result.executionAlias, 'lumina-studio');
    expect(result.capabilities, containsAll(['internetClient', 'privateNetworkClientServer', 'runFullTrust']));
    expect(result.size, greaterThan(10 * 1024 * 1024));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 45)));

  test('a copy without flutter_filament.dll fails naming the file', () async {
    final copy = await brokenCopy('nofil.msix', r"$z.GetEntry('flutter_filament.dll').Delete()");
    final result = await verifyMsix(copy, expected);
    expect(result.problems, isNotEmpty);
    expect(result.problems.join('\n'), contains('flutter_filament.dll'));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 5)));

  test('a manifest with another publisher fails naming both', () async {
    const other = 'CN=Someone Else, O=Elsewhere, C=US';
    final copy = await brokenCopy('pub.msix', r"""
$e = $z.GetEntry('AppxManifest.xml'); $r = New-Object System.IO.StreamReader($e.Open()); $xml = $r.ReadToEnd(); $r.Dispose(); $e.Delete();
$xml = $xml.Replace('Publisher="CN=Lumina Studio Dev, O=Lumina, C=TR"', 'Publisher="CN=Someone Else, O=Elsewhere, C=US"');
$n = $z.CreateEntry('AppxManifest.xml'); $w = New-Object System.IO.StreamWriter($n.Open()); $w.Write($xml); $w.Dispose()
""");
    final result = await verifyMsix(copy, expected);
    final text = result.problems.join('\n');
    expect(text, contains(other));
    expect(text, contains(DevCertificate.subject));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 5)));
}
