import 'package:lumina_editor_data/lumina_editor.dart' show kUmgWidgetLibraryShadcn;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/color_field.dart';
import 'package:lumina_ui/ui/core/property_editors/enum_field.dart';
import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/combo_box_options_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/umg/umg_theme_helper.dart';

part 'slot_inspector/slot_section.dart';
part 'slot_inspector/appearance_section.dart';
part 'slot_inspector/component_fields.dart';

/// The designer's right panel: Slot (anchors preset matrix, position/size/
/// alignment, size-to-content, Z-order — or the honest box/overlay slot
/// fields), Appearance (color & tint, font size, image brush, per-type
/// content) and Widget Events (`[+] OnClicked` …).
class UmgSlotInspector extends StatelessWidget {
  final UmgEditorViewModel vm;

  const UmgSlotInspector({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final node = vm.selectedNode;
    if (node == null) {
      return const Center(child: Text('Select an element on the canvas or in the hierarchy', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)));
    }
    final parent = vm.document.parentOf(node.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              SecondaryBadge(child: Text(node.type.displayName, style: const TextStyle(fontSize: 8))),
              const SizedBox(width: 6),
              Expanded(child: Text(node.name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('field: ${node.fieldName}', style: const TextStyle(fontSize: 8.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground)),
        ),
        // Is Variable — a member of the widget's graph.
        if (parent != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                Checkbox(
                  key: ValueKey('umg_is_variable_${node.id}'),
                  state: node.isVariable ? CheckboxState.checked : CheckboxState.unchecked,
                  onChanged: (s) => vm.setIsVariable(node.id, s == CheckboxState.checked),
                ),
                const SizedBox(width: 6),
                const Expanded(child: Text('Is Variable', style: TextStyle(fontSize: 9, color: EditorColors.foreground))),
                Tooltip(
                  tooltip: (_) => const TooltipContainer(
                      child: Text('A variable is a member of the widget\'s graph: Get <widget> and bound events', style: TextStyle(fontSize: 9))),
                  child: const Icon(LucideIcons.info, size: 10, color: EditorColors.mutedForeground),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Expanded(
          child: SingleChildScrollView(
            // One Accordion per group so all three stay open independently
            // (shadcn's Accordion is single-expansion).
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Accordion(
                  items: [
                    AccordionItem(
                      expanded: true,
                      trigger: AccordionTrigger(child: Text(_slotTitle(node, parent), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                      content: _slotSection(context, node, parent),
                    ),
                  ],
                ),
                Accordion(
                  items: [
                    AccordionItem(
                      expanded: true,
                      trigger: const AccordionTrigger(child: Text('Appearance & Style', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                      content: _appearanceSection(context, node),
                    ),
                  ],
                ),
                Accordion(
                  items: [
                    AccordionItem(
                      expanded: true,
                      trigger: const AccordionTrigger(child: Text('Widget Events', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                      content: _eventsSection(node),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _slotTitle(UmgNode node, UmgNode? parent) {
    if (parent == null) return 'Slot (root)';
    return 'Slot (${parent.type.displayName} Slot)';
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2, top: 2),
        child: Text(text, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(text, style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground, fontStyle: FontStyle.italic)),
      );

  Widget _switchRow(String label, bool value, Key key, ValueChanged<bool> onChanged) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
            Switch(key: key, value: value, onChanged: onChanged),
          ],
        ),
      );
}

/// Draws the little anchor glyph (dot/bar) of a preset.
class _AnchorGlyphPainter extends CustomPainter {
  final UmgAnchorPreset preset;
  const _AnchorGlyphPainter(this.preset);

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = EditorColors.mutedForeground;
    canvas.drawRect(Offset.zero & size, frame);
    final fill = Paint()..color = EditorColors.foreground;
    final stretchX = preset.min.dx != preset.max.dx;
    final stretchY = preset.min.dy != preset.max.dy;
    final w = stretchX ? size.width - 4 : 4.0;
    final h = stretchY ? size.height - 4 : 4.0;
    final x = stretchX ? 2.0 : preset.min.dx * (size.width - 4) ;
    final y = stretchY ? 2.0 : preset.min.dy * (size.height - 4);
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), fill);
  }

  @override
  bool shouldRepaint(_AnchorGlyphPainter old) => old.preset != preset;
}
