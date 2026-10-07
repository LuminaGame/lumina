part of '../material_graph_parser.dart';

/// The local types a declaration can name, by width (a `bool` has none).
const _localTypes = {'float': 1, 'vec2': 2, 'vec3': 3, 'vec4': 4, 'bool': 0};

/// One lowered branch of an `if` chain: its condition (null for the `else`)
/// and the locals as the branch leaves them.
typedef _Branch = ({_Val? cond, Map<String, _Val> locals});

/// Lowers comparisons, logic, `?:` and `if` / `else if` / `else` chains.
///
/// A chain's branches are lowered one after the other from the state before
/// the `if`; each local a branch assigns then becomes
/// `If(cond1, v1, If(cond2, v2, … v_else))`, a branch that leaves it alone
/// keeping the value from before the `if`. A branch that writes a material
/// field or calls `prepareMaterial` has no node (its side effect cannot be
/// selected), so it throws [_Unsupported]. A local declared without a value
/// stays unassigned until every path assigns it; reading it before that
/// throws.
mixin _ControlFlow {
  // Provided by _Lowering.
  Map<String, _Val> get _locals;
  _Val _lower(_E e);
  void _statement(_Parser p);
  LuminaBlueprintNode _add(String kind, [Map<String, dynamic>? literals]);
  void _input(LuminaBlueprintNode node, String pin, _Val v, {bool inline = true});
  _Val _arith(String op, _Val a, _Val b);
  _Val _bindLocal(String name, _Val value);
  MaterialValueType _broadcastType(_Val a, _Val b);

  /// Locals declared without a value that not every path has assigned yet,
  /// with their widths.
  final Map<String, int> _unassigned = {};

  /// Names declared inside an `if` branch: gone once the branch ends.
  final Set<String> _branchScoped = {};

  /// How many `if` branches the statement being lowered is inside.
  int _branchDepth = 0;

  void _resetLocals() {
    _locals.clear();
    _unassigned.clear();
    _branchScoped.clear();
  }

  _Unsupported _undeclared(String name) {
    if (_unassigned.containsKey(name)) {
      return _Unsupported('$name may be read unassigned (not every path before this read assigns it)');
    }
    if (_branchScoped.contains(name)) return _Unsupported("'$name' is declared inside an if branch and read after it");
    return _Unsupported("'$name' is not declared");
  }

  // -- Declarations and assignments ---------------------------------------

  /// `<type> name = value;` or `<type> name;` (the type already read).
  void _declaration(_Parser p, String typeWord) {
    final width = _localTypes[typeWord]!;
    final name = p.next();
    if (!name.isIdent) throw _Unsupported('expected a variable name');
    final n = name.text;
    if (_branchDepth > 0) {
      if (_locals.containsKey(n) || _unassigned.containsKey(n)) {
        throw _Unsupported("an if branch declares '$n' again");
      }
      _branchScoped.add(n);
    } else {
      _branchScoped.remove(n);
    }
    if (p.peek == ';') {
      p.next();
      if (width == 0) throw _Unsupported('bool $n is declared without a value');
      _locals.remove(n);
      _unassigned[n] = width;
      return;
    }
    p.expect('=');
    final value = _lower(p.expr());
    p.expect(';');
    if (value.argWidth != width) throw _Unsupported('$typeWord $n is given a ${value.type.label}');
    _unassigned.remove(n);
    _locals[n] = _bindLocal(n, value);
  }

  /// `name = value;` or a compound `name += value;`.
  void _assignLocal(String name, String op, _E rhs) {
    final current = _locals[name];
    if (current != null) {
      _locals[name] = op == '=' ? _lower(rhs) : _arith(op.substring(0, 1), current, _lower(rhs));
      return;
    }
    final width = _unassigned[name];
    if (width == null || op != '=') throw _undeclared(name);
    final value = _lower(rhs);
    if (value.argWidth != width) throw _Unsupported('$name is given a ${value.type.label}');
    _unassigned.remove(name);
    // Named where every path has assigned it (after the if, for a branch).
    _locals[name] = _branchDepth == 0 ? _bindLocal(name, value) : value;
  }

  // -- if / else if / else -------------------------------------------------

  /// The chain after its `if` keyword.
  void _ifChain(_Parser p) {
    final before = Map.of(_locals);
    final beforeUnassigned = Map.of(_unassigned);
    final branches = <_Branch>[];
    var hasElse = false;
    while (true) {
      p.expect('(');
      final cond = _condition(p.expr());
      p.expect(')');
      branches.add(_branch(p, cond, before, beforeUnassigned));
      if (p.peek != 'else') break;
      p.next();
      if (p.peek == 'if') {
        p.next();
        continue;
      }
      branches.add(_branch(p, null, before, beforeUnassigned));
      hasElse = true;
      break;
    }
    _merge(branches, before, beforeUnassigned, hasElse: hasElse);
  }

  /// Lowers one branch body (`{ … }` or a single statement), then restores
  /// the locals from before the `if`.
  _Branch _branch(_Parser p, _Val? cond, Map<String, _Val> before, Map<String, int> beforeUnassigned) {
    _branchDepth++;
    try {
      if (p.peek == '{') {
        p.next();
        while (p.peek != '}') {
          _statement(p);
        }
        p.next();
      } else {
        _statement(p);
      }
    } finally {
      _branchDepth--;
    }
    final result = (cond: cond, locals: Map.of(_locals));
    _locals
      ..clear()
      ..addAll(before);
    _unassigned
      ..clear()
      ..addAll(beforeUnassigned);
    return result;
  }

  void _merge(List<_Branch> branches, Map<String, _Val> before, Map<String, int> beforeUnassigned,
      {required bool hasElse}) {
    final conditional = hasElse ? branches.sublist(0, branches.length - 1) : branches;
    for (final name in {...before.keys, ...beforeUnassigned.keys}) {
      final old = before[name];
      if (branches.every((b) => _Val.same(b.locals[name], old))) continue;
      var acc = hasElse ? branches.last.locals[name] : old;
      if (acc == null || conditional.any((b) => b.locals[name] == null)) {
        // Some path leaves it unassigned: it stays so.
        continue;
      }
      for (final b in conditional.reversed) {
        final v = b.locals[name]!;
        acc = _Val.same(v, acc) ? acc : _ifValue(b.cond!, v, acc!, local: name);
      }
      _unassigned.remove(name);
      _locals[name] = old == null && _branchDepth == 0 ? _bindLocal(name, acc!) : acc!;
    }
  }

  // -- Expressions ---------------------------------------------------------

  _Val _condition(_E e) {
    final v = _lower(e);
    if (v.type != MaterialValueType.boolean) throw _Unsupported('a condition is a ${v.type.label}, not a bool');
    return v;
  }

  /// `c ? t : f` and `!a`.
  _Val _logic(_E e) => switch (e) {
        _Cond(:final c, :final t, :final f) => _ifValue(_condition(c), _lower(t), _lower(f)),
        _Not(e: final inner) => _boolNode(MaterialLogicNodes.not, [_condition(inner)]),
        _ => throw _Unsupported('not a logic expression'),
      };

  /// A comparison (Compare) or `&&` / `||` (And / Or).
  _Val _logicBin(String op, _E a, _E b) {
    if (op == '&&' || op == '||') {
      return _boolNode(op == '&&' ? MaterialLogicNodes.and : MaterialLogicNodes.or, [_condition(a), _condition(b)]);
    }
    final x = _lower(a), y = _lower(b);
    for (final v in [x, y]) {
      if (v.type != MaterialValueType.float1 || v.broadcastTo != null) {
        throw _Unsupported("'$op' compares floats, not a ${v.type.label}");
      }
    }
    final node = _add(MaterialLogicNodes.compare, {'op': op});
    _input(node, 'a', x);
    _input(node, 'b', y);
    return _Val.node(node.id, 'out', MaterialValueType.boolean);
  }

  _Val _boolNode(String kind, List<_Val> inputs) {
    final node = _add(kind);
    for (final (k, v) in inputs.indexed) {
      _input(node, k == 0 ? 'a' : 'b', v, inline: false);
    }
    return _Val.node(node.id, 'out', MaterialValueType.boolean);
  }

  /// An If node choosing [t] or [f] by [cond].
  _Val _ifValue(_Val cond, _Val t, _Val f, {String? local}) {
    if (t.type == MaterialValueType.boolean || f.type == MaterialValueType.boolean) {
      throw _Unsupported(local == null
          ? 'a ?: choosing between bools has no node'
          : 'an if branch assigns the bool $local, which has no node (an If picks floats)');
    }
    var type = _broadcastType(t, f);
    for (final v in [t, f]) {
      if (v.broadcastTo != null && v.broadcastTo! > type.width) type = MaterialValueType.ofWidth(v.broadcastTo!);
    }
    final node = _add(MaterialLogicNodes.ifNode);
    _input(node, 'condition', cond, inline: false);
    _input(node, 'then', t);
    _input(node, 'else', f);
    return _Val.node(node.id, 'out', type);
  }

  /// A bool reaches only a bool pin, and a bool pin takes only a bool.
  void _checkBoolPin(LuminaBlueprintNode node, String pin, _Val v) {
    final def = MaterialNodes.inputsOf(node).where((p) => p.id == pin).firstOrNull;
    final wantsBool = def?.type == MaterialValueType.boolean;
    final title = MaterialNodes.spec(node.registryId)?.title ?? node.registryId;
    if (wantsBool && v.type != MaterialValueType.boolean) {
      throw _Unsupported("$title's ${def!.name} takes a bool, not a ${v.type.label}");
    }
    if (!wantsBool && v.type == MaterialValueType.boolean) {
      throw _Unsupported('a bool feeds $title; bools only feed If, And, Or and Not');
    }
  }
}
