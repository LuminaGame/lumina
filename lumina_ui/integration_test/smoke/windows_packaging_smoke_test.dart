import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/tooling/windows_packaging/windows_packaging.dart';
import 'package:path/path.dart' as p;

import '../../test/helpers/desktop_window.dart';
import '../../test/helpers/mcp_test_client.dart';

/// A self-signed MSIX of Lumina Studio, built by
/// `tool/package-windows.sh`, installed with Add-AppxPackage, started through
/// its `lumina-studio` execution alias (from a folder outside the workspace,
/// as a user would), shown on DISPLAY1, then uninstalled. A second start opens
/// a project straight into the stock editor and reads its Filament viewport
/// over MCP, which proves the packaged DLLs load.
///
/// The dev certificate must already be trusted (the one-time admin step the
/// script prints); the scenario never installs it and never uses
/// `Add-AppxPackage -AllowUnsigned`.
const String _name = 'Windows Packaging Smoke: a self-signed MSIX of Lumina Studio installs, launches to the launcher and uninstalls';
const String _identity = 'LuminaEngine.LuminaEngine';

/// Whether [thumbprint] is trusted for sideloading on this machine.
Future<bool> _trusted(String thumbprint) async {
  final r = await runPowerShell(
    r"$t = $env:LPW_THUMB; "
    r"if ((Test-Path ('Cert:\LocalMachine\TrustedPeople\' + $t)) -or (Test-Path ('Cert:\LocalMachine\Root\' + $t))) { 'yes' } else { 'no' }",
    environment: {'LPW_THUMB': thumbprint},
  );
  return (r.stdout as String).trim() == 'yes';
}

/// The installed package's `lumina_ui` processes.
Future<List<int>> _packagedPids() => processIds('lumina_ui', pathLike: r'*\WindowsApps\*LuminaEngine*');

Future<ProcessResult> _appx(String script, [Map<String, String> environment = const {}]) =>
    runPowerShell(script, environment: {'LPW_IDENTITY': _identity, ...environment});

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(_name, (tester) async {
    if (!Platform.isWindows) {
      markTestSkipped('MSIX packages are Windows only');
      return;
    }
    await tester.runAsync(() async {
      final uiRoot = Directory.current.path;
      final dev = DevCertificate(Directory(p.join(uiRoot, 'windows', 'packaging', 'dev')));
      String trustSkip(String thumbprint) =>
          'the dev certificate ($thumbprint) is not trusted on this machine; run once, in an elevated PowerShell: '
          '${dev.trustCommand}';

      // Known already: skip before a packaging run.
      if (dev.pfx.existsSync() && dev.cer.existsSync()) {
        final thumb = (await readCertificate(dev.cer.path)).thumbprint;
        if (!await _trusted(thumb)) {
          markTestSkipped(trustSkip(thumb));
          return;
        }
      }
      final sh = findGitSh();
      if (sh == null) {
        markTestSkipped('Git Bash sh.exe not found (tool/package-windows.sh)');
        return;
      }

      // 1. tool/package-windows.sh, self-signed. The Release folder is reused
      // when present: a Release build next to this running Debug app would
      // share build/windows/x64.
      final temp = Directory.systemTemp.createTempSync('lpws_');
      final outDir = Directory(p.join(temp.path, 'out'));
      final hasRelease = File(p.join(uiRoot, 'build', 'windows', 'x64', 'runner', 'Release', 'lumina_ui.exe')).existsSync();
      final env = Map<String, String>.of(Platform.environment);
      final flutterRoot = env['FLUTTER_ROOT'];
      if (flutterRoot != null) env['PATH'] = '${p.join(flutterRoot, 'bin')};${env['PATH']}';
      final packaging = Stopwatch()..start();
      final built = await Process.run(
          sh, [p.join(uiRoot, 'tool', 'package-windows.sh'), if (hasRelease) '--skip-build', '--output', outDir.path],
          environment: env, workingDirectory: uiRoot);
      packaging.stop();
      expect(built.exitCode, 0, reason: '${built.stdout}\n${built.stderr}');
      final version = msixVersionFromPubspec(File(p.join(uiRoot, 'pubspec.yaml')).readAsStringSync());
      final msix = File(p.join(outDir.path, 'LuminaEngine_${version}_x64.msix'));
      expect(msix.existsSync(), isTrue);
      expect(built.stdout as String, contains('Import-Certificate'), reason: 'the script prints the one-time trust command');
      final cert = await readCertificate(dev.cer.path);
      expect(cert.subject, DevCertificate.subject);
      final verification = await verifyMsix(
          msix,
          MsixExpectation(
              identityName: _identity,
              publisher: DevCertificate.subject,
              version: version,
              mode: PackagingMode.selfSigned,
              thumbprint: cert.thumbprint));
      expect(verification.problems, isEmpty);
      if (!await _trusted(cert.thumbprint)) {
        temp.deleteSync(recursive: true);
        markTestSkipped(trustSkip(cert.thumbprint));
        return;
      }

      // Outside the workspace: an installed copy has no checkout around it.
      final cwd = Directory(p.join(temp.path, 'cwd'))..createSync();
      // Config and project outside AppData (MSIX redirects AppData writes).
      final smokeRoot = Directory(p.join(uiRoot, 'build', 'msix_smoke', '${DateTime.now().millisecondsSinceEpoch}'))
        ..createSync(recursive: true);
      final configDir = Directory(p.join(smokeRoot.path, 'config'))..createSync();
      final seen = <int>[];
      try {
        // 2. Install (a previous run's leftover first).
        await _appx(r'Get-AppxPackage -Name $env:LPW_IDENTITY | Remove-AppxPackage');
        final add = await _appx(r'Add-AppxPackage -Path $env:LPW_MSIX', {'LPW_MSIX': msix.path});
        expect(add.exitCode, 0, reason: '${add.stderr}');
        final info = await _appx(r'Get-AppxPackage -Name $env:LPW_IDENTITY | '
            r'Select-Object Name, Publisher, @{n="Version";e={[string]$_.Version}}, InstallLocation | ConvertTo-Json -Compress');
        final installed = jsonDecode((info.stdout as String).trim()) as Map<String, dynamic>;
        expect(installed['Publisher'], DevCertificate.subject);
        expect(installed['Version'], version);
        final location = installed['InstallLocation'] as String;
        expect(location, contains(r'\WindowsApps\'));
        for (final dll in ['flutter_filament.dll', 'flutter_assimp.dll', 'flutter_riglogic.dll']) {
          expect(File(p.join(location, dll)).existsSync(), isTrue, reason: '$dll is installed');
        }

        // 3. Start through the execution alias → the launcher, on DISPLAY1.
        final alias = p.join(Platform.environment['LOCALAPPDATA']!, 'Microsoft', 'WindowsApps', 'lumina-studio.exe');
        expect(File(alias).existsSync(), isTrue, reason: 'the lumina-studio alias is registered');
        final appEnv = {
          ...Platform.environment,
          'LUMINA_CONFIG_DIR': configDir.path,
          'FILAMENT_GPU': 'RTX PRO 2000',
          'CUDA_VISIBLE_DEVICES': '1',
          'LUMINA_MOUSE_CAPTURE': 'off',
        }..remove('LUMINA_WORKSPACE');
        final started = Stopwatch()..start();
        await Process.start(alias, const [], workingDirectory: cwd.path, environment: appEnv, mode: ProcessStartMode.detached);
        (int, int, int, int)? rect;
        int? pid;
        while (started.elapsed < const Duration(seconds: 90) && rect == null) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          final pids = await _packagedPids();
          seen.addAll(pids.where((x) => !seen.contains(x)));
          if (pids.isNotEmpty) {
            pid = pids.first;
            rect = await placeOnDisplay1(pid);
          }
        }
        expect(rect, isNotNull, reason: 'the installed Lumina Studio opened a window');
        final launcherUp = started.elapsed;
        await Future<void>.delayed(const Duration(seconds: 3));
        final (x, y, w, h) = await placeOnDisplay1(pid!) ?? rect!;

        final video = recordRegionWebm(x: x, y: y, w: w, h: h, outWebm: p.join(temp.path, 'launcher.webm'));
        await Future<void>.delayed(const Duration(seconds: 4));
        final png = await windowPng(pid, p.join(temp.path, 'launcher.png'));
        expect(await distinctColours(png), greaterThan(20), reason: 'the launcher drew its UI (not a blank window)');
        SmokeArtifacts.saveScreenshot('$_name: launcher on DISPLAY1', png.readAsBytesSync(), metrics: {
          'packaging_s': packaging.elapsed.inSeconds,
          'launcher_window_ms': launcherUp.inMilliseconds,
          'msix_bytes': msix.lengthSync(),
          'skip_build': hasRelease,
        });
        SmokeArtifacts.saveVideo('$_name: launcher', (await video).readAsBytesSync());
        for (final id in await _packagedPids()) {
          await killTree(id);
        }

        // 4. The Filament viewport from the package: `--project` with the
        // default preferences. A plugin-less project opens in the installed
        // stock editor (with no engine checkout around it there is no
        // per-project editor to build); the viewport is read over MCP.
        final projectDir = Directory(p.join(smokeRoot.path, 'PkgGame'))..createSync();
        const project = LuminaProject(projectName: 'PkgGame', activeLevel: 'contents/levels/L_Main.lmas');
        File(p.join(projectDir.path, 'PkgGame.lmproject')).writeAsStringSync(jsonEncode(project.toMap()));
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final port = socket.port;
        await socket.close();
        File(p.join(configDir.path, 'mcp_server_settings.json')).writeAsStringSync(jsonEncode({'enabled': true, 'port': port}));
        await Process.start(alias, ['--project', projectDir.path],
            workingDirectory: cwd.path, environment: appEnv, mode: ProcessStartMode.detached);
        final connection = File(p.join(configDir.path, 'mcp_server.json'));
        final editorStart = Stopwatch()..start();
        while (!connection.existsSync() && editorStart.elapsed < const Duration(seconds: 120)) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          for (final id in await _packagedPids()) {
            if (!seen.contains(id) && await placeOnDisplay1(id) != null) seen.add(id);
          }
        }
        expect(connection.existsSync(), isTrue, reason: 'the installed editor opened PkgGame and started its MCP server');
        final conn = jsonDecode(connection.readAsStringSync()) as Map<String, dynamic>;
        final client = McpTestClient(conn['url'] as String, conn['token'] as String);
        await client.handshake();
        final projectInfo = await client.callTool('project_info');
        expect(projectInfo.data['project_name'], 'PkgGame');
        // A real mesh through the packaged import pipeline (Assimp / GLB), placed and framed.
        const barrel = 'Props/Barrels/dented_barrel.glb';
        final imported = await client.callTool('import_asset', {'path': p.join(SmokeArtifacts.testAssetsDir.path, barrel)});
        expect(imported.isError, isFalse, reason: imported.text);
        final meshAsset =
            (imported.data['imported'] as List).cast<Map<String, Object?>>().firstWhere((a) => a['type'] == 'filamesh');
        final placed = await client.callTool('spawn_actor_from_asset', {'asset': meshAsset['path']});
        expect(placed.isError, isFalse, reason: placed.text);
        expect(placed.data['has_geometry'], isTrue);
        await client.callTool('focus_actor', {'id': (placed.data['actor'] as Map<String, Object?>)['id']});
        await Future<void>.delayed(const Duration(seconds: 4));
        final shot = await client.callTool('viewport_screenshot');
        final image = base64Decode(shot.content.firstWhere((c) => c['type'] == 'image')['data'] as String);
        final viewportPng = File(p.join(temp.path, 'viewport.png'))..writeAsBytesSync(image);
        expect(await distinctColours(viewportPng), greaterThan(20), reason: 'the Filament viewport rendered the level');
        SmokeArtifacts.saveScreenshot('$_name: installed editor Filament viewport', image,
            usedAssets: const [barrel], metrics: {'editor_mcp_ready_ms': editorStart.elapsed.inMilliseconds});
        client.close();
      } finally {
        for (final id in await _packagedPids()) {
          await killTree(id);
        }
        await Future<void>.delayed(const Duration(seconds: 2));
        // 5. Uninstall.
        final remove = await _appx(r'Get-AppxPackage -Name $env:LPW_IDENTITY | Remove-AppxPackage');
        final left = await _appx(r'(Get-AppxPackage -Name $env:LPW_IDENTITY | Measure-Object).Count');
        expect((left.stdout as String).trim(), '0', reason: 'Remove-AppxPackage: ${remove.stderr}');
        for (final d in [temp, smokeRoot]) {
          try {
            if (d.existsSync()) d.deleteSync(recursive: true);
          } on FileSystemException catch (_) {}
        }
      }
    });
  }, timeout: const Timeout(Duration(minutes: 60)));
}
