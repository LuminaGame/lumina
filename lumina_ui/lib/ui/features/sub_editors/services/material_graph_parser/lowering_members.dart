part of '../material_graph_parser.dart';

/// Lowers vectors, texture coordinates, members, swizzles and parameters.
extension _LoweringMembers on _Lowering {
  _Val _append(_Val a, _Val b) {
    final width = a.argWidth + b.argWidth;
    if (width > 4) throw _Unsupported('a vector wider than four components');
    if (a.broadcastTo != null || b.broadcastTo != null) throw _Unsupported('a broadcast inside a vector constructor');
    final node = _add(MaterialNodes.appendVector);
    _input(node, 'a', a, inline: false);
    _input(node, 'b', b, inline: false);
    return _out(node, MaterialValueType.ofWidth(width));
  }

  _Val _texCoord(int index, double u, double v) {
    final key = 'uv$index/$u/$v';
    final existing = _shared[key];
    if (existing != null) return _Val.node(existing, 'out', MaterialValueType.float2);
    final node = _add(MaterialNodes.textureCoordinate, {'index': index, 'uTiling': u, 'vTiling': v});
    _retitle(node);
    _shared[key] = node.id;
    return _out(node, MaterialValueType.float2);
  }

  _Val _sharedNode(String kind, String pin, MaterialValueType type) {
    final id = _shared[kind] ??= _add(kind).id;
    return _Val.node(id, pin, type);
  }

  static final RegExp _swizzle = RegExp(r'^([xyzw]{1,4}|[rgba]{1,4})$');

  /// The one Vertex Variable node reading [name] in the fragment.
  _Val _readVariable(String name) {
    final id = _shared['variable:$name'] ??= () {
      final node = _add(MaterialNodes.vertexVariable, {'name': name});
      _retitle(node);
      return node.id;
    }();
    return _Val.node(id, 'rgba', MaterialValueType.float4);
  }

  /// The one WorldPosition node of [space].
  _Val _worldPosition(String space) {
    final id = _shared['world:$space'] ??= () {
      final node = _add(MaterialNodes.worldPosition, {'space': space});
      _retitle(node);
      return node.id;
    }();
    return _Val.node(id, 'out', MaterialValueType.float3);
  }

  /// `material.worldPosition` in the vertex block.
  static bool _isVertexWorldPosition(_E e) =>
      e is _Mem && e.name == 'worldPosition' && e.target is _Id && (e.target as _Id).name == 'material';

  /// `mulMat4x4Float3(getUserWorldFromWorldMatrix(), material.worldPosition.xyz)`:
  /// the absolute world position the codegen writes in the vertex block.
  static bool _isUserWorldPosition(_E e) =>
      e is _Call &&
      e.callee == 'mulMat4x4Float3' &&
      e.args.length == 2 &&
      e.args[0] is _Call &&
      (e.args[0] as _Call).callee == 'getUserWorldFromWorldMatrix' &&
      (e.args[0] as _Call).args.isEmpty &&
      e.args[1] is _Mem &&
      (e.args[1] as _Mem).name == 'xyz' &&
      _isVertexWorldPosition((e.args[1] as _Mem).target);

  _Val _member(_E target, String name) {
    if (target is _Id && target.name == 'materialParams') return _parameter(name);
    if (_vertex) {
      if (target is _Id && target.name == 'material') {
        switch (name) {
          case 'uv0' || 'uv1':
            return _texCoord(name == 'uv0' ? 0 : 1, 1.0, 1.0);
          case 'color':
            return _sharedNode(MaterialNodes.vertexColor, 'rgba', MaterialValueType.float4);
        }
        final written = _vertexWrites[name];
        if (written != null) return written;
        throw _Unsupported('material.$name has no node in the vertex block');
      }
      if (_isVertexWorldPosition(target)) {
        return _member(_ValExpr(_worldPosition(MaterialNodes.cameraRelativeSpace)), name);
      }
      if (_isUserWorldPosition(target)) {
        return _member(_ValExpr(_worldPosition(MaterialNodes.absoluteSpace)), name);
      }
    }
    if (target is _Id && target.name == 'material') {
      if (!_fieldDefaults.containsKey(name)) throw _Unsupported('material.$name has no Material output pin');
      return _currentField(name);
    }
    if (target is _Call && target.callee == 'getUserTime' && target.args.isEmpty && name == 'x') {
      return _sharedNode(MaterialNodes.time, 'out', MaterialValueType.float1);
    }
    if (!_swizzle.hasMatch(name)) throw _Unsupported(".$name is not a swizzle");
    final v = _lower(target);
    final letters = name.replaceAll('x', 'r').replaceAll('y', 'g').replaceAll('z', 'b').replaceAll('w', 'a');
    final indices = [for (final c in letters.split('')) 'rgba'.indexOf(c)];
    if (indices.any((k) => k >= v.type.width)) throw _Unsupported('.$name reads past a ${v.type.label}');
    if (v.isLiteral) return _Val.lit([for (final k in indices) v.literal![k]]);
    final node = graph.node(v.nodeId!)!;
    final named = MaterialNodes.outputsOf(node).length > 1 && v.pinId == 'rgba';
    if (named) {
      const byLetters = {'rgb': 'rgb', 'r': 'r', 'g': 'g', 'b': 'b', 'a': 'a', 'rgba': 'rgba'};
      final pin = byLetters[letters];
      if (pin != null) return _Val.node(node.id, pin, pin == 'rgba' ? MaterialValueType.float4 : (pin == 'rgb' ? MaterialValueType.float3 : MaterialValueType.float1));
    }
    final ordered = [for (var k = 1; k < indices.length; k++) indices[k] > indices[k - 1]].every((x) => x);
    if (ordered && indices.length == v.type.width) return v;
    if (ordered) {
      final mask = _add(MaterialNodes.componentMask, {for (final c in ['r', 'g', 'b', 'a']) c: letters.contains(c)});
      _retitle(mask);
      _input(mask, 'in', v, inline: false);
      return _out(mask, MaterialValueType.ofWidth(indices.length));
    }
    return _customExpr('return In0.$name;', [v], MaterialValueType.ofWidth(indices.length));
  }

  _Val _parameter(String name) {
    final decl = _decls[name];
    if (decl == null) throw _Unsupported('materialParams.$name is not declared in the header');
    final type = decl.type.toLowerCase();
    if (type == 'float') {
      return _Val.node(_paramNode(decl), 'out', MaterialValueType.float1);
    }
    if (const {'float3', 'float4', 'vec3', 'vec4', 'color'}.contains(type)) {
      return _Val.node(_paramNode(decl), 'rgba', MaterialValueType.float4);
    }
    if (type == 'float2' || type == 'vec2') {
      return _customExpr('return materialParams.$name;', const [], MaterialValueType.float2);
    }
    throw _Unsupported('a ${decl.type} parameter has no material node');
  }

  /// The one node standing for header parameter [decl].
  String _paramNode(MatParameterDecl decl) {
    final existing = _paramNodes[decl.name];
    if (existing != null) return existing;
    final type = decl.type.toLowerCase();
    final LuminaBlueprintNode node;
    if (type == 'float') {
      node = _add(MaterialNodes.scalarParameter, {'name': decl.name, 'default': _number(decl.defaultValue) ?? 0.0});
    } else if (decl.isSampler) {
      node = _add(MaterialNodes.textureParameter, {'name': decl.name});
    } else {
      node = _add(MaterialNodes.vectorParameter, {
        'name': decl.name,
        'default': _vector4(decl.defaultValue),
        if (type != 'float4') 'declType': decl.type,
      });
    }
    node.literals['declOrder'] = _declOrder.indexOf(decl.name);
    _retitle(node);
    _paramNodes[decl.name] = node.id;
    return node.id;
  }

  static double? _number(MatValue? v) => v is MatAtom ? double.tryParse(v.text) : null;

  static List<double> _vector4(MatValue? v) {
    final out = <double>[];
    if (v is MatList) {
      for (final i in v.items) {
        final d = _number(i);
        if (d != null) out.add(d);
      }
    }
    if (out.isEmpty) return [1.0, 1.0, 1.0, 1.0];
    while (out.length < 4) {
      out.add(1.0);
    }
    return out.take(4).toList();
  }

  /// Declared parameters the fragment never reads still get nodes, so a graph
  /// edit keeps them in the header (and in the panel).
  void declareHeaderParameters({required bool unusedOnly}) {
    final extras = <String>[];
    for (final decl in src.parameters) {
      if (unusedOnly && (_paramNodes.containsKey(decl.name) || _usedSamplers.contains(decl.name))) continue;
      final type = decl.type.toLowerCase();
      if (type == 'float' || decl.isSampler || const {'float3', 'float4', 'vec3', 'vec4', 'color'}.contains(type)) {
        _paramNode(decl);
      } else {
        extras.add(decl.raw.render());
      }
    }
    if (extras.isNotEmpty) {
      final output = graph.node(MaterialNodes.outputNodeId)!;
      output.literals['extraParameters'] = extras;
    }
  }
}
