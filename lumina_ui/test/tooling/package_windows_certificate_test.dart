import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/tooling/windows_packaging/windows_packaging.dart';
import 'package:path/path.dart' as p;

/// The stable Lumina development code-signing
/// certificate, made once by real PowerShell into a temp folder (the override
/// root), then reused so the self-signed publisher never changes.
void main() {
  final skip = Platform.isWindows ? false : 'New-SelfSignedCertificate: Windows only';
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('lpw_cert_'));
  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  Future<bool> inCurrentUserStore(String thumbprint) async {
    final r = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      "if (Test-Path 'Cert:\\CurrentUser\\My\\$thumbprint') { 'yes' } else { 'no' }",
    ]);
    return (r.stdout as String).trim() == 'yes';
  }

  test('the first run creates the .pfx, the .cer and a password file; the key leaves the user store', () async {
    final dev = DevCertificate(Directory(p.join(temp.path, 'dev')));
    final info = await dev.ensure(environment: const {});
    expect(dev.pfx.existsSync(), isTrue);
    expect(dev.cer.existsSync(), isTrue);
    expect(dev.passwordFile.existsSync(), isTrue);
    expect(dev.passwordFile.readAsStringSync().trim(), hasLength(greaterThanOrEqualTo(24)));
    expect(info.subject, 'CN=Lumina Studio Dev, O=Lumina, C=TR');
    expect(DevCertificate.subject, 'CN=Lumina Studio Dev, O=Lumina, C=TR');
    expect(info.thumbprint, matches(RegExp(r'^[0-9A-F]{40}$')));
    expect(info.password, dev.passwordFile.readAsStringSync().trim());

    // The public .cer carries the same certificate with the code-signing EKU.
    final cer = await readCertificate(dev.cer.path);
    expect(cer.subject, info.subject);
    expect(cer.thumbprint, info.thumbprint);
    expect(cer.enhancedKeyUsages, contains(codeSigningEku));
    expect(cer.notAfter.isAfter(DateTime.now().add(const Duration(days: 4 * 365))), isTrue, reason: 'valid for five years');
    // The .pfx opens with the password.
    final pfx = await readCertificate(dev.pfx.path, password: info.password);
    expect(pfx.thumbprint, info.thumbprint);
    expect(pfx.hasPrivateKey, isTrue);

    expect(await inCurrentUserStore(info.thumbprint), isFalse, reason: 'the key is removed from Cert:\\CurrentUser\\My after export');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('the second run reuses them: same thumbprint, same mtime', () async {
    final dev = DevCertificate(Directory(p.join(temp.path, 'dev')));
    final first = await dev.ensure(environment: const {});
    final pfxTime = dev.pfx.lastModifiedSync();
    final cerTime = dev.cer.lastModifiedSync();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final second = await dev.ensure(environment: const {});
    expect(second.thumbprint, first.thumbprint);
    expect(second.password, first.password);
    expect(dev.pfx.lastModifiedSync(), pfxTime);
    expect(dev.cer.lastModifiedSync(), cerTime);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('LUMINA_MSIX_DEV_PASSWORD is used instead of a password file', () async {
    final dev = DevCertificate(Directory(p.join(temp.path, 'dev')));
    final info = await dev.ensure(environment: const {'LUMINA_MSIX_DEV_PASSWORD': 'from-the-env-123'});
    expect(info.password, 'from-the-env-123');
    expect(dev.passwordFile.existsSync(), isFalse);
    expect((await readCertificate(dev.pfx.path, password: 'from-the-env-123')).thumbprint, info.thumbprint);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));

  test('reading a .pfx with a wrong password fails with "cannot open certificate"', () async {
    final pfx = await createSelfSignedPfx(
      subject: 'CN=Lumina Throwaway, C=TR',
      pfx: File(p.join(temp.path, 'x.pfx')),
      password: 'right',
    );
    expect(
      () => readCertificate(pfx.path, password: 'wrong'),
      throwsA(isA<PackagingException>().having((e) => e.message, 'message', contains('cannot open certificate'))),
    );
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
}
