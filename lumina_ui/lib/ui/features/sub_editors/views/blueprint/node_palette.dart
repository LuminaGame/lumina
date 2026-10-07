import 'dart:math' as math;

import 'package:lumina/lumina.dart' show LuminaBlueprintTypeContext;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_palette.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_pin_style.dart';

/// The node palette ("All Actions for this Blueprint"): lumina's node
/// library grouped by category and searchable by title, category and
/// keywords. Opened from a pin drag it is "context sensitive": only nodes
/// that can take the wire are listed.
class BlueprintNodePalette extends StatefulWidget {
  final List<BlueprintPaletteEntry> entries;
  final BlueprintPinRef? from;
  final String? fromLabel;

  /// The dragged pin's type name and colour; the Blueprint style of
  /// [from]'s type when null.
  final String? fromTypeLabel;
  final Color? fromColor;
  final ValueChanged<BlueprintPaletteEntry> onSelect;
  final VoidCallback onClose;

  /// The graph's type context, for ordering a pin drag's rows by class.
  final LuminaBlueprintTypeContext context;

  const BlueprintNodePalette({
    super.key,
    required this.entries,
    required this.onSelect,
    required this.onClose,
    this.context = const LuminaBlueprintTypeContext(),
    this.from,
    this.fromLabel,
    this.fromTypeLabel,
    this.fromColor,
  });

  @override
  State<BlueprintNodePalette> createState() => BlueprintNodePaletteState();
}

class BlueprintNodePaletteState extends State<BlueprintNodePalette> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  List<BlueprintPaletteEntry> get visibleEntries => BlueprintPalette.search(widget.entries, _query);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = visibleEntries;
    final rows = <Widget>[];
    void addGroups(Iterable<BlueprintPaletteEntry> entries, {bool bestMatches = true}) {
      final searching = _query.isNotEmpty && bestMatches;
      final rest = <BlueprintPaletteEntry>[];
      if (searching) {
        // Rows whose title matches the search lead as Best Matches (each
        // with its full category), then the keyword matches under their
        // categories: `movement` puts Add Movement Input first, above the
        // Character Movement keyword hits.
        final best = <BlueprintPaletteEntry>[];
        for (final e in entries) {
          (BlueprintPalette.rank(e, _query) == 0 ? best : rest).add(e);
        }
        if (best.isNotEmpty) {
          rows.add(const Padding(
            key: ValueKey('palette_best_matches'),
            padding: EdgeInsets.only(top: 6, bottom: 2),
            child: Text('BEST MATCHES', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: EditorColors.primary)),
          ));
          for (final e in best) {
            rows.add(_entryRow(e, showCategory: true));
          }
        }
      } else {
        rest.addAll(entries);
      }
      final groups = <String, List<BlueprintPaletteEntry>>{};
      for (final e in rest) {
        (groups[e.category] ??= []).add(e);
      }
      // A pin drag lists the categories about the pin's class first (the
      // widget's elements, the Text Block setters), then what else it can join.
      int best(String c) => groups[c]!.map((e) => BlueprintPalette.relevance(e, widget.from, widget.context)).reduce(math.min);
      final ordered = groups.keys.toList()
        ..sort((a, b) {
          final byRank = best(a).compareTo(best(b));
          return byRank != 0 ? byRank : a.compareTo(b);
        });
      for (final category in ordered) {
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(category.replaceAll('|', ' › ').toUpperCase(),
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
        ));
        for (final e in groups[category]!) {
          rows.add(_entryRow(e));
        }
      }
    }

    // "Create a Reference to <Actor>" for the outliner's
    // selected actors leads the menu.
    for (final e in visible.where((e) => e.pinned)) {
      rows.add(_entryRow(e));
    }
    // Promote to Variable is pinned above everything on a pin drag.
    for (final e in visible.where((e) => e.isAction)) {
      rows.add(_entryRow(e));
    }
    if (visible.any((e) => e.isAction || e.pinned)) rows.add(const Padding(padding: EdgeInsets.only(top: 4), child: Divider(height: 1)));

    // The project's own exposed Dart functions first,
    // under their categories, then lumina's library.
    final project = visible.where((e) => e.isProject).toList();
    if (project.isNotEmpty) {
      rows.add(const Padding(
        key: ValueKey('palette_project_section'),
        padding: EdgeInsets.only(top: 4),
        child: Text('PROJECT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.primary)),
      ));
      addGroups(project, bestMatches: false);
      rows.add(const Padding(padding: EdgeInsets.only(top: 6), child: Divider(height: 1)));
    }
    addGroups(visible.where((e) => !e.isProject && !e.isAction && !e.pinned));

    return AlertDialog(
      title: Text(widget.from == null ? 'Node Palette' : 'Node Palette — Context Sensitive'),
      content: SizedBox(
        width: 360,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.from != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: widget.fromColor ?? BlueprintPinStyle.color(widget.from!.type), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'From ${widget.fromLabel ?? widget.from!.pinId} (${widget.fromTypeLabel ?? BlueprintPinStyle.label(widget.from!.type)})',
                        style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              key: const ValueKey('palette_search'),
              controller: _search,
              autofocus: true,
              placeholder: const Text('Search nodes...').small(),
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: (_) {
                if (visible.isNotEmpty) widget.onSelect(visible.first);
              },
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Text('No node matches', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                    )
                  : ListView(children: rows),
            ),
          ],
        ),
      ),
      actions: [
        GhostButton(onPressed: widget.onClose, child: const Text('Cancel')),
      ],
    );
  }

  Widget _entryRow(BlueprintPaletteEntry e, {bool showCategory = false}) {
    final row = _entryContent(e, showCategory: showCategory);
    final tip = e.tooltip;
    if (tip == null || tip.isEmpty) return row;
    // The function's doc comment as its tooltip.
    return Tooltip(
      key: ValueKey('palette_tooltip_${e.key}'),
      tooltip: (context) => TooltipContainer(child: Text(tip, style: const TextStyle(fontSize: 10))),
      child: row,
    );
  }

  Widget _entryContent(BlueprintPaletteEntry e, {bool showCategory = false}) {
    return Clickable(
      key: ValueKey('palette_entry_${e.key}'),
      onPressed: () => widget.onSelect(e),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
        child: Row(
          children: [
            if (e.isAction)
              const Icon(LucideIcons.arrowUpFromLine, size: 10, color: EditorColors.primary)
            else
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: Color(e.headerColor), shape: BoxShape.circle),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                e.title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: e.isAction ? FontWeight.w600 : FontWeight.normal,
                  color: e.deprecation != null ? EditorColors.mutedForeground : EditorColors.foreground,
                  decoration: e.deprecation != null ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (e.deprecation != null)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Text('deprecated', style: TextStyle(fontSize: 8, color: EditorColors.warning)),
              ),
            if (e.isProject)
              Padding(
                key: ValueKey('palette_project_badge_${e.key}'),
                padding: const EdgeInsets.only(right: 6),
                child: const OutlineBadge(child: Text('Project', style: TextStyle(fontSize: 8))),
              ),
            if (!e.isAction)
              Text(showCategory ? e.category.replaceAll('|', ' › ') : e.group,
                  style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
          ],
        ),
      ),
    );
  }
}
