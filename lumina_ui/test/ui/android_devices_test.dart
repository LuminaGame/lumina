import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/main_editor/services/android_device_runner.dart';
import 'package:lumina_ui/ui/features/main_editor/services/android_devices.dart';
import 'package:lumina_ui/ui/features/main_editor/services/android_sdk.dart';

import '../helpers/android_tools_stand_in.dart';

/// Play on Device's Android side: finding the SDK, reading what adb, the
/// emulator and the AVD files say (text captured from a real machine with a
/// Xiaomi MI 8 Lite connected and two AVDs, in test/fixtures/android), and
/// the build → install → launch flow, run against stand-in tools that record
/// their command lines.
void main() {
  final fixtures = '${Directory.current.path}/test/fixtures/android';
  String fixture(String name) => File('$fixtures/$name').readAsStringSync();

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('android_devices_'));
  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  /// A real SDK layout: `platform-tools/adb[.exe]` (and the emulator).
  Directory makeSdk(String path, {bool adb = true, bool emulator = true}) {
    final ext = Platform.isWindows ? '.exe' : '';
    final dir = Directory(path)..createSync(recursive: true);
    if (adb) File('${dir.path}/platform-tools/adb$ext').createSync(recursive: true);
    if (emulator) File('${dir.path}/emulator/emulator$ext').createSync(recursive: true);
    return dir;
  }

  group('AndroidSdk.locate', () {
    final os = Platform.operatingSystem;

    test('ANDROID_HOME names the SDK', () {
      final sdk = makeSdk('${temp.path}/sdk_home');
      final found = AndroidSdk.locate(environment: {'ANDROID_HOME': sdk.path}, homeDir: '${temp.path}/home');
      expect(found, isNotNull);
      expect(found!.root, sdk.path);
      expect(File(found.adbPath).existsSync(), isTrue);
      expect(found.emulatorPath, isNotNull);
      expect(found.avdHome.replaceAll('\\', '/'), '${temp.path}/home/.android/avd'.replaceAll('\\', '/'));
    });

    test('a folder without adb is skipped for the next candidate (Android Studio\'s default location)', () {
      final noAdb = makeSdk('${temp.path}/broken', adb: false);
      final home = '${temp.path}/home';
      final env = <String, String>{'ANDROID_HOME': noAdb.path};
      final String defaultPath;
      if (os == 'windows') {
        env['LOCALAPPDATA'] = '${temp.path}\\localappdata';
        defaultPath = '${temp.path}\\localappdata\\Android\\Sdk';
      } else if (os == 'macos') {
        defaultPath = '$home/Library/Android/sdk';
      } else {
        defaultPath = '$home/Android/Sdk';
      }
      makeSdk(defaultPath, emulator: false);
      final found = AndroidSdk.locate(environment: env, homeDir: home);
      expect(found, isNotNull);
      expect(found!.root.replaceAll('\\', '/'), defaultPath.replaceAll('\\', '/'));
      expect(found.emulatorPath, isNull, reason: 'no emulator installed in that SDK');
    });

    test('Flutter\'s android-sdk setting is used', () {
      final sdk = makeSdk('${temp.path}/from_flutter');
      final home = '${temp.path}/home';
      final env = <String, String>{};
      if (os == 'windows') {
        env['APPDATA'] = '${temp.path}\\appdata';
        File('${temp.path}\\appdata\\.flutter_settings')
          ..createSync(recursive: true)
          ..writeAsStringSync('{"android-sdk": "${sdk.path.replaceAll('\\', '\\\\')}"}');
      } else {
        File('$home/.config/flutter/settings')
          ..createSync(recursive: true)
          ..writeAsStringSync('{"android-sdk": "${sdk.path}"}');
      }
      expect(AndroidSdk.locate(environment: env, homeDir: home)?.root, sdk.path);
    });

    test('no SDK anywhere → null', () {
      final env = <String, String>{if (os == 'windows') 'LOCALAPPDATA': '${temp.path}\\nothing'};
      expect(AndroidSdk.locate(environment: env, homeDir: '${temp.path}/home'), isNull);
    });
  });

  group('parsers (real captures)', () {
    test('adb devices -l: a phone online and an emulator still booting', () {
      final entries = AdbDeviceEntry.parseList(fixture('adb_devices_phone_and_booting_emulator.txt'));
      expect(entries, hasLength(2));
      expect(entries[0].serial, '0a1b2c3');
      expect(entries[0].state, AndroidDeviceState.online);
      expect(entries[0].properties['model'], 'MI_8_Lite');
      expect(entries[0].isEmulator, isFalse);
      expect(entries[1].serial, 'emulator-5554');
      expect(entries[1].state, AndroidDeviceState.offline);
      expect(entries[1].isEmulator, isTrue);
    });

    test('adb devices -l: a booted emulator', () {
      final entries = AdbDeviceEntry.parseList(fixture('adb_devices_phone_and_booted_emulator.txt'));
      final emulator = entries.singleWhere((e) => e.isEmulator);
      expect(emulator.state, AndroidDeviceState.online);
      expect(emulator.properties['model'], isNotEmpty);
    });

    test('adb devices -l: unauthorized and no-permissions lines (adb\'s documented wording)', () {
      final entries = AdbDeviceEntry.parseList('List of devices attached\n'
          'R58M123ABC             unauthorized usb:1-1 transport_id:4\n'
          '0123456789ABCDEF       no permissions (missing udev rules? user is in the plugdev group); see [http://developer.android.com/tools/device.html] usb:3-2 transport_id:5\n');
      expect(entries[0].state, AndroidDeviceState.unauthorized);
      expect(entries[0].properties['usb'], '1-1');
      expect(entries[1].state, AndroidDeviceState.noPermissions);
      expect(entries[1].properties['transport_id'], '5');
    });

    test('getprop: the Xiaomi MI 8 Lite reads as Android 10.0 ("Q") | arm64', () {
      final props = parseGetprop(fixture('getprop_xiaomi_mi_8_lite.txt'));
      expect(props['ro.product.model'], 'MI 8 Lite');
      expect(props['ro.product.manufacturer'], 'Xiaomi');
      final release = androidReleaseFor(int.parse(props['ro.build.version.sdk']!),
          release: props['ro.build.version.release'], codename: props['ro.build.version.codename']);
      final device = AndroidDevice(
          kind: AndroidDeviceKind.physical, state: AndroidDeviceState.online, name: 'Xiaomi MI 8 Lite', release: release, abi: props['ro.product.cpu.abi']!);
      expect(device.description, 'Android 10.0 ("Q") | arm64');
    });

    test('getprop: the API 37 emulator reads as Android 17.0 ("CinnamonBun") | x86_64', () {
      final props = parseGetprop(fixture('getprop_medium_phone_api_37.txt'));
      final release = androidReleaseFor(int.parse(props['ro.build.version.sdk']!),
          release: props['ro.build.version.release'], codename: props['ro.build.version.codename']);
      expect(release.version, '17.0');
      expect(release.codename, 'CinnamonBun');
      expect(shortAbi(props['ro.product.cpu.abi']!), 'x86_64');
    });

    test('emulator -list-avds and the AVD files', () {
      expect(parseAvdList(fixture('emulator_list_avds.txt')), ['Medium_Phone_API_37.0', 'XR_Headset']);
      // The `.ini` files point at the capturing machine's folder; the reader
      // falls back to `path.rel` beside them.
      final phone = AvdInfo.read('$fixtures/avd', 'Medium_Phone_API_37.0')!;
      expect(phone.displayName, 'Medium Phone API 37.0');
      expect(phone.apiLevel, 37);
      expect(phone.abi, 'x86_64');
      final xr = AvdInfo.read('$fixtures/avd', 'XR_Headset')!;
      expect(xr.displayName, 'XR Headset');
      expect(xr.apiLevel, 34);
      expect(androidReleaseFor(xr.apiLevel), (version: '14.0', codename: 'UpsideDownCake'));
    });

    test('ABI → flutter build apk --target-platform', () {
      expect(flutterTargetPlatformFor('arm64-v8a'), 'android-arm64');
      expect(flutterTargetPlatformFor('x86_64'), 'android-x64');
      expect(flutterTargetPlatformFor('armeabi-v7a'), 'android-arm');
    });
  });

  /// An SDK whose adb / emulator are the stand-in, with the AVD fixtures.
  Future<(AndroidSdk, AndroidToolsStandIn)> standInSdk({bool emulatorBooting = false}) async {
    final standIn = await AndroidToolsStandIn.create(Directory('${temp.path}/state'));
    addTearDown(standIn.killAll);
    final avdHome = Directory('${temp.path}/avd')..createSync();
    for (final e in Directory('$fixtures/avd').listSync(recursive: true).whereType<File>()) {
      final rel = e.path.substring('$fixtures/avd'.length + 1);
      File('${avdHome.path}/$rel')
        ..createSync(recursive: true)
        ..writeAsBytesSync(e.readAsBytesSync());
    }
    final sdk = AndroidSdk(root: temp.path, adbPath: '${temp.path}/adb', emulatorPath: '${temp.path}/emulator', avdHome: avdHome.path);
    standIn
      ..write('list_avds.txt', fixture('emulator_list_avds.txt'))
      ..write('getprop_0a1b2c3.txt', fixture('getprop_xiaomi_mi_8_lite.txt'))
      ..write('devices.txt', fixture(emulatorBooting ? 'adb_devices_phone_and_booting_emulator.txt' : 'adb_devices_phone_only.txt'))
      ..write('avdname_emulator-5554.txt', fixture('adb_emu_avd_name.txt'));
    return (sdk, standIn);
  }

  group('AndroidDeviceProbe', () {
    test('connected devices first, then every AVD; a running emulator is its AVD\'s row', () async {
      final (sdk, standIn) = await standInSdk(emulatorBooting: true);
      final devices = await AndroidDeviceProbe(sdk, starter: standIn.starter).list();
      expect(devices.map((d) => d.name), ['Xiaomi MI 8 Lite', 'Medium Phone API 37.0', 'XR Headset']);
      final phone = devices[0];
      expect(phone.kind, AndroidDeviceKind.physical);
      expect(phone.serial, '0a1b2c3');
      expect(phone.description, 'Android 10.0 ("Q") | arm64');
      expect(phone.id, 'serial:0a1b2c3');
      final medium = devices[1];
      expect(medium.serial, 'emulator-5554', reason: 'the running emulator maps to its AVD and is not listed twice');
      expect(medium.state, AndroidDeviceState.offline);
      expect(medium.hint, contains('booting'));
      expect(medium.description, 'Android 17.0 ("CinnamonBun") | x86_64');
      final xr = devices[2];
      expect(xr.state, AndroidDeviceState.stopped);
      expect(xr.canRun, isTrue);
      expect(xr.id, 'avd:XR_Headset');
      expect(xr.description, 'Android 14.0 ("UpsideDownCake") | x86_64');
    });
  });

  group('AndroidDeviceRunner', () {
    Directory makeProject() {
      final project = Directory('${temp.path}/Game')..createSync();
      File('${project.path}/pubspec.yaml').writeAsStringSync('name: game\nflutter:\n  uses-material-design: true\n');
      File('${project.path}/android/app/build.gradle.kts')
        ..createSync(recursive: true)
        ..writeAsStringSync(
            'android {\n    namespace = "com.example.game"\n    defaultConfig {\n        applicationId = "com.example.game"\n    }\n}\n');
      return project;
    }

    test('a connected phone: build for arm64, install, launch, then Stop force-stops the app', () async {
      final (sdk, standIn) = await standInSdk();
      final project = makeProject();
      final devices = await AndroidDeviceProbe(sdk, starter: standIn.starter).list();
      final phone = devices.firstWhere((d) => d.serial == '0a1b2c3');
      final runner = AndroidDeviceRunner(project.path, sdk,
          starter: standIn.starter, flutterExecutable: 'flutter', pollInterval: const Duration(milliseconds: 200));
      addTearDown(runner.dispose);
      expect(AndroidDeviceRunner.readApplicationId(project.path), 'com.example.game');

      expect(await runner.start(phone), isTrue);
      expect(runner.state, AndroidRunState.running);
      final cmds = standIn.commands;
      expect(cmds, contains('flutter build apk --debug --target-platform android-arm64'));
      expect(cmds.where((c) => c.startsWith('adb -s 0a1b2c3 install -r ') && c.endsWith('app-debug.apk')), hasLength(1));
      expect(cmds, contains('adb -s 0a1b2c3 shell monkey -p com.example.game -c android.intent.category.LAUNCHER 1'));
      expect(cmds, contains('adb -s 0a1b2c3 logcat -v brief --pid=4242'));
      expect(cmds.indexWhere((c) => c.startsWith('flutter build')), lessThan(cmds.indexWhere((c) => c.contains(' install '))));
      expect(cmds.any((c) => c.startsWith('emulator -avd')), isFalse);

      await runner.stop();
      expect(runner.state, AndroidRunState.idle);
      expect(standIn.commands, contains('adb -s 0a1b2c3 shell am force-stop com.example.game'));
    });

    test('a stopped emulator is started and waited for, then the game is built for x86_64', () async {
      final (sdk, standIn) = await standInSdk();
      standIn
        ..write('devices_booted.txt',
            '${fixture('adb_devices_phone_and_booted_emulator.txt').split('\n').firstWhere((l) => l.startsWith('emulator-'))}\n')
        ..write('getprop_emulator-5554.txt', fixture('getprop_medium_phone_api_37.txt'));
      final project = makeProject();
      final devices = await AndroidDeviceProbe(sdk, starter: standIn.starter).list();
      final medium = devices.firstWhere((d) => d.avdName == 'Medium_Phone_API_37.0');
      expect(medium.state, AndroidDeviceState.stopped);
      final runner = AndroidDeviceRunner(project.path, sdk,
          starter: standIn.starter, pollInterval: const Duration(milliseconds: 200));
      addTearDown(runner.dispose);
      final states = <AndroidRunState>[];
      runner.addListener(() => states.add(runner.state));

      expect(await runner.start(medium), isTrue);
      expect(runner.serial, 'emulator-5554');
      expect(states.first, AndroidRunState.booting);
      final cmds = standIn.commands;
      final boot = cmds.indexOf('emulator -avd Medium_Phone_API_37.0');
      final booted = cmds.indexOf('adb -s emulator-5554 shell getprop sys.boot_completed');
      final build = cmds.indexOf('flutter build apk --debug --target-platform android-x64');
      expect(boot, greaterThanOrEqualTo(0));
      expect(booted, greaterThan(boot));
      expect(build, greaterThan(booted));
      expect(cmds, contains('adb -s emulator-5554 shell monkey -p com.example.game -c android.intent.category.LAUNCHER 1'));
      await runner.stop();
    });

    test('a failed build stops before installing', () async {
      final (sdk, standIn) = await standInSdk();
      standIn.write('build_fails', '1');
      final project = makeProject();
      final phone = (await AndroidDeviceProbe(sdk, starter: standIn.starter).list()).first;
      final runner = AndroidDeviceRunner(project.path, sdk, starter: standIn.starter);
      addTearDown(runner.dispose);
      expect(await runner.start(phone), isFalse);
      expect(runner.state, AndroidRunState.idle);
      expect(standIn.commands.any((c) => c.contains(' install ')), isFalse);
      expect(runner.output.any((l) => l.contains('build failed')), isTrue);
    });
  });
}
