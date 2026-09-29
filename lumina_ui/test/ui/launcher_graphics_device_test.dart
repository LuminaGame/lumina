import 'dart:convert';
import 'dart:io';

import 'package:flutter_filament/flutter_filament.dart' show FilamentEngine, FilamentGpuPreference;
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/launcher/view_models/launcher_view_model.dart';
import 'package:lumina_ui/ui/features/launcher/views/launcher_view.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The Graphics Device setting, on this machine's real Vulkan
/// devices and a real launcher settings file.
void main() {
  late Directory config;
  final devices = LuminaGraphicsDevices.list();
  final noOverride = <String, String>{};

  setUp(() => config = Directory.systemTemp.createTempSync('lumina_gpu_setting_'));
  tearDown(() {
    LuminaGraphicsDevices.usePreferred(null, environment: const {});
    LuminaGraphicsDevices.inUse.value = null;
    config.deleteSync(recursive: true);
  });

  Map<String, dynamic> savedSettings() =>
      jsonDecode(File('${config.path}/launcher_settings.json').readAsStringSync()) as Map<String, dynamic>;

  Future<LauncherViewModel> openSettings(WidgetTester tester, {Map<String, String>? environment}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = LauncherViewModel(configDir: config, environment: environment ?? noOverride);
    await tester.pumpWidget(ShadcnApp(theme: luminaEditorTheme(), home: LauncherView(viewModel: vm)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    return vm;
  }

  testWidgets('lists Automatic and every Vulkan device on this machine', (tester) async {
    await openSettings(tester);
    expect(find.byKey(const ValueKey('graphics_device_card')), findsOneWidget);
    if (devices.isEmpty) {
      expect(find.textContaining('Vulkan not available'), findsOneWidget);
      return;
    }
    await tester.tap(find.byKey(const ValueKey('graphics_device_select')));
    await tester.pumpAndSettle();
    expect(find.text('Automatic (let Filament choose)'), findsWidgets);
    for (final d in devices) {
      expect(find.text(d.label), findsOneWidget, reason: d.label);
    }
    final pro = devices.where((d) => d.name.contains('RTX PRO 2000')).firstOrNull;
    if (pro != null) expect(pro.label, 'NVIDIA RTX PRO 2000 Blackwell · Discrete');
  });

  testWidgets('choosing a device saves it, applies it to new engines, and a new launcher reads it back', (tester) async {
    if (devices.isEmpty) return;
    final target = devices.last;
    await openSettings(tester);
    await tester.tap(find.byKey(const ValueKey('graphics_device_select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(target.label).last);
    await tester.pumpAndSettle();

    expect(savedSettings()['graphics_device'], target.name);
    expect(FilamentEngine.defaultGpuPreference, FilamentGpuPreference(deviceName: target.name));

    // A fresh launcher (the next app start) on the same config.
    LuminaGraphicsDevices.usePreferred(null, environment: const {});
    final again = LauncherViewModel(configDir: config, environment: noOverride);
    expect(again.graphicsDevice, target.name);
    expect(FilamentEngine.defaultGpuPreference, FilamentGpuPreference(deviceName: target.name));

    // Automatic clears it.
    await again.setGraphicsDevice(null);
    expect(savedSettings()['graphics_device'], isNull);
    expect(FilamentEngine.defaultGpuPreference, FilamentGpuPreference.automatic);
  });

  testWidgets('a saved device that no longer exists warns and uses Automatic', (tester) async {
    File('${config.path}/launcher_settings.json').writeAsStringSync(jsonEncode({'graphics_device': 'Retired GPU 1000'}));
    final vm = await openSettings(tester);
    expect(vm.graphicsDeviceIsStale, isTrue);
    expect(FilamentEngine.defaultGpuPreference, FilamentGpuPreference.automatic);
    expect(find.byKey(const ValueKey('graphics_device_stale')), findsOneWidget);
    expect(vm.graphicsDevice, 'Retired GPU 1000', reason: 'kept, so it reapplies if the device returns');
  });

  testWidgets('an environment override is shown and wins over the saved device', (tester) async {
    if (devices.isEmpty) return;
    File('${config.path}/launcher_settings.json').writeAsStringSync(jsonEncode({'graphics_device': devices.first.name}));
    await openSettings(tester, environment: {'VK_DEVICE_INDEX': '1'});
    expect(find.text('Overridden by environment (VK_DEVICE_INDEX=1).'), findsOneWidget);
    expect(FilamentEngine.defaultGpuPreference, FilamentGpuPreference.automatic,
        reason: 'automatic in code lets flutter_filament read the environment');
  });

  testWidgets('the device in use is marked once an engine reports it', (tester) async {
    if (devices.isEmpty) return;
    await openSettings(tester);
    LuminaGraphicsDevices.inUse.value = devices.first.name;
    await tester.pumpAndSettle();
    expect(find.text('In use: ${devices.first.name}'), findsOneWidget);
  });
}
