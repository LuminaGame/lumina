import 'dart:math' as math;

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_completion.dart';

/// The `.mat` source pane's suggestion list: one row per item (kind icon,
/// label with the matched characters bold, detail right-aligned), at most
/// [maxVisibleRows] visible with the rest scrolled, and beside it a details
/// pane with the selected item's signature and documentation.
class MatCompletionPopup extends StatelessWidget {
  final List<MatCompletionItem> items;
  final int selectedIndex;
  final ScrollController scrollController;
  final ValueChanged<int> onAccept;

  /// Where the details pane goes: to the right of the list, to its left, or
  /// nowhere when there is no room for it.
  final MatDetailsSide detailsSide;

  const MatCompletionPopup({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.scrollController,
    required this.onAccept,
    this.detailsSide = MatDetailsSide.right,
  });

  static const double rowHeight = 22;
  static const int maxVisibleRows = 10;
  static const double listWidth = 380;
  static const double detailsWidth = 300;

  /// The list's height for [count] items, borders included.
  static double listHeight(int count) => math.min(count, maxVisibleRows) * rowHeight + 2;

  /// The scroll offset that keeps row [index] visible in a list scrolled to [offset].
  static double offsetRevealing(int index, double offset) {
    final top = index * rowHeight;
    final bottom = top + rowHeight;
    const viewport = maxVisibleRows * rowHeight;
    if (top < offset) return top;
    if (bottom > offset + viewport) return bottom - viewport;
    return offset;
  }

  @override
  Widget build(BuildContext context) {
    final list = Container(
      key: const ValueKey('mat_completion_list'),
      width: listWidth,
      height: listHeight(items.length),
      decoration: BoxDecoration(
        color: EditorColors.sidebar,
        border: Border.all(color: EditorColors.borderSolid),
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: ListView.builder(
        controller: scrollController,
        padding: EdgeInsets.zero,
        itemExtent: rowHeight,
        itemCount: items.length,
        itemBuilder: (context, index) =>
            _MatCompletionRow(item: items[index], selected: index == selectedIndex, onTap: () => onAccept(index)),
      ),
    );
    if (detailsSide == MatDetailsSide.none || items.isEmpty) return list;
    final details = _MatCompletionDetails(item: items[selectedIndex.clamp(0, items.length - 1)]);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: detailsSide == MatDetailsSide.right
          ? [list, const SizedBox(width: 2), details]
          : [details, const SizedBox(width: 2), list],
    );
  }
}

enum MatDetailsSide { right, left, none }

/// The Lucide icon of a suggestion kind.
IconData matCompletionKindIcon(MatCompletionKind kind) => switch (kind) {
  MatCompletionKind.keyword => LucideIcons.key,
  MatCompletionKind.type => LucideIcons.type,
  MatCompletionKind.function => LucideIcons.box,
  MatCompletionKind.field => LucideIcons.tag,
  MatCompletionKind.property => LucideIcons.wrench,
  MatCompletionKind.value => LucideIcons.listOrdered,
  MatCompletionKind.variable => LucideIcons.variable,
  MatCompletionKind.parameter => LucideIcons.atSign,
  MatCompletionKind.constant => LucideIcons.pi,
  MatCompletionKind.snippet => LucideIcons.squareCode,
};

/// The colour of a suggestion kind's icon.
Color matCompletionKindColor(MatCompletionKind kind) => switch (kind) {
  MatCompletionKind.keyword => EditorColors.mutedForeground,
  MatCompletionKind.type => EditorColors.primary,
  MatCompletionKind.function => EditorColors.chart4,
  MatCompletionKind.field || MatCompletionKind.property => EditorColors.accent,
  MatCompletionKind.value => EditorColors.warning,
  MatCompletionKind.variable || MatCompletionKind.parameter => EditorColors.chart3,
  MatCompletionKind.constant => EditorColors.materialPinFloat2,
  MatCompletionKind.snippet => EditorColors.foreground,
};

class _MatCompletionRow extends StatelessWidget {
  final MatCompletionItem item;
  final bool selected;
  final VoidCallback onTap;
  const _MatCompletionRow({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(fontFamily: EditorTypography.monoFamily, fontSize: 12, color: EditorColors.foreground);
    final highlighted = item.highlights.toSet();
    final spans = <TextSpan>[];
    for (var i = 0; i < item.label.length; i++) {
      final bold = highlighted.contains(i);
      spans.add(
        TextSpan(
          text: item.label[i],
          style: bold ? const TextStyle(fontWeight: FontWeight.w700, color: EditorColors.accent) : null,
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: selected ? EditorColors.selectionBg : null,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            Icon(matCompletionKindIcon(item.kind), size: 14, color: matCompletionKindColor(item.kind)),
            const SizedBox(width: 6),
            Flexible(
              flex: 3,
              child: Text.rich(
                TextSpan(style: base, children: spans),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Text(
                item.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: EditorTypography.monoFamily,
                  fontSize: 11,
                  color: EditorColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatCompletionDetails extends StatelessWidget {
  final MatCompletionItem item;
  const _MatCompletionDetails({required this.item});

  @override
  Widget build(BuildContext context) {
    final signature = item.detail.isEmpty ? item.label : item.detail;
    return Container(
      key: const ValueKey('mat_completion_details'),
      width: MatCompletionPopup.detailsWidth,
      constraints: BoxConstraints(maxHeight: MatCompletionPopup.listHeight(MatCompletionPopup.maxVisibleRows)),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: EditorColors.sidebar,
        border: Border.all(color: EditorColors.borderSolid),
        borderRadius: BorderRadius.circular(3),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(matCompletionKindIcon(item.kind), size: 12, color: matCompletionKindColor(item.kind)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    signature,
                    style: const TextStyle(
                      fontFamily: EditorTypography.monoFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: EditorColors.foreground,
                    ),
                  ),
                ),
              ],
            ),
            if (item.documentation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.documentation,
                style: const TextStyle(fontSize: 11, height: 1.4, color: EditorColors.mutedForeground),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
