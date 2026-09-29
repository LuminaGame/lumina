part of '../blueprint_vm.dart';

/// A user function ready to run: its graph (macros expanded), pins, and the
/// entry / Return nodes.
class _FunctionGraph {
  final LuminaBlueprintFunctionGraph function;
  final LuminaBlueprintGraph graph;
  final Map<String, ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs})> pins;
  _FunctionGraph(this.function, this.graph, this.pins);

  LuminaBlueprintNode? get entry => graph.nodes.where((n) => n.registryId == LuminaBlueprintNodeLibrary.functionEntry).firstOrNull;
  LuminaBlueprintNode? get result => graph.nodes.where((n) => n.registryId == LuminaBlueprintNodeLibrary.functionResult).firstOrNull;
}

/// One function call's frame: the function's graph on the owning
/// instance's variables, with its own locals and result.
class _FunctionScope implements LuminaBlueprintGraphHost {
  final LuminaBlueprintInstance owner;
  final _FunctionGraph function;
  final Map<String, Object?> locals = {};
  Map<String, Object?>? result;
  _FunctionScope(this.owner, this.function);

  @override
  LuminaBlueprintGraph get hostGraph => function.graph;
  @override
  Map<String, ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs})> get hostPins => function.pins;
  @override
  Map<String, Object?> get hostVariables => owner.variables;
  @override
  LuminaActor get hostSelf => owner.hostSelf;
  @override
  int get hostMaxNodes => owner.maxNodesPerEvent;
  @override
  String get hostName => '${owner.blueprintClass.name}.${function.function.name}';
  @override
  void hostTrace(String eventNodeId, String nodeId, String registryId, Map<String, Object?> values, {String? printed}) =>
      owner.hostTrace(eventNodeId, nodeId, registryId, values, printed: printed);
  @override
  void hostDelay(String nodeId, double seconds, void Function() resume) => owner.hostDelay(nodeId, seconds, resume);
  @override
  void hostRetriggerableDelay(String nodeId, double seconds, void Function() resume) =>
      owner.hostRetriggerableDelay(nodeId, seconds, resume);
  @override
  void hostError(String message) => owner.hostError(message);
  @override
  Map<String, Object?> get hostFlowState => owner.blueprintFlowState;
  @override
  Map<String, Object?> get hostLocals => locals;
  @override
  LuminaBlueprintInstance get hostInstance => owner;
}

/// A stored literal as the pin type's value; null is the type's zero.
Object? _typed(LuminaPinType type, Object? stored) => luminaBlueprintLiteral(type, stored) ?? _zero(type);

Object? _zero(LuminaPinType type) => luminaBlueprintZero(type);

typedef _PinsOf = ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs});

class _InfiniteLoop implements Exception {
  final String nodeId;
  _InfiniteLoop(this.nodeId);
}

/// One event invocation: follows exec wires, evaluates pure inputs on demand
/// (cached per exec step), runs intrinsics, calls the
/// function library for everything else.
class _Frame {
  final LuminaBlueprintGraphHost host;
  final String eventNodeId;
  final Map<String, Object?> eventOutputs;
  final Map<String, Map<String, Object?>> _pureCache = {};
  final Map<String, Map<String, Object?>> _impureOutputs = {};
  int _steps = 0;

  _Frame(this.host, this.eventNodeId, this.eventOutputs);

  LuminaBlueprintGraph get graph => host.hostGraph;

  void _count(String nodeId) {
    if (++_steps > host.hostMaxNodes) throw _InfiniteLoop(nodeId);
  }

  /// Loops the VM has broken out of in this run (ForLoopWithBreak).
  final Set<String> _broken = {};

  void runFrom(String nodeId, String execPin) {
    // Exec pins to follow, and loop continuations that run after the body
    // they pushed has completed (a loop never recurses the interpreter).
    final stack = <Object>[(nodeId, execPin)];
    while (stack.isNotEmpty) {
      final top = stack.removeLast();
      if (top is void Function()) {
        top();
        continue;
      }
      final (fromNode, fromPin) = top as (String, String);
      final wire = graph.wiresFrom(fromNode, fromPin).firstOrNull;
      if (wire == null) continue;
      final node = graph.node(wire.toNodeId);
      if (node == null) continue;
      _count(node.id);
      _pureCache.clear();
      final pins = host.hostPins[node.id]!;
      final values = <String, Object?>{};
      final flow = host.hostFlowState;
      if (LuminaBlueprintNodeLibrary.flowIntrinsics.contains(node.registryId)) {
        _flow(node, wire.toPinId, pins, values, flow, stack);
        continue;
      }
      switch (node.registryId) {
        case 'branch':
          final condition = _input(node, 'condition', pins) as bool;
          values['condition'] = condition;
          _emit(node, values);
          stack.add((node.id, condition ? 'true_out' : 'false_out'));
        case 'sequence':
          _emit(node, values);
          final outs = pins.outputs.where((p) => p.type == LuminaPinType.exec).toList();
          for (final out in outs.reversed) {
            stack.add((node.id, out.id));
          }
        case 'delay':
          final duration = _input(node, 'duration', pins) as double;
          values['duration'] = duration;
          _emit(node, values);
          // Retriggering a pending Delay does nothing. The
          // chain resumes in a new frame with this event's outputs.
          final event = eventNodeId;
          final outputs = eventOutputs;
          host.hostDelay(node.id, duration,
              () => LuminaBlueprintInterpreter.run(host, node.id, 'exec_out', outputs, eventNodeId: event));
        case LuminaBlueprintNodeLibrary.variableSet:
          final name = node.literals['variable'] as String;
          var value = _input(node, 'value', pins);
          // Arrays are values: a Set copies.
          if (value is List) value = List<Object?>.from(value);
          host.hostVariables[name] = value;
          _impureOutputs[node.id] = {'value': value};
          values['value'] = value;
          _emit(node, values);
          stack.add((node.id, 'exec_out'));
        case LuminaBlueprintNodeLibrary.isValidBranch:
          final object = _input(node, 'input_object', pins);
          values['input_object'] = object;
          _emit(node, values);
          stack.add((node.id, LuminaBlueprintFunctionLibrary.isValid(object) ? 'is_valid' : 'is_not_valid'));
        case LuminaBlueprintNodeLibrary.functionResult:
          final scope = host;
          final outputs = {for (final p in pins.inputs) if (p.type != LuminaPinType.exec) p.id: _input(node, p.id, pins)};
          _emit(node, outputs);
          if (scope is _FunctionScope) scope.result = outputs;
        case LuminaBlueprintNodeLibrary.localVariableSet:
          final name = node.literals['variable'] as String;
          var value = _input(node, 'value', pins);
          if (value is List) value = List<Object?>.from(value);
          host.hostLocals[name] = value;
          _impureOutputs[node.id] = {'value': value};
          values['value'] = value;
          _emit(node, values);
          stack.add((node.id, 'exec_out'));
        case LuminaBlueprintNodeLibrary.switchOnEnum:
          final selection = _input(node, 'selection', pins);
          values['selection'] = selection;
          _emit(node, values);
          final outs = pins.outputs.where((p) => p.type == LuminaPinType.exec).toList();
          for (final out in outs) {
            if (out.name == selection) {
              stack.add((node.id, out.id));
              break;
            }
          }
        case LuminaBlueprintNodeLibrary.loadStreamLevel:
          final level = _input(node, 'level_name', pins) as String;
          final visible = _input(node, 'make_visible_after_load', pins) as bool;
          final block = _input(node, 'should_block_on_load', pins) as bool;
          values['level_name'] = level;
          values['make_visible_after_load'] = visible;
          values['should_block_on_load'] = block;
          _emit(node, values);
          LuminaBlueprintFunctionLibrary.loadStreamLevel(host.hostSelf, level, visible, block,
              () => LuminaBlueprintInterpreter.run(host, node.id, 'completed', const {}, eventNodeId: node.id));
          stack.add((node.id, 'exec_out'));
        case LuminaBlueprintNodeLibrary.asyncSaveGameToSlot:
          final object = _input(node, 'save_game_object', pins);
          final slot = _input(node, 'slot_name', pins) as String;
          final user = _input(node, 'user_index', pins) as int;
          values['save_game_object'] = object;
          values['slot_name'] = slot;
          values['user_index'] = user;
          _emit(node, values);
          LuminaBlueprintFunctionLibrary.asyncSaveGameToSlot(host.hostSelf, object, slot, user,
              (ok) => LuminaBlueprintInterpreter.run(host, node.id, 'completed', {'success': ok}, eventNodeId: node.id));
          stack.add((node.id, 'exec_out'));
        case LuminaBlueprintNodeLibrary.loadLevel:
        case LuminaBlueprintNodeLibrary.changeLevel:
        case LuminaBlueprintNodeLibrary.loadAndChangeLevel:
          // Each result (On Progress per asset, On Error, On
          // Success) re-enters the chain from its pin with fresh outputs, as
          // a timeline's Update does; Exec Out goes on now.
          for (final p in pins.inputs) {
            if (p.type != LuminaPinType.exec) values[p.id] = _input(node, p.id, pins);
          }
          _emit(node, values);
          void resume(String pin, Map<String, Object?> outputs) =>
              LuminaBlueprintInterpreter.run(host, node.id, pin, outputs, eventNodeId: node.id);
          final level = values['level_name'] as String;
          switch (node.registryId) {
            case LuminaBlueprintNodeLibrary.loadLevel:
              LuminaBlueprintFunctionLibrary.loadLevel(host.hostSelf, level, resume, values['on_progress_event'],
                  values['on_error_event'], values['on_success_event']);
            case LuminaBlueprintNodeLibrary.changeLevel:
              LuminaBlueprintFunctionLibrary.changeLevel(
                  host.hostSelf, level, resume, values['on_error_event'], values['on_success_event']);
            default:
              LuminaBlueprintFunctionLibrary.loadAndChangeLevel(
                  host.hostSelf, level, resume, values['on_error_event'], values['on_success_event']);
          }
          stack.add((node.id, 'exec_out'));
        case LuminaBlueprintNodeLibrary.timeline:
          final instance = host.hostInstance;
          if (instance == null) continue;
          final timeline = instance.timelineFor(host, node);
          switch (wire.toPinId) {
            case 'play':
              timeline.play();
            case 'play_from_start':
              timeline.playFromStart();
            case 'stop':
              timeline.stop();
            case 'reverse':
              timeline.reverse();
            case 'reverse_from_start':
              timeline.reverseFromStart();
            case 'set_new_time':
              final t = _input(node, 'new_time', pins) as double;
              values['new_time'] = t;
              timeline.setNewTime(t);
          }
          values['pin'] = wire.toPinId;
          _emit(node, values);
        case LuminaBlueprintNodeLibrary.castTo:
          final object = _input(node, 'object', pins);
          final cls = _input(node, 'class', pins) as String? ?? '';
          final result = LuminaBlueprintFunctionLibrary.castTo(object, cls);
          values['object'] = object;
          values['class'] = cls;
          values['as_class'] = result;
          _impureOutputs[node.id] = {'as_class': result};
          _emit(node, values);
          stack.add((node.id, result != null ? 'cast_succeeded' : 'cast_failed'));
        default:
          final function = LuminaBlueprintFunctionLibrary.functions[node.registryId];
          if (function == null) {
            if (LuminaBlueprintFunctionRegistry.isDeclaredOnly(node.registryId)) {
              // Project code this process cannot run. Its
              // outputs are their zero values and the chain goes on.
              final outputs = _unavailable(node, pins);
              _impureOutputs[node.id] = outputs;
              _emit(node, outputs);
              final next = pins.outputs.where((p) => p.type == LuminaPinType.exec).firstOrNull;
              if (next != null) stack.add((node.id, next.id));
            }
            continue;
          }
          for (final p in pins.inputs) {
            if (p.type != LuminaPinType.exec) values[p.id] = _input(node, p.id, pins);
          }
          var outputs = function(LuminaBlueprintCallContext(host.hostSelf), {..._settings(node, pins), ...values});
          // A signature call may answer fewer outputs than the
          // node has pins (an unimplemented interface message): zeros fill in.
          if (LuminaBlueprintNodeLibrary.signatureCalls.contains(node.registryId)) {
            outputs = {
              ...outputs,
              for (final p in pins.outputs)
                if (p.type != LuminaPinType.exec && !outputs.containsKey(p.id)) p.id: _zero(p.type),
            };
          }
          _impureOutputs[node.id] = outputs;
          _emit(node, {...values, ...outputs},
              printed: node.registryId == 'print_string'
                  ? values['in_string'] as String?
                  : (node.registryId == 'print_text' ? values['in_text'] as String? : null));
          final next = pins.outputs.where((p) => p.type == LuminaPinType.exec).firstOrNull;
          if (next != null) stack.add((node.id, next.id));
      }
    }
  }

  /// Runs a flow-control macro entered through [inPin].
  void _flow(LuminaBlueprintNode node, String inPin, _PinsOf pins, Map<String, Object?> values,
      Map<String, Object?> flow, List<Object> stack) {
    final id = node.id;
    switch (node.registryId) {
      case 'do_once':
        if (inPin == 'reset') {
          flow[id] = false;
          values['fired'] = false;
          _emit(node, values);
          return;
        }
        final done = flow[id] as bool? ?? (_input(node, 'start_closed', pins) as bool);
        values['fired'] = !done;
        _emit(node, values);
        if (done) return;
        flow[id] = true;
        stack.add((id, 'completed'));
      case 'flip_flop':
        final isA = flow[id] as bool? ?? true;
        flow[id] = !isA;
        _impureOutputs[id] = {'is_a': isA};
        values['is_a'] = isA;
        _emit(node, values);
        stack.add((id, isA ? 'a' : 'b'));
      case 'gate':
        var open = flow[id] as bool? ?? !(_input(node, 'start_closed', pins) as bool);
        switch (inPin) {
          case 'open':
            open = true;
          case 'close':
            open = false;
          case 'toggle':
            open = !open;
        }
        flow[id] = open;
        values['is_open'] = open;
        values['pin'] = inPin;
        _emit(node, values);
        if (inPin == 'exec_in' && open) stack.add((id, 'exit'));
      case 'do_n':
        if (inPin == 'reset') {
          flow[id] = 0;
          values['counter'] = 0;
          _emit(node, values);
          return;
        }
        final n = _input(node, 'n', pins) as int;
        final count = flow[id] as int? ?? 0;
        values['n'] = n;
        if (count >= n) {
          values['counter'] = count;
          _emit(node, values);
          return;
        }
        flow[id] = count + 1;
        _impureOutputs[id] = {'counter': count + 1};
        values['counter'] = count + 1;
        _emit(node, values);
        stack.add((id, 'exit'));
      case 'for_loop':
      case 'for_loop_with_break':
        if (inPin == 'break') {
          _broken.add(id);
          return;
        }
        final first = _input(node, 'first_index', pins) as int;
        final last = _input(node, 'last_index', pins) as int;
        _broken.remove(id);
        _emit(node, {'first_index': first, 'last_index': last});
        var index = first;
        late void Function() next;
        next = () {
          if (index > last || _broken.remove(id)) {
            stack.add((id, 'completed'));
            return;
          }
          _pureCache.clear();
          _impureOutputs[id] = {'index': index};
          _emit(node, {'index': index});
          index++;
          stack.add(next);
          stack.add((id, 'loop_body'));
        };
        next();
      case 'while_loop':
        _emit(node, values);
        var iterations = 0;
        late void Function() next;
        next = () {
          _pureCache.clear();
          final condition = _input(node, 'condition', pins) as bool;
          if (!condition) {
            _emit(node, {'condition': false, 'iterations': iterations});
            stack.add((id, 'completed'));
            return;
          }
          if (iterations >= LuminaBlueprintNodeLibrary.whileLoopCap) {
            LuminaBlueprintFunctionLibrary.whileLoopCapped(host.hostName, node.id);
            _emit(node, {'condition': true, 'iterations': iterations, 'capped': true});
            stack.add((id, 'completed'));
            return;
          }
          _emit(node, {'condition': true, 'iterations': iterations});
          iterations++;
          stack.add(next);
          stack.add((id, 'loop_body'));
        };
        next();
      case 'for_each_loop':
        final array = _input(node, 'array', pins);
        final items = LuminaBlueprintFunctionLibrary.arrayItems(array);
        _emit(node, {'array': array});
        var index = 0;
        late void Function() next;
        next = () {
          if (index >= items.length) {
            stack.add((id, 'completed'));
            return;
          }
          _pureCache.clear();
          final element = items[index];
          _impureOutputs[id] = {'array_element': element, 'array_index': index};
          _emit(node, {'array_element': element, 'array_index': index});
          index++;
          stack.add(next);
          stack.add((id, 'loop_body'));
        };
        next();
      case 'retriggerable_delay':
        final duration = _input(node, 'duration', pins) as double;
        values['duration'] = duration;
        _emit(node, values);
        final event = eventNodeId;
        final outputs = eventOutputs;
        host.hostRetriggerableDelay(
            id, duration, () => LuminaBlueprintInterpreter.run(host, id, 'exec_out', outputs, eventNodeId: event));
      case 'switch_on_int':
      case 'switch_on_string':
      case 'switch_on_name':
        final selection = _input(node, 'selection', pins);
        values['selection'] = selection;
        _emit(node, values);
        final cases = node.literals['cases'];
        final list = cases is List ? cases : const [];
        for (var i = 0; i < list.length; i++) {
          final c = list[i];
          if (c == selection || '$c' == '$selection') {
            stack.add((id, 'case_$i'));
            return;
          }
        }
        stack.add((id, 'default'));
      case 'switch_on_bool':
        final selection = _input(node, 'selection', pins) as bool;
        values['selection'] = selection;
        _emit(node, values);
        stack.add((id, selection ? 'true_out' : 'false_out'));
      case 'multi_gate':
        final outs = pins.outputs.where((p) => p.type == LuminaPinType.exec).map((p) => p.id).toList();
        if (inPin == 'reset') {
          flow.remove(id);
          values['index'] = -1;
          _emit(node, values);
          return;
        }
        final isRandom = _input(node, 'is_random', pins) as bool;
        final loop = _input(node, 'loop', pins) as bool;
        final startIndex = _input(node, 'start_index', pins) as int;
        final r = LuminaBlueprintFunctionLibrary.multiGateNext(
            (flow[id] as List?)?.cast<int>(), outs.length, isRandom, loop, startIndex);
        flow[id] = r.used;
        values['index'] = r.index;
        _emit(node, values);
        if (r.index >= 0) stack.add((id, outs[r.index]));
    }
  }

  /// A declared-only function's outputs (their zero values), logged once
  /// per node and Blueprint: it is project code this process cannot run.
  Map<String, Object?> _unavailable(
    LuminaBlueprintNode node,
    ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs}) pins,
  ) {
    final logged = _unavailableLogged[host] ??= <String>{};
    if (logged.add(node.id)) {
      developer.log('${host.hostName}: ${node.title} ${LuminaBlueprintFunctionRegistry.unavailableMessage}; skipped.',
          name: 'Blueprint', level: 900);
    }
    return {
      for (final p in pins.outputs)
        if (p.type != LuminaPinType.exec) p.id: _zero(p.type),
    };
  }

  static final Expando<Set<String>> _unavailableLogged = Expando('blueprint unavailable functions');

  void _emit(LuminaBlueprintNode node, Map<String, Object?> values, {String? printed}) =>
      host.hostTrace(eventNodeId, node.id, node.registryId, values, printed: printed);

  /// The value of [node]'s input [pinId]: its wire's source, else its
  /// literal, else the library default, else the type's zero.
  Object? _input(
    LuminaBlueprintNode node,
    String pinId,
    ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs}) pins,
  ) {
    final spec = pins.inputs.where((p) => p.id == pinId).firstOrNull;
    if (spec == null) return node.literals[pinId];
    final wire = graph.wireInto(node.id, pinId);
    if (wire != null) return _output(wire.fromNodeId, wire.fromPinId);
    if (node.literals.containsKey(pinId)) {
      return _typed(spec.type, node.literals[pinId]);
    }
    return _typed(spec.type, spec.defaultValue);
  }

  /// A node's setting literals that its function reads but that are not
  /// pins (`event`, `function`, `dispatcher`, `interface`, `enum`, an enum
  /// literal's `value`).
  static const Set<String> _settingKeys = {'event', 'function', 'dispatcher', 'interface', 'enum', 'value', 'macro', 'class', 'field', 'actor', 'element'};

  Map<String, Object?> _settings(LuminaBlueprintNode node, _PinsOf pins) => {
        for (final e in node.literals.entries)
          if (_settingKeys.contains(e.key) && !pins.inputs.any((p) => p.id == e.key)) e.key: e.value,
      };

  Object? _output(String nodeId, String pinId) {
    if (nodeId == eventNodeId) return eventOutputs[pinId];
    final impure = _impureOutputs[nodeId];
    if (impure != null) return impure[pinId];
    final node = graph.node(nodeId);
    if (node == null) return null;
    // A custom event's red delegate pin: the event bound to this Blueprint.
    if (node.registryId == LuminaBlueprintNodeLibrary.customEvent && pinId == 'delegate') {
      final instance = host.hostInstance;
      return instance == null ? null : LuminaBlueprintDelegate(instance, node.literals['name'] as String? ?? '');
    }
    final spec = LuminaBlueprintNodeLibrary.spec(node.registryId);
    if (spec == null || spec.kind != LuminaBlueprintNodeKind.pure) {
      // An output of a node that has not run in this frame (another event's,
      // or an impure node not yet reached): its type's zero.
      final type = host.hostPins[nodeId]?.outputs.where((p) => p.id == pinId).firstOrNull?.type;
      return type == null ? null : _zero(type);
    }
    final cached = _pureCache[nodeId];
    if (cached != null) return cached[pinId];
    _count(nodeId);
    final pins = host.hostPins[nodeId]!;
    Map<String, Object?> outputs;
    final values = <String, Object?>{};
    final function = LuminaBlueprintFunctionLibrary.functions[node.registryId];
    if (node.registryId == LuminaBlueprintNodeLibrary.variableGet) {
      outputs = {'value': host.hostVariables[node.literals['variable'] as String]};
    } else if (node.registryId == LuminaBlueprintNodeLibrary.localVariableGet) {
      outputs = {'value': host.hostLocals[node.literals['variable'] as String]};
    } else if (function == null) {
      outputs = _unavailable(node, pins);
    } else {
      for (final p in pins.inputs) {
        values[p.id] = _input(node, p.id, pins);
      }
      outputs = function(LuminaBlueprintCallContext(host.hostSelf), {..._settings(node, pins), ...values});
      if (LuminaBlueprintNodeLibrary.signatureCalls.contains(node.registryId)) {
        outputs = {
          ...outputs,
          for (final p in pins.outputs)
            if (p.type != LuminaPinType.exec && !outputs.containsKey(p.id)) p.id: _zero(p.type),
        };
      }
    }
    _pureCache[nodeId] = outputs;
    _emit(node, {...values, ...outputs});
    return outputs[pinId];
  }
}
