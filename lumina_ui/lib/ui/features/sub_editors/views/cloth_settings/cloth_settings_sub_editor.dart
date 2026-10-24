import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/theme/asset_type_style.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/widgets/tab_bar_actions.dart';
import 'package:lumina_ui/ui/core/widgets/editor_island.dart';
import 'package:lumina_ui/ui/features/sub_editors/sub_editor_binding.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/cloth_settings_editor_view_model.dart';

/// The Cloth Settings editor: a cloth settings `.lmas` (mass, stiffness,
/// wind, motion, self-collision) that cloth components share. The left
/// panel lists the setting groups, the right one edits the selected group;
/// the toolbar saves or reverts the asset.
class ClothSettingsSubEditor extends StatefulWidget {
  const ClothSettingsSubEditor({
    super.key,
    required this.assetName,
    this.assetPath,
    this.asset,
    this.onClose,
    this.onBind,
    this.viewModel,
  });

  final String assetName;
  final String? assetPath;
  final RealAssetInfo? asset;
  final VoidCallback? onClose;
  final SubEditorBindCallback? onBind;
  final ClothSettingsEditorViewModel? viewModel;

  @override
  State<ClothSettingsSubEditor> createState() => _ClothSettingsSubEditorState();
}

class _ClothSettingsSubEditorState extends State<ClothSettingsSubEditor> {
  late final ClothSettingsEditorViewModel _vm;
  late final bool _ownsVm;

  static const Map<String, IconData> _sectionIcons = {
    'material': LucideIcons.layers,
    'simulation': LucideIcons.cpu,
    'wind': LucideIcons.wind,
    'motion': LucideIcons.move,
    'collision': LucideIcons.copy,
  };

  @override
  void initState() {
    super.initState();
    _ownsVm = widget.viewModel == null;
    _vm = widget.viewModel ?? ClothSettingsEditorViewModel(assetPath: widget.assetPath ?? widget.asset?.lmasPath ?? '');
    widget.onBind?.call(_vm, _vm.save, () => _vm.isDirty);
    _vm.addListener(_changed);
    if (!_vm.isLoaded) _vm.load();
  }

  @override
  void dispose() {
    _vm.removeListener(_changed);
    if (_ownsVm) _vm.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: EditorColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(),
          Expanded(
            child: !_vm.isLoaded
                ? const Center(child: CircularProgressIndicator())
                : EditorIslandGround(child: ResizablePanel.horizontal(
                  dividerBuilder: EditorIslandDividers.gap,
                    children: [
                      ResizablePane(initialSize: 220, minSize: 160, maxSize: 360, child: EditorIsland(key: const ValueKey('cloth_settings_island_sections'), child: _sectionsPanel())),
                      ResizablePane.flex(child: EditorIsland(key: const ValueKey('cloth_settings_island_settings'), child: _settingsPanel())),
                    ],
                  )),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    final style = AssetTypeStyle.of(AssetType.clothSettings);
    return SubEditorToolbar(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.cardHeader,
      children: [
          SubEditorToolbarTitle(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(style.icon, size: 15, color: style.color),
const SizedBox(width: 8),
Text(
            widget.assetName + (_vm.isDirty ? ' *' : ''),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EditorColors.foreground),
          ),
          ])),
          const SizedBox(width: 8),
          Text(style.displayName, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
          if (_vm.error != null) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(_vm.error!,
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: EditorColors.destructive)),
            ),
          ],
          const Spacer(),
          if (_vm.isDirty)
            OutlineButton(
              density: ButtonDensity.compact,
              onPressed: _vm.revert,
              child: const Text('Revert', style: TextStyle(fontSize: 11)),
            ),
          const SizedBox(width: 6),
          PrimaryButton(
            key: const ValueKey('cloth_settings_save'),
            density: ButtonDensity.compact,
            onPressed: _vm.isDirty ? _vm.save : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(LucideIcons.save, size: 12), SizedBox(width: 4), Text('Save', style: TextStyle(fontSize: 11))],
            ),
          ),
          if (widget.onClose != null) ...[
            const SizedBox(width: 8),
            SubEditorToolbarClose(child: GhostButton(
              density: ButtonDensity.iconDense,
              onPressed: widget.onClose,
              child: const Icon(LucideIcons.x, size: 14),
            )),
          ]
      ],
    );
  }

  Widget _sectionsPanel() {
    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header('SETTINGS'),
          for (final section in ClothSettingsEditorViewModel.sections) _sectionRow(section),
        ],
      ),
    );
  }

  Widget _header(String text) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: const BoxDecoration(
          color: EditorColors.cardHeader,
          border: Border(bottom: BorderSide(color: EditorColors.border)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
      );

  Widget _sectionRow(ClothSettingsSection section) {
    final selected = _vm.selectedSection == section.id;
    return GestureDetector(
      key: ValueKey('cloth_settings_section_${section.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _vm.selectSection(section.id),
      child: Container(
        height: 24,
        padding: const EdgeInsets.only(left: 10, right: 8),
        color: selected ? EditorColors.selectionBg : null,
        child: Row(
          children: [
            Icon(_sectionIcons[section.id] ?? LucideIcons.circleDot, size: 12, color: EditorColors.mutedForeground),
            const SizedBox(width: 6),
            Expanded(
              child: Text(section.label, style: const TextStyle(fontSize: 11, color: EditorColors.foreground)),
            ),
            Text('${section.keys.length}', style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          ],
        ),
      ),
    );
  }

  Widget _settingsPanel() {
    final section = _vm.section;
    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(section.label.toUpperCase()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [for (final key in section.keys) _settingRow(key)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingRow(String key) {
    final (label, unit) = ClothSettingsEditorViewModel.labels[key] ?? (key, null);
    final value = _vm.valueOf(key);
    final Widget editor;
    if (value is bool) {
      editor = Align(
        alignment: Alignment.centerLeft,
        child: Switch(value: value, onChanged: (v) => _vm.set(key, v)),
      );
    } else {
      final range = LuminaClothSettingsDocument.ranges[key]!;
      final integer = LuminaClothSettingsDocument.isInteger(key);
      editor = SliderField(
        value: (value as num).toDouble(),
        defaultValue: (_vm.defaultOf(key) as num).toDouble(),
        min: range.$1,
        max: range.$2,
        hardMin: range.$1,
        hardMax: range.$2,
        unit: unit,
        fractionDigits: integer ? 0 : 2,
        onChanged: (v) => _vm.set(key, integer ? v.round() : v),
        onCommit: (v) => _vm.set(key, integer ? v.round() : v),
        onReset: () => _vm.reset(key),
      );
    }
    return Padding(
      key: ValueKey('cloth_settings_$key'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
          ),
          Expanded(child: editor),
        ],
      ),
    );
  }
}
