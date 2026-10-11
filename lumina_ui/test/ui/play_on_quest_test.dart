import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/ui/features/main_editor/services/android_device_runner.dart';
import 'package:lumina_ui/ui/features/main_editor/services/android_devices.dart';
import 'package:lumina_ui/ui/features/main_editor/services/android_sdk.dart';

import '../helpers/android_tools_stand_in.dart';

/// A 1×1 PNG, what `screencap -p` streams (smallest real PNG).
final List<int> _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');

/// Play on Device with a Meta Quest 3S: the device as adb describes it (the
/// `getprop`, `dumpsys battery` and `adb devices -l` text captured from the
/// headset, in test/fixtures/android) and the Quest flow (the Meta Quest
/// profile composed, an arm64 build, install, `am start`, captures), run
/// against stand-in tools that record their command lines: no test touches
/// a device.
void main() {
  final fixtures = '${Directory.current.path}/test/fixtures/android';
  String fixture(String name) => File('$fixtures/$name').readAsStringSync();
  const serial = '340YC10GBS0VRX';

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('play_on_quest_'));
  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  Future<(AndroidSdk, AndroidToolsStandIn)> questSdk() async {
    final standIn = await AndroidToolsStandIn.create(Directory('${temp.path}/state'));
    addTearDown(standIn.killAll);
    standIn
      ..write('devices.txt', fixture('adb_devices_quest_3s.txt'))
      ..write('getprop_$serial.txt', fixture('getprop_quest_3s.txt'))
      ..write('battery_$serial.txt', fixture('dumpsys_battery_quest_3s.txt'))
      ..write('list_avds.txt', '');
    File('${standIn.state.path}/screencap.png').writeAsBytesSync(_png);
    File('${standIn.state.path}/screenrecord.mp4').writeAsBytesSync(List<int>.filled(64, 7));
    final avd = Directory('${temp.path}/avd')..createSync();
    return (AndroidSdk(root: temp.path, adbPath: '${temp.path}/adb', emulatorPath: '${temp.path}/emulator', avdHome: avd.path), standIn);
  }

  /// A real project folder: its manifest, Flutter's Android app template.
  Future<Directory> questProject() async {
    final dir = Directory('${temp.path}/Posing Game')..createSync();
    File('${dir.path}/pubspec.yaml').writeAsStringSync('name: posing_game\n\ndependencies:\n  flutter:\n    sdk: flutter\n');
    File('${dir.path}/android/app/src/main/AndroidManifest.xml')
      ..createSync(recursive: true)
      ..writeAsStringSync(fixture('template_AndroidManifest.xml'));
    File('${dir.path}/android/app/build.gradle.kts').writeAsStringSync(fixture('template_build.gradle.kts'));
    File('${dir.path}/android/app/src/main/kotlin/com/example/my_game/MainActivity.kt')
      ..createSync(recursive: true)
      ..writeAsStringSync('package com.example.my_game\n\nimport io.flutter.embedding.android.FlutterActivity\n\nclass MainActivity : FlutterActivity()\n');
    await ProjectRepository().saveProject(
      const LuminaProject(projectName: 'posing_game', packaging: ProjectPackagingSettings(targets: ['android'])),
      dir.path,
    );
    return dir;
  }

  test('the Quest 3S is listed with its model, Horizon OS version and battery', () async {
    final (sdk, standIn) = await questSdk();
    final devices = await AndroidDeviceProbe(sdk, starter: standIn.starter).list();
    final quest = devices.single;
    expect(quest.isQuest, isTrue);
    expect(quest.title, 'Quest 3S · Horizon OS 2.7.0');
    expect(quest.apiLevel, 34);
    expect(quest.abi, 'arm64-v8a');
    expect(quest.batteryLevel, 93);
    expect(quest.description, 'Android 14.0 ("UpsideDownCake") | arm64 | battery 93 %');
  });

  test('choosing it builds the Quest profile, installs, launches the activity and captures', () async {
    final (sdk, standIn) = await questSdk();
    final project = await questProject();
    final quest = (await AndroidDeviceProbe(sdk, starter: standIn.starter).list()).single;
    final runner = AndroidDeviceRunner(project.path, sdk,
        starter: standIn.starter, flutterExecutable: 'flutter', pollInterval: const Duration(milliseconds: 200));
    addTearDown(runner.dispose);

    expect(await runner.prepareProject(quest), isTrue);
    // The Meta Quest profile, composed for this run.
    expect(AndroidDeviceRunner.readApplicationId(project.path), 'com.lumina.posing_game');
    final gradle = File('${project.path}/android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('minSdk = $kQuestMinSdk'));
    expect(gradle, contains('abiFilters += listOf("arm64-v8a")'));
    expect(File('${project.path}/android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        contains('android:name="io.flutter.embedding.android.EnableImpeller" android:value="false"'));

    expect(await runner.start(quest), isTrue);
    expect(runner.state, AndroidRunState.running);
    final cmds = standIn.commands;
    expect(cmds, contains('flutter build apk --debug --target-platform android-arm64'));
    expect(cmds.where((c) => c.startsWith('adb -s $serial install -r ') && c.endsWith('app-debug.apk')), hasLength(1));
    expect(cmds, contains('adb -s $serial shell am start -n com.lumina.posing_game/.MainActivity'));
    expect(cmds.any((c) => c.contains(' monkey ')), isFalse);
    expect(cmds, contains('adb -s $serial logcat -v brief --pid=4242'));

    final png = await runner.captureScreenshot();
    expect(png, isNotNull);
    expect(png!.path.replaceAll('\\', '/'), startsWith('${project.path.replaceAll('\\', '/')}/Saved/Captures/Quest_3S_'));
    expect(png.readAsBytesSync(), _png);
    expect(standIn.commands, contains('adb -s $serial exec-out screencap -p'));

    final video = await runner.recordVideo(seconds: 15);
    expect(video, isNotNull);
    expect(video!.lengthSync(), 64);
    expect(standIn.commands.any((c) => c.startsWith('adb -s $serial shell screenrecord --time-limit 15 /sdcard/Quest_3S_')), isTrue);
    expect(standIn.commands.any((c) => c.startsWith('adb -s $serial pull /sdcard/Quest_3S_')), isTrue);

    await runner.stop();
    expect(runner.state, AndroidRunState.idle);
    expect(standIn.commands, contains('adb -s $serial shell am force-stop com.lumina.posing_game'));
  });
}
