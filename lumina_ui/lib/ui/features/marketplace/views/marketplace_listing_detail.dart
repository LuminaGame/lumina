import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/marketplace/view_models/marketplace_view_model.dart';
import 'package:lumina_ui/ui/features/marketplace/views/marketplace_listing_card.dart';

/// The selected listing: screenshots, description, version, the licenses it
/// is published under, and Get / Add to Project (or Install Plugin / Theme /
/// Template) with download progress and Cancel, or the installed version
/// with Uninstall.
class MarketplaceListingDetail extends StatelessWidget {
  const MarketplaceListingDetail({super.key, required this.viewModel});

  final MarketplaceViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final l = vm.selected;
    if (l == null) {
      return Center(
        child: Text('Select a listing to see its details and licenses.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
      );
    }
    final shot = l.screenshots.isEmpty ? null : vm.media(l.screenshots.first);
    return ListView(
      key: ValueKey('marketplace_detail_${l.slug}'),
      padding: const EdgeInsets.all(12),
      children: [
        if (shot != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AspectRatio(aspectRatio: 16 / 9, child: Image.memory(shot, fit: BoxFit.cover, gaplessPlayback: true)),
          ),
        if (shot != null) const SizedBox(height: 10),
        Row(
          children: [
            Icon(marketplaceCategoryIcon(l.category), size: 14, color: EditorColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(l.title,
                  key: const ValueKey('marketplace_detail_title'),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${l.publisher.displayName} (@${l.publisher.username}) · ${l.category.label}'
          '${l.latestVersion == null ? '' : ' · v${l.latestVersion!.version}'} · engine ${l.engineVersion}+',
          style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
        ),
        const SizedBox(height: 10),
        _actions(context, l),
        const SizedBox(height: 14),
        _heading('LICENSES'),
        const SizedBox(height: 6),
        for (final id in l.licenses.ids) _license(id),
        if (l.licenses.ids.isEmpty) Text('No license declared.', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        const SizedBox(height: 14),
        _heading('DESCRIPTION'),
        const SizedBox(height: 6),
        Text(_plain(l.description), style: TextStyle(fontSize: 10.5, height: 1.4, color: EditorColors.secondaryForeground)),
        if (l.tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 4, runSpacing: 4, children: [
            for (final t in l.tags) SecondaryBadge(child: Text(t, style: const TextStyle(fontSize: 8))),
          ]),
        ],
      ],
    );
  }

  Widget _heading(String text) => Text(text,
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: EditorColors.mutedForeground));

  /// A license from the free catalogue (`licenses.dart` in the shared
  /// package): name, kind, summary, what it asks, and its text URL.
  Widget _license(String id) {
    final info = licenseById(id);
    return Container(
      key: ValueKey('marketplace_license_$id'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            PrimaryBadge(child: Text(id, style: const TextStyle(fontSize: 9))),
            const SizedBox(width: 6),
            Expanded(
              child: Text(info == null ? id : '${info.name} · ${info.kind.label}',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
            ),
          ]),
          if (info != null) ...[
            const SizedBox(height: 4),
            Text(info.summary, style: TextStyle(fontSize: 10, color: EditorColors.secondaryForeground)),
            const SizedBox(height: 2),
            Text(
              [
                info.attributionRequired ? 'Attribution required' : 'No attribution required',
                if (info.shareAlike) 'share-alike',
              ].join(' · '),
              style: TextStyle(fontSize: 9, color: info.attributionRequired ? EditorColors.warning : EditorColors.mutedForeground),
            ),
            const SizedBox(height: 2),
            SelectableText(info.url, style: TextStyle(fontSize: 9, color: EditorColors.accent)),
          ],
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, Listing l) {
    final vm = viewModel;
    final job = vm.job(l.id);
    final record = vm.installedRecord(l.id);
    final kind = l.category.installKind;
    if (job != null && job.running) {
      final p = job.progress;
      final mb = p == null || p.total <= 0 ? '' : ' · ${_mb(p.received)} / ${_mb(p.total)}';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${p?.message ?? 'Preparing ${l.title}'}$mb',
              key: const ValueKey('marketplace_install_status'), style: TextStyle(fontSize: 10, color: EditorColors.foreground)),
          const SizedBox(height: 6),
          Progress(key: const ValueKey('marketplace_install_progress'), progress: job.fraction * 100, min: 0, max: 100),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlineButton(
              key: const ValueKey('marketplace_cancel_install'),
              density: ButtonDensity.compact,
              onPressed: () => vm.cancelInstall(l.id),
              leading: const Icon(LucideIcons.x, size: 12),
              child: const Text('Cancel', style: TextStyle(fontSize: 10)),
            ),
          ),
        ],
      );
    }
    final buttons = <Widget>[];
    if (!vm.isSignedIn) {
      buttons.add(Text('Sign in to get and install this listing.', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)));
    } else {
      if (!vm.inLibrary(l)) {
        buttons.add(OutlineButton(
          key: const ValueKey('marketplace_get'),
          density: ButtonDensity.compact,
          onPressed: () => vm.get(l),
          leading: const Icon(LucideIcons.library, size: 12),
          child: const Text('Get (Free)', style: TextStyle(fontSize: 10)),
        ));
      }
      final canInstall = vm.canInstall(l);
      buttons.add(PrimaryButton(
        key: const ValueKey('marketplace_install'),
        density: ButtonDensity.compact,
        onPressed: canInstall ? () => vm.install(l) : null,
        leading: const Icon(LucideIcons.download, size: 12),
        child: Text(record == null ? MarketplaceViewModel.installLabel(l.category) : 'Reinstall',
            style: const TextStyle(fontSize: 10)),
      ));
      if (record != null) {
        buttons.add(DestructiveButton(
          key: const ValueKey('marketplace_uninstall'),
          density: ButtonDensity.compact,
          onPressed: () => vm.uninstall(record),
          leading: const Icon(LucideIcons.trash2, size: 12),
          child: const Text('Uninstall', style: TextStyle(fontSize: 10)),
        ));
      }
      if (record != null && kind == InstallKind.plugin && vm.host.openPluginManager != null) {
        buttons.add(OutlineButton(
          key: const ValueKey('marketplace_open_plugin_manager'),
          density: ButtonDensity.compact,
          onPressed: vm.host.openPluginManager,
          leading: const Icon(LucideIcons.plug, size: 12),
          child: const Text('Enable in Plugin Manager', style: TextStyle(fontSize: 10)),
        ));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: buttons),
        if (record != null) ...[
          const SizedBox(height: 6),
          Text('Installed v${record.version} in ${record.installedTo}',
              key: const ValueKey('marketplace_installed_note'), style: TextStyle(fontSize: 9.5, color: EditorColors.logSuccess)),
        ],
        if (kind == InstallKind.projectContents && vm.isSignedIn && vm.dirs.projectRoot != null) ...[
          const SizedBox(height: 4),
          Text('Installs into contents/Marketplace/${installFolderName(l.publisher.username)}/${installFolderName(l.title)}/, '
              'or drag the card onto a folder on the right.',
              style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        ],
        if (kind == InstallKind.projectContents && vm.dirs.projectRoot == null)
          Text('Open a project to add assets to it.', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        if (job?.error != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(LucideIcons.circleAlert, size: 12, color: EditorColors.destructive),
            const SizedBox(width: 4),
            Expanded(
              child: Text(job!.error!,
                  key: const ValueKey('marketplace_install_error'),
                  style: TextStyle(fontSize: 9.5, color: EditorColors.destructive)),
            ),
            GhostButton(
              density: ButtonDensity.compact,
              onPressed: () => vm.dismissInstallError(l.id),
              child: const Icon(LucideIcons.x, size: 10),
            ),
          ]),
        ],
      ],
    );
  }

  static String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  /// The Markdown description as plain text (headings and emphasis marks
  /// dropped).
  static String _plain(String markdown) => markdown
      .split('\n')
      .map((line) => line.replaceFirst(RegExp(r'^#+\s*'), '').replaceAll('**', '').replaceAll('`', ''))
      .join('\n')
      .trim();
}
