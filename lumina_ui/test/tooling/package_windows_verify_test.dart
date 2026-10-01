import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/tooling/windows_packaging/windows_packaging.dart';
import 'package:path/path.dart' as p;

/// The read-back check after `msix:create`. A real
/// self-signed `.msix` of Lumina Studio is built once (over the existing
/// Release folder when there is one, else a full build — only with
/// LUMINA_PACKAGING_TESTS=1, as `tool/ci.sh --package` sets), then real
/// copies of it are broken with .NET's ZipArchive. The unsigned Microsoft
/// Store package is built from the same Release folder and checked against
/// what the Store requires of a desktop app's manifest.
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
  late File storeMsix;
  late MsixExpectation expected;
  late MsixExpectation storeExpected;
  final log = StringBuffer();
  final version = msixVersionFromPubspec(File('pubspec.yaml').readAsStringSync());
  final config = MsixConfig.fromPubspec(File('pubspec.yaml').readAsStringSync());

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
    msix = File(p.join(out.path, 'LuminaEngine_${version}_x64.msix'));
    final dev = await DevCertificate(Directory(p.join(temp.path, 'dev'))).ensure(environment: const {});
    expected = MsixExpectation(
      identityName: 'LuminaEngine.LuminaEngine',
      publisher: DevCertificate.subject,
      version: version,
      mode: PackagingMode.selfSigned,
      thumbprint: dev.thumbprint,
      osMinVersion: '10.0.19041.0',
      executionAlias: 'lumina-studio',
      capabilities: const ['internetClient', 'privateNetworkClientServer'],
    );

    // The Store package, from the Release folder the build above left.
    final storeOut = Directory(p.join(temp.path, 'store'));
    final storeCode = await runPackageWindows(
      ['--store', '--skip-build', '--output', storeOut.path],
      PackagingContext(packageRoot: Directory.current.path, environment: Platform.environment, out: log, err: log),
    );
    expect(storeCode, 0, reason: '$log');
    storeMsix = File(p.join(storeOut.path, 'LuminaEngine_${version}_x64.msix'));
    storeExpected = MsixExpectation(
      identityName: 'LuminaEngine.LuminaEngine',
      publisher: config.storePublisher!,
      version: version,
      mode: PackagingMode.store,
      osMinVersion: '10.0.19041.0',
      executionAlias: 'lumina-studio',
      capabilities: const ['internetClient', 'privateNetworkClientServer'],
    );
  });

  tearDownAll(() {
    if (skip == false && temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// Copies the package and edits the copy's zip with .NET (real zip I/O).
  Future<File> brokenCopy(String name, String powershellEdit, {File? from}) async {
    final copy = (from ?? msix).copySync(p.join(temp.path, name));
    final script = "Add-Type -AssemblyName System.IO.Compression.FileSystem; "
        "\$z = [System.IO.Compression.ZipFile]::Open('${copy.path}', 'Update'); "
        "try { $powershellEdit } finally { \$z.Dispose() }";
    final r = await Process.run('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', script]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    return copy;
  }

  test('the built package passes verification', () async {
    expect(msix.existsSync(), isTrue, reason: '$log');
    expect(log.toString(), contains('LuminaEngine_${version}_x64.msix'));
    final result = await verifyMsix(msix, expected);
    expect(result.problems, isEmpty);
    expect(result.entries, containsAll(MsixExpectation.requiredFiles));
    expect(result.entries.any((e) => e.startsWith('data/flutter_assets/')), isTrue);
    expect(result.identityName, 'LuminaEngine.LuminaEngine');
    expect(result.publisher, DevCertificate.subject);
    expect(result.version, version);
    expect(result.signerSubject, DevCertificate.subject);
    expect(result.signerThumbprint, expected.thumbprint);
    expect(result.signatureStatus, anyOf('Valid', 'UnknownError', 'NotTrusted'));
    expect(result.executionAlias, 'lumina-studio');
    expect(result.capabilities, containsAll(['internetClient', 'privateNetworkClientServer', 'runFullTrust']));
    expect(result.size, greaterThan(10 * 1024 * 1024));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 45)));

  test('the Store package: unsigned, the Partner Center identity, the Store manifest requirements', () async {
    expect(storeMsix.existsSync(), isTrue, reason: '$log');
    final result = await verifyMsix(storeMsix, storeExpected);
    expect(result.problems, isEmpty);
    expect(result.signatureStatus, 'NotSigned', reason: 'the Store signs what it is sent');
    expect(result.signerSubject, isNull);
    expect(result.identityName, 'LuminaEngine.LuminaEngine');
    expect(result.publisher, 'CN=76408633-2846-4256-BED6-0DF8748A95C6');
    final parts = result.version!.split('.').map(int.parse).toList();
    expect(parts[3], 0, reason: 'the Store owns the fourth section');
    expect(parts[0], greaterThan(0), reason: 'the Store refuses a first section of 0');
    expect(result.capabilities, containsAll(['internetClient', 'privateNetworkClientServer', 'runFullTrust']));
    expect(result.deviceFamily, 'Windows.Desktop');
    expect(result.deviceFamilyMinVersion, '10.0.19041.0');
    expect(result.executionAlias, 'lumina-studio');
    expect(result.entries, containsAll(MsixExpectation.requiredImages));
    expect(result.entries, containsAll(MsixExpectation.requiredFiles));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 45)));

  test('a Store package whose manifest lacks runFullTrust fails naming it', () async {
    final copy = await brokenCopy('nofulltrust.msix', r"""
$e = $z.GetEntry('AppxManifest.xml'); $r = New-Object System.IO.StreamReader($e.Open()); $xml = $r.ReadToEnd(); $r.Dispose(); $e.Delete();
$xml = $xml.Replace('<rescap:Capability Name="runFullTrust" />', '');
$n = $z.CreateEntry('AppxManifest.xml'); $w = New-Object System.IO.StreamWriter($n.Open()); $w.Write($xml); $w.Dispose()
""", from: storeMsix);
    final result = await verifyMsix(copy, storeExpected);
    expect(result.problems.join('\n'), contains('runFullTrust'));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 5)));

  test('a Store package without the 400 % store logo fails naming it', () async {
    final copy = await brokenCopy('nologo.msix', r"$z.GetEntry('Images/StoreLogo.scale-400.png').Delete()", from: storeMsix);
    final result = await verifyMsix(copy, storeExpected);
    expect(result.problems.join('\n'), contains('Images/StoreLogo.scale-400.png'));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 5)));

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
