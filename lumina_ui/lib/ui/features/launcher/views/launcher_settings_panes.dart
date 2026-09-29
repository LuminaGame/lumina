import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina/lumina.dart';
import '../../../core/theme/editor_theme.dart';
import '../view_models/launcher_view_model.dart';

/// The launcher's Engine Versions pane: the running engine, its render
/// backend and the graphics device in use.
class LauncherEngineVersionsPane extends StatelessWidget {
  const LauncherEngineVersionsPane({super.key, required this.viewModel});

  final LauncherViewModel viewModel;

  LauncherViewModel get _viewModel => viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Engine Versions & Runtime',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Installed Lumina Engine runtimes and active hardware backend.',
            style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: EditorColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: EditorColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.cpu,
                      color: EditorColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Lumina Engine ${_viewModel.engineVersion}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.emerald.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.emerald),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.emerald,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _buildSettingRow(
                  'Engine Version',
                  _viewModel.engineDisplayVersion,
                ),
                _buildSettingRow('3D Render Backend', 'Filament (Vulkan)'),
                ValueListenableBuilder<String?>(
                  valueListenable: LuminaGraphicsDevices.inUse,
                  builder: (context, inUse, _) => _buildSettingRow(
                    'Target Graphics Device',
                    inUse ?? (_viewModel.graphicsDevice ?? 'Automatic'),
                  ),
                ),
                _buildSettingRow('Flutter SDK', 'Flutter 3.x with Dart 3.x'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) => LauncherSettingRow(label: label, value: value);
}

/// The launcher's Settings pane: the default projects directory and the
/// graphics device.
class LauncherSettingsPane extends StatelessWidget {
  const LauncherSettingsPane({super.key, required this.viewModel});

  final LauncherViewModel viewModel;

  LauncherViewModel get _viewModel => viewModel;

  @override
  Widget build(BuildContext context) {
    final dirController = TextEditingController(
      text: _viewModel.defaultProjectsDirectory,
    );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Launcher Settings',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Configure editor workspace defaults and appearance.',
            style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: EditorColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: EditorColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Default Projects Directory',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dirController,
                        onSubmitted: (val) =>
                            _viewModel.setDefaultProjectsDirectory(val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PrimaryButton(
                      onPressed: () => _viewModel.setDefaultProjectsDirectory(
                        dirController.text.trim(),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildGraphicsDeviceCard(),
        ],
      ),
    );
  }

  /// The GPU every engine opened from now on renders on.
  Widget _buildGraphicsDeviceCard() {
    final devices = _viewModel.graphicsDevices;
    final override = _viewModel.graphicsDeviceOverride;
    final saved = _viewModel.graphicsDevice;
    final stale = _viewModel.graphicsDeviceIsStale;
    const muted = TextStyle(fontSize: 10, color: EditorColors.mutedForeground);
    return Container(
      key: const ValueKey('graphics_device_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: EditorColors.border),
      ),
      child: ValueListenableBuilder<String?>(
        valueListenable: LuminaGraphicsDevices.inUse,
        builder: (context, inUse, _) {
          String labelFor(String value) {
            if (value.isEmpty) return 'Automatic (let Filament choose)';
            final device = devices.where((d) => d.name == value).firstOrNull;
            final text = device?.label ?? value;
            return inUse != null && inUse == value ? '$text (in use)' : text;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Graphics Device', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (devices.isEmpty)
                const Text('Vulkan not available — the system default GPU is used.', style: muted)
              else
                SizedBox(
                  width: double.infinity,
                  child: Select<String>(
                    key: const ValueKey('graphics_device_select'),
                    value: saved ?? '',
                    enabled: override == null,
                    onChanged: (value) => _viewModel.setGraphicsDevice(value),
                    itemBuilder: (context, value) => Text(labelFor(value)),
                    popup: SelectPopup(
                      items: SelectItemList(
                        children: [
                          SelectItemButton(value: '', child: Text(labelFor(''))),
                          for (final d in devices) SelectItemButton(value: d.name, child: Text(labelFor(d.name))),
                        ],
                      ),
                    ).call,
                  ),
                ),
              const SizedBox(height: 6),
              if (override != null)
                Text('Overridden by environment ($override).', key: const ValueKey('graphics_device_override'), style: muted)
              else if (stale)
                Text(
                  'The saved device "$saved" was not found; Automatic is used until it returns.',
                  key: const ValueKey('graphics_device_stale'),
                  style: const TextStyle(fontSize: 10, color: EditorColors.warning),
                )
              else
                const Text('Applies to projects opened after this. Open projects keep their current GPU.', style: muted),
              if (inUse != null) ...[
                const SizedBox(height: 4),
                Text('In use: $inUse', key: const ValueKey('graphics_device_in_use'), style: muted),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// One label / value row of a launcher info card.
class LauncherSettingRow extends StatelessWidget {
  const LauncherSettingRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: EditorColors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: EditorTypography.monoFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
