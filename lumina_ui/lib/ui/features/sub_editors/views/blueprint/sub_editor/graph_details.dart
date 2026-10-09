part of '../blueprint_sub_editor.dart';

/// Details for graph items: level, function, macro and dispatcher
/// signatures, and the selected node's settings.
mixin _BlueprintSubEditorGraphDetails on _BlueprintSubEditorStateBase {

  /// A Level Blueprint's Details with nothing selected: the level it
  /// scripts and its placed actors (a Level Blueprint has no class defaults).
  @override
  Widget _buildLevelDetails() {
    final context = _viewModel.typeContext;
    final actors = context.levelActors ?? const <LuminaBlueprintLevelActorRef>[];
    return ListView(
      key: const ValueKey('bp_level_details'),
      padding: const EdgeInsets.all(12),
      children: [
        _detailsHeader(LucideIcons.map, 'LEVEL: ${_viewModel.displayName}', 'Scripts the level itself: starts, ticks and ends with it'),
        Text('${actors.length} placed actor${actors.length == 1 ? '' : 's'} can be referenced',
            style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
        const SizedBox(height: 6),
        const Text(
          'Select actors in the outliner and right-click the graph for "Create a Reference to …", or drag one from My '
          'Blueprint\'s Level Actors. Components, a 3D viewport and class defaults belong to actor Blueprints.',
          style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
        ),
      ],
    );
  }

  /// A widget graph's Details with nothing selected: the
  /// widget it scripts, its variables and the element events it binds.
  @override
  Widget _buildWidgetDetails() {
    final context = _viewModel.typeContext;
    final variables = context.widgetVariables ?? const <LuminaBlueprintWidgetElement>[];
    final bound = [
      for (final n in _viewModel.document.eventGraph.nodes)
        if (n.registryId == LuminaBlueprintNodeLibrary.eventWidgetElement) n.title,
    ];
    return ListView(
      key: const ValueKey('bp_widget_details'),
      padding: const EdgeInsets.all(12),
      children: [
        _detailsHeader(LucideIcons.layoutTemplate, 'WIDGET: ${_viewModel.displayName}', 'Scripts the widget: constructs, ticks and reacts with it'),
        Text('${variables.length} widget variable${variables.length == 1 ? '' : 's'} (Is Variable)',
            style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        for (final v in variables)
          Text('${v.name} · ${LuminaBlueprintObjectClass.displayName(v.objectClass)}', style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        const SizedBox(height: 8),
        Text('${bound.length} bound element event${bound.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
        const SizedBox(height: 4),
        for (final b in bound) Text(b, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        const SizedBox(height: 8),
        const Text(
          'Bind an element event with the + buttons of the Designer\'s Details ▸ Widget Events, or drag a widget from My '
          'Blueprint\'s Widgets. Components, a 3D viewport and class defaults belong to actor Blueprints.',
          style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
        ),
      ],
    );
  }

  @override
  Widget _buildFunctionDetails(LuminaBlueprintFunctionGraph fn) {
    final context = _viewModel.graphEditor(BlueprintGraphRef.function(fn.name)).context;
    return ListView(
      key: const ValueKey('bp_function_details'),
      padding: const EdgeInsets.all(12),
      children: [
        _detailsHeader(LucideIcons.squareFunction, 'FUNCTION: ${fn.name}', '${fn.category}${fn.pure ? ' · pure' : ''}'),
        Row(children: [
          const Expanded(child: Text('Pure', style: TextStyle(fontSize: 10, color: EditorColors.foreground))),
          Switch(key: const ValueKey('fn_pure_switch'), value: fn.pure, onChanged: (v) => _viewModel.setFunctionPure(fn.name, v)),
        ]),
        const SizedBox(height: 4),
        const Text('Pure functions have no exec pins and are called from data chains.', style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
        const SizedBox(height: 10),
        const Text('Category', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        const SizedBox(height: 4),
        TextField(
          key: const ValueKey('fn_category_field'),
          initialValue: fn.category,
          style: const TextStyle(fontSize: 10),
          onSubmitted: (v) => _viewModel.setFunctionCategory(fn.name, v.trim().isEmpty ? 'Default' : v.trim()),
        ),
        const SizedBox(height: 12),
        BlueprintSignatureEditor(
          title: 'Inputs',
          keyPrefix: 'fn_input',
          parameters: fn.inputs,
          context: context,
          onChanged: (v) => _viewModel.setFunctionInputs(fn.name, v),
        ),
        const SizedBox(height: 8),
        BlueprintSignatureEditor(
          title: 'Outputs',
          keyPrefix: 'fn_output',
          parameters: fn.outputs,
          context: context,
          showDefaults: false,
          onChanged: (v) => _viewModel.setFunctionOutputs(fn.name, v),
        ),
        const SizedBox(height: 8),
        Text('Called by ${_viewModel.nodesCallingFunction(fn.name).length} node(s)', style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        const SizedBox(height: 8),
        OutlineButton(
          key: const ValueKey('fn_open_graph'),
          size: ButtonSize.small,
          onPressed: () => showGraph(BlueprintGraphRef.function(fn.name)),
          child: const Text('Open Graph', style: TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  @override
  Widget _buildMacroDetails(LuminaBlueprintMacroGraph macro) {
    final context = _viewModel.graphEditor(BlueprintGraphRef.macro(macro.name)).context;
    return ListView(
      key: const ValueKey('bp_macro_details'),
      padding: const EdgeInsets.all(12),
      children: [
        _detailsHeader(LucideIcons.boxes, 'MACRO: ${macro.name}', 'Expanded into every caller'),
        BlueprintSignatureEditor(
          title: 'Inputs',
          keyPrefix: 'macro_input',
          parameters: macro.inputs,
          context: context,
          allowExec: true,
          onChanged: (v) => _viewModel.setMacroInputs(macro.name, v),
        ),
        const SizedBox(height: 8),
        BlueprintSignatureEditor(
          title: 'Outputs',
          keyPrefix: 'macro_output',
          parameters: macro.outputs,
          context: context,
          allowExec: true,
          showDefaults: false,
          onChanged: (v) => _viewModel.setMacroOutputs(macro.name, v),
        ),
        const SizedBox(height: 8),
        Text('Used by ${_viewModel.nodesCallingMacro(macro.name).length} node(s)', style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        const SizedBox(height: 8),
        OutlineButton(
          key: const ValueKey('macro_open_graph'),
          size: ButtonSize.small,
          onPressed: () => showGraph(BlueprintGraphRef.macro(macro.name)),
          child: const Text('Open Graph', style: TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  @override
  Widget _buildDispatcherDetails(LuminaBlueprintDispatcher d) {
    return ListView(
      key: const ValueKey('bp_dispatcher_details'),
      padding: const EdgeInsets.all(12),
      children: [
        _detailsHeader(LucideIcons.radio, 'EVENT DISPATCHER: ${d.name}', 'Other Blueprints bind events to it'),
        BlueprintSignatureEditor(
          title: 'Parameters',
          keyPrefix: 'dispatcher_param',
          parameters: d.parameters,
          context: _viewModel.typeContext,
          showDefaults: false,
          onChanged: (v) => _viewModel.setDispatcherParameters(d.name, v),
        ),
        const SizedBox(height: 8),
        Text('Used by ${_viewModel.nodesUsingDispatcher(d.name).length} node(s)', style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        const SizedBox(height: 4),
        const Text('Drag it onto a graph for Call, Bind, Unbind or Assign.', style: TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
      ],
    );
  }

  @override
  Widget _detailsHeader(IconData icon, String title, String? subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: EditorColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.primary),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        ],
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget _buildNodeDetails(LuminaBlueprintNode node, BlueprintGraphEditor editor) {
    final pins = editor.pinsOf(node);
    final isInput = node.registryId == LuminaBlueprintNodeLibrary.enhancedInputAction;
    final actions = _viewModel.inputActions;
    final problems = editor.problems(node);
    return ListView(
      key: const ValueKey('bp_node_details'),
      padding: const EdgeInsets.all(12),
      children: [
        _detailsHeader(LucideIcons.squareFunction, 'NODE: ${node.title}', node.category.replaceAll('|', ' › ')),
        for (final p in problems)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(p.message,
                style: TextStyle(fontSize: 9, color: p.isError ? EditorColors.destructive : EditorColors.warning)),
          ),
        if (isInput) ...[
          const Text('Input Action', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
          const SizedBox(height: 4),
          Select<String>(
            key: const ValueKey('details_action_select'),
            value: actions.any((a) => a.name == node.literals['action']) ? node.literals['action'] as String : null,
            placeholder: const Text('Pick an input action', style: TextStyle(fontSize: 11)),
            itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 11)),
            onChanged: (v) {
              if (v != null) editor.setNodeAction(node.id, v);
            },
            popup: SelectPopup(
              items: SelectItemList(
                children: [
                  for (final a in actions)
                    SelectItemButton(
                      key: ValueKey('details_action_item_${a.name}'),
                      value: a.name,
                      child: Text(a.name, style: const TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ).call,
          ),
          const SizedBox(height: 4),
          Text(
            'Action Value: ${BlueprintPinStyle.label(pins.outputs.where((p) => p.id == 'action_value').firstOrNull?.type)}',
            style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
          ),
          const SizedBox(height: 12),
        ],
        ..._nodeSettings(node, editor),
        for (final p in pins.inputs)
          if (p.type != LuminaPinType.exec &&
              BlueprintPinLiteralEditor.supports(p.type) &&
              !editor.isConnected(node.id, p.id, output: false))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p.name}  (${BlueprintPinStyle.label(p.type)})',
                      style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
                  const SizedBox(height: 4),
                  BlueprintPinLiteralEditor(
                    keyPrefix: 'details_literal_${node.id}_${p.id}',
                    type: p.type,
                    value: node.literals[p.id] ?? p.defaultValue,
                    options: editor.pinOptions(node, p),
                    expanded: true,
                    onCommit: (v) => editor.setLiteral(node.id, p.id, v),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  /// Node settings editors: the widget class of Get
  /// Element, the cases of a Switch, the outputs of Multi Gate, the item
  /// count and type of Make Array, the type of a wildcard node, Add pin on
  /// Sequence, and the placeholder count of Format Text.
  List<Widget> _nodeSettings(LuminaBlueprintNode node, BlueprintGraphEditor editor) {
    final context = _viewModel.typeContext;
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(text, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        );
    Widget select(String key, String? value, List<String> options, {String Function(String)? show}) => SizedBox(
          height: 24,
          child: Select<String>(
            key: ValueKey('details_setting_${node.id}_$key'),
            value: options.contains(value) ? value : null,
            placeholder: const Text('Pick...', style: TextStyle(fontSize: 10)),
            itemBuilder: (context, item) => Text(show?.call(item) ?? item, style: const TextStyle(fontSize: 10)),
            onChanged: (v) {
              if (v != null) editor.setNodeSetting(node.id, key, v);
            },
            popup: SelectPopup(
              items: SelectItemList(
                children: [
                  for (final o in options)
                    SelectItemButton(
                      key: ValueKey('details_setting_${node.id}_${key}_$o'),
                      value: o,
                      child: Text(show?.call(o) ?? o, style: const TextStyle(fontSize: 10)),
                    ),
                ],
              ),
            ).call,
          ),
        );
    Widget addPin(String text, VoidCallback onPressed) => OutlineButton(
          key: ValueKey('details_add_pin_${node.id}'),
          size: ButtonSize.small,
          onPressed: onPressed,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.plus, size: 10),
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(fontSize: 10)),
          ]),
        );
    const gap = SizedBox(height: 12);
    final typeOptions = [for (final t in LuminaPinType.values) if (t != LuminaPinType.exec && t != LuminaPinType.wildcard) t.name];
    final enumNames = [for (final e in context.enums) e.name];

    switch (node.registryId) {
      case BlueprintEditorNodes.comment:
        return [
          label('Title'),
          TextField(
            key: ValueKey('details_comment_title_${node.id}'),
            initialValue: node.literals['title']?.toString() ?? node.title,
            style: const TextStyle(fontSize: 10),
            onSubmitted: (v) => editor.setComment(node.id, title: v),
          ),
          const SizedBox(height: 6),
          label('Colour'),
          BlueprintPinLiteralEditor(
            keyPrefix: 'details_comment_color_${node.id}',
            type: LuminaPinType.color,
            value: _argbToRgba(BlueprintEditorNodes.commentColor(node)),
            expanded: true,
            onCommit: (v) {
              if (v is List) editor.setComment(node.id, color: _rgbaToArgb(v.cast<num>()));
            },
          ),
          gap,
        ];
      case LuminaBlueprintNodeLibrary.customEvent:
        return [
          label('Event Name'),
          TextField(
            key: ValueKey('details_event_name_${node.id}'),
            initialValue: node.literals['name']?.toString() ?? '',
            style: const TextStyle(fontSize: 10),
            onSubmitted: (v) => editor.renameCustomEvent(node.id, v),
          ),
          const SizedBox(height: 8),
          BlueprintSignatureEditor(
            title: 'Parameters',
            keyPrefix: 'event_param_${node.id}',
            parameters: LuminaBlueprintNodeLibrary.customEventParameters(node),
            context: context,
            showDefaults: false,
            onChanged: (v) => editor.setCustomEventParameters(node.id, v),
          ),
          gap,
        ];
      case LuminaBlueprintNodeLibrary.timeline:
        final tracks = BlueprintGraphEditor.timelineTracks(node);
        return [
          Text('${tracks.length} track${tracks.length == 1 ? '' : 's'} · ${_viewModel.timelineLength(node.id)} s'
              '${_viewModel.timelineLoop(node.id) ? ' · loop' : ''}${_viewModel.timelineAutoPlay(node.id) ? ' · auto play' : ''}',
              style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          const SizedBox(height: 6),
          OutlineButton(
            key: ValueKey('details_open_timeline_${node.id}'),
            size: ButtonSize.small,
            onPressed: () => showGraph(BlueprintGraphRef.timeline(node.id)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.chartLine, size: 10),
              SizedBox(width: 4),
              Text('Open Timeline', style: TextStyle(fontSize: 10)),
            ]),
          ),
          gap,
        ];
      case LuminaBlueprintNodeLibrary.enumLiteral:
        final values = context.enumeration(node.literals['enum'] as String?)?.values ?? const <String>[];
        return [
          label('Enum'),
          select('enum', node.literals['enum'] as String?, enumNames),
          const SizedBox(height: 6),
          label('Value'),
          select('value', node.literals['value'] as String?, values),
          gap,
        ];
      case LuminaBlueprintNodeLibrary.switchOnEnum:
      case 'int_to_enum':
      case 'get_enum_value_count':
        return [
          label('Enum'),
          select('enum', node.literals['enum'] as String?, enumNames),
          gap,
        ];
      case LuminaBlueprintNodeLibrary.callFunction:
      case LuminaBlueprintNodeLibrary.callFunctionPure:
        return [
          label('Function'),
          select('function', node.literals['function'] as String?, [for (final f in context.functions) f.name]),
          gap,
        ];
      case LuminaBlueprintNodeLibrary.callMacro:
        return [
          label('Macro'),
          select('macro', node.literals['macro'] as String?, [for (final m in context.macros) m.name]),
          gap,
        ];
      case LuminaBlueprintNodeLibrary.callCustomEvent:
        final target = node.literals['class'] as String?;
        final owned = target == null || !LuminaBlueprintObjectClass.isClassString(target) || target == context.selfClass;
        return [
          label(owned ? 'Event' : 'Event of ${LuminaBlueprintObjectClass.name(target)}'),
          select('event', node.literals['event'] as String?, [
            for (final e in owned ? context.customEvents : context.customEventOwners[LuminaBlueprintObjectClass.name(target)] ?? const <LuminaBlueprintCustomEvent>[])
              e.name
          ]),
          gap,
        ];
      case LuminaBlueprintNodeLibrary.getLevelActor:
        // Which placed actor the reference names.
        return [
          label('Actor'),
          select('actor', node.literals['actor'] as String?, [for (final a in context.levelActors ?? const <LuminaBlueprintLevelActorRef>[]) a.name]),
          gap,
        ];
      case LuminaBlueprintNodeLibrary.callDispatcher:
      case LuminaBlueprintNodeLibrary.bindEventToDispatcher:
      case LuminaBlueprintNodeLibrary.unbindEventFromDispatcher:
      case LuminaBlueprintNodeLibrary.unbindAllEvents:
        return [
          label('Dispatcher'),
          select('dispatcher', node.literals['dispatcher'] as String?, [for (final d in context.dispatchers) d.name]),
          gap,
        ];
      case LuminaBlueprintNodeLibrary.interfaceMessage:
      case LuminaBlueprintNodeLibrary.eventInterfaceFunction:
        final iface = context.interface(node.literals['interface'] as String?);
        return [
          label('Interface'),
          select('interface', node.literals['interface'] as String?, [for (final i in context.interfaces) i.name]),
          const SizedBox(height: 6),
          label('Function'),
          select('function', node.literals['function'] as String?, [for (final f in iface?.functions ?? const <LuminaBlueprintFunctionSignature>[]) f.name]),
          gap,
        ];
      case LuminaBlueprintNodeLibrary.getWidgetElement:
        final classes = [for (final w in context.widgetClasses) w.name];
        return [
          label('Widget Class'),
          select('class', node.literals['class'] as String?, classes),
          gap,
        ];
      case 'switch_on_int':
      case 'switch_on_string':
      case 'switch_on_name':
        final isInt = node.registryId == 'switch_on_int';
        final cases = node.literals['cases'] is List ? List<Object?>.from(node.literals['cases'] as List) : <Object?>[];
        return [
          label('Cases'),
          for (var i = 0; i < cases.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Expanded(
                  child: BlueprintPinLiteralEditor(
                    keyPrefix: 'details_case_${node.id}_$i',
                    type: isInt ? LuminaPinType.integer : LuminaPinType.string,
                    value: cases[i],
                    expanded: true,
                    onCommit: (v) => editor.setNodeSetting(node.id, 'cases', [...cases]..[i] = v),
                  ),
                ),
                GhostButton(
                  key: ValueKey('details_case_remove_${node.id}_$i'),
                  size: ButtonSize.xSmall,
                  density: ButtonDensity.icon,
                  onPressed: () => editor.setNodeSetting(node.id, 'cases', [...cases]..removeAt(i)),
                  child: const Icon(LucideIcons.x, size: 10),
                ),
              ]),
            ),
          addPin('Add case', () => editor.setNodeSetting(node.id, 'cases', [...cases, isInt ? cases.length : ''])),
          gap,
        ];
      case 'multi_gate':
        return [
          label('Outputs'),
          addPin('Add pin', () => editor.addCountedPin(node.id)),
          gap,
        ];
      case 'make_array':
        return [
          label('Item Type'),
          select('type', node.literals['type'] as String?, typeOptions, show: (t) => BlueprintPinStyle.label(LuminaPinType.parse(t))),
          if (node.literals['type'] == 'object') ...[
            const SizedBox(height: 6),
            label('Class'),
            select('class', node.literals['class'] as String?, BlueprintPalette.castTargets(context),
                show: LuminaBlueprintObjectClass.displayName),
          ],
          const SizedBox(height: 6),
          addPin('Add pin', () => editor.addCountedPin(node.id)),
          gap,
        ];
      case 'sequence':
        return [
          label('Outputs'),
          addPin('Add pin', () => editor.addSequencePin(node.id)),
          gap,
        ];
      case 'format_string':
        final format = (node.literals['format'] ?? 'FPS: {0}').toString();
        final n = RegExp(r'\{(\d+)\}').allMatches(format).map((m) => m.group(1)).toSet().length;
        return [
          Text('$n placeholder pin${n == 1 ? '' : 's'} from the Format text ({0}, {1}, ...)',
              style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          gap,
        ];
    }
    if (LuminaBlueprintNodeLibrary.adoptsWildcardType(node)) {
      return [
        label('Type'),
        select('type', node.literals['type'] as String?, typeOptions, show: (t) => BlueprintPinStyle.label(LuminaPinType.parse(t))),
        if (node.literals['type'] == 'object') ...[
          const SizedBox(height: 6),
          label('Class'),
          select('class', node.literals['class'] as String?, BlueprintPalette.castTargets(context),
              show: LuminaBlueprintObjectClass.displayName),
        ],
        gap,
      ];
    }
    return const [];
  }
}

List<double> _argbToRgba(int argb) => [
      ((argb >> 16) & 0xFF) / 255.0,
      ((argb >> 8) & 0xFF) / 255.0,
      (argb & 0xFF) / 255.0,
      ((argb >> 24) & 0xFF) / 255.0,
    ];

int _rgbaToArgb(List<num> c) {
  int channel(int i, [double fallback = 1.0]) => ((c.length > i ? c[i].toDouble() : fallback).clamp(0.0, 1.0) * 255).round();
  return (channel(3) << 24) | (channel(0) << 16) | (channel(1) << 8) | channel(2);
}
