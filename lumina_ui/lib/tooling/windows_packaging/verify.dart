/// Reads a built `.msix` back — its files (the Flutter
/// runner and the Filament / Assimp / RigLogic DLLs the native-assets hook
/// bundles), its manifest identity, and its Authenticode signature.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import 'certificates.dart';
import 'options.dart';

/// What a package must be.
class MsixExpectation {
  final String identityName;
  final String publisher;
  final String version;
  final PackagingMode mode;

  /// The signing certificate's thumbprint, when known.
  final String? thumbprint;

  const MsixExpectation({
    required this.identityName,
    required this.publisher,
    required this.version,
    required this.mode,
    this.thumbprint,
  });

  /// Files every Lumina Studio package holds (plus `data/flutter_assets/…`).
  static const List<String> requiredFiles = [
    'lumina_ui.exe',
    'flutter_windows.dll',
    'flutter_filament.dll',
    'flutter_assimp.dll',
    'flutter_riglogic.dll',
    'data/app.so',
    'AppxManifest.xml',
  ];
}

/// The read-back of a package; [problems] is empty when it passed.
class MsixVerification {
  final Set<String> entries;
  final String? identityName;
  final String? publisher;
  final String? version;
  final String? executionAlias;
  final List<String> capabilities;
  final String signatureStatus;
  final String signatureMessage;
  final String? signerSubject;
  final String? signerThumbprint;
  final bool timestamped;
  final int size;
  final List<String> problems;

  const MsixVerification({
    required this.entries,
    required this.identityName,
    required this.publisher,
    required this.version,
    required this.executionAlias,
    required this.capabilities,
    required this.signatureStatus,
    required this.signatureMessage,
    required this.signerSubject,
    required this.signerThumbprint,
    required this.timestamped,
    required this.size,
    required this.problems,
  });

  bool get ok => problems.isEmpty;
}

String _unescapeXml(String s) => s
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

/// Verifies [msix] against [expected]: every problem is collected, each
/// naming what was found and what was expected.
Future<MsixVerification> verifyMsix(File msix, MsixExpectation expected) async {
  final problems = <String>[];
  if (!msix.existsSync()) {
    return MsixVerification(
      entries: const {},
      identityName: null,
      publisher: null,
      version: null,
      executionAlias: null,
      capabilities: const [],
      signatureStatus: 'Missing',
      signatureMessage: '',
      signerSubject: null,
      signerThumbprint: null,
      timestamped: false,
      size: 0,
      problems: ['${msix.path} does not exist'],
    );
  }

  // The package is a zip; entry names are percent-encoded (OPC).
  final entries = <String>{};
  String? manifest;
  final input = InputFileStream(msix.path);
  try {
    final archive = ZipDecoder().decodeStream(input);
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final name = Uri.decodeComponent(file.name.replaceAll(r'\', '/'));
      entries.add(name);
      if (name == 'AppxManifest.xml') manifest = utf8.decode(file.readBytes() ?? const []);
    }
  } on Object catch (e) {
    problems.add('${msix.path} is not a readable MSIX (zip): $e');
  } finally {
    input.closeSync();
  }

  for (final required in MsixExpectation.requiredFiles) {
    if (!entries.contains(required)) problems.add('the package is missing $required');
  }
  if (entries.isNotEmpty && !entries.any((e) => e.startsWith('data/flutter_assets/'))) {
    problems.add('the package is missing data/flutter_assets/');
  }

  String? identityName, publisher, version, alias;
  final capabilities = <String>[];
  if (manifest != null) {
    final identity = RegExp(r'<Identity\b[^>]*>', dotAll: true).firstMatch(manifest)?.group(0) ?? '';
    String? attr(String tag, String name) {
      final m = RegExp('\\b$name="([^"]*)"').firstMatch(tag);
      return m == null ? null : _unescapeXml(m.group(1)!);
    }

    identityName = attr(identity, 'Name');
    publisher = attr(identity, 'Publisher');
    version = attr(identity, 'Version');
    final aliasMatch = RegExp(r'<(?:\w+:)?ExecutionAlias\b[^>]*\bAlias="([^"]+)"').firstMatch(manifest);
    alias = aliasMatch == null ? null : _unescapeXml(aliasMatch.group(1)!).replaceAll(RegExp(r'\.exe$'), '');
    for (final m in RegExp(r'<(?:\w+:)?(?:Device)?Capability\b[^>]*\bName="([^"]+)"').allMatches(manifest)) {
      capabilities.add(m.group(1)!);
    }
    if (identityName != expected.identityName) {
      problems.add('AppxManifest.xml Identity Name is "$identityName", expected "${expected.identityName}"');
    }
    if (publisher != expected.publisher) {
      problems.add('AppxManifest.xml Publisher is "$publisher", expected "${expected.publisher}"');
    }
    if (version != expected.version) {
      problems.add('AppxManifest.xml Version is "$version", expected "${expected.version}"');
    }
  }

  // The signature, read back by Windows.
  var status = 'Unknown', message = '';
  String? signerSubject, signerThumbprint;
  var timestamped = false;
  if (Platform.isWindows) {
    final r = await runPowerShell(
      r"$s = Get-AuthenticodeSignature -LiteralPath $env:LPW_MSIX; "
      r"[Console]::Out.Write((New-Object PSObject -Property @{ status = [string]$s.Status; message = [string]$s.StatusMessage; "
      r"subject = $(if ($s.SignerCertificate) { $s.SignerCertificate.Subject } else { '' }); "
      r"thumbprint = $(if ($s.SignerCertificate) { $s.SignerCertificate.Thumbprint } else { '' }); "
      r"timestamped = [bool]$s.TimeStamperCertificate } | ConvertTo-Json -Compress))",
      environment: {'LPW_MSIX': msix.absolute.path},
    );
    if (r.exitCode == 0) {
      final json = jsonDecode((r.stdout as String).trim()) as Map<String, dynamic>;
      status = json['status'] as String;
      message = json['message'] as String;
      signerSubject = (json['subject'] as String).isEmpty ? null : json['subject'] as String;
      signerThumbprint = (json['thumbprint'] as String).isEmpty ? null : (json['thumbprint'] as String).toUpperCase();
      timestamped = json['timestamped'] as bool;
    } else {
      problems.add('Get-AuthenticodeSignature failed: ${(r.stderr as String).trim()}');
    }
    final allowed = expected.mode == PackagingMode.publish ? const ['Valid'] : const ['Valid', 'UnknownError', 'NotTrusted'];
    if (!allowed.contains(status)) {
      problems.add('the signature status is $status ($message), expected ${allowed.join(' or ')}');
    }
    if (signerSubject != expected.publisher) {
      problems.add('the package is signed by "$signerSubject", expected "${expected.publisher}"');
    }
    if (expected.thumbprint != null && signerThumbprint != expected.thumbprint!.toUpperCase()) {
      problems.add('the signing certificate is $signerThumbprint, expected ${expected.thumbprint}');
    }
    if (expected.mode == PackagingMode.publish && !timestamped) {
      problems.add('the signature is not timestamped');
    }
  }

  return MsixVerification(
    entries: entries,
    identityName: identityName,
    publisher: publisher,
    version: version,
    executionAlias: alias,
    capabilities: capabilities,
    signatureStatus: status,
    signatureMessage: message,
    signerSubject: signerSubject,
    signerThumbprint: signerThumbprint,
    timestamped: timestamped,
    size: msix.lengthSync(),
    problems: problems,
  );
}
