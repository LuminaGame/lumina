import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';
import '../services/marketplace_license_records.dart';
import '../view_models/marketplace_view_model.dart';
import 'marketplace_folder_rail.dart';
import 'marketplace_listing_card.dart';
import 'marketplace_listing_detail.dart';
import 'marketplace_sign_in_dialog.dart';

/// Window → Marketplace: a workspace tab that signs in to
/// the Lumina Marketplace, browses and searches the catalogue the web front
/// end shows, lists the user's library and what is installed, and installs
/// listings — assets into the open project, plugins, themes and templates
/// into the editor.
class MarketplaceView extends StatefulWidget {
  const MarketplaceView({super.key, required this.viewModel, this.contentFolders, this.foldersChanged});

  final MarketplaceViewModel viewModel;

  /// The project's Content Browser folders, for the drop rail (none in the
  /// launcher).
  final List<String> Function()? contentFolders;

  /// Notifies when [contentFolders] may have changed (the editor).
  final Listenable? foldersChanged;

  @override
  State<MarketplaceView> createState() => _MarketplaceViewState();
}

class _MarketplaceViewState extends State<MarketplaceView> {
  late final TextEditingController _search = TextEditingController(text: widget.viewModel.query);

  @override
  void initState() {
    super.initState();
    widget.viewModel.start();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    return ListenableBuilder(
      listenable: Listenable.merge([vm, ?widget.foldersChanged]),
      builder: (context, _) => Container(
        color: EditorColors.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, vm),
            Divider(height: 1, color: EditorColors.border),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final showRail = widget.contentFolders != null && constraints.maxWidth > 900;
                final detailWidth = (constraints.maxWidth * 0.32).clamp(260.0, 420.0);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _body(vm)),
                    VerticalDivider(width: 1, color: EditorColors.border),
                    SizedBox(
                      width: detailWidth,
                      child: Container(color: EditorColors.sidebar, child: MarketplaceListingDetail(viewModel: vm)),
                    ),
                    if (showRail) ...[
                      VerticalDivider(width: 1, color: EditorColors.border),
                      SizedBox(
                        width: 190,
                        child: MarketplaceFolderRail(viewModel: vm, folders: widget.contentFolders!()),
                      ),
                    ],
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, MarketplaceViewModel vm) {
    final user = vm.user;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          Icon(LucideIcons.store, size: 14, color: EditorColors.primary),
          const SizedBox(width: 6),
          Text('MARKETPLACE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: EditorColors.foreground)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(vm.serverUrl.toString(),
                overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
          ),
          const SizedBox(width: 16),
          Tabs(
            index: vm.section.index,
            onChanged: (i) => vm.section = MarketplaceSection.values[i],
            children: const [
              TabItem(key: ValueKey('marketplace_tab_browse'), child: Text('Browse', style: TextStyle(fontSize: 10))),
              TabItem(key: ValueKey('marketplace_tab_library'), child: Text('Library', style: TextStyle(fontSize: 10))),
              TabItem(key: ValueKey('marketplace_tab_installed'), child: Text('Installed', style: TextStyle(fontSize: 10))),
            ],
          ),
          const Spacer(),
          if (user != null) ...[
            Icon(LucideIcons.user, size: 12, color: EditorColors.mutedForeground),
            const SizedBox(width: 4),
            Text(user.displayName,
                key: const ValueKey('marketplace_signed_in_user'), style: TextStyle(fontSize: 10, color: EditorColors.foreground)),
            const SizedBox(width: 8),
            GhostButton(
              key: const ValueKey('marketplace_sign_out'),
              density: ButtonDensity.compact,
              onPressed: vm.sessionBusy ? null : vm.signOut,
              leading: const Icon(LucideIcons.logOut, size: 12),
              child: const Text('Sign Out', style: TextStyle(fontSize: 10)),
            ),
          ] else
            PrimaryButton(
              key: const ValueKey('marketplace_sign_in'),
              density: ButtonDensity.compact,
              onPressed: () => showMarketplaceSignInDialog(context, vm),
              leading: const Icon(LucideIcons.logIn, size: 12),
              child: const Text('Sign In', style: TextStyle(fontSize: 10)),
            ),
        ],
      ),
    );
  }

  Widget _body(MarketplaceViewModel vm) => switch (vm.section) {
        MarketplaceSection.browse => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _searchBar(vm),
              Expanded(child: _grid(vm, vm.results, empty: vm.searching ? 'Searching…' : vm.searchError ?? 'No listings match.')),
            ],
          ),
        MarketplaceSection.library => vm.isSignedIn
            ? _grid(vm, [for (final e in vm.library) e.listing], empty: 'Your library is empty: Get a listing to add it.')
            : _message('Sign in to see your library.'),
        MarketplaceSection.installed => _installedList(vm),
      };

  Widget _message(String text) =>
      Center(child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: EditorColors.mutedForeground)));

  Widget _searchBar(MarketplaceViewModel vm) {
    void run() => vm.search(query: _search.text);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('marketplace_search_field'),
              controller: _search,
              placeholder: const Text('Search models, materials, plugins, themes…'),
              onSubmitted: (_) => run(),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 150,
            child: Select<ListingCategory?>(
              key: const ValueKey('marketplace_category_filter'),
              value: vm.category,
              placeholder: const Text('All categories', style: TextStyle(fontSize: 10)),
              onChanged: (c) => c == null ? vm.search(clearCategory: true) : vm.search(category: c),
              itemBuilder: (context, c) => Text(c?.pluralLabel ?? 'All categories', style: const TextStyle(fontSize: 10)),
              popup: SelectPopup<ListingCategory?>(
                items: SelectItemList(children: [
                  const SelectItemButton<ListingCategory?>(value: null, child: Text('All categories', style: TextStyle(fontSize: 10))),
                  for (final c in ListingCategory.values)
                    SelectItemButton<ListingCategory?>(value: c, child: Text(c.pluralLabel, style: const TextStyle(fontSize: 10))),
                ]),
              ).call,
            ),
          ),
          const SizedBox(width: 6),
          PrimaryButton(
            key: const ValueKey('marketplace_search_button'),
            density: ButtonDensity.compact,
            onPressed: run,
            leading: const Icon(LucideIcons.search, size: 12),
            child: const Text('Search', style: TextStyle(fontSize: 10)),
          ),
          const SizedBox(width: 10),
          Text(vm.searching ? '…' : '${vm.total} result${vm.total == 1 ? '' : 's'}',
              key: const ValueKey('marketplace_result_count'), style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        ],
      ),
    );
  }

  Widget _grid(MarketplaceViewModel vm, List<Listing> listings, {required String empty}) {
    if (listings.isEmpty) return _message(empty);
    return LayoutBuilder(builder: (context, constraints) {
      const spacing = 10.0;
      final columns = ((constraints.maxWidth - 20 + spacing) / (190 + spacing)).floor().clamp(1, 8);
      final width = (constraints.maxWidth - 20 - spacing * (columns - 1)) / columns;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final l in listings) MarketplaceListingCard(viewModel: vm, listing: l, width: width)],
        ),
      );
    });
  }

  Widget _installedList(MarketplaceViewModel vm) {
    final records = vm.installed;
    if (records.isEmpty) return _message('Nothing from the Marketplace is installed in this project or editor yet.');
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [for (final r in records) _installedRow(vm, r)],
    );
  }

  Widget _installedRow(MarketplaceViewModel vm, MarketplaceInstallRecord r) {
    return Container(
      key: ValueKey('marketplace_installed_${r.slug}'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      child: Row(
        children: [
          Icon(marketplaceCategoryIcon(r.category), size: 16, color: EditorColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${r.title}  v${r.version}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
                const SizedBox(height: 2),
                Text('${r.category.label} · ${r.installedTo}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                const SizedBox(height: 2),
                Text(
                  '${[for (final l in r.licenses) l.id].join(', ')}'
                  '${r.attributionRequired ? ' · credit ${r.publisherDisplayName}' : ''} · ${r.licenseFile.split('/').last}',
                  style: TextStyle(fontSize: 9, color: r.attributionRequired ? EditorColors.warning : EditorColors.mutedForeground),
                ),
              ],
            ),
          ),
          if (r.installKind == InstallKind.plugin && vm.host.openPluginManager != null)
            GhostButton(
              density: ButtonDensity.compact,
              onPressed: vm.host.openPluginManager,
              leading: const Icon(LucideIcons.plug, size: 12),
              child: const Text('Plugin Manager', style: TextStyle(fontSize: 10)),
            ),
          DestructiveButton(
            key: ValueKey('marketplace_installed_remove_${r.slug}'),
            density: ButtonDensity.compact,
            onPressed: () => vm.uninstall(r),
            leading: const Icon(LucideIcons.trash2, size: 12),
            child: const Text('Uninstall', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }
}
