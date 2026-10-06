import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';
import '../../main_editor/services/editor_preferences.dart';
import 'appearance_preferences_page.dart';
import 'engine_source_preferences_page.dart';
import 'graphics_device_preferences_page.dart';
import 'project_editor_builds_preferences_page.dart';

/// Edit → Editor Preferences: the user's own editor settings — a category
/// list on the left, the category's sections on the right. Every change is
/// saved at once.
/// General › Appearance picks and edits the JSON editor
/// theme.
class EditorPreferencesSubEditor extends StatefulWidget {
  const EditorPreferencesSubEditor({super.key, required this.preferences, this.onClose, this.projectDir});

  /// The open project (its editor source copy); null outside one.
  final String? projectDir;

  final EditorPreferences preferences;
  final VoidCallback? onClose;

  static const String viewportsCategory = 'Level Editor › Viewports';
  static const String appearanceCategory = 'General › Appearance';

  @override
  State<EditorPreferencesSubEditor> createState() => _EditorPreferencesSubEditorState();
}

class _EditorPreferencesSubEditorState extends State<EditorPreferencesSubEditor> {
  static const String viewportsCategory = EditorPreferencesSubEditor.viewportsCategory;

  String _category = viewportsCategory;

  EditorPreferences get preferences => widget.preferences;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: preferences,
      builder: (context, _) => Container(
        color: EditorColors.background,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 220,
              decoration: const BoxDecoration(
                color: EditorColors.card,
                border: Border(right: BorderSide(color: EditorColors.border)),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('EDITOR PREFERENCES',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground, letterSpacing: 0.8)),
                  const SizedBox(height: 10),
                  for (final category in const [
                    viewportsCategory,
                    EditorPreferencesSubEditor.appearanceCategory,
                    GraphicsDevicePreferencesPage.category,
                    ProjectEditorBuildsPreferencesPage.category,
                    EngineSourcePreferencesPage.category,
                  ])
                    _categoryButton(category),
                ],
              ),
            ),
            Expanded(
              child: _category == EditorPreferencesSubEditor.appearanceCategory
                  ? const AppearancePreferencesPage()
                  : _category == GraphicsDevicePreferencesPage.category
                  ? GraphicsDevicePreferencesPage(configDir: preferences.file.parent)
                  : _category == ProjectEditorBuildsPreferencesPage.category
                  ? ProjectEditorBuildsPreferencesPage(preferences: preferences, projectDir: widget.projectDir)
                  : _category == EngineSourcePreferencesPage.category
                  ? const EngineSourcePreferencesPage()
                  : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(viewportsCategory,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
                  const SizedBox(height: 4),
                  Text('Saved for this user in ${preferences.file.path}',
                      style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                  const SizedBox(height: 16),
                  _section('Controls', [
                    _row(
                      'Flight Camera Control Type',
                      Select<FlightCameraControlType>(
                        key: const ValueKey('editor_prefs_flight_camera_control'),
                        value: preferences.flightCameraControl,
                        onChanged: (value) {
                          if (value != null) preferences.setFlightCameraControl(value);
                        },
                        itemBuilder: (context, item) => Text(item.label, style: const TextStyle(fontSize: 10.5)),
                        popup: SelectPopup(
                          items: SelectItemList(
                            children: [
                              for (final type in FlightCameraControlType.values)
                                SelectItemButton(value: type, child: Text(type.label, style: const TextStyle(fontSize: 10.5))),
                            ],
                          ),
                        ).call,
                      ),
                      help: switch (preferences.flightCameraControl) {
                        FlightCameraControlType.rmbHeld =>
                          'Hold the right mouse button over the viewport and use W/A/S/D to fly, Q/E to go down/up (Shift faster, Ctrl slower). Without the button, Q/W/E/R pick the transform tools.',
                        FlightCameraControlType.always =>
                          'W/A/S/D/Q/E fly whenever the viewport has keyboard focus. Pick transform tools on the toolbar, or cycle them with Space.',
                        FlightCameraControlType.never =>
                          'W/A/S/D/Q/E never move the camera. The right mouse button still looks around; arrow keys still move.',
                      },
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _section('Import', [
                    _row(
                      'Background Import Workers',
                      Select<int>(
                        key: const ValueKey('editor_prefs_import_workers'),
                        value: preferences.importWorkers,
                        onChanged: (value) {
                          if (value != null) preferences.setImportWorkers(value);
                        },
                        itemBuilder: (context, item) => Text('$item', style: const TextStyle(fontSize: 10.5)),
                        popup: SelectPopup(
                          items: SelectItemList(
                            children: [
                              for (var n = 1; n <= EditorPreferences.maxImportWorkers; n++)
                                SelectItemButton(value: n, child: Text('$n', style: const TextStyle(fontSize: 10.5))),
                            ],
                          ),
                        ).call,
                      ),
                      help: 'How many files a Content Browser import converts at once, each in its own background '
                          'isolate. More workers finish large batches sooner and use more memory; the editor stays '
                          'responsive either way.',
                    ),
                  ]),
                  const SizedBox(height: 16),
                  // The server Window → Marketplace uses.
                  _section('Marketplace', [
                    _row(
                      'Marketplace Server',
                      _MarketplaceUrlField(preferences: preferences),
                      help: 'The Lumina Marketplace Window → Marketplace browses and installs from. The default is the '
                          'local server (lumina_marketplace, http://127.0.0.1:8787). Press Enter to apply; the window '
                          'signs in again on the new server.',
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryButton(String category) {
    final selected = category == _category;
    return GestureDetector(
      key: ValueKey(switch (category) {
        viewportsCategory => 'editor_prefs_category_viewports',
        ProjectEditorBuildsPreferencesPage.category => 'editor_prefs_category_project_editor_builds',
        EngineSourcePreferencesPage.category => 'editor_prefs_category_engine_source',
        GraphicsDevicePreferencesPage.category => 'editor_prefs_category_graphics_device',
        _ => 'editor_prefs_category_appearance',
      }),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _category = category),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? EditorColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(category,
            style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? EditorColors.foreground : EditorColors.mutedForeground)),
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, Widget control, {required String help}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 220,
              child: Text(label, style: const TextStyle(fontSize: 11, color: EditorColors.foreground)),
            ),
            Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: control)),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 220),
          child: Text(help, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        ),
      ],
    );
  }
}

/// The Marketplace server URL, applied on Enter (an invalid URL is refused
/// and the stored one kept).
class _MarketplaceUrlField extends StatefulWidget {
  const _MarketplaceUrlField({required this.preferences});

  final EditorPreferences preferences;

  @override
  State<_MarketplaceUrlField> createState() => _MarketplaceUrlFieldState();
}

class _MarketplaceUrlFieldState extends State<_MarketplaceUrlField> {
  late final TextEditingController _controller = TextEditingController(text: widget.preferences.marketplaceUrl);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply(String value) {
    final ok = widget.preferences.setMarketplaceUrl(value);
    setState(() => _error = ok ? null : 'Enter an http:// or https:// URL.');
    if (!ok) _controller.text = widget.preferences.marketplaceUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const ValueKey('editor_prefs_marketplace_url'),
          controller: _controller,
          style: const TextStyle(fontSize: 10.5),
          onSubmitted: _apply,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_error!, style: TextStyle(fontSize: 10, color: EditorColors.destructive)),
          ),
      ],
    );
  }
}
