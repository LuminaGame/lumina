part of '../node_library.dart';

/// [LuminaBlueprintNodeLibrary.pinsOf]: the node's pins as the library
/// resolves them for [context].
({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs})? _pinsOf(
  LuminaBlueprintNode node,
  LuminaBlueprintTypeContext context,
) {
  final s = LuminaBlueprintNodeLibrary.spec(node.registryId);
  if (s == null) return null;
  LuminaBlueprintPinSpec retype(LuminaBlueprintPinSpec p, LuminaPinType t) => p.retyped(t);
  String? literalClass(String key) {
    final v = node.literals[key];
    return v is String && v.isNotEmpty ? v : null;
  }

  List<LuminaBlueprintPinSpec> params(List<LuminaBlueprintVariable> vars) => [for (final v in vars) LuminaBlueprintPinSpec.ofVariable(v)];
  if (LuminaBlueprintNodeLibrary.widgetOnlyNodes.contains(s.id)) return _widgetPinsOf(s, node, context);
  switch (s.id) {
    case LuminaBlueprintNodeLibrary.customEvent:
      return (inputs: s.inputs, outputs: [...s.outputs, ...params(LuminaBlueprintNodeLibrary.customEventParameters(node))]);
    case LuminaBlueprintNodeLibrary.callCustomEvent:
      // With a `class` literal (`Actor:BP_Door`) the event is
      // called on a Target of that class, its parameters from that class.
      final targetClass = literalClass('class');
      if (targetClass != null && LuminaBlueprintObjectClass.isClassString(targetClass)) {
        final event = context.customEventOf(targetClass, node.literals['event'] as String?);
        return (
          inputs: [...s.inputs, _obj('target', 'Target', targetClass), ...params(event?.parameters ?? const [])],
          outputs: s.outputs,
        );
      }
      final event = context.customEvent(node.literals['event'] as String?);
      return (inputs: [...s.inputs, ...params(event?.parameters ?? const [])], outputs: s.outputs);
    case LuminaBlueprintNodeLibrary.functionEntry:
      final fn = context.functionScope;
      if (fn == null) return (inputs: s.inputs, outputs: s.outputs);
      return (inputs: const [], outputs: [if (!fn.pure) _execOut, ...params(fn.inputs)]);
    case LuminaBlueprintNodeLibrary.functionResult:
      final fn = context.functionScope;
      if (fn == null) return (inputs: s.inputs, outputs: s.outputs);
      return (inputs: [if (!fn.pure) _execIn, ...params(fn.outputs)], outputs: const []);
    case LuminaBlueprintNodeLibrary.callFunction:
    case LuminaBlueprintNodeLibrary.callFunctionPure:
      final fn = context.function(node.literals['function'] as String?);
      if (fn == null) return (inputs: s.inputs, outputs: s.outputs);
      final pure = s.id == LuminaBlueprintNodeLibrary.callFunctionPure;
      return (inputs: [if (!pure) _execIn, ...params(fn.inputs)], outputs: [if (!pure) _execOut, ...params(fn.outputs)]);
    case LuminaBlueprintNodeLibrary.macroInput:
      final macro = context.macroScope;
      return (inputs: const [], outputs: params(macro?.inputs ?? const []));
    case LuminaBlueprintNodeLibrary.macroOutput:
      final macro = context.macroScope;
      return (inputs: params(macro?.outputs ?? const []), outputs: const []);
    case LuminaBlueprintNodeLibrary.callMacro:
      final macro = context.macro(node.literals['macro'] as String?);
      return (inputs: params(macro?.inputs ?? const []), outputs: params(macro?.outputs ?? const []));
    case LuminaBlueprintNodeLibrary.localVariableGet:
    case LuminaBlueprintNodeLibrary.localVariableSet:
      final variable = context.localVariable(node.literals['variable'] as String?);
      final type = variable?.type ?? LuminaPinType.float;
      LuminaBlueprintPinSpec typed(LuminaBlueprintPinSpec p) => p.type == LuminaPinType.exec
          ? p
          : p.retyped(type, objectClass: variable?.objectClass, elementType: variable?.elementType, enumName: variable?.enumName);
      return (inputs: s.inputs.map(typed).toList(), outputs: s.outputs.map(typed).toList());
    case LuminaBlueprintNodeLibrary.callDispatcher:
      final d = context.dispatcher(node.literals['dispatcher'] as String?);
      return (inputs: [...s.inputs, ...params(d?.parameters ?? const [])], outputs: s.outputs);
    case LuminaBlueprintNodeLibrary.interfaceMessage:
      final sig = context.interface(node.literals['interface'] as String?)?.function(node.literals['function'] as String?);
      return (inputs: [...s.inputs, ...params(sig?.inputs ?? const [])], outputs: [...s.outputs, ...params(sig?.outputs ?? const [])]);
    case LuminaBlueprintNodeLibrary.eventInterfaceFunction:
      final sig = context.interface(node.literals['interface'] as String?)?.function(node.literals['function'] as String?);
      return (inputs: s.inputs, outputs: [...s.outputs, ...params(sig?.inputs ?? const [])]);
    case LuminaBlueprintNodeLibrary.getLevelActor:
      final ref = context.levelActor(literalClass('actor'));
      if (ref == null) return (inputs: s.inputs, outputs: s.outputs);
      return (inputs: s.inputs, outputs: [for (final p in s.outputs) p.retyped(p.type, objectClass: ref.actorClass)]);
    case LuminaBlueprintNodeLibrary.getLevelActorsOfClass:
      final cls = literalClass('class');
      if (cls == null || !LuminaBlueprintObjectClass.isClassString(cls)) return (inputs: s.inputs, outputs: s.outputs);
      return (
        inputs: s.inputs,
        outputs: [for (final p in s.outputs) p.retyped(p.type, elementType: LuminaPinType.object, objectClass: cls)],
      );
    case LuminaBlueprintNodeLibrary.getGameMode:
      final cls = context.gameModeClass;
      if (cls == null || cls.isEmpty) return (inputs: s.inputs, outputs: s.outputs);
      return (inputs: s.inputs, outputs: [for (final p in s.outputs) p.retyped(p.type, objectClass: LuminaBlueprintObjectClass.actor(cls))]);
    case LuminaBlueprintNodeLibrary.createSaveGameObject:
    case 'load_game_from_slot':
      final cls = literalClass('class');
      if (cls == null) return (inputs: s.inputs, outputs: s.outputs);
      final name = LuminaBlueprintObjectClass.kind(cls) == LuminaBlueprintObjectClass.saveGameKind ? LuminaBlueprintObjectClass.name(cls) : cls;
      return (inputs: s.inputs, outputs: [for (final p in s.outputs) p.type == LuminaPinType.object ? p.retyped(p.type, objectClass: LuminaBlueprintObjectClass.saveGame(name)) : p]);
    case LuminaBlueprintNodeLibrary.setSaveField:
    case LuminaBlueprintNodeLibrary.getSaveField:
      final doc = context.saveGameClass(literalClass('class'));
      final field = doc?.field(literalClass('field'));
      if (doc == null) return (inputs: s.inputs, outputs: s.outputs);
      LuminaBlueprintPinSpec typed(LuminaBlueprintPinSpec p) {
        if (p.type == LuminaPinType.object) return p.retyped(p.type, objectClass: LuminaBlueprintObjectClass.saveGame(doc.name));
        if (p.type == LuminaPinType.wildcard && field != null) {
          return p.retyped(field.type ?? LuminaPinType.wildcard, objectClass: field.objectClass, elementType: field.elementType, enumName: field.enumName);
        }
        return p;
      }
      return (inputs: s.inputs.map(typed).toList(), outputs: s.outputs.map(typed).toList());
    case LuminaBlueprintNodeLibrary.enumLiteral:
    case 'int_to_enum':
      final name = node.literals['enum'] as String?;
      return (
        inputs: s.inputs,
        outputs: [for (final p in s.outputs) p.type == LuminaPinType.enumeration ? p.retyped(p.type, enumName: name) : p],
      );
    case LuminaBlueprintNodeLibrary.switchOnEnum:
      final name = node.literals['enum'] as String?;
      final values = context.enumeration(name)?.values ?? const <String>[];
      return (
        inputs: [for (final p in s.inputs) p.type == LuminaPinType.enumeration ? p.retyped(p.type, enumName: name) : p],
        outputs: [for (var i = 0; i < values.length; i++) LuminaBlueprintPinSpec('case_$i', values[i], LuminaPinType.exec)],
      );
    case LuminaBlueprintNodeLibrary.timeline:
      final tracks = node.literals['tracks'];
      return (
        inputs: s.inputs,
        outputs: [
          ...s.outputs,
          if (tracks is List)
            for (final t in tracks)
              if (t is Map && t['name'] is String)
                LuminaBlueprintPinSpec(t['name'] as String, t['name'] as String, LuminaBlueprintNodeLibrary.timelineTrackType('${t['type'] ?? 'float'}')),
        ],
      );
    case LuminaBlueprintNodeLibrary.variableGet:
    case LuminaBlueprintNodeLibrary.variableSet:
      final rawClass = literalClass('class');
      final targetClass = rawClass == null
          ? null
          : (LuminaBlueprintObjectClass.isClassString(rawClass) ? rawClass : LuminaBlueprintObjectClass.actor(rawClass));
      final LuminaBlueprintVariable? variable;
      if (targetClass != null) {
        variable = context.variableOf(targetClass, node.literals['variable'] as String?);
      } else {
        variable = context.variable(node.literals['variable'] as String?);
      }
      final type = variable?.type ?? LuminaPinType.float;
      final cls = variable?.objectClass;
      final of = variable?.elementType;
      final en = variable?.enumName;
      final targetPin = targetClass != null ? _obj('target', 'Target', targetClass) : null;
      if (s.id == LuminaBlueprintNodeLibrary.variableGet) {
        return (
          inputs: [
            ?targetPin,
          ],
          outputs: [
            for (final p in s.outputs)
              p.retyped(type, objectClass: cls, elementType: of, enumName: en)
          ],
        );
      }
      return (
        inputs: [
          _execIn,
          ?targetPin,
          for (final p in s.inputs)
            if (p.type != LuminaPinType.exec)
              p.retyped(type, objectClass: cls, elementType: of, enumName: en)
        ],
        outputs: [
          for (final p in s.outputs)
            p.type == LuminaPinType.exec ? p : p.retyped(type, objectClass: cls, elementType: of, enumName: en)
        ],
      );
    case 'create_widget':
      final cls = literalClass('class');
      final widgetClass = cls == null ? LuminaBlueprintObjectClass.widgetKind : LuminaBlueprintObjectClass.widget(cls);
      return (
        inputs: s.inputs,
        outputs: [
          for (final p in s.outputs) p.id == _returnValue ? p.retyped(p.type, objectClass: widgetClass) : p
        ],
      );
    case LuminaBlueprintNodeLibrary.getWidgetElement:
      final found = context.widgetElement(literalClass('class'), literalClass('element'));
      if (found == null) return (inputs: s.inputs, outputs: s.outputs);
      return (
        inputs: [
          for (final p in s.inputs)
            p.id == 'target' ? p.retyped(p.type, objectClass: found.cls.objectClass) : p
        ],
        outputs: [
          for (final p in s.outputs)
            p.id == _returnValue ? p.retyped(p.type, objectClass: found.element.objectClass) : p
        ],
      );
    case LuminaBlueprintNodeLibrary.getComponent:
      final rawClass = literalClass('class');
      final targetClass = rawClass == null
          ? null
          : (LuminaBlueprintObjectClass.isClassString(rawClass) ? rawClass : LuminaBlueprintObjectClass.actor(rawClass));
      final LuminaBlueprintComponentRef? ref;
      if (targetClass != null) {
        ref = context.componentOf(targetClass, literalClass('component'));
      } else {
        ref = context.component(literalClass('component'));
      }
      if (ref == null) return (inputs: s.inputs, outputs: s.outputs);
      final targetPin = targetClass != null ? _obj('target', 'Target', targetClass) : null;
      return (
        inputs: [
          ?targetPin,
          ...s.inputs,
        ],
        outputs: [
          for (final p in s.outputs) p.id == _returnValue ? p.retyped(p.type, objectClass: ref.objectClass) : p
        ],
      );
    case LuminaBlueprintNodeLibrary.castTo:
    case 'get_component_by_class':
    case 'add_component':
    case 'spawn_actor_from_class':
    case 'get_all_actors_of_class':
    case 'get_actors_in_view_cone':
    case 'get_closest_actor_of_class_in_direction':
    case 'get_actors_within_radius':
    case 'sphere_overlap_actors':
    case 'array_filter_by_class':
    case 'get_overlapping_actors':
      final cls = literalClass('class');
      if (cls == null || !LuminaBlueprintObjectClass.isClassString(cls)) {
        return (inputs: s.inputs, outputs: s.outputs);
      }
      return (
        inputs: s.inputs,
        outputs: [
          for (final p in s.outputs)
            p.type == LuminaPinType.object
                ? p.retyped(p.type, objectClass: cls)
                : (p.type == LuminaPinType.array
                    ? p.retyped(p.type, elementType: LuminaPinType.object, objectClass: cls)
                    : p)
        ],
      );
    case LuminaBlueprintNodeLibrary.enhancedInputAction:
      final action = context.inputAction(node.literals['action'] as String?);
      final stored = node.pin('action_value')?.type;
      final type = action != null ? LuminaBlueprintNodeLibrary.actionValueType(action.valueType) : (stored ?? LuminaPinType.boolean);
      return (
        inputs: s.inputs,
        outputs: [for (final p in s.outputs) p.id == 'action_value' ? retype(p, type) : p],
      );
    case 'sequence':
      final stored = node.outputs.where((p) => p.type == LuminaPinType.exec).toList();
      if (stored.length < 2) return (inputs: s.inputs, outputs: s.outputs);
      return (
        inputs: s.inputs,
        outputs: [for (final p in stored) LuminaBlueprintPinSpec(p.id, p.name, LuminaPinType.exec)],
      );
    case 'switch_on_int':
    case 'switch_on_string':
    case 'switch_on_name':
      // One exec output per `cases` literal entry (`case_<i>`, named after the value), then Default.
      final cases = node.literals['cases'];
      final list = cases is List ? cases : const [];
      return (
        inputs: s.inputs,
        outputs: [
          for (var i = 0; i < list.length; i++) LuminaBlueprintPinSpec('case_$i', '${list[i]}', LuminaPinType.exec),
          ...s.outputs,
        ],
      );
    case 'multi_gate':
      final count = (node.literals['count'] as num?)?.toInt() ?? 2;
      return (
        inputs: s.inputs,
        outputs: [for (var i = 0; i < (count < 1 ? 1 : count); i++) LuminaBlueprintPinSpec('out_$i', 'Out $i', LuminaPinType.exec)],
      );
    case 'make_array':
      final count = (node.literals['count'] as num?)?.toInt() ?? 2;
      final type = LuminaPinType.parse(node.literals['type'] as String?) ?? LuminaPinType.wildcard;
      final cls = literalClass('class');
      return (
        inputs: [
          for (var i = 0; i < (count < 0 ? 0 : count); i++)
            LuminaBlueprintPinSpec('item_$i', '[$i]', type, objectClass: cls),
        ],
        outputs: [for (final p in s.outputs) p.retyped(p.type, elementType: type == LuminaPinType.wildcard ? null : type, objectClass: cls)],
      );
  }
  if (LuminaBlueprintNodeLibrary.wildcardNodes.contains(s.id)) {
    final type = LuminaPinType.parse(node.literals['type'] as String?);
    if (type == null || type == LuminaPinType.wildcard) return (inputs: s.inputs, outputs: s.outputs);
    final cls = literalClass('class');
    LuminaBlueprintPinSpec typed(LuminaBlueprintPinSpec p) => p.type == LuminaPinType.wildcard
        ? p.retyped(type, objectClass: cls)
        : (p.type == LuminaPinType.array ? p.retyped(p.type, elementType: type, objectClass: cls) : p);
    return (inputs: s.inputs.map(typed).toList(), outputs: s.outputs.map(typed).toList());
  }
  return (inputs: s.inputs, outputs: s.outputs);
}
