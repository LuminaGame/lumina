import 'package:lumina_core/lumina_core.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/engine_bootstrap/view_models/engine_bootstrap_view_model.dart';
import 'package:lumina_ui/ui/features/engine_bootstrap/views/engine_bootstrap_view.dart';

/// Editor Preferences → General › Engine Source: which engine source this
/// editor generates and builds games against — the release version and
/// commit, the checkout and its Filament — and, in an installed release,
/// Re-download engine.
class EngineSourcePreferencesPage extends StatefulWidget {
  const EngineSourcePreferencesPage({super.key, this.bootstrap, this.releaseVersion, this.releaseCommit});

  static const String category = 'General › Engine Source';

  /// The release bootstrap; defaults to this build's ([EngineBootstrap.release])
  /// in a release build, none in a dev build.
  final EngineBootstrap? bootstrap;

  /// The release tag and commit; default [LuminaRelease].
  final String? releaseVersion;
  final String? releaseCommit;

  @override
  State<EngineSourcePreferencesPage> createState() => _EngineSourcePreferencesPageState();
}

class _EngineSourcePreferencesPageState extends State<EngineSourcePreferencesPage> {
  late final EngineBootstrap? _bootstrap =
      widget.bootstrap ?? (LuminaRelease.isRelease ? EngineBootstrap.release() : null);

  String get _version => widget.releaseVersion ?? LuminaRelease.version;
  String get _commit => widget.releaseCommit ?? LuminaRelease.commit;

  Future<void> _redownload() async {
    final bootstrap = _bootstrap;
    if (bootstrap == null) return;
    final vm = EngineBootstrapViewModel(bootstrap);
    await showOverlay<void>(
      context,
      const DialogConfiguration(barrierDismissible: false),
      builder: (dialogContext) => AlertDialog(
        key: const Key('engine_source_redownload_dialog'),
        title: const Text('Re-download engine'),
        content: SizedBox(
          width: 720,
          height: 520,
          child: EngineBootstrapView(
            viewModel: vm,
            force: true,
            onReady: (_) => Navigator.of(dialogContext).pop(),
            onQuit: () => Navigator.of(dialogContext).pop(),
            quitLabel: 'Close',
          ),
        ),
      ),
    ).future;
    vm.dispose();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = _bootstrap;
    final EngineCheckout? checkout = bootstrap?.readyCheckout();
    final release = _version.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(EngineSourcePreferencesPage.category,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        Text(
          release
              ? 'This installed Lumina Studio builds games against the engine source of its own release, fetched on first start.'
              : 'Development build: the engine source is the checkout this editor runs from.',
          style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: EditorColors.card,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: EditorColors.border),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row('Engine Version', release ? _version : 'Development build', key: 'engine_source_version'),
              _row('Commit', checkout?.commit ?? (_commit.isNotEmpty ? _commit : (LuminaWorkspace.engineCommit ?? '—')),
                  key: 'engine_source_commit'),
              _row('Checkout', LuminaWorkspace.root, key: 'engine_source_checkout'),
              if (release) _row('Filament', checkout == null ? 'Not downloaded yet' : '${checkout.filamentVersion}  (${checkout.filamentDir})',
                  key: 'engine_source_filament'),
              if (checkout != null) _row('Repository', checkout.repo, key: 'engine_source_repo'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlineButton(
              key: const ValueKey('engine_source_redownload'),
              onPressed: bootstrap == null ? null : _redownload,
              leading: const Icon(LucideIcons.download, size: 12),
              child: const Text('Re-download engine', style: TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                bootstrap == null
                    ? 'Only an installed release downloads its engine source.'
                    : 'Deletes the checkout, downloads it again and resolves its packages.',
                style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(String label, String value, {required String key}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 11, color: EditorColors.foreground))),
            Expanded(
              child: Text(value,
                  key: ValueKey(key), style: const TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
            ),
          ],
        ),
      );
}
