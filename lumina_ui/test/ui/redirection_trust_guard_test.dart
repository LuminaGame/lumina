// Startup guard against an inherited Windows RedirectionGuard: a Studio
// started by a process that enforces redirection trust (Inno Setup's finish
// page does) cannot traverse the junctions its engine checkout and projects
// are made of, so it relaunches itself without the policy.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/core/host/redirection_trust_guard.dart';

void main() {
  group('decideRedirectionTrustAction', () {
    test('proceeds when the policy is off, audit-only or cannot be read', () {
      expect(decideRedirectionTrustAction(policyFlags: 0, relaunched: false), RedirectionTrustAction.proceed);
      expect(decideRedirectionTrustAction(policyFlags: 0x2, relaunched: false), RedirectionTrustAction.proceed);
      expect(decideRedirectionTrustAction(policyFlags: null, relaunched: false), RedirectionTrustAction.proceed);
      expect(decideRedirectionTrustAction(policyFlags: 0, relaunched: true), RedirectionTrustAction.proceed);
    });

    test('relaunches when redirection trust is enforced', () {
      expect(decideRedirectionTrustAction(policyFlags: 0x1, relaunched: false), RedirectionTrustAction.relaunch);
      expect(decideRedirectionTrustAction(policyFlags: 0x3, relaunched: false), RedirectionTrustAction.relaunch);
    });

    test('explains instead of relaunching again when a relaunched copy is still enforced', () {
      expect(decideRedirectionTrustAction(policyFlags: 0x1, relaunched: true), RedirectionTrustAction.explain);
    });
  });

  test('windowsCommandLine quotes arguments so CommandLineToArgvW reads them back unchanged', () {
    expect(windowsCommandLine([r'C:\Program Files\Lumina Studio\lumina_ui.exe', '--project', r'C:\Users\me\Lumina Projects\My Game']),
        r'"C:\Program Files\Lumina Studio\lumina_ui.exe" --project "C:\Users\me\Lumina Projects\My Game"');
    expect(windowsCommandLine(['a.exe', '', 'plain']), 'a.exe "" plain');
    expect(windowsCommandLine(['a.exe', 'say "hi"']), r'a.exe "say \"hi\""');
    expect(windowsCommandLine(['a.exe', r'C:\dir with space\']), r'a.exe "C:\dir with space\\"');
    expect(windowsCommandLine(['a.exe', r'back\\"slash']), r'a.exe "back\\\\\"slash"');
  });

  group('a process started with redirection trust enforced', () {
    final skip = _harnessSkipReason();
    late Directory root;
    late String fixtureExe;

    setUpAll(() async {
      if (skip != null) return;
      root = Directory.systemTemp.createTempSync('lmrt_');
      fixtureExe = '${root.path}\\fixture.exe';
      final compile = await Process.run(
        _sdkDart(),
        ['compile', 'exe', 'test/helpers/redirection_trust_fixture.dart', '-o', fixtureExe],
        workingDirectory: Directory.current.path,
      );
      expect(compile.exitCode, 0, reason: '${compile.stdout}\n${compile.stderr}');
    });

    tearDownAll(() {
      if (skip != null) return;
      // The junction first, so the recursive delete never follows it.
      final link = Directory('${root.path}\\link');
      if (link.existsSync()) Process.runSync('cmd', ['/c', 'rmdir', link.path]);
      root.deleteSync(recursive: true);
    });

    Future<Map<String, Object?>> runFixture({required bool enforce, required List<String> args}) async {
      final target = Directory('${root.path}\\target')..createSync(recursive: true);
      File('${target.path}\\probe.txt').writeAsStringSync('ok');
      final link = '${root.path}\\link';
      if (!Directory(link).existsSync()) {
        final mk = Process.runSync('cmd', ['/c', 'mklink', '/J', link, target.path]);
        expect(mk.exitCode, 0, reason: '${mk.stdout}${mk.stderr}');
      }
      final report = File('${root.path}\\report_${enforce ? 'enforced' : 'plain'}.json');
      final first = File('${report.path}.first');
      for (final f in [report, first]) {
        if (f.existsSync()) f.deleteSync();
      }
      final started = await Process.run(fixtureExe, [
        if (enforce) '--enforce-and-start',
        '--report',
        report.path,
        '--junction',
        link,
        ...args,
      ]);
      expect(started.exitCode, 0, reason: '${started.stdout}\n${started.stderr}');
      // A relaunched copy runs on its own; wait for its report.
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (!report.existsSync() || report.lengthSync() == 0) {
        if (DateTime.now().isAfter(deadline)) fail('no report from the fixture; launcher said: ${started.stdout}\n${started.stderr}');
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return {
        ...jsonDecode(report.readAsStringSync()) as Map<String, Object?>,
        'first': jsonDecode(first.readAsStringSync()),
      };
    }

    const extraArgs = ['--project', r'C:\Lumina Projects\My "Quoted" Game', ''];

    test('a normal start proceeds in place and traverses a user junction', () async {
      final r = await runFixture(enforce: false, args: extraArgs);
      expect(r['policyFlags'], 0);
      expect(r['relaunched'], isFalse);
      expect(r['pid'], (r['first']! as Map<String, Object?>)['pid']);
      expect(r['junction'], 'ok');
      expect(r['args'], extraArgs);
    }, skip: skip);

    test('relaunches itself without the policy, keeps its arguments and traverses a user junction', () async {
      final r = await runFixture(enforce: true, args: extraArgs);
      final first = r['first']! as Map<String, Object?>;
      expect(first['policyFlags'], 1, reason: 'the enforced launcher must have handed the policy on');
      expect(r['junction'], 'ok');
      expect(r['pid'], isNot(first['pid']));
      expect(r['policyFlags'], 0);
      expect(r['relaunched'], isTrue);
      expect(r['explained'], isNull);
      expect(r['args'], extraArgs);
      expect(r['cwd'], Directory.current.path);
    }, skip: skip);
  });
}

String? _harnessSkipReason() {
  if (!Platform.isWindows) return 'RedirectionGuard is a Windows mitigation';
  if (queryRedirectionTrustPolicyFlags() == null) return 'this Windows has no redirection trust policy (Windows 10 22H2 or later)';
  return null;
}

String _sdkDart() {
  final exe = Platform.resolvedExecutable.replaceAll(r'\', '/');
  final cache = exe.indexOf('/bin/cache/');
  if (cache >= 0) {
    final sdkDart = '${exe.substring(0, cache)}/bin/cache/dart-sdk/bin/dart.exe';
    if (File(sdkDart).existsSync()) return sdkDart;
  }
  return 'dart';
}
