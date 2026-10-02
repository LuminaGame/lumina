import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/services/lumina_config_dir.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/main_editor/services/android_device_runner.dart';
import 'package:lumina_ui/ui/features/main_editor/services/android_sdk.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/views/toolbar_widget.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../helpers/android_tools_stand_in.dart';

/// Play's dropdown lists the Android devices and emulators under "Play on
/// Device" when the machine has an Android SDK, and choosing one runs the
/// project on it. adb, the emulator and flutter are stand-ins that record
/// their command lines (captured real output in test/fixtures/android), so no
/// phone is touched.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixtures = '${Directory.current.path}/test/fixtures/android';
  String fixture(String name) => File('$fixtures/$name').readAsStringSync();

  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('play_on_device_'));
  tearDown(() {
    try {
      temp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {}
  });

  Future<EditorViewModel> bootViewModel() async {
    final dir = Directory('${temp.path}/Projects/DeviceGame')..createSync(recursive: true);
    const project = LuminaProject(projectName: 'DeviceGame', activeLevel: 'contents/levels/L_Main.lmas');
    File('${dir.path}/DeviceGame.lmproject').writeAsStringSync(jsonEncode(project.toMap()));
    File('${dir.path}/android/app/build.gradle.kts')
      ..createSync(recursive: true)
      ..writeAsStringSync('android {\n    defaultConfig {\n        applicationId = "com.example.device_game"\n    }\n}\n');
    final vm = EditorViewModel(initialProject: project, projectLocation: '${temp.path}/Projects');
    await vm.ensureDefaultLevelAssets();
    return vm;
  }

  /// An SDK whose tools are the stand-in, its AVD folder holding the two
  /// captured AVDs.
  Future<(AndroidSdk, AndroidToolsStandIn)> standInSdk({required String devices, required String avds}) async {
    final standIn = await AndroidToolsStandIn.create(Directory('${temp.path}/state'));
    addTearDown(standIn.killAll);
    final avdHome = Directory('${temp.path}/avd')..createSync();
    for (final e in Directory('$fixtures/avd').listSync(recursive: true).whereType<File>()) {
      File('${avdHome.path}/${e.path.substring('$fixtures/avd'.length + 1)}')
        ..createSync(recursive: true)
        ..writeAsBytesSync(e.readAsBytesSync());
    }
    standIn
      ..write('devices.txt', devices)
      ..write('list_avds.txt', avds)
      ..write('getprop_0a1b2c3.txt', fixture('getprop_xiaomi_mi_8_lite.txt'));
    return (
      AndroidSdk(root: temp.path, adbPath: '${temp.path}/adb', emulatorPath: '${temp.path}/emulator', avdHome: avdHome.path),
      standIn,
    );
  }

  Future<void> pumpToolbar(WidgetTester tester, EditorViewModel vm) async {
    tester.view.physicalSize = const Size(2400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ShadcnApp(
      theme: luminaEditorTheme(),
      home: Scaffold(child: Column(children: [ToolbarWidget(viewModel: vm), const Expanded(child: SizedBox())])),
    ));
    await tester.pump();
  }

  /// Opens Play's dropdown and lets the device listing finish.
  Future<void> openPlayModes(WidgetTester tester, EditorViewModel vm) async {
    await tester.tap(find.byKey(const ValueKey('play_mode_dropdown')));
    await tester.pump();
    await tester.runAsync(() async {
      final until = DateTime.now().add(const Duration(seconds: 30));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      while (vm.androidDevices.loading && DateTime.now().isBefore(until)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> closeMenu(WidgetTester tester) async {
    await tester.tapAt(const Offset(1200, 800));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the devices and emulators show as a tree; choosing the phone runs the game on it and is remembered', (tester) async {
    final vm = await tester.runAsync(bootViewModel) as EditorViewModel;
    final (sdk, standIn) = (await tester.runAsync(() => standInSdk(
          devices: fixture('adb_devices_phone_only.txt'),
          avds: fixture('emulator_list_avds.txt'),
        )))!;
    vm
      ..androidSdkLocator = (() => sdk)
      ..androidProcessStarter = standIn.starter;
    addTearDown(() => vm.androidRunner?.dispose());
    await pumpToolbar(tester, vm);

    await tester.tap(find.byKey(const ValueKey('play_mode_dropdown')));
    await tester.pump();
    expect(find.byKey(const ValueKey('play_on_device_section')), findsOneWidget);
    expect(find.byKey(const ValueKey('play_on_device_loading')), findsOneWidget, reason: 'the listing runs without blocking the menu');
    await tester.runAsync(() async {
      while (vm.androidDevices.loading) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('play_on_device_loading')), findsNothing);
    expect(find.text('Play on Device'), findsOneWidget);
    expect(find.text('Connected devices'), findsOneWidget);
    expect(find.text('Emulators'), findsOneWidget);
    expect(find.text('Xiaomi MI 8 Lite'), findsOneWidget);
    expect(find.text('Android 10.0 ("Q") | arm64'), findsOneWidget);
    expect(find.text('Medium Phone API 37.0'), findsOneWidget);
    expect(find.text('Android 17.0 ("CinnamonBun") | x86_64'), findsOneWidget);
    expect(find.text('XR Headset'), findsOneWidget);
    expect(find.text('Android 14.0 ("UpsideDownCake") | x86_64'), findsOneWidget);
    expect(find.byKey(const ValueKey('play_on_device_refresh')), findsOneWidget);
    // Tree order: the phone under Connected devices, the AVDs under Emulators.
    double y(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(y('Connected devices'), lessThan(y('Xiaomi MI 8 Lite')));
    expect(y('Xiaomi MI 8 Lite'), lessThan(y('Emulators')));
    expect(y('Emulators'), lessThan(y('Medium Phone API 37.0')));

    await tester.tap(find.byKey(const ValueKey('play_on_device_serial:0a1b2c3')));
    await tester.pump();
    await tester.runAsync(() async {
      final until = DateTime.now().add(const Duration(seconds: 60));
      while (vm.androidRunner?.state != AndroidRunState.running && DateTime.now().isBefore(until)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await tester.pump();
    expect(vm.androidRunner!.state, AndroidRunState.running);
    final cmds = standIn.commands;
    expect(cmds, contains('flutter build apk --debug --target-platform android-arm64'));
    expect(cmds.any((c) => c.startsWith('adb -s 0a1b2c3 install -r ') && c.endsWith('app-debug.apk')), isTrue);
    expect(cmds, contains('adb -s 0a1b2c3 shell monkey -p com.example.device_game -c android.intent.category.LAUNCHER 1'));
    expect(find.byKey(const ValueKey('play_on_device_status')), findsOneWidget);
    expect(vm.isPlaying, isFalse, reason: 'Play on Device does not start Play In Editor');

    // Remembered: checked on the next open, and on disk for the next editor.
    expect(vm.androidDevices.lastDeviceId, 'serial:0a1b2c3');
    expect(File('${LuminaConfigDir.resolve().path}/play_on_device.json').readAsStringSync(), contains('serial:0a1b2c3'));

    // The toolbar's Stop force-stops the game on the device.
    await tester.tap(find.byKey(const ValueKey('toolbar_stop')));
    await tester.runAsync(() async {
      final until = DateTime.now().add(const Duration(seconds: 20));
      while (vm.androidRunner!.isActive && DateTime.now().isBefore(until)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();
    expect(standIn.commands, contains('adb -s 0a1b2c3 shell am force-stop com.example.device_game'));
    expect(find.byKey(const ValueKey('play_on_device_status')), findsNothing);

    await openPlayModes(tester, vm);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('play_on_device_serial:0a1b2c3')),
        matching: find.byWidgetPredicate((w) => w is Icon && w.icon == LucideIcons.check),
      ),
      findsOneWidget,
    );
    await closeMenu(tester);
  });

  testWidgets('without an Android SDK there is no Play on Device section', (tester) async {
    final vm = await tester.runAsync(bootViewModel) as EditorViewModel;
    vm.androidSdkLocator = () => null;
    await pumpToolbar(tester, vm);
    await openPlayModes(tester, vm);
    expect(find.byKey(const ValueKey('play_mode_standalone')), findsOneWidget);
    expect(find.byKey(const ValueKey('play_on_device_section')), findsNothing);
    expect(find.text('Play on Device'), findsNothing);
    await closeMenu(tester);
  });

  testWidgets('an SDK with no device and no AVD shows a disabled "No devices" row', (tester) async {
    final vm = await tester.runAsync(bootViewModel) as EditorViewModel;
    final (sdk, standIn) = (await tester.runAsync(() => standInSdk(devices: 'List of devices attached\n', avds: '')))!;
    vm
      ..androidSdkLocator = (() => sdk)
      ..androidProcessStarter = standIn.starter;
    await pumpToolbar(tester, vm);
    await openPlayModes(tester, vm);
    expect(find.byKey(const ValueKey('play_on_device_section')), findsOneWidget);
    expect(find.byKey(const ValueKey('play_on_device_none')), findsOneWidget);
    expect(find.text('No devices'), findsOneWidget);
    expect(find.text('Connected devices'), findsNothing);
    await closeMenu(tester);
  });
}
