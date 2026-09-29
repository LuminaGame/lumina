/// Code-signing certificates through Windows
/// PowerShell — the stable Lumina development certificate, and reading a
/// `.pfx` / `.cer` to check its subject before a build.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'options.dart';

/// The code-signing extended key usage (1.3.6.1.5.5.7.3.3).
const String codeSigningEku = '1.3.6.1.5.5.7.3.3';

/// What a certificate file holds.
class CertificateInfo {
  final String subject;
  final String thumbprint;
  final DateTime notAfter;
  final bool hasPrivateKey;
  final List<String> enhancedKeyUsages;

  const CertificateInfo({
    required this.subject,
    required this.thumbprint,
    required this.notAfter,
    required this.hasPrivateKey,
    required this.enhancedKeyUsages,
  });
}

/// Runs a Windows PowerShell [script]; secrets travel in [environment], never
/// on the command line.
Future<ProcessResult> runPowerShell(String script, {Map<String, String> environment = const {}}) {
  // The machine module path: a PowerShell 7 parent's PSModulePath breaks the
  // PKI module of Windows PowerShell 5.1 (as the msix package does).
  final prelude = r"$ErrorActionPreference = 'Stop'; "
      r"$env:PSModulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine'); ";
  return Process.run(
    'powershell.exe',
    ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', prelude + script],
    environment: environment,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
}

/// Reads the certificate in [path] (a `.pfx` with [password], or a `.cer`).
/// Throws a [PackagingException] (64) "cannot open certificate …" when the
/// file does not open (a wrong password, not a certificate). The password is
/// never part of the message.
Future<CertificateInfo> readCertificate(String path, {String? password}) async {
  if (!File(path).existsSync()) {
    throw PackagingException.usage('cannot open certificate $path: the file does not exist.');
  }
  const script = r'''
$x509 = 'System.Security.Cryptography.X509Certificates'
try {
  if ($env:LPW_CERT_HAS_PASSWORD -eq '1') {
    $flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::EphemeralKeySet
    $c = New-Object "$x509.X509Certificate2" -ArgumentList $env:LPW_CERT_PATH, $env:LPW_CERT_PASSWORD, $flags
  } else {
    $c = New-Object "$x509.X509Certificate2" -ArgumentList $env:LPW_CERT_PATH
  }
} catch {
  $e = $_.Exception; while ($e.InnerException) { $e = $e.InnerException }
  [Console]::Error.WriteLine($e.Message); exit 3
}
$ekus = @()
foreach ($ext in $c.Extensions) {
  if ($ext -is [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]) {
    foreach ($u in $ext.EnhancedKeyUsages) { $ekus += $u.Value }
  }
}
[Console]::Out.Write((New-Object PSObject -Property @{
  subject = $c.Subject; thumbprint = $c.Thumbprint; notAfter = $c.NotAfter.ToUniversalTime().ToString('o');
  hasPrivateKey = $c.HasPrivateKey; ekus = ($ekus -join ',')
} | ConvertTo-Json -Compress))
''';
  final r = await runPowerShell(script, environment: {
    'LPW_CERT_PATH': path,
    'LPW_CERT_HAS_PASSWORD': password != null ? '1' : '0',
    'LPW_CERT_PASSWORD': password ?? '',
  });
  if (r.exitCode != 0) {
    final why = (r.stderr as String).trim().split(RegExp(r'\r?\n')).first;
    throw PackagingException.usage('cannot open certificate $path${password != null ? ' with the given password' : ''}: $why');
  }
  final json = jsonDecode((r.stdout as String).trim()) as Map<String, dynamic>;
  return CertificateInfo(
    subject: json['subject'] as String,
    thumbprint: (json['thumbprint'] as String).toUpperCase(),
    notAfter: DateTime.parse(json['notAfter'] as String),
    hasPrivateKey: json['hasPrivateKey'] as bool,
    enhancedKeyUsages: (json['ekus'] as String).split(',').where((e) => e.isNotEmpty).toList(),
  );
}

/// Creates a self-signed code-signing certificate for [subject] with
/// `New-SelfSignedCertificate` (in `Cert:\CurrentUser\My`, five years),
/// exports it to [pfx] (protected by [password]) and, when given, its public
/// part to [cer], then deletes it and its key from the user store. Returns
/// [pfx].
Future<File> createSelfSignedPfx({
  required String subject,
  required File pfx,
  required String password,
  File? cer,
}) async {
  pfx.parent.createSync(recursive: true);
  cer?.parent.createSync(recursive: true);
  const script = r'''
Import-Module PKI
$c = New-SelfSignedCertificate -Type CodeSigningCert -Subject $env:LPW_SUBJECT -KeyUsage DigitalSignature `
  -KeyExportPolicy Exportable -HashAlgorithm SHA256 -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddYears(5)
try {
  $pw = ConvertTo-SecureString -String $env:LPW_PASSWORD -AsPlainText -Force
  Export-PfxCertificate -Cert $c -FilePath $env:LPW_PFX -Password $pw | Out-Null
  if ($env:LPW_CER) { Export-Certificate -Cert $c -FilePath $env:LPW_CER -Type CERT | Out-Null }
} finally {
  Remove-Item -Path ("Cert:\CurrentUser\My\" + $c.Thumbprint) -DeleteKey
}
[Console]::Out.Write($c.Thumbprint)
''';
  final r = await runPowerShell(script, environment: {
    'LPW_SUBJECT': subject,
    'LPW_PASSWORD': password,
    'LPW_PFX': pfx.absolute.path,
    'LPW_CER': cer?.absolute.path ?? '',
  });
  if (r.exitCode != 0 || !pfx.existsSync()) {
    throw PackagingException(1, 'New-SelfSignedCertificate failed for "$subject": ${(r.stderr as String).trim()}');
  }
  return pfx;
}

/// The dev certificate as used for a build.
class DevCertificateInfo {
  final String subject;
  final String thumbprint;
  final String password;
  final String pfxPath;
  final String cerPath;

  const DevCertificateInfo({
    required this.subject,
    required this.thumbprint,
    required this.password,
    required this.pfxPath,
    required this.cerPath,
  });
}

/// The stable Lumina development code-signing certificate
/// (`windows/packaging/dev/`, git-ignored): created once, then reused, so
/// every self-signed build carries the same publisher and a newer package
/// upgrades an installed one in place.
class DevCertificate {
  static const String subject = 'CN=Lumina Studio Dev, O=Lumina, C=TR';

  /// Overrides the generated password file.
  static const String passwordVariable = 'LUMINA_MSIX_DEV_PASSWORD';

  final Directory dir;

  DevCertificate(this.dir);

  File get pfx => File(p.join(dir.path, 'lumina_dev.pfx'));
  File get cer => File(p.join(dir.path, 'lumina_dev.cer'));
  File get passwordFile => File(p.join(dir.path, 'password.txt'));

  /// The one-time, admin command that trusts [cer] for sideloading.
  String get trustCommand =>
      "Import-Certificate -FilePath '${cer.absolute.path}' -CertStoreLocation Cert:\\LocalMachine\\TrustedPeople";

  /// The password: [passwordVariable], else the password file (generated
  /// once). Null in a dry run when neither exists yet.
  String? existingPassword(Map<String, String> environment) {
    final fromEnv = environment[passwordVariable];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    if (passwordFile.existsSync()) return passwordFile.readAsStringSync().trim();
    return null;
  }

  /// Creates the certificate on first use, or reuses the existing one.
  Future<DevCertificateInfo> ensure({required Map<String, String> environment}) async {
    var password = existingPassword(environment);
    if (password == null) {
      final random = Random.secure();
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
      password = List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
      dir.createSync(recursive: true);
      passwordFile.writeAsStringSync('$password\n');
    }
    if (!pfx.existsSync()) {
      await createSelfSignedPfx(subject: subject, pfx: pfx, password: password, cer: cer);
    }
    final CertificateInfo info;
    try {
      info = await readCertificate(pfx.path, password: password);
    } on PackagingException catch (e) {
      throw PackagingException.usage('${e.message}\n'
          'The dev certificate in ${dir.path} does not open with its password '
          '(${environment[passwordVariable]?.isNotEmpty == true ? passwordVariable : passwordFile.path}). '
          'Delete the folder to create a new one (a new publisher: uninstall the old package first).');
    }
    if (info.subject != subject) {
      throw PackagingException.usage('The dev certificate ${pfx.path} is for "${info.subject}", not "$subject". '
          'Delete ${dir.path} to create a new one.');
    }
    if (!cer.existsSync()) {
      final r = await runPowerShell(
        r"$c = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList $env:LPW_PFX, $env:LPW_PASSWORD; "
        r"[IO.File]::WriteAllBytes($env:LPW_CER, $c.Export('Cert'))",
        environment: {'LPW_PFX': pfx.absolute.path, 'LPW_PASSWORD': password, 'LPW_CER': cer.absolute.path},
      );
      if (r.exitCode != 0) throw PackagingException(1, 'Could not export ${cer.path}: ${r.stderr}');
    }
    return DevCertificateInfo(
      subject: info.subject,
      thumbprint: info.thumbprint,
      password: password,
      pfxPath: pfx.absolute.path,
      cerPath: cer.absolute.path,
    );
  }
}
