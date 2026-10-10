part of '../blueprint_dart_generator.dart';

/// Where values live while an event method runs: the event's outputs and the
/// method-level variables holding impure nodes' outputs (null until the node
/// runs in this frame, which reads as the pin type's zero, as in the VM).
class _Frame {
  final String eventNodeId;
  final String methodSuffix;
  final Map<String, String> eventOutputs;
  final String params;
  final String args;

  /// The event id the trace reports: the event node, or a transition's id
  /// for its rule (as the VM's rule host reports it).
  final String traceId;
  final Map<String, String> impureVars = {};
  final List<String> declarations = [];
  _Frame(this.eventNodeId, this.methodSuffix, this.eventOutputs, this.params, this.args, {String? traceId})
      : traceId = traceId ?? eventNodeId;
}

typedef _Pins = ({List<LuminaBlueprintPinSpec> inputs, List<LuminaBlueprintPinSpec> outputs});

/// Numbers the method-local temporaries of one generated class.
class _Counter {
  var value = 0;
  int next() => value++;
}

/// Compiles one graph's execution chains and pure expressions into Dart
/// statements, as the VM's frame runs them. [self] is what the function
/// library's `self` is (the Blueprint, or an Animation Blueprint's pawn), and
/// [readVariable] / [writeVariable] where variables live.
class _GraphCompiler {
  final LuminaBlueprintGraph graph;
  final Map<String, _Pins> pins;
  final String self;
  final String Function(String name) readVariable;
  final String Function(String name, String value) writeVariable;

  /// Local variables of a function graph; null outside one.
  final String Function(String name)? readLocal;
  final String Function(String name, String value)? writeLocal;

  /// Writes the Return node of a function graph: the
  /// statement returning [outputs] (pin id → expression).
  final String Function(Map<String, String> outputs)? returnStatement;

  /// The Dart getter of a Timeline node's runtime.
  final String Function(LuminaBlueprintNode node)? timelineOf;
  final void Function(String message, {String? node}) error;
  final _Counter _counter;

  /// Resume methods (after a Delay), written after the event methods.
  final List<String> methods = [];
  final Set<String> _resumeMethods = {};

  /// Per-node flow-control state fields, and how BeginPlay
  /// resets them, as the VM clears its flow state.
  final List<String> stateFields = [];
  final List<String> stateResets = [];
  final Set<String> _stateNodes = {};

  /// The state field of flow node [nodeId]: declared once with [type] and
  /// its initial value `null`.
  String _stateField(String nodeId, String type) {
    final name = '_flow${_cap(_id(nodeId))}';
    if (_stateNodes.add(nodeId)) {
      stateFields.add('$type? $name;');
      stateResets.add('$name = null;');
    }
    return name;
  }

  /// Libraries of the exposed functions the graph calls.
  final Set<String> libraries;

  _GraphCompiler(this.graph, LuminaBlueprintTypeContext context, this._counter,
      {required this.self,
      required this.readVariable,
      required this.writeVariable,
      required this.error,
      this.readLocal,
      this.writeLocal,
      this.returnStatement,
      this.timelineOf,
      Set<String>? libraries})
      : libraries = libraries ?? {},
        pins = {for (final n in graph.nodes) n.id: LuminaBlueprintNodeLibrary.pinsOf(n, context)!};

  /// The argument map of a signature call: every data input
  /// but the node's own settings, in pin order.
  String _signatureArgs(_Frame frame, LuminaBlueprintNode node, Map<String, Map<String, String>> step, List<String> out,
      String pad, Set<String> settings, Map<String, String> values) {
    final entries = <String>[];
    for (final p in pins[node.id]!.inputs) {
      if (p.type == LuminaPinType.exec || settings.contains(p.id)) continue;
      final expr = _input(frame, node, p.id, step, out, pad);
      values[p.id] = expr;
      entries.add('${_str(p.id)}: $expr');
    }
    return '<String, Object?>{${entries.join(', ')}}';
  }

  /// The typed read of output [pin] from a signature call's result map [r].
  String _mapOutput(String r, LuminaBlueprintPinSpec pin) {
    final zero = _literal(pin.type, null);
    final type = _dartType(pin.type);
    if (type == 'Object?') return '$r[${_str(pin.id)}]';
    return zero == 'null' ? '$r[${_str(pin.id)}] as $type?' : '(($r[${_str(pin.id)}] as $type?) ?? $zero)';
  }

  /// How node [registryId]'s function is called: the function library's, or
  /// an exposed Dart function's.
  static LuminaBlueprintCallShape? _shape(String registryId) =>
      LuminaBlueprintFunctionLibrary.callShapes[registryId] ?? LuminaBlueprintFunctionRegistry.callShape(registryId);

  /// The call of [shape] on [node] with the argument expressions [args] (by
  /// [LuminaBlueprintCallShape.args] order). An exposed function is called
  /// through its library prefix, by name for named parameters, leaving out
  /// optional ones the node neither wires nor sets (Dart's default is the
  /// pin's), and passing object pins, which generated code holds as
  /// `Object?`, as `dynamic` so the function's own parameter type checks them.
  String _call(LuminaBlueprintCallShape shape, LuminaBlueprintNode node, List<String> args) {
    final library = shape.library;
    if (library == null) {
      return 'LuminaBlueprintFunctionLibrary.${shape.method}(${[if (shape.self) self, ...args].join(', ')})';
    }
    libraries.add(library);
    bool omit(String a) =>
        shape.optional.contains(a) && graph.wireInto(node.id, a) == null && !node.literals.containsKey(a);
    String arg(int i) {
      final type = pins[node.id]!.inputs.where((p) => p.id == shape.args[i]).firstOrNull?.type;
      return type == LuminaPinType.object ? '${args[i]} as dynamic' : args[i];
    }

    final positional = [for (var i = 0; i < shape.args.length; i++) if (!shape.named.contains(shape.args[i])) i];
    var keep = positional.length;
    while (keep > 0 && omit(shape.args[positional[keep - 1]])) {
      keep--;
    }
    final parts = [
      if (shape.self) self,
      for (final i in positional.take(keep)) arg(i),
      for (var i = 0; i < shape.args.length; i++)
        if (shape.named.contains(shape.args[i]) && !omit(shape.args[i])) '${shape.args[i]}: ${arg(i)}',
    ];
    return '${BlueprintDartGenerator.functionPrefix(library)}.${shape.method}(${parts.join(', ')})';
  }

  String eventMethod(String name, _Frame frame, LuminaBlueprintNode event, String execPin, String title) {
    final body = <String>[];
    _chain(frame, event.id, execPin, body, 1, {});
    final b = StringBuffer();
    b.writeln('  /// $title (node ${event.id}).');
    b.writeln('  void $name(${frame.params}) {');
    for (final d in frame.declarations) {
      b.writeln('    $d');
    }
    for (final line in body) {
      b.writeln('  $line');
    }
    b.writeln('  }');
    return b.toString();
  }

  /// A method returning the value of [node]'s input [pin], evaluating the
  /// pure nodes behind it: a transition rule's Result.
  String valueMethod(String name, _Frame frame, LuminaBlueprintNode node, String pin, String doc) {
    final body = <String>[];
    final value = _input(frame, node, pin, <String, Map<String, String>>{}, body, '  ');
    final b = StringBuffer();
    b.writeln('  /// $doc');
    b.writeln('  bool $name() {');
    for (final line in body) {
      b.writeln('  $line');
    }
    b.writeln('    return $value;');
    b.writeln('  }');
    return b.toString();
  }

  /// Emits the chain leaving [fromNode]'s exec output [fromPin].
  void _chain(_Frame frame, String fromNode, String fromPin, List<String> out, int indent, Set<String> path) {
    final wire = graph.wiresFrom(fromNode, fromPin).firstOrNull;
    if (wire == null) return;
    final node = graph.node(wire.toNodeId);
    if (node == null) return;
    final pad = '  ' * indent;
    final inPin = wire.toPinId;
    final step = <String, Map<String, String>>{};
    final nodePins = pins[node.id]!;
    final trace = _str(frame.traceId);
    String input(String pin) => _input(frame, node, pin, step, out, pad);
    String flowTrace(String values) =>
        "${pad}if (trace != null) blueprintTrace($trace, ${_str(node.id)}, ${_str(node.registryId)}, $values);";

    // Pins that never continue execution (a loop's Break, a macro's Reset /
    // Open / Close / Toggle) may be reached from inside the node's own chain.
    if (LuminaBlueprintNodeLibrary.flowIntrinsics.contains(node.registryId) && inPin != 'exec_in') {
      _flowSide(frame, node, inPin, out, pad, flowTrace, input);
      return;
    }
    if (path.contains(node.id)) {
      error('An exec loop through ${node.title} cannot be generated (the VM stops it as an infinite loop); '
          'repeat with a Delay or Tick instead.', node: node.id);
      return;
    }
    final here = {...path, node.id};
    if (LuminaBlueprintNodeLibrary.flowIntrinsics.contains(node.registryId)) {
      _flowEnter(frame, node, out, indent, here, step, flowTrace, input);
      return;
    }

    switch (node.registryId) {
      case 'branch':
        final condition = input('condition');
        out.add("${pad}if (trace != null) blueprintTrace($trace, ${_str(node.id)}, 'branch', {'condition': $condition});");
        final whenTrue = <String>[];
        final whenFalse = <String>[];
        _chain(frame, node.id, 'true_out', whenTrue, indent + 1, here);
        _chain(frame, node.id, 'false_out', whenFalse, indent + 1, here);
        if (whenTrue.isEmpty && whenFalse.isEmpty) break;
        if (whenTrue.isEmpty) {
          out.add('${pad}if (!$condition) {');
          out.addAll(whenFalse);
        } else {
          out.add('${pad}if ($condition) {');
          out.addAll(whenTrue);
          if (whenFalse.isNotEmpty) {
            out.add('$pad} else {');
            out.addAll(whenFalse);
          }
        }
        out.add('$pad}');
      case 'sequence':
        out.add("${pad}if (trace != null) blueprintTrace($trace, ${_str(node.id)}, 'sequence', {});");
        for (final p in nodePins.outputs.where((p) => p.type == LuminaPinType.exec)) {
          _chain(frame, node.id, p.id, out, indent, here);
        }
      case 'delay':
        final duration = input('duration');
        final resume = '_resume${_cap(_id(node.id))}From${_cap(frame.methodSuffix)}';
        out.add("${pad}if (trace != null) blueprintTrace($trace, ${_str(node.id)}, 'delay', {'duration': $duration});");
        out.add('${pad}blueprintDelay(${_str(node.id)}, $duration, () => $resume(${frame.args}));');
        if (_resumeMethods.add(resume)) {
          // A new frame, as the VM resumes: impure outputs start over.
          final next = _Frame(frame.eventNodeId, frame.methodSuffix, frame.eventOutputs, frame.params, frame.args,
              traceId: frame.traceId);
          methods.add(_eventMethodAfter(resume, next, node));
        }
      case LuminaBlueprintNodeLibrary.isValidBranch:
        final object = input('input_object');
        out.add("${pad}if (trace != null) blueprintTrace($trace, ${_str(node.id)}, 'is_valid_branch', "
            "{'input_object': $object});");
        final whenValid = <String>[];
        final whenInvalid = <String>[];
        _chain(frame, node.id, 'is_valid', whenValid, indent + 1, here);
        _chain(frame, node.id, 'is_not_valid', whenInvalid, indent + 1, here);
        if (whenValid.isEmpty && whenInvalid.isEmpty) break;
        if (whenValid.isEmpty) {
          out.add('${pad}if (!LuminaBlueprintFunctionLibrary.isValid($object)) {');
          out.addAll(whenInvalid);
        } else {
          out.add('${pad}if (LuminaBlueprintFunctionLibrary.isValid($object)) {');
          out.addAll(whenValid);
          if (whenInvalid.isNotEmpty) {
            out.add('$pad} else {');
            out.addAll(whenInvalid);
          }
        }
        out.add('$pad}');
      case LuminaBlueprintNodeLibrary.castTo:
        final object = input('object');
        final cls = input('class');
        final r = 'r${_counter.next()}';
        out.add('${pad}final $r = LuminaBlueprintFunctionLibrary.castTo($object, $cls);');
        final holder = _impureVar(frame, node.id, 'as_class', LuminaPinType.object);
        out.add('$pad$holder = $r;');
        out.add("${pad}if (trace != null) blueprintTrace($trace, ${_str(node.id)}, 'cast_to', "
            "{'object': $object, 'class': $cls, 'as_class': $r});");
        final ok = <String>[];
        final failed = <String>[];
        _chain(frame, node.id, 'cast_succeeded', ok, indent + 1, here);
        _chain(frame, node.id, 'cast_failed', failed, indent + 1, here);
        if (ok.isEmpty && failed.isEmpty) break;
        if (ok.isEmpty) {
          out.add('${pad}if ($r == null) {');
          out.addAll(failed);
        } else {
          out.add('${pad}if ($r != null) {');
          out.addAll(ok);
          if (failed.isNotEmpty) {
            out.add('$pad} else {');
            out.addAll(failed);
          }
        }
        out.add('$pad}');
      case LuminaBlueprintNodeLibrary.functionResult:
        final outputs = <String, String>{};
        for (final p in nodePins.inputs) {
          if (p.type != LuminaPinType.exec) outputs[p.id] = input(p.id);
        }
        out.add(flowTrace(_map(outputs)));
        if (returnStatement != null) out.add('$pad${returnStatement!(outputs)}');
      case LuminaBlueprintNodeLibrary.localVariableSet:
        final name = node.literals['variable'] as String;
        var value = input('value');
        final valueType = nodePins.inputs.firstWhere((p) => p.id == 'value').type;
        if (valueType == LuminaPinType.array) value = 'List<Object?>.from($value)';
        if (writeLocal == null) {
          error('Local variable $name is used outside a function.', node: node.id);
          return;
        }
        out.add('$pad${writeLocal!(name, value)}');
        final localHolder = _impureVar(frame, node.id, 'value', valueType);
        out.add('$pad$localHolder = $value;');
        out.add(flowTrace("{'value': $value}"));
        _chain(frame, node.id, 'exec_out', out, indent, here);
      case LuminaBlueprintNodeLibrary.callCustomEvent:
      case LuminaBlueprintNodeLibrary.callDispatcher:
      case LuminaBlueprintNodeLibrary.callFunction:
      case LuminaBlueprintNodeLibrary.interfaceMessage:
        final values = <String, String>{};
        final targeted = node.registryId == LuminaBlueprintNodeLibrary.callCustomEvent && nodePins.inputs.any((p) => p.id == 'target');
        final settings = switch (node.registryId) {
          LuminaBlueprintNodeLibrary.callCustomEvent when targeted => const {'event', 'target'},
          LuminaBlueprintNodeLibrary.callCustomEvent => const {'event'},
          LuminaBlueprintNodeLibrary.callDispatcher => const {'dispatcher'},
          LuminaBlueprintNodeLibrary.callFunction => const {'function'},
          _ => const {'target', 'interface', 'function'},
        };
        String? target;
        if (node.registryId == LuminaBlueprintNodeLibrary.interfaceMessage || targeted) {
          target = input('target');
          values['target'] = target;
        }
        final args = _signatureArgs(frame, node, step, out, pad, settings, values);
        final name = _str(node.literals[settings.contains('event') ? 'event' : (settings.contains('dispatcher') ? 'dispatcher' : 'function')] as String? ?? '');
        switch (node.registryId) {
          case LuminaBlueprintNodeLibrary.callCustomEvent:
            out.add(targeted
                ? '${pad}LuminaBlueprintFunctionLibrary.callCustomEvent($self, $name, $args, $target);'
                : '${pad}LuminaBlueprintFunctionLibrary.callCustomEvent($self, $name, $args);');
          case LuminaBlueprintNodeLibrary.callDispatcher:
            out.add('${pad}LuminaBlueprintFunctionLibrary.callDispatcher($self, $name, $args);');
          case LuminaBlueprintNodeLibrary.callFunction:
            final r = 'r${_counter.next()}';
            out.add('${pad}final $r = LuminaBlueprintFunctionLibrary.callFunction($self, $name, $args);');
            for (final o in nodePins.outputs) {
              if (o.type == LuminaPinType.exec) continue;
              final holder = _impureVar(frame, node.id, o.id, o.type);
              out.add('$pad$holder = ${_mapOutput(r, o)};');
              values[o.id] = holder;
            }
          default:
            final r = 'r${_counter.next()}';
            out.add('${pad}final $r = LuminaBlueprintFunctionLibrary.interfaceMessage($self, $target, '
                '${_str(node.literals['interface'] as String? ?? '')}, $name, $args);');
            for (final o in nodePins.outputs) {
              if (o.type == LuminaPinType.exec) continue;
              final holder = _impureVar(frame, node.id, o.id, o.type);
              out.add('$pad$holder = ${_mapOutput(r, o)};');
              values[o.id] = holder;
            }
        }
        out.add(flowTrace(_map(values)));
        _chain(frame, node.id, 'exec_out', out, indent, here);
      case LuminaBlueprintNodeLibrary.switchOnEnum:
        final selection = input('selection');
        final sel = 's${_counter.next()}';
        out.add('${pad}final $sel = $selection;');
        out.add(flowTrace("{'selection': $sel}"));
        var opened = false;
        for (final o in nodePins.outputs.where((p) => p.type == LuminaPinType.exec)) {
          final body = <String>[];
          _chain(frame, node.id, o.id, body, indent + 1, here);
          if (body.isEmpty) continue;
          out.add('$pad${opened ? '} else ' : ''}if ($sel == ${_str(o.name)}) {');
          out.addAll(body);
          opened = true;
        }
        if (opened) out.add('$pad}');
      case LuminaBlueprintNodeLibrary.loadStreamLevel:
      case LuminaBlueprintNodeLibrary.asyncSaveGameToSlot:
        // A latent node resumed from a callback: the chain
        // continues at Exec Out now and at Completed later, in a new frame.
        final isSave = node.registryId == LuminaBlueprintNodeLibrary.asyncSaveGameToSlot;
        final values = <String, String>{};
        for (final p in nodePins.inputs) {
          if (p.type != LuminaPinType.exec) values[p.id] = input(p.id);
        }
        out.add(flowTrace(_map(values)));
        final resume = '_resume${_cap(_id(node.id))}From${_cap(frame.methodSuffix)}';
        if (isSave) {
          out.add('${pad}LuminaBlueprintFunctionLibrary.asyncSaveGameToSlot($self, ${values['save_game_object']}, ${values['slot_name']}, '
              '${values['user_index']}, (success) => $resume(success));');
        } else {
          out.add('${pad}LuminaBlueprintFunctionLibrary.loadStreamLevel($self, ${values['level_name']}, ${values['make_visible_after_load']}, '
              '${values['should_block_on_load']}, () => $resume());');
        }
        if (_resumeMethods.add(resume)) {
          final next = isSave
              ? _Frame(node.id, '${_id(node.id)}Completed', const {'success': 'success'}, 'bool success', 'success')
              : _Frame(node.id, '${_id(node.id)}Completed', const {}, '', '');
          methods.add(_eventMethodAfter(resume, next, node, pin: 'completed'));
        }
        _chain(frame, node.id, 'exec_out', out, indent, here);
      case LuminaBlueprintNodeLibrary.loadLevel:
      case LuminaBlueprintNodeLibrary.changeLevel:
      case LuminaBlueprintNodeLibrary.loadAndChangeLevel:
        // Each result pin resumes in its own method with the
        // node's fresh outputs, called back as often as the VM re-enters it
        // (On Progress once per asset); Exec Out goes on now.
        final values = <String, String>{};
        for (final p in nodePins.inputs) {
          if (p.type != LuminaPinType.exec) values[p.id] = input(p.id);
        }
        out.add(flowTrace(_map(values)));
        final isLoad = node.registryId == LuminaBlueprintNodeLibrary.loadLevel;
        final outputs = <String, String>{
          for (final o in nodePins.outputs)
            if (o.type != LuminaPinType.exec) o.id: '(o[${_str(o.id)}] as ${_dartType(o.type)})',
        };
        final branches = <String>[];
        for (final pin in isLoad ? const ['on_progress', 'on_error', 'on_success'] : const ['on_error', 'on_success']) {
          if (graph.wiresFrom(node.id, pin).isEmpty) continue;
          final resume = '_resume${_cap(_id(node.id))}${_cap(_id(pin))}From${_cap(frame.methodSuffix)}';
          if (_resumeMethods.add(resume)) {
            final next = _Frame(node.id, '${_id(node.id)}${_cap(_id(pin))}', outputs, 'Map<String, Object?> o', 'o');
            methods.add(_eventMethodAfter(resume, next, node, pin: pin));
          }
          branches.add('if (pin == ${_str(pin)}) {\n$pad      $resume(o);\n$pad    }');
        }
        // Continuation lines: the method writer indents only an entry's first line.
        final resumeFn = branches.isEmpty ? '(pin, o) {}' : '(pin, o) {\n$pad    ${branches.join(' else ')}\n$pad  }';
        final method = switch (node.registryId) {
          LuminaBlueprintNodeLibrary.loadLevel => 'loadLevel',
          LuminaBlueprintNodeLibrary.changeLevel => 'changeLevel',
          _ => 'loadAndChangeLevel',
        };
        final delegates = [
          if (isLoad) values['on_progress_event']!,
          values['on_error_event']!,
          values['on_success_event']!,
        ];
        out.add('${pad}LuminaBlueprintFunctionLibrary.$method($self, ${values['level_name']}, $resumeFn, ${delegates.join(', ')});');
        _chain(frame, node.id, 'exec_out', out, indent, here);
      case LuminaBlueprintNodeLibrary.timeline:
        final getter = timelineOf?.call(node);
        if (getter == null) {
          error('A Timeline cannot run here.', node: node.id);
          return;
        }
        final values = <String, String>{};
        final call = switch (inPin) {
          'play' => 'play()',
          'play_from_start' => 'playFromStart()',
          'stop' => 'stop()',
          'reverse' => 'reverse()',
          'reverse_from_start' => 'reverseFromStart()',
          'set_new_time' => 'setNewTime(${values['new_time'] = input('new_time')})',
          _ => null,
        };
        if (call == null) return;
        out.add('$pad$getter.$call;');
        values['pin'] = _str(inPin);
        out.add(flowTrace(_map(values)));
      case LuminaBlueprintNodeLibrary.variableSet:
        final name = node.literals['variable'] as String;
        var value = input('value');
        final valueType = nodePins.inputs.firstWhere((p) => p.id == 'value').type;
        if (valueType == LuminaPinType.array) value = 'List<Object?>.from($value)';
        final hasTarget = nodePins.inputs.any((p) => p.id == 'target');
        if (hasTarget) {
          final target = input('target');
          out.add('$pad($target as dynamic)?.${_var(name)} = $value;');
        } else {
          out.add('$pad${writeVariable(name, value)}');
        }
        final holder = _impureVar(frame, node.id, 'value', nodePins.inputs.firstWhere((p) => p.id == 'value').type);
        out.add('$pad$holder = $value;');
        out.add("${pad}if (trace != null) blueprintTrace($trace, ${_str(node.id)}, 'variable_set', {'value': $value});");
        _chain(frame, node.id, 'exec_out', out, indent, here);
      default:
        final shape = _shape(node.registryId);
        if (shape == null) {
          error('${node.title} cannot be generated.', node: node.id);
          return;
        }
        final args = [for (final a in shape.args) input(a)];
        final call = _call(shape, node, args);
        // The trace carries pins only (a setting such as `dispatcher` is not one), as the VM's does.
        final values = <String, String>{
          for (var i = 0; i < args.length; i++)
            if (nodePins.inputs.any((p) => p.id == shape.args[i])) shape.args[i]: args[i]
        };
        if (shape.outputs.isEmpty) {
          out.add('$pad$call;');
        } else {
          final r = 'r${_counter.next()}';
          out.add('${pad}final $r = $call;');
          for (final o in shape.outputs) {
            final expr = shape.returnsRecord ? '$r.${_recordField(o)}' : r;
            values[o] = expr;
            final type = nodePins.outputs.firstWhere((p) => p.id == o).type;
            out.add('$pad${_impureVar(frame, node.id, o, type)} = $expr;');
          }
        }
        final printed = node.registryId == 'print_string' || node.registryId == 'print_text' ? ', printed: ${args.first}' : '';
        out.add('${pad}if (trace != null) blueprintTrace($trace, ${_str(node.id)}, '
            '${_str(node.registryId)}, ${_map(values)}$printed);');
        final next = nodePins.outputs.where((p) => p.type == LuminaPinType.exec).firstOrNull;
        if (next != null) _chain(frame, node.id, next.id, out, indent, here);
    }
  }

  String _eventMethodAfter(String name, _Frame frame, LuminaBlueprintNode delay, {String pin = 'exec_out'}) {
    final body = <String>[];
    _chain(frame, delay.id, pin, body, 1, {});
    final b = StringBuffer();
    b.writeln('  /// After ${delay.title} (node ${delay.id}).');
    b.writeln('  void $name(${frame.params}) {');
    for (final d in frame.declarations) {
      b.writeln('    $d');
    }
    for (final line in body) {
      b.writeln('  $line');
    }
    b.writeln('  }');
    return b.toString();
  }

  String _impureVar(_Frame frame, String nodeId, String pin, LuminaPinType type) {
    final key = '$nodeId.$pin';
    return frame.impureVars.putIfAbsent(key, () {
      final name = 'o${_id(nodeId)}_${_id(pin)}';
      frame.declarations.add('${_nullableType(type)} $name;');
      return name;
    });
  }
}
