import 'package:lumina/lumina.dart' show kUmgWidgetLibraryShadcn;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/umg_document.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/umg_editor_view_model.dart';

/// Icon per palette type (LucideIcons, shadcn_flutter).
IconData umgIconFor(UmgWidgetType type) {
  switch (type) {
    case UmgWidgetType.canvasPanel:
      return LucideIcons.layoutDashboard;
    case UmgWidgetType.overlay:
      return LucideIcons.layers;
    case UmgWidgetType.horizontalBox:
      return LucideIcons.columns3;
    case UmgWidgetType.verticalBox:
      return LucideIcons.rows3;
    case UmgWidgetType.gridPanel:
      return LucideIcons.layoutGrid;
    case UmgWidgetType.scrollBox:
      return LucideIcons.scrollText;
    case UmgWidgetType.widgetSwitcher:
      return LucideIcons.arrowLeftRight;
    case UmgWidgetType.sizeBox:
      return LucideIcons.square;
    case UmgWidgetType.border:
      return LucideIcons.squareDashed;
    case UmgWidgetType.button:
      return LucideIcons.mousePointerClick;
    case UmgWidgetType.text:
      return LucideIcons.type;
    case UmgWidgetType.image:
      return LucideIcons.image;
    case UmgWidgetType.progressBar:
      return LucideIcons.gauge;
    case UmgWidgetType.slider:
      return LucideIcons.slidersHorizontal;
    case UmgWidgetType.checkBox:
      return LucideIcons.squareCheck;
    case UmgWidgetType.editableText:
      return LucideIcons.textCursorInput;
    case UmgWidgetType.comboBox:
      return LucideIcons.chevronsUpDown;
    case UmgWidgetType.container:
      return LucideIcons.squareSquare;
    case UmgWidgetType.shadcnCard:
      return LucideIcons.creditCard;
    case UmgWidgetType.shadcnBadge:
      return LucideIcons.badge;
    case UmgWidgetType.shadcnAvatar:
      return LucideIcons.circleUser;
    case UmgWidgetType.shadcnAlert:
      return LucideIcons.triangleAlert;
    case UmgWidgetType.shadcnSeparator:
      return LucideIcons.minus;
    case UmgWidgetType.shadcnProgress:
      return LucideIcons.chartNoAxesGantt;
    case UmgWidgetType.shadcnSwitch:
      return LucideIcons.toggleRight;
    case UmgWidgetType.shadcnToggle:
      return LucideIcons.bold;
    case UmgWidgetType.shadcnTabs:
      return LucideIcons.panelTop;
    case UmgWidgetType.shadcnAccordion:
      return LucideIcons.listCollapse;
    case UmgWidgetType.shadcnTooltip:
      return LucideIcons.messageSquare;
    case UmgWidgetType.shadcnChip:
      return LucideIcons.tag;
    case UmgWidgetType.shadcnKbd:
      return LucideIcons.keyboard;
    case UmgWidgetType.shadcnSkeleton:
      return LucideIcons.loader;
    case UmgWidgetType.shadcnTextField:
      return LucideIcons.textCursor;
    case UmgWidgetType.shadcnTextArea:
      return LucideIcons.letterText;
    case UmgWidgetType.shadcnSelect:
      return LucideIcons.listChecks;
    case UmgWidgetType.shadcnRadioGroup:
      return LucideIcons.circleDot;
    case UmgWidgetType.shadcnSlider:
      return LucideIcons.slidersHorizontal;
    case UmgWidgetType.shadcnCheckbox:
      return LucideIcons.squareCheckBig;
    case UmgWidgetType.shadcnPrimaryButton:
    case UmgWidgetType.shadcnSecondaryButton:
    case UmgWidgetType.shadcnOutlineButton:
    case UmgWidgetType.shadcnGhostButton:
    case UmgWidgetType.shadcnDestructiveButton:
      return LucideIcons.mousePointerClick;
    case UmgWidgetType.shadcnLinkButton:
      return LucideIcons.link;
  }
}

/// The widget palette: `Accordion` categories whose entries are real
/// `Draggable<UmgWidgetType>`s (pointer-anchored so the drop point is the
/// pointer). Double-click places the widget into the selected panel.
class UmgPalette extends StatelessWidget {
  final UmgEditorViewModel vm;

  const UmgPalette({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final panels = UmgWidgetType.values.where((t) => t.category == UmgWidgetCategory.panels).toList();
    final common = UmgWidgetType.values.where((t) => t.category == UmgWidgetCategory.common).toList();
    // Shadcn's components only for a project on shadcn_flutter.
    final shadcn = vm.widgetLibrary == kUmgWidgetLibraryShadcn
        ? UmgWidgetType.values.where((t) => t.category == UmgWidgetCategory.shadcn).toList()
        : const <UmgWidgetType>[];
    // One Accordion per category: shadcn's Accordion is single-expansion, and
    // the palette must be able to show both categories at once.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Accordion(
            items: [
              AccordionItem(
                expanded: true,
                trigger: const AccordionTrigger(child: Text('Panels', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                content: Column(children: panels.map(_entry).toList()),
              ),
            ],
          ),
          Accordion(
            items: [
              AccordionItem(
                expanded: true,
                trigger: const AccordionTrigger(child: Text('Common', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                content: Column(children: common.map(_entry).toList()),
              ),
            ],
          ),
          if (shadcn.isNotEmpty)
            Accordion(
              key: const ValueKey('umg_palette_category_shadcn'),
              items: [
                AccordionItem(
                  expanded: true,
                  trigger: const AccordionTrigger(child: Text('shadcn', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                  content: Column(children: shadcn.map(_entry).toList()),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _entry(UmgWidgetType type) {
    final row = Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: EditorColors.card,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: EditorColors.border),
      ),
      child: Row(
        children: [
          Icon(umgIconFor(type), size: 12, color: EditorColors.mutedForeground),
          const SizedBox(width: 6),
          Expanded(child: Text(type.displayName, style: const TextStyle(fontSize: 9.5, color: EditorColors.foreground))),
          const Icon(LucideIcons.gripVertical, size: 10, color: EditorColors.mutedForeground),
        ],
      ),
    );
    return Tooltip(
      tooltip: (_) => TooltipContainer(child: Text('Drag onto the canvas or a hierarchy panel · double-click to add to the selected panel', style: const TextStyle(fontSize: 9))),
      child: GestureDetector(
        onDoubleTap: () => _quickAdd(type),
        child: Draggable<UmgWidgetType>(
          key: ValueKey('umg_palette_${type.name}'),
          data: type,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: _ghost(type),
          childWhenDragging: Opacity(opacity: 0.4, child: row),
          child: row,
        ),
      ),
    );
  }

  /// Ghost feedback card shown under the pointer while dragging.
  Widget _ghost(UmgWidgetType type) {
    return IgnorePointer(
      child: Transform.translate(
        offset: const Offset(12, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: EditorColors.cardHeader.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: EditorColors.primary),
            // a drop shadow/scrim: black at 40%, not a surface
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(umgIconFor(type), size: 12, color: EditorColors.primary),
              const SizedBox(width: 6),
              Text(type.displayName, style: const TextStyle(fontSize: 10, color: EditorColors.foreground, decoration: TextDecoration.none)),
            ],
          ),
        ),
      ),
    );
  }

  void _quickAdd(UmgWidgetType type) {
    final selected = vm.selectedNode;
    var parent = selected;
    while (parent != null && parent.type.capacity == UmgChildCapacity.none) {
      parent = vm.document.parentOf(parent.id);
    }
    parent ??= vm.document.root;
    vm.addWidget(type, parentId: parent.id, canvasPosition: const Offset(32, 32));
  }
}
