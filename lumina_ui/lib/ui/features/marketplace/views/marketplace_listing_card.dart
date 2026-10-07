import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/marketplace/view_models/marketplace_view_model.dart';

/// What a Marketplace card carries when it is dragged onto a Content
/// Browser folder (manual placement).
class MarketplaceListingDrag {
  const MarketplaceListingDrag(this.listing);
  final Listing listing;
}

/// The license badges of a listing: one per declared license id.
List<String> marketplaceLicenseIds(Listing l) => l.licenses.ids;

/// The icon of a listing category.
IconData marketplaceCategoryIcon(ListingCategory c) => switch (c) {
      ListingCategory.model => LucideIcons.box,
      ListingCategory.blueprint => LucideIcons.workflow,
      ListingCategory.material => LucideIcons.palette,
      ListingCategory.texture => LucideIcons.image,
      ListingCategory.sound => LucideIcons.music,
      ListingCategory.animation => LucideIcons.personStanding,
      ListingCategory.gameTemplate => LucideIcons.gamepad2,
      ListingCategory.plugin => LucideIcons.plug,
      ListingCategory.theme => LucideIcons.swatchBook,
    };

/// A catalogue card: screenshot, title, publisher, category and licenses,
/// with an installed / in-library marker. Tapping selects the listing;
/// asset listings can be dragged onto a Content Browser folder.
class MarketplaceListingCard extends StatelessWidget {
  const MarketplaceListingCard({super.key, required this.viewModel, required this.listing, required this.width});

  final MarketplaceViewModel viewModel;
  final Listing listing;
  final double width;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final selected = vm.selected?.id == listing.id;
    final installed = vm.installedRecord(listing.id) != null;
    final card = _card(selected: selected, installed: installed);
    final draggable = listing.category.installKind == InstallKind.projectContents && vm.canInstall(listing);
    final tappable = GestureDetector(
      key: ValueKey('marketplace_card_${listing.slug}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => vm.select(listing),
      child: card,
    );
    if (!draggable) return tappable;
    return Draggable<MarketplaceListingDrag>(
      data: MarketplaceListingDrag(listing),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragFeedback(title: listing.title),
      childWhenDragging: Opacity(opacity: 0.5, child: card),
      child: tappable,
    );
  }

  Widget _card({required bool selected, required bool installed}) {
    final shot = listing.screenshots.isEmpty ? null : viewModel.media(listing.screenshots.first);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: selected ? EditorColors.primary : EditorColors.border, width: selected ? 1.6 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              color: EditorColors.rail,
              child: shot == null
                  ? Center(child: Icon(marketplaceCategoryIcon(listing.category), size: 28, color: EditorColors.mutedForeground))
                  : Image.memory(shot, fit: BoxFit.cover, gaplessPlayback: true),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(listing.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditorColors.foreground)),
                    ),
                    if (installed)
                      Icon(LucideIcons.circleCheck, key: ValueKey('marketplace_card_installed_${listing.slug}'), size: 12,
                          color: EditorColors.logSuccess),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${listing.publisher.displayName} · ${listing.category.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    const SecondaryBadge(child: Text('Free', style: TextStyle(fontSize: 8))),
                    for (final id in marketplaceLicenseIds(listing)) OutlineBadge(child: Text(id, style: const TextStyle(fontSize: 8))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: EditorColors.popover,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.primary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.packagePlus, size: 12, color: EditorColors.primary),
          const SizedBox(width: 6),
          Text('Add "$title" to a folder', style: TextStyle(fontSize: 10, color: EditorColors.foreground)),
        ],
      ),
    );
  }
}
