import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_pin_style.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/pin_literal_editor.dart';

/// A parameter list of a signature: the inputs or
/// outputs of a function, macro, dispatcher, custom event or interface
/// function. Each row edits the parameter's name, type (the type pill's
/// groups, plus `Exec` for macro pins) and default; `+` adds one, `×`
/// removes one; every change hands the whole list back through [onChanged],
/// which the owner commits as one undo step.
class BlueprintSignatureEditor extends StatelessWidget {
  final String title;
  final String keyPrefix;
  final List<LuminaBlueprintVariable> parameters;
  final ValueChanged<List<LuminaBlueprintVariable>> onChanged;
  final LuminaBlueprintTypeContext context;
  final bool allowExec;
  final bool showDefaults;

  const BlueprintSignatureEditor({
    super.key,
    required this.title,
    required this.keyPrefix,
    required this.parameters,
    required this.onChanged,
    this.context = const LuminaBlueprintTypeContext(),
    this.allowExec = false,
    this.showDefaults = true,
  });

  static final RegExp _identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

  String _uniqueName(String base) {
    var name = base;
    for (var n = 2; parameters.any((p) => p.name == name); n++) {
      name = '$base$n';
    }
    return name;
  }

  @override
  Widget build(BuildContext buildContext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground))),
            GhostButton(
              key: ValueKey('${keyPrefix}_add'),
              size: ButtonSize.xSmall,
              density: ButtonDensity.icon,
              onPressed: () {
                final name = _uniqueName('NewParam');
                onChanged([
                  ...parameters,
                  LuminaBlueprintVariable(name: name, typeName: 'Float', defaultValue: BlueprintPinStyle.defaultValueFor('Float')),
                ]);
              },
              child: const Icon(LucideIcons.plus, size: 11),
            ),
          ],
        ),
        if (parameters.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('None', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          ),
        for (var i = 0; i < parameters.length; i++) _row(buildContext, i),
      ],
    );
  }

  Widget _row(BuildContext buildContext, int i) {
    final p = parameters[i];
    final type = LuminaPinType.parseVariableType(p.typeName);
    final color = p.typeName == 'Exec' ? BlueprintPinStyle.color(LuminaPinType.exec) : BlueprintPinStyle.color(type);
    final isExec = p.typeName == 'Exec';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 22,
                  child: TextField(
                    key: ValueKey('${keyPrefix}_name_$i'),
                    initialValue: p.name,
                    style: const TextStyle(fontSize: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    onSubmitted: (v) {
                      final name = v.trim();
                      if (!_identifier.hasMatch(name) || parameters.any((x) => x != p && x.name == name)) return;
                      onChanged([...parameters]..[i] = LuminaBlueprintVariable(name: name, typeName: p.typeName, defaultValue: p.defaultValue));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Builder(
                builder: (chipContext) => Clickable(
                  key: ValueKey('${keyPrefix}_type_$i'),
                  onPressed: () {
                    final box = chipContext.findRenderObject() as RenderBox?;
                    showDropdown(
                      context: buildContext,
                      // An explicit position is where the menu opens; following the
                      // anchor widget would drag it to that widget's bottom centre.
                      follow: false,
                      // Top-left corner at the point, as editor context menus open.
                      alignment: Alignment.topLeft,
                      anchorAlignment: Alignment.topLeft,
                      position: box?.localToGlobal(box.size.bottomLeft(Offset.zero)) ?? Offset.zero,
                      builder: (menuContext) => DropdownMenu(
                        children: [
                          for (final group in BlueprintPinStyle.parameterTypeGroups(context, allowExec: allowExec))
                            if (group.typeNames.isNotEmpty) ...[
                              MenuLabel(
                                child: Text(group.title.toUpperCase(),
                                    style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
                              ),
                              for (final t in group.typeNames)
                                MenuButton(
                                  key: ValueKey('${keyPrefix}_type_${i}_$t'),
                                  leading: Container(
                                    width: 10,
                                    height: 4,
                                    color: t == 'Exec' ? BlueprintPinStyle.color(LuminaPinType.exec) : BlueprintPinStyle.color(LuminaPinType.parseVariableType(t)),
                                  ),
                                  child: Text(t == 'Exec' ? 'Exec' : BlueprintPinStyle.variableLabel(t), style: const TextStyle(fontSize: 10)),
                                  onPressed: (ctx) => onChanged([...parameters]
                                    ..[i] = LuminaBlueprintVariable(name: p.name, typeName: t, defaultValue: BlueprintPinStyle.defaultValueFor(t))),
                                ),
                            ],
                        ],
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.7)),
                    ),
                    child: Text(isExec ? 'Exec' : BlueprintPinStyle.variableLabel(p.typeName),
                        style: TextStyle(fontSize: 8.5, color: color, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              GhostButton(
                key: ValueKey('${keyPrefix}_remove_$i'),
                size: ButtonSize.xSmall,
                density: ButtonDensity.icon,
                onPressed: () => onChanged([...parameters]..removeAt(i)),
                child: const Icon(LucideIcons.x, size: 10),
              ),
            ],
          ),
          if (showDefaults && !isExec && type != null && BlueprintPinLiteralEditor.supports(type))
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 2),
              child: Row(children: [
                const Text('Default', style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
                const SizedBox(width: 6),
                BlueprintPinLiteralEditor(
                  keyPrefix: '${keyPrefix}_default_$i',
                  type: type,
                  value: p.defaultValue,
                  options: type == LuminaPinType.enumeration ? context.enumeration(p.enumName)?.values : null,
                  onCommit: (v) => onChanged([...parameters]..[i] = LuminaBlueprintVariable(name: p.name, typeName: p.typeName, defaultValue: v)),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}
