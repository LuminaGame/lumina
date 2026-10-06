import 'dart:io';

import 'package:lumina/lumina.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../main_editor/services/editor_graphics_preferences.dart';

class GraphicsDevicePreferencesPage extends StatefulWidget {
  const GraphicsDevicePreferencesPage({
    super.key,
    required this.configDir,
    this.environment,
  });
  static const category = 'General › Graphics Device';
  final Directory configDir;
  final Map<String, String>? environment;

  @override
  State<GraphicsDevicePreferencesPage> createState() =>
      _GraphicsDevicePreferencesPageState();
}

class _GraphicsDevicePreferencesPageState
    extends State<GraphicsDevicePreferencesPage> {
  late final store = EditorGraphicsPreferences(
    configDir: widget.configDir,
    environment: widget.environment,
  );
  String? error;

  @override
  Widget build(BuildContext context) {
    final devices = store.devices;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          GraphicsDevicePreferencesPage.category,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text('Editor graphics device'),
        const SizedBox(height: 8),
        Select<String>(
          key: const ValueKey('editor_prefs_graphics_device'),
          value: store.selected ?? '',
          enabled: store.override == null,
          itemBuilder: (context, value) =>
              Text(value.isEmpty ? 'Automatic' : value),
          onChanged: (value) {
            if (value == null) return;
            try {
              store.select(value);
              setState(() => error = null);
            } catch (failure) {
              setState(
                () => error = 'Could not save graphics preference: $failure',
              );
            }
          },
          popup: SelectPopup(
            items: SelectItemList(
              children: [
                const SelectItemButton(value: '', child: Text('Automatic')),
                for (final device in devices)
                  SelectItemButton(
                    value: device.name,
                    child: Text(device.label),
                  ),
                if (store.isStale)
                  SelectItemButton(
                    value: store.selected!,
                    child: Text('${store.selected} (unavailable)'),
                  ),
              ],
            ),
          ).call,
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<String?>(
          valueListenable: LuminaGraphicsDevices.inUse,
          builder: (context, device, _) =>
              Text('Currently in use: ${device ?? 'No render engine started'}'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Saved immediately. Restart the editor to use the selected graphics device.',
        ),
        if (devices.isEmpty)
          const Text(
            'No Vulkan graphics devices could be detected. Automatic selection remains available.',
          ),
        if (store.isStale)
          const Text(
            'The saved device is unavailable. Automatic selection will be used.',
          ),
        if (store.override != null)
          Text(
            'Controlled by ${store.override}. Remove the environment override to use this setting.',
          ),
        if (error != null) Text(error!),
      ],
    );
  }
}
