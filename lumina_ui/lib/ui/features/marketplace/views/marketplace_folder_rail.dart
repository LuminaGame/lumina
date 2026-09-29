import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../core/theme/editor_theme.dart';
import '../view_models/marketplace_view_model.dart';
import 'marketplace_listing_card.dart';

/// The open project's Content Browser folders beside the catalogue: drop an
/// asset listing's card on one to install it there
/// (`<folder>/<Listing>/`) instead of `contents/Marketplace/<Publisher>/`
/// — manual placement.
class MarketplaceFolderRail extends StatelessWidget {
  const MarketplaceFolderRail({super.key, required this.viewModel, required this.folders});

  final MarketplaceViewModel viewModel;

  /// Project-relative Content Browser folders (`contents`, `contents/Props`, …).
  final List<String> folders;

  @override
  Widget build(BuildContext context) {
    final sorted = [...folders]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return Container(
      color: EditorColors.rail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
            child: Text('CONTENT BROWSER',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: EditorColors.mutedForeground)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: Text('Drag a listing onto a folder to add it there.',
                style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: [for (final f in sorted) _folder(f)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _folder(String path) {
    final depth = '/'.allMatches(path).length;
    return DragTarget<MarketplaceListingDrag>(
      onWillAcceptWithDetails: (d) => viewModel.canInstall(d.data.listing),
      onAcceptWithDetails: (d) => viewModel.install(d.data.listing, folder: path),
      builder: (context, candidates, rejected) {
        final hover = candidates.isNotEmpty;
        return Container(
          key: ValueKey('marketplace_folder_$path'),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: EdgeInsets.fromLTRB(6.0 + depth * 10, 4, 6, 4),
          decoration: BoxDecoration(
            color: hover ? EditorColors.primary.withValues(alpha: 0.25) : null,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: hover ? EditorColors.primary : EditorColors.rail),
          ),
          child: Row(
            children: [
              Icon(hover ? LucideIcons.folderOpen : LucideIcons.folder, size: 11,
                  color: hover ? EditorColors.primary : EditorColors.mutedForeground),
              const SizedBox(width: 6),
              Expanded(
                child: Text(path.split('/').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: hover ? EditorColors.primary : EditorColors.foreground)),
              ),
            ],
          ),
        );
      },
    );
  }
}
