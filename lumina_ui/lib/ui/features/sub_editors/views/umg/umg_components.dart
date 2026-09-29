import 'package:lumina/lumina.dart'
    show LuminaUmgContainer, LuminaUmgContainerStyle, LuminaUmgElementBinding, LuminaUmgStyleJson;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import '../../models/umg_document.dart';

/// How the designer canvas and [UmgRuntimeView] draw a
/// Container and the shadcn components, from the designer props under the
/// runtime element state, exactly as the generated widget does.

/// The Container style of [props] (designer) under [element] (runtime).
LuminaUmgContainerStyle umgContainerStyle(Map<String, dynamic> props, Map<String, Object?>? element) {
  final designer = LuminaUmgContainerStyle.fromProps(Map<String, Object?>.from(props));
  return LuminaUmgElementBinding.containerStyle(element, designer);
}

/// A Container element: Flutter's `Container` via [LuminaUmgContainer].
Widget umgContainer(UmgNode node, Map<String, Object?>? element, {ImageProvider? image, Widget? child}) =>
    LuminaUmgContainer(style: umgContainerStyle(node.props, element), image: image, child: child);

/// The comma-separated options / items of a component.
List<String> umgItems(Object? v) => (v?.toString() ?? '').split(',').map((o) => o.trim()).where((o) => o.isNotEmpty).toList();

/// What a plain-Flutter project shows instead of a shadcn component: the
/// game cannot import shadcn_flutter.
Widget umgRequiresShadcn(UmgNode node) => Container(
      key: ValueKey('umg_requires_shadcn_${node.id}'),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: EditorColors.logWarning.withValues(alpha: 0.12),
        border: Border.all(color: EditorColors.logWarning),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        '${node.type.displayName} (shadcn) requires the shadcn widget library',
        style: const TextStyle(fontSize: 10, color: EditorColors.logWarning),
      ),
    );

/// The runtime key a component's value is written under (the key the
/// element nodes it shares read), and the designer key it
/// was seeded from.
({String runtime, String designer})? umgShadcnValueKey(UmgWidgetType type) {
  switch (type) {
    case UmgWidgetType.shadcnSwitch:
    case UmgWidgetType.shadcnToggle:
    case UmgWidgetType.shadcnCheckbox:
      return (runtime: 'isChecked', designer: 'checked');
    case UmgWidgetType.shadcnSelect:
    case UmgWidgetType.shadcnRadioGroup:
      return (runtime: 'selectedOption', designer: 'selected');
    case UmgWidgetType.shadcnTabs:
      return (runtime: 'activeIndex', designer: 'activeIndex');
    case UmgWidgetType.shadcnSlider:
      return (runtime: 'value', designer: 'value');
    case UmgWidgetType.shadcnTextField:
    case UmgWidgetType.shadcnTextArea:
      return (runtime: 'text', designer: 'text');
    default:
      return null;
  }
}

/// A shadcn component of [node]: [element] is its runtime state (null in the
/// designer), [children] its built children (a Card's / Tooltip's content,
/// the pages of Tabs, the item contents of an Accordion). [onChanged] gets
/// the new value of an interactive component, [onPressed] a button press.
Widget umgShadcnComponent(
  UmgNode node,
  Map<String, Object?>? element, {
  List<Widget> children = const [],
  void Function(Object? value)? onChanged,
  VoidCallback? onPressed,
}) {
  final p = node.props;
  String str(String key, [String? runtimeKey]) => LuminaUmgElementBinding.value<String>(element, runtimeKey ?? key, p[key]?.toString() ?? '');
  double dbl(String key, double d) {
    final v = p[key];
    return LuminaUmgElementBinding.value<double>(element, key, v is num ? v.toDouble() : d);
  }

  bool checked() => LuminaUmgElementBinding.value<bool>(element, 'isChecked', p['checked'] == true);
  final child = children.isEmpty ? null : children.first;
  switch (node.type) {
    case UmgWidgetType.shadcnCard:
      return Card(
        padding: EdgeInsets.all(dbl('padding', 16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(str('title'), style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(str('description'), style: const TextStyle(fontSize: 12)).muted(),
            if (child != null) ...[const SizedBox(height: 12), child],
          ],
        ),
      );
    case UmgWidgetType.shadcnBadge:
      final label = Text(str('text'));
      switch (p['variant']?.toString()) {
        case 'secondary':
          return SecondaryBadge(child: label);
        case 'outline':
          return OutlineBadge(child: label);
        case 'destructive':
          return DestructiveBadge(child: label);
        default:
          return PrimaryBadge(child: label);
      }
    case UmgWidgetType.shadcnAvatar:
      return Avatar(initials: str('initials'), size: dbl('size', 40));
    case UmgWidgetType.shadcnAlert:
      return Alert(
        title: Text(str('title')),
        content: Text(str('description')),
        destructive: LuminaUmgElementBinding.value<bool>(element, 'destructive', p['destructive'] == true),
      );
    case UmgWidgetType.shadcnSeparator:
      final label = str('label');
      if (p['orientation'] == 'vertical') return const VerticalDivider();
      return Divider(child: label.isEmpty ? null : Text(label));
    case UmgWidgetType.shadcnProgress:
      return Progress(progress: dbl('percent', 0.6).clamp(0.0, 1.0));
    case UmgWidgetType.shadcnSwitch:
      return Switch(value: checked(), onChanged: onChanged, trailing: Text(str('label')));
    case UmgWidgetType.shadcnToggle:
      return Toggle(value: checked(), onChanged: onChanged, child: Text(str('label')));
    case UmgWidgetType.shadcnCheckbox:
      return Checkbox(
        state: checked() ? CheckboxState.checked : CheckboxState.unchecked,
        onChanged: onChanged == null ? null : (s) => onChanged(s == CheckboxState.checked),
        trailing: Text(str('label')),
      );
    case UmgWidgetType.shadcnTabs:
      final items = umgItems(p['items']);
      final index = LuminaUmgElementBinding.value<int>(element, 'activeIndex', (p['activeIndex'] as num?)?.toInt() ?? 0)
          .clamp(0, items.isEmpty ? 0 : items.length - 1);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isNotEmpty) Tabs(index: index, onChanged: (i) => onChanged?.call(i), children: [for (final t in items) TabItem(child: Text(t))]),
          if (children.isNotEmpty) IndexedStack(index: index.clamp(0, children.length - 1), children: children),
        ],
      );
    case UmgWidgetType.shadcnAccordion:
      final items = umgItems(p['items']);
      final expanded = (p['expandedIndex'] as num?)?.toInt() ?? -1;
      return Accordion(items: [
        for (var i = 0; i < items.length; i++)
          AccordionItem(
            expanded: i == expanded,
            trigger: AccordionTrigger(child: Text(items[i])),
            content: i < children.length ? children[i] : const SizedBox.shrink(),
          ),
      ]);
    case UmgWidgetType.shadcnTooltip:
      final tip = str('tooltip');
      return Tooltip(tooltip: (context) => TooltipContainer(child: Text(tip)), child: child ?? const SizedBox.shrink());
    case UmgWidgetType.shadcnChip:
      return Chip(child: Text(str('text')));
    case UmgWidgetType.shadcnKbd:
      return KeyboardDisplay(keys: LuminaUmgStyleJson.keyboardKeys(str('text')));
    case UmgWidgetType.shadcnSkeleton:
      final lines = ((p['lines'] as num?)?.toInt() ?? 3).clamp(1, 12);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (var i = 0; i < lines; i++) const Text('Loading placeholder text line')],
      ).asSkeleton();
    case UmgWidgetType.shadcnTextField:
      return TextField(
        key: ValueKey('umg_shadcn_field_${node.id}_${p['text']}'),
        initialValue: str('text'),
        placeholder: Text(str('hint', 'hintText')),
        onChanged: onChanged,
      );
    case UmgWidgetType.shadcnTextArea:
      return TextArea(
        key: ValueKey('umg_shadcn_area_${node.id}_${p['text']}'),
        initialValue: str('text'),
        placeholder: Text(str('hint', 'hintText')),
        onChanged: onChanged,
      );
    case UmgWidgetType.shadcnSelect:
      final options = LuminaUmgElementBinding.options(element, umgItems(p['options']));
      final selected = LuminaUmgElementBinding.value<String?>(element, 'selectedOption', p['selected']?.toString());
      return Select<String>(
        value: options.contains(selected) ? selected : null,
        onChanged: onChanged,
        itemBuilder: (context, item) => Text(item),
        popup: SelectPopup(items: SelectItemList(children: [for (final o in options) SelectItemButton(value: o, child: Text(o))])).call,
      );
    case UmgWidgetType.shadcnRadioGroup:
      final options = LuminaUmgElementBinding.options(element, umgItems(p['options']));
      final selected = LuminaUmgElementBinding.value<String?>(element, 'selectedOption', p['selected']?.toString());
      return RadioGroup<String>(
        value: options.contains(selected) ? selected : null,
        onChanged: onChanged,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final o in options) RadioItem<String>(value: o, trailing: Text(o))],
        ),
      );
    case UmgWidgetType.shadcnSlider:
      return Slider(value: SliderValue.single(dbl('value', 0.5).clamp(0.0, 1.0)), onChanged: (v) => onChanged?.call(v.value));
    case UmgWidgetType.shadcnPrimaryButton:
      return PrimaryButton(onPressed: onPressed, child: Text(str('label')));
    case UmgWidgetType.shadcnSecondaryButton:
      return SecondaryButton(onPressed: onPressed, child: Text(str('label')));
    case UmgWidgetType.shadcnOutlineButton:
      return OutlineButton(onPressed: onPressed, child: Text(str('label')));
    case UmgWidgetType.shadcnGhostButton:
      return GhostButton(onPressed: onPressed, child: Text(str('label')));
    case UmgWidgetType.shadcnDestructiveButton:
      return DestructiveButton(onPressed: onPressed, child: Text(str('label')));
    case UmgWidgetType.shadcnLinkButton:
      return LinkButton(onPressed: onPressed, child: Text(str('label')));
    default:
      return const SizedBox.shrink();
  }
}
