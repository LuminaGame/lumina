import 'dart:io';
import 'dart:isolate';

import 'package:lumina/lumina.dart' show EditorHostGeneratorService, EditorSourceVendorService;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';

/// Editor Preferences › Project Editor Builds › Editor Source:
/// the open project's copy of the engine source under `.lumina/editor/`,
/// whether the engine moved on since it was made, and Sync, which replaces
/// the copy (after a warning) so the next open rebuilds from the engine's
/// current source.
class ProjectEditorSourceSection extends StatefulWidget {
  const ProjectEditorSourceSection({super.key, required this.projectDir, required this.engineRoot, required this.formatBytes});

  final String projectDir;
  final String engineRoot;
  final String Function(int bytes) formatBytes;

  @override
  State<ProjectEditorSourceSection> createState() => _ProjectEditorSourceSectionState();
}

class _ProjectEditorSourceSectionState extends State<ProjectEditorSourceSection> {
  bool _loading = true;
  bool _vendored = false;
  List<String> _packages = const [];
  String? _copiedAt;
  int? _bytes;
  List<String> _engineChanged = const [];
  double? _syncProgress;
  String? _message;

  String get _hostDir => EditorHostGeneratorService.hostDirOf(widget.projectDir);
  EditorSourceVendorService get _vendor => EditorSourceVendorService(engineRoot: widget.engineRoot);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final host = _hostDir;
    final vendored = _vendor.isVendored(host);
    final stamp = EditorSourceVendorService.readStamp(host);
    final packages = EditorSourceVendorService.copiedRepos(host);
    final bytes = vendored ? await _sizeInIsolate(host, packages) : null;
    final changed = vendored ? await _vendor.engineChangedSince(host) : const <String>[];
    if (!mounted) return;
    setState(() {
      _loading = false;
      _vendored = vendored;
      _packages = packages;
      _copiedAt = stamp?['copiedAt'] as String?;
      _bytes = bytes;
      _engineChanged = changed;
    });
  }

  void _confirmSync() {
    showOverlay(
      context,
      const DialogConfiguration(),
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sync Editor Source from Engine'),
        content: Text(
          "This replaces every file under ${_hostDir.replaceAll(r'\', '/')}/<package>/ with the engine's current source. "
          "Changes you made to this project's copy of the editor are lost.",
        ),
        actions: [
          GhostButton(
            key: const ValueKey('editor_prefs_sync_cancel'),
            onPressed: () => closeOverlay(dialogContext),
            child: const Text('Cancel'),
          ),
          DestructiveButton(
            key: const ValueKey('editor_prefs_sync_confirm'),
            onPressed: () {
              closeOverlay(dialogContext);
              _sync();
            },
            child: const Text('Sync'),
          ),
        ],
      ),
    );
  }

  Future<void> _sync() async {
    setState(() {
      _syncProgress = 0;
      _message = null;
    });
    String message;
    try {
      await _vendor.sync(_hostDir, onProgress: (fraction, _) {
        if (mounted && (fraction - (_syncProgress ?? 0) >= 0.01 || fraction == 1)) setState(() => _syncProgress = fraction);
      });
      message = "Synced from the engine. The next open rebuilds this project's editor.";
    } on Object catch (e) {
      message = 'Sync failed: $e';
    }
    if (!mounted) return;
    setState(() {
      _syncProgress = null;
      _message = message;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    const help = TextStyle(fontSize: 10, color: EditorColors.mutedForeground);
    final copiedAt = _copiedAt == null ? null : DateTime.tryParse(_copiedAt!)?.toLocal();
    final when = copiedAt == null
        ? '?'
        : '${copiedAt.year}-${_two(copiedAt.month)}-${_two(copiedAt.day)} ${_two(copiedAt.hour)}:${_two(copiedAt.minute)}';
    final status = _loading
        ? 'Reading the copy…'
        : _vendored
            ? 'Copied on $when · ${_packages.length} packages · ${_bytes == null ? '?' : widget.formatBytes(_bytes!)}'
            : 'Not copied yet: the next open copies the engine source into the project (about 650 MB).';
    final engine = _loading || !_vendored
        ? ''
        : _engineChanged.isEmpty
            ? 'Up to date with the engine'
            : 'Engine changed since the copy: ${_engineChanged.join(', ')}';
    final syncing = _syncProgress != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_hostDir.replaceAll(r'\', '/'),
            key: const ValueKey('editor_prefs_editor_source_path'),
            style: const TextStyle(fontSize: 10.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground)),
        const SizedBox(height: 6),
        Text(status, key: const ValueKey('editor_prefs_editor_source_status'), style: help),
        if (engine.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(engine,
              key: const ValueKey('editor_prefs_editor_source_engine'),
              style: TextStyle(fontSize: 10, color: _engineChanged.isEmpty ? EditorColors.logSuccess : EditorColors.logWarning)),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          OutlineButton(
            key: const ValueKey('editor_prefs_sync_editor_source'),
            onPressed: syncing || _loading ? null : _confirmSync,
            child: const Text('Sync Editor Source from Engine…', style: TextStyle(fontSize: 11)),
          ),
          GhostButton(
            key: const ValueKey('editor_prefs_refresh_editor_source'),
            onPressed: syncing || _loading ? null : _load,
            child: const Text('Refresh', style: TextStyle(fontSize: 11)),
          ),
        ]),
        if (syncing) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(key: const ValueKey('editor_prefs_sync_progress'), value: _syncProgress),
        ],
        if (_message != null) ...[
          const SizedBox(height: 6),
          Text(_message!, key: const ValueKey('editor_prefs_sync_result'), style: help),
        ],
        const SizedBox(height: 6),
        const Text(
          "The project's editor builds from this copy, not from the engine checkout. Edit it to change this project's "
          'editor; Sync takes the engine\'s current source instead. Filament is linked from the engine, not copied.',
          style: help,
        ),
      ],
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

/// The copy's size on disk, off the UI isolate (top-level, so the closure
/// captures only its arguments). Links are not followed: Filament is shared.
Future<int> _sizeInIsolate(String host, List<String> packages) => Isolate.run(() {
      var total = 0;
      for (final rel in packages) {
        final dir = Directory('$host/$rel');
        if (!dir.existsSync()) continue;
        for (final f in dir.listSync(recursive: true, followLinks: false).whereType<File>()) {
          total += f.lengthSync();
        }
      }
      return total;
    });
