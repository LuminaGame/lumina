import 'dart:io';

import 'package:lumina/lumina.dart' show EditorBuildCache;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';
import '../../../core/host/editor_host.dart';
import '../../main_editor/services/editor_preferences.dart';
import 'project_editor_source_section.dart';

/// Editor Preferences → General › Project Editor Builds: how
/// project editors (a project's code plugins compiled into its own editor)
/// are built, and the shared cache they live in.
class ProjectEditorBuildsPreferencesPage extends StatefulWidget {
  const ProjectEditorBuildsPreferencesPage({super.key, required this.preferences, this.projectDir, this.engineRoot});

  final EditorPreferences preferences;

  /// The open project, whose copy of the engine source the Editor Source
  /// section shows; null in the launcher.
  final String? projectDir;

  /// The engine checkout the copy syncs from; defaults to this editor's.
  final String? engineRoot;

  static const String category = 'General › Project Editor Builds';

  /// The cache the preferences point at.
  static EditorBuildCache cacheFor(EditorPreferences preferences) =>
      EditorBuildCache(root: preferences.editorBuildCacheDir == null ? null : Directory(preferences.editorBuildCacheDir!));

  @override
  State<ProjectEditorBuildsPreferencesPage> createState() => _ProjectEditorBuildsPreferencesPageState();
}

class _ProjectEditorBuildsPreferencesPageState extends State<ProjectEditorBuildsPreferencesPage> {
  late final TextEditingController _cacheDir;
  String? _cleanResult;
  bool _cleaning = false;

  EditorPreferences get prefs => widget.preferences;
  EditorBuildCache get cache => ProjectEditorBuildsPreferencesPage.cacheFor(prefs);

  @override
  void initState() {
    super.initState();
    _cacheDir = TextEditingController(text: cache.root.path);
  }

  @override
  void dispose() {
    _cacheDir.dispose();
    super.dispose();
  }

  static String formatBytes(int bytes) {
    if (bytes >= 1 << 30) return '${(bytes / (1 << 30)).toStringAsFixed(2)} GB';
    if (bytes >= 1 << 20) return '${(bytes / (1 << 20)).toStringAsFixed(1)} MB';
    if (bytes >= 1 << 10) return '${(bytes / (1 << 10)).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  Future<void> _clean() async {
    setState(() => _cleaning = true);
    final c = cache;
    final removed = await c.evict(keep: prefs.editorBuildKeep);
    if (!mounted) return;
    setState(() {
      _cleaning = false;
      _cleanResult = removed.isEmpty
          ? 'Nothing to clean: every build is among the last ${prefs.editorBuildKeep} or was used in the last 30 days.'
          : 'Removed ${removed.length} build(s), freed ${formatBytes(c.lastEvictedBytes)}.';
    });
  }

  Future<void> _openCacheFolder() async {
    final dir = cache.root;
    await dir.create(recursive: true);
    if (Platform.isWindows) {
      await Process.start('explorer', [dir.path], mode: ProcessStartMode.detached);
    } else {
      await Process.start(Platform.isMacOS ? 'open' : 'xdg-open', [dir.path], mode: ProcessStartMode.detached);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = cache;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(ProjectEditorBuildsPreferencesPage.category,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        const Text(
          'Every project opens in its own editor, compiled once per plugin set and engine and shared between projects '
          'through this cache.',
          style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
        ),
        const SizedBox(height: 16),
        // On by default; off restores the shared editor for plugin-less projects.
        _section('Projects', [
          _row(
            'Open every project in its own project editor',
            ListenableBuilder(
              listenable: prefs,
              builder: (context, _) => Switch(
                key: const ValueKey('editor_prefs_per_project_editors'),
                value: prefs.perProjectEditors,
                onChanged: prefs.setPerProjectEditors,
              ),
            ),
            help: "A project's first open builds its editor behind the launcher's splash; later opens start the built "
                'one. Off, a project without code plugins opens in this editor instead.',
          ),
        ]),
        if (widget.projectDir != null) ...[
          const SizedBox(height: 16),
          _section('Editor Source', [
            ProjectEditorSourceSection(
              projectDir: widget.projectDir!,
              engineRoot: widget.engineRoot ?? LuminaEditorHost.engineRoot,
              formatBytes: formatBytes,
            ),
          ]),
        ],
        const SizedBox(height: 16),
        _section('Build', [
          _row(
            'Build Mode',
            Select<String>(
              key: const ValueKey('editor_prefs_editor_build_mode'),
              value: prefs.editorBuildMode,
              onChanged: (v) {
                if (v != null) prefs.setEditorBuildMode(v);
              },
              itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 10.5)),
              popup: SelectPopup(
                items: SelectItemList(children: [
                  for (final m in EditorPreferences.editorBuildModes)
                    SelectItemButton(value: m, child: Text(m, style: const TextStyle(fontSize: 10.5))),
                ]),
              ).call,
            ),
            help: 'release (default) starts fast and runs fast. debug keeps asserts and lets a debugger attach — for '
                'plugin authors. Changing it makes the next Open rebuild.',
          ),
        ]),
        const SizedBox(height: 16),
        _section('Cache', [
          _row(
            'Cache Location',
            TextField(
              key: const ValueKey('editor_prefs_editor_build_cache_dir'),
              controller: _cacheDir,
              style: const TextStyle(fontSize: 10.5),
              onSubmitted: (v) {
                prefs.setEditorBuildCacheDir(v == EditorBuildCache.defaultRoot().path ? null : v);
                setState(() {});
              },
            ),
            help: 'Where built project editors are kept (${formatBytes(c.totalBytes())} in ${c.hashes().length} build(s) now). '
                'Press Enter to apply; empty restores the default.',
          ),
          const SizedBox(height: 10),
          _row(
            'Keep Last N Builds',
            Select<int>(
              key: const ValueKey('editor_prefs_editor_build_keep'),
              value: prefs.editorBuildKeep,
              onChanged: (v) {
                if (v != null) prefs.setEditorBuildKeep(v);
              },
              itemBuilder: (context, item) => Text('$item', style: const TextStyle(fontSize: 10.5)),
              popup: SelectPopup(
                items: SelectItemList(children: [
                  for (final n in const [1, 2, 3, 5, 10, 20])
                    SelectItemButton(value: n, child: Text('$n', style: const TextStyle(fontSize: 10.5))),
                ]),
              ).call,
            ),
            help: 'Clean unused builds keeps this many recently used builds, and anything used in the last 30 days.',
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 220),
            child: Wrap(spacing: 8, children: [
              OutlineButton(
                key: const ValueKey('editor_prefs_clean_editor_builds'),
                onPressed: _cleaning ? null : _clean,
                child: const Text('Clean unused builds', style: TextStyle(fontSize: 11)),
              ),
              GhostButton(
                key: const ValueKey('editor_prefs_open_editor_build_cache'),
                onPressed: _openCacheFolder,
                child: const Text('Open cache folder', style: TextStyle(fontSize: 11)),
              ),
            ]),
          ),
          if (_cleanResult != null)
            Padding(
              padding: const EdgeInsets.only(left: 220, top: 6),
              child: Text(_cleanResult!,
                  key: const ValueKey('editor_prefs_clean_result'),
                  style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
            ),
        ]),
      ],
    );
  }

  Widget _section(String title, List<Widget> rows) => Container(
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

  Widget _row(String label, Widget control, {required String help}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            SizedBox(width: 220, child: Text(label, style: const TextStyle(fontSize: 11, color: EditorColors.foreground))),
            Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: control)),
          ]),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 220),
            child: Text(help, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
          ),
        ],
      );
}
