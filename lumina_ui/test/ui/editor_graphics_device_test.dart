import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';
import 'package:lumina_ui/ui/features/main_editor/services/editor_graphics_preferences.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/graphics_device_preferences_page.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  tearDown(
    () => LuminaGraphicsDevices.usePreferred(null, environment: const {}),
  );
  test(
    'environment overrides stay authoritative and unavailable devices are identified',
    () {
      final config = Directory.systemTemp.createTempSync(
        'editor_gpu_override_',
      );
      addTearDown(() => config.deleteSync(recursive: true));
      final store = EditorGraphicsPreferences(
        configDir: config,
        environment: const {'FILAMENT_GPU': 'RTX PRO 2000'},
      );
      expect(store.override, 'FILAMENT_GPU=RTX PRO 2000');
      store.select(config.path);
      expect(store.isStale, isTrue);
      store.apply();
      expect(
        EditorGraphicsPreferences(
          configDir: config,
          environment: const {'VK_DEVICE_INDEX': '1'},
        ).override,
        'VK_DEVICE_INDEX=1',
      );
    },
  );
  testWidgets(
    'graphics preferences show real devices and persist a selection',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final config = Directory.systemTemp.createTempSync('editor_gpu_widget_');
      addTearDown(() => config.deleteSync(recursive: true));
      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: GraphicsDevicePreferencesPage(
              configDir: config,
              environment: const {},
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('editor_prefs_graphics_device')),
      );
      await tester.pumpAndSettle();
      final devices = LuminaGraphicsDevices.list();
      for (final device in devices) {
        expect(find.text(device.label), findsOneWidget);
      }
      if (devices.isNotEmpty) {
        await tester.tap(find.text(devices.first.label));
        await tester.pumpAndSettle();
        expect(
          EditorGraphicsPreferences(configDir: config).selected,
          devices.first.name,
        );
      }
      expect(find.textContaining('Restart the editor'), findsOneWidget);
    },
  );

  test('unreadable graphics settings fall back without preventing startup', () {
    final config = Directory.systemTemp.createTempSync('editor_gpu_invalid_');
    addTearDown(() => config.deleteSync(recursive: true));
    File(
      '${config.path}/launcher_settings.json',
    ).writeAsStringSync('{ invalid');
    expect(EditorGraphicsPreferences(configDir: config).selected, isNull);
  });
  test(
    'editor GPU preference shares launcher storage and preserves other settings',
    () {
      final config = Directory.systemTemp.createTempSync('editor_gpu_');
      addTearDown(() => config.deleteSync(recursive: true));
      final file = File('${config.path}/launcher_settings.json')
        ..writeAsStringSync(
          jsonEncode({
            'theme_mode': 'light',
            'default_projects_dir': config.path,
          }),
        );
      final store = EditorGraphicsPreferences(
        configDir: config,
        environment: const {},
      );
      final devices = LuminaGraphicsDevices.list();
      if (devices.isEmpty) {
        markTestSkipped('Vulkan devices unavailable');
        return;
      }
      store.select(devices.first.name);
      expect(
        EditorGraphicsPreferences(
          configDir: config,
          environment: const {},
        ).selected,
        devices.first.name,
      );
      expect(
        (jsonDecode(file.readAsStringSync()) as Map)['theme_mode'],
        'light',
      );
      store.select(null);
      expect(
        EditorGraphicsPreferences(
          configDir: config,
          environment: const {},
        ).selected,
        isNull,
      );
    },
  );
}
