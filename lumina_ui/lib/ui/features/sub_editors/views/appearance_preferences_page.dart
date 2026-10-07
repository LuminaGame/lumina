import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/color_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_data.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme_store.dart';

/// Where Import and Export ask for a file. The defaults are the system file
/// dialogs; a test points them at files it created.
abstract final class AppearanceFilePickers {
  static Future<File?> Function() pickImportFile = _pickImport;
  static Future<File?> Function(String suggestedName) pickExportFile = _pickExport;

  static void reset() {
    pickImportFile = _pickImport;
    pickExportFile = _pickExport;
  }

  static Future<File?> _pickImport() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import an editor theme',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = result?.files.single.path;
    return path == null ? null : File(path);
  }

  static Future<File?> _pickExport(String suggestedName) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export the editor theme',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    return path == null ? null : File(path);
  }
}

/// Edit → Editor Preferences → Appearance → Theme: pick a theme, duplicate it, edit
/// any token with a colour picker while a live preview shows the result,
/// reset the edits, import and export `.json` themes. Built-in themes are
/// read-only (duplicate one to edit it). "Apply" saves the edited user theme
/// and makes it the active one; the whole editor recolours at once.
class AppearancePreferencesPage extends StatefulWidget {
  const AppearancePreferencesPage({super.key});

  @override
  State<AppearancePreferencesPage> createState() => _AppearancePreferencesPageState();
}

class _AppearancePreferencesPageState extends State<AppearancePreferencesPage> {
  String? _selected;
  EditorThemeData? _draft;
  String? _message;

  EditorThemeController get _themes => EditorThemeScope.of(context);

  EditorThemeData _selectedTheme(EditorThemeController c) =>
      c.byName(_selected ?? c.activeName) ?? c.active;

  EditorThemeData _current(EditorThemeController c) {
    final selected = _selectedTheme(c);
    final draft = _draft;
    return draft != null && draft.name == selected.name ? draft : selected;
  }

  bool get _dirty {
    final draft = _draft;
    if (draft == null) return false;
    return draft != _selectedTheme(_themes);
  }

  void _select(String name) => setState(() {
        _selected = name;
        _draft = null;
        _message = null;
      });

  void _edit(EditorThemeData Function(EditorThemeData) change) {
    final c = _themes;
    if (c.isBuiltIn(_current(c).name)) return;
    setState(() => _draft = change(_current(c)));
  }

  void _apply() {
    final c = _themes;
    final theme = _current(c);
    if (!c.isBuiltIn(theme.name) && _dirty) c.save(theme);
    c.activate(theme.name);
    setState(() {
      _draft = null;
      _message = '${theme.name} is now the editor theme.';
    });
  }

  void _duplicate() {
    final copy = _themes.duplicate(_current(_themes).name);
    _select(copy.name);
    setState(() => _message = 'Duplicated as ${copy.name}; edit its colours, then Apply.');
  }

  Future<void> _rename() async {
    final c = _themes;
    final name = _current(c).name;
    final controller = TextEditingController(text: name);
    final newName = await showOverlay<String>(
      context,
      const DialogConfiguration(),
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Theme'),
        content: SizedBox(
          width: 280,
          child: TextField(key: const ValueKey('appearance_rename_field'), controller: controller, autofocus: true),
        ),
        actions: [
          OutlineButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          PrimaryButton(
            key: const ValueKey('appearance_rename_confirm'),
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    ).future;
    controller.dispose();
    if (newName == null || !mounted) return;
    if (c.rename(name, newName)) {
      _select(newName.trim());
    } else {
      setState(() => _message = 'Could not rename to "$newName": the name is empty or taken.');
    }
  }

  Future<void> _delete() async {
    final c = _themes;
    final name = _current(c).name;
    final ok = await showOverlay<bool>(
      context,
      const DialogConfiguration(),
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Theme?'),
        content: Text('$name and its file are deleted.'),
        actions: [
          OutlineButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          DestructiveButton(
            key: const ValueKey('appearance_delete_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).future;
    if (ok == true && mounted && c.delete(name)) _select(c.activeName);
  }

  Future<void> _import() async {
    final file = await AppearanceFilePickers.pickImportFile();
    if (file == null || !mounted) return;
    try {
      final theme = _themes.importFile(file);
      _select(theme.name);
      setState(() => _message = theme.warnings.isEmpty
          ? 'Imported ${theme.name}.'
          : 'Imported ${theme.name} with ${theme.warnings.length} warning(s).');
    } on FileSystemException catch (e) {
      setState(() => _message = 'Could not import ${file.path}: ${e.message}');
    }
  }

  Future<void> _export() async {
    final theme = _current(_themes);
    final file = await AppearanceFilePickers.pickExportFile('${EditorThemeStore.slug(theme.name)}.json');
    if (file == null || !mounted) return;
    // An exported theme is what is on screen, unsaved edits included.
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(theme.encode(), flush: true);
    setState(() => _message = 'Exported ${theme.name} to ${file.path}.');
  }

  @override
  Widget build(BuildContext context) {
    final c = _themes;
    final theme = _current(c);
    final builtIn = c.isBuiltIn(theme.name);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 230, child: _themeList(c, theme)),
        const VerticalDivider(width: 1),
        Expanded(child: _tokenEditor(c, theme, builtIn)),
        const VerticalDivider(width: 1),
        SizedBox(width: 300, child: _AppearancePreview(key: const ValueKey('appearance_preview'), theme: theme)),
      ],
    );
  }

  Widget _themeList(EditorThemeController c, EditorThemeData current) {
    final builtIn = c.isBuiltIn(current.name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: Text('THEMES', style: EditorTypography.panelHeading),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final t in c.themes)
                _ThemeRow(
                  key: ValueKey('appearance_theme_${t.name}'),
                  theme: t,
                  selected: t.name == current.name,
                  active: t.name == c.activeName,
                  builtIn: c.isBuiltIn(t.name),
                  onTap: () => _select(t.name),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlineButton(key: const ValueKey('appearance_duplicate'), size: ButtonSize.small, onPressed: _duplicate, child: const Text('Duplicate')),
              OutlineButton(key: const ValueKey('appearance_rename'), size: ButtonSize.small, onPressed: builtIn ? null : _rename, child: const Text('Rename')),
              DestructiveButton(key: const ValueKey('appearance_delete'), size: ButtonSize.small, onPressed: builtIn ? null : _delete, child: const Text('Delete')),
              OutlineButton(key: const ValueKey('appearance_import'), size: ButtonSize.small, onPressed: _import, child: const Text('Import…')),
              OutlineButton(key: const ValueKey('appearance_export'), size: ButtonSize.small, onPressed: _export, child: const Text('Export…')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tokenEditor(EditorThemeController c, EditorThemeData theme, bool builtIn) {
    final warnings = theme.warnings;
    return ListView(
      key: const ValueKey('appearance_tokens'),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(theme.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
            ),
            OutlineButton(
              key: const ValueKey('appearance_reset'),
              size: ButtonSize.small,
              onPressed: _dirty ? () => setState(() => _draft = null) : null,
              child: const Text('Reset'),
            ),
            const SizedBox(width: 8),
            PrimaryButton(key: const ValueKey('appearance_apply'), size: ButtonSize.small, onPressed: _apply, child: const Text('Apply')),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          builtIn
              ? 'Built-in theme, read-only — Duplicate it to edit its colours.'
              : 'Saved in ${c.store.fileFor(theme.name).path}${_dirty ? ' · unsaved edits' : ''}',
          style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!, key: const ValueKey('appearance_message'), style: const TextStyle(fontSize: 10, color: EditorColors.accent)),
        ],
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          Alert(
            key: const ValueKey('appearance_warnings'),
            leading: const Icon(LucideIcons.triangleAlert, size: 14),
            title: Text('${warnings.length} value(s) replaced by defaults'),
            content: Text(warnings.join('\n'), style: const TextStyle(fontSize: 10)),
          ),
        ],
        const SizedBox(height: 12),
        _group('Layout', [
          _numberRow('Corner radius', 'appearance_radius', theme.radius, EditorThemeData.minRadius, EditorThemeData.maxRadius, builtIn,
              (v) => _edit((t) => t.copyWith(radius: double.parse(v.toStringAsFixed(3))))),
          _numberRow('Density (scaling)', 'appearance_density', theme.density, EditorThemeData.minDensity, EditorThemeData.maxDensity, builtIn,
              (v) => _edit((t) => t.copyWith(density: double.parse(v.toStringAsFixed(2))))),
          _fontRow('Sans font', 'appearance_font_sans', theme.sansFamily, EditorThemeData.sansFamilies, builtIn,
              (f) => _edit((t) => t.copyWith(sansFamily: f))),
          _fontRow('Mono font', 'appearance_font_mono', theme.monoFamily, EditorThemeData.monoFamilies, builtIn,
              (f) => _edit((t) => t.copyWith(monoFamily: f))),
        ]),
        for (final group in EditorThemeData.groups)
          _group(group, [
            for (final token in EditorThemeData.tokens.where((t) => t.group == group)) _tokenRow(theme, token, builtIn),
          ]),
      ],
    );
  }

  Widget _group(String title, List<Widget> rows) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title.toUpperCase(), style: EditorTypography.panelHeading),
            const SizedBox(height: 6),
            ...rows,
          ],
        ),
      );

  Widget _row(String label, String help, Widget editor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: EditorColors.foreground)),
                  if (help.isNotEmpty) Text(help, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                ],
              ),
            ),
            Expanded(child: editor),
          ],
        ),
      );

  Widget _tokenRow(EditorThemeData theme, EditorThemeToken token, bool builtIn) {
    final value = EditorThemeData.formatColor(theme.color(token.key));
    final saved = EditorThemeData.formatColor(_selectedTheme(_themes).color(token.key));
    return _row(
      token.key,
      token.description,
      IgnorePointer(
        ignoring: builtIn,
        child: Opacity(
          opacity: builtIn ? 0.6 : 1,
          child: ColorField(
            key: ValueKey('appearance_token_${token.key}'),
            value: value,
            defaultValue: saved,
            showAlpha: true,
            onChanged: (v) => _setToken(token.key, v),
            onCommit: (v) => _setToken(token.key, v),
            onReset: () => _setToken(token.key, saved),
          ),
        ),
      ),
    );
  }

  void _setToken(String key, String hex) {
    final color = EditorThemeData.parseColor(hex);
    if (color == null) return;
    _edit((t) => t.withColor(key, color));
  }

  Widget _numberRow(String label, String key, double value, double min, double max, bool builtIn, ValueChanged<double> onChanged) {
    return _row(
      label,
      value.toStringAsFixed(2),
      Slider(
        key: ValueKey(key),
        value: SliderValue.single(value.clamp(min, max)),
        min: min,
        max: max,
        onChanged: builtIn ? null : (v) => onChanged(v.value),
      ),
    );
  }

  Widget _fontRow(String label, String key, String value, List<String> families, bool builtIn, ValueChanged<String> onChanged) {
    return _row(
      label,
      '',
      Select<String>(
        key: ValueKey(key),
        value: value,
        enabled: !builtIn,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 10.5)),
        popup: SelectPopup(
          items: SelectItemList(
            children: [for (final f in families) SelectItemButton(value: f, child: Text(f, style: const TextStyle(fontSize: 10.5)))],
          ),
        ).call,
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({super.key, required this.theme, required this.selected, required this.active, required this.builtIn, required this.onTap});

  final EditorThemeData theme;
  final bool selected;
  final bool active;
  final bool builtIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: EditorDensity.rowHeight + 4,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        color: selected ? EditorColors.selectionBg : Colors.transparent,
        child: Row(
          children: [
            // The theme's own surface and accent, as a swatch.
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: theme.color('background'),
                border: Border.all(color: theme.color('primary'), width: 2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(theme.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: EditorColors.foreground)),
            ),
            if (builtIn) const OutlineBadge(child: Text('Built-in', style: TextStyle(fontSize: 8))),
            if (active) ...[
              const SizedBox(width: 6),
              const Icon(LucideIcons.check, key: ValueKey('appearance_active_check'), size: 12, color: EditorColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}

/// A mini editor drawn in [theme]'s own colours — the draft, before Apply —
/// so an edit shows at once: title bar, tab strip, toolbar, a panel with its
/// header and rows, a selected row, text in every weight, buttons, a log.
class _AppearancePreview extends StatelessWidget {
  const _AppearancePreview({super.key, required this.theme});

  final EditorThemeData theme;

  @override
  Widget build(BuildContext context) {
    Color c(String token) => theme.color(token);
    Widget text(String s, String token, {double size = 10, FontWeight? weight}) =>
        Text(s, style: TextStyle(fontSize: size, color: c(token), fontWeight: weight));
    Widget button(String label, String fill, String fg) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: c(fill), borderRadius: BorderRadius.circular(theme.radius * 16)),
          child: text(label, fg, size: 9, weight: FontWeight.w600),
        );
    return Container(
      color: c('background'),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('LIVE PREVIEW', style: EditorTypography.panelHeading),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(border: Border.all(color: c('border')), color: c('background')),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 22,
                  color: c('cardHeader'),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(children: [
                    text('Lumina Studio', 'foreground', weight: FontWeight.bold),
                    const Spacer(),
                    text('—  ▢  ✕', 'mutedForeground'),
                  ]),
                ),
                Container(
                  height: 20,
                  color: c('sidebar'),
                  padding: const EdgeInsets.only(left: 6, top: 3),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: c('cardHeader'),
                        border: Border(top: BorderSide(color: c('primary'), width: 2)),
                      ),
                      child: text('L_Main', 'primary', size: 9, weight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    text('BP_Door', 'foreground', size: 9),
                  ]),
                ),
                Container(height: 18, color: c('cardHeader')),
                Container(
                  height: 20,
                  color: c('cardHeader'),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.centerLeft,
                  child: text('WORLD OUTLINER', 'mutedForeground', size: 9, weight: FontWeight.w600),
                ),
                Container(height: 16, color: c('rail')),
                for (final (i, name) in ['PlayerStart', 'Barrel_01', 'SkyLight'].indexed)
                  Container(
                    height: 20,
                    color: i == 1 ? c('selectionBg') : c('background'),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.centerLeft,
                    child: text(name, i == 1 ? 'foreground' : 'secondaryForeground'),
                  ),
                Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: c('card'), borderRadius: BorderRadius.circular(theme.radius * 16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    text('Location', 'foreground'),
                    text('X 120.0  Y 0.0  Z 45.0', 'mutedForeground', size: 9),
                    const SizedBox(height: 6),
                    Row(children: [
                      button('Apply', 'primary', 'primaryForeground'),
                      const SizedBox(width: 4),
                      button('Accent', 'accent', 'accentForeground'),
                      const SizedBox(width: 4),
                      button('Delete', 'destructive', 'accentForeground'),
                    ]),
                  ]),
                ),
                Container(
                  color: c('rail'),
                  padding: const EdgeInsets.all(6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    text('[info] Level saved', 'logInfo', size: 9),
                    text('[warning] Texture is 8K', 'logWarning', size: 9),
                    text('[error] Missing mesh', 'logError', size: 9),
                    text('[success] Build finished', 'logSuccess', size: 9),
                  ]),
                ),
                Container(
                  height: 30,
                  color: c('graphCanvas'),
                  padding: const EdgeInsets.all(6),
                  child: Row(children: [
                    for (final pin in ['materialPinFloat1', 'materialPinFloat2', 'materialPinFloat3', 'materialPinFloat4', 'materialPinTexture'])
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(color: c(pin), shape: BoxShape.circle),
                      ),
                    const Spacer(),
                    for (final chart in ['chart1', 'chart2', 'chart3', 'chart4', 'chart5'])
                      Container(width: 8, height: 16, margin: const EdgeInsets.only(left: 3), color: c(chart)),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
