/// The whole `tool/package-windows.sh` run — parse,
/// plan (refusing bad publish input before any build), `dart run msix:…`,
/// verify, report.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:lumina_ui/tooling/windows_packaging/options.dart';
import 'package:lumina_ui/tooling/windows_packaging/plan.dart';
import 'package:lumina_ui/tooling/windows_packaging/verify.dart';

/// The Dart SDK executable to run `msix` with: this process when it is dart,
/// else the Flutter SDK's (FLUTTER_ROOT, the ancestors of this executable,
/// then PATH).
String findDartExecutable(Map<String, String> environment) {
  final exeName = Platform.isWindows ? 'dart.exe' : 'dart';
  final self = Platform.resolvedExecutable;
  if (p.basenameWithoutExtension(self) == 'dart') return self;
  final root = environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    final dart = p.join(root, 'bin', 'cache', 'dart-sdk', 'bin', exeName);
    if (File(dart).existsSync()) return dart;
  }
  var dir = p.dirname(self);
  while (p.dirname(dir) != dir) {
    for (final candidate in [p.join(dir, 'dart-sdk', 'bin', exeName), p.join(dir, 'bin', 'cache', 'dart-sdk', 'bin', exeName)]) {
      if (File(candidate).existsSync()) return candidate;
    }
    dir = p.dirname(dir);
  }
  for (final entry in (environment['PATH'] ?? '').split(Platform.isWindows ? ';' : ':')) {
    if (entry.isEmpty) continue;
    final sdkDart = p.join(entry, 'cache', 'dart-sdk', 'bin', exeName);
    if (File(sdkDart).existsSync()) return sdkDart;
    final dart = p.join(entry, exeName);
    if (File(dart).existsSync()) return dart;
  }
  throw const PackagingException(1, 'Dart SDK not found: put Flutter\'s bin folder on PATH or set FLUTTER_ROOT.');
}

String _size(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).toStringAsFixed(1)} KB';

/// Runs the packaging for [args]; returns the process exit code.
Future<int> runPackageWindows(List<String> args, PackagingContext context) async {
  final out = context.out, err = context.err;
  try {
    final options = PackageWindowsOptions.parse(args);
    if (options.help) {
      out.write(PackageWindowsOptions.usage);
      return 0;
    }
    if (!options.dryRun && !Platform.isWindows) {
      throw const PackagingException(2, 'MSIX packages are built on Windows.');
    }

    final plan = await PackagingPlanner(context).plan(options);
    final modeName = switch (plan.mode) {
      PackagingMode.selfSigned => 'self-signed',
      PackagingMode.publish => 'publish',
      PackagingMode.store => 'Microsoft Store, unsigned',
    };
    out
      ..writeln('Lumina Studio MSIX ($modeName)')
      ..writeln('  identity:  ${plan.config.identityName} (${plan.config.displayName})')
      ..writeln('  version:   ${plan.version}')
      ..writeln('  publisher: ${plan.publisher}')
      ..writeln('  signing:   ${plan.signingSource}')
      ..writeln('  build:     ${plan.skipBuild ? 'reuse ${context.releaseDir}' : 'flutter build windows (Release)'}')
      ..writeln('  output:    ${plan.msixPath}')
      ..writeln('  command:   ${plan.describeCommand()}');
    if (options.dryRun) {
      out.writeln('Dry run: nothing was built or signed.');
      return 0;
    }

    if (plan.skipBuild && !File(p.join(context.releaseDir, 'lumina_ui.exe')).existsSync()) {
      throw PackagingException(1, '--skip-build: no Release build in ${context.releaseDir}; run without --skip-build.');
    }
    Directory(plan.outputDir).createSync(recursive: true);
    final stale = File(plan.msixPath);
    if (stale.existsSync()) stale.deleteSync();

    final dart = findDartExecutable(context.environment);
    final process = await Process.start(
      dart,
      ['run', 'msix:${plan.msixCommand}', ...plan.msixArguments],
      workingDirectory: context.packageRoot,
      environment: context.environment,
      includeParentEnvironment: false,
    );
    String masked(String line) {
      var m = line;
      for (final s in plan.secrets) {
        if (s.isNotEmpty) m = m.replaceAll(s, '****');
      }
      return m;
    }

    final pipes = [
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).forEach((l) => out.writeln(masked(l))),
      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).forEach((l) => err.writeln(masked(l))),
    ];
    final code = await process.exitCode;
    await Future.wait(pipes);
    if (code != 0 || !File(plan.msixPath).existsSync()) {
      throw PackagingException(1, 'dart run msix:${plan.msixCommand} failed (exit $code); no ${plan.msixPath}.');
    }

    final result = await verifyMsix(
      File(plan.msixPath),
      MsixExpectation(
        identityName: plan.config.identityName!,
        publisher: plan.publisher,
        version: plan.version,
        mode: plan.mode,
        thumbprint: plan.certificateThumbprint,
        osMinVersion: plan.config.osMinVersion,
        executionAlias: plan.config.executionAlias,
        capabilities: plan.config.capabilities,
      ),
    );
    if (!result.ok) {
      throw PackagingException(1, 'Verification of ${plan.msixPath} failed:\n  - ${result.problems.join('\n  - ')}');
    }
    out
      ..writeln('Built ${plan.msixPath}')
      ..writeln('  size:       ${_size(result.size)}')
      ..writeln('  mode:       $modeName')
      ..writeln('  publisher:  ${result.publisher}')
      ..writeln('  thumbprint: ${result.signerThumbprint ?? 'none'}')
      ..writeln('  signature:  ${result.signatureStatus}${result.timestamped ? ', timestamped' : ''}')
      ..writeln('  manifest:   ${result.capabilities.join(', ')}; ${result.deviceFamily} ${result.deviceFamilyMinVersion}; '
          'alias ${result.executionAlias}')
      ..writeln('  verified:   ${MsixExpectation.requiredFiles.join(', ')}, data/flutter_assets/, '
          '${MsixExpectation.requiredImages.length} logo images');
    final dev = plan.devCertificate;
    if (dev != null) {
      out
        ..writeln()
        ..writeln('Self-signed: trust the dev certificate once (elevated PowerShell) before installing:')
        ..writeln('  ${dev.trustCommand}')
        ..writeln('Then install with: Add-AppxPackage -Path "${plan.msixPath}"');
    }
    if (plan.mode == PackagingMode.store) {
      out
        ..writeln()
        ..writeln('Upload ${p.basename(plan.msixPath)} in Partner Center (Packages); it does not install locally until '
            'the Store has signed it.');
    }
    return 0;
  } on PackagingException catch (e) {
    err.writeln(e.message);
    return e.exitCode;
  }
}
