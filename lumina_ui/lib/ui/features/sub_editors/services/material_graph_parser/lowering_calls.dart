part of '../material_graph_parser.dart';

/// Lowers calls, constructors and custom expressions, and wires the outputs.
extension _LoweringCalls on _Lowering {
  _Val _call(_Call c) {
    final args = c.args;
    if (_vertex && _fragmentOnlyCalls.contains(c.callee)) {
      throw _Unsupported('${c.callee}() is not available in the vertex block');
    }
    switch (c.callee) {
      case 'getUserWorldPosition' || 'getWorldPosition' when args.isEmpty:
        return _worldPosition(
            c.callee == 'getUserWorldPosition' ? MaterialNodes.absoluteSpace : MaterialNodes.cameraRelativeSpace);
      case 'texture':
        if (args.length != 2 || args[0] is! _Id || !(args[0] as _Id).name.startsWith('materialParams_')) {
          throw _Unsupported('texture() is only read from a material sampler parameter');
        }
        final param = (args[0] as _Id).name.substring('materialParams_'.length);
        _usedSamplers.add(param);
        final node = _add(MaterialNodes.textureSample, {'parameter': param});
        final order = _declOrder.indexOf(param);
        if (order >= 0) node.literals['declOrder'] = order;
        _retitle(node);
        final uv = args[1];
        if (!(uv is _Call && uv.callee == 'getUV0' && uv.args.isEmpty)) {
          _input(node, 'uvs', _lower(uv), inline: false);
        }
        return _out(node, MaterialValueType.float4, 'rgba');
      case 'getUV0':
      case 'getUV1':
        if (args.isNotEmpty) throw _Unsupported('${c.callee} takes no arguments');
        return _texCoord(c.callee == 'getUV0' ? 0 : 1, 1.0, 1.0);
      case 'getColor':
        return _sharedNode(MaterialNodes.vertexColor, 'rgba', MaterialValueType.float4);
      case 'mix':
        _arity(c, 3);
        final a = _lower(args[0]), b = _lower(args[1]), t = _lower(args[2]);
        final node = _add(MaterialNodes.lerp);
        _input(node, 'a', a);
        _input(node, 'b', b);
        _input(node, 'alpha', t);
        return _out(node, _broadcastType(a, b));
      case 'clamp':
        _arity(c, 3);
        final x = _lower(args[0]);
        final node = _add(MaterialNodes.clamp);
        _input(node, 'in', x, inline: false);
        _input(node, 'min', _lower(args[1]));
        _input(node, 'max', _lower(args[2]));
        return _out(node, x.type);
      case 'pow':
        _arity(c, 2);
        final x = _lower(args[0]);
        final node = _add(MaterialNodes.power);
        _input(node, 'base', x, inline: false);
        _input(node, 'exp', _lower(args[1]));
        return _out(node, x.type);
      case 'dot':
        _arity(c, 2);
        final node = _add(MaterialNodes.dot);
        _input(node, 'a', _lower(args[0]), inline: false);
        _input(node, 'b', _lower(args[1]), inline: false);
        return _out(node, MaterialValueType.float1);
      case 'normalize':
        _arity(c, 1);
        final x = _lower(args[0]);
        final node = _add(MaterialNodes.normalize);
        _input(node, 'in', x, inline: false);
        return _out(node, x.type);
      case 'lumina_fresnel':
        _arity(c, 2);
        final node = _add(MaterialNodes.fresnel);
        _input(node, 'exponent', _lower(args[0]));
        _input(node, 'base_reflect_fraction', _lower(args[1]));
        return _out(node, MaterialValueType.float1);
      case 'float':
      case 'vec2':
      case 'vec3':
      case 'vec4':
        return _construct(c);
    }
    final helper = _helpers[c.callee];
    if (helper != null) {
      _calledHelpers.add(helper.name);
      if (args.length != helper.params.length) throw _Unsupported('${c.callee} is called with ${args.length} arguments');
      final node = _customNodeFor(helper);
      for (var k = 0; k < args.length; k++) {
        _input(node, helper.params[k], _lower(args[k]), inline: false);
      }
      final out = MaterialValueType.parse(helper.returnType);
      if (out == null) throw _Unsupported('${c.callee} returns ${helper.returnType}');
      return _out(node, out);
    }
    if (args.isEmpty) {
      final known = (_vertex ? _vertexKnownValues : _knownValues)['${c.callee}()'];
      if (known != null) return _customExpr('return ${c.callee}();', const [], known);
    }
    if (_componentWise1.contains(c.callee) && args.length == 1) {
      final x = _lower(args[0]);
      return _customCall(c.callee, [x], x.type);
    }
    if ((_componentWise2.contains(c.callee) && args.length == 2) || (c.callee == 'smoothstep' && args.length == 3)) {
      final vals = [for (final a in args) _lower(a)];
      var type = vals.first.type;
      for (final v in vals.skip(1)) {
        type = _broadcastType(_Val.lit(List.filled(type.width, 0)), v);
      }
      return _customCall(c.callee, vals, type);
    }
    if ((c.callee == 'length' && args.length == 1) || (c.callee == 'distance' && args.length == 2)) {
      return _customCall(c.callee, [for (final a in args) _lower(a)], MaterialValueType.float1);
    }
    if (c.callee == 'cross' && args.length == 2) {
      return _customCall(c.callee, [for (final a in args) _lower(a)], MaterialValueType.float3);
    }
    if (c.callee == 'reflect' && args.length == 2) {
      final vals = [for (final a in args) _lower(a)];
      return _customCall(c.callee, vals, vals.first.type);
    }
    throw _Unsupported('${c.callee}() has no material node');
  }

  void _arity(_Call c, int n) {
    if (c.args.length != n) throw _Unsupported('${c.callee}() takes $n arguments');
  }

  _Val _construct(_Call c) => _constructVals(c.callee, [for (final a in c.args) _lower(a)]);

  _Val _constructVals(String callee, List<_Val> vals) {
    final n = callee == 'float' ? 1 : int.parse(callee.substring(3));
    if (vals.isEmpty) throw _Unsupported('$callee() needs arguments');
    if (vals.length == 1) {
      final v = vals.single;
      if (v.type.width == n && v.broadcastTo == null) return v;
      if (v.type == MaterialValueType.float1) return n == 1 ? v : v.withBroadcast(n);
      if (v.type.width > n) {
        const letters = ['r', 'rg', 'rgb'];
        return _member(_ValExpr(v), letters[n - 1]);
      }
      throw _Unsupported('$callee() of a ${v.type.label}');
    }
    if (vals.every((v) => v.isLiteral && v.broadcastTo == null) && vals.fold<int>(0, (s, v) => s + v.type.width) == n) {
      return _Val.lit([for (final v in vals) ...v.literal!]);
    }
    // Mixed: group consecutive float literals into one Constant, append the rest.
    final parts = <_Val>[];
    final pending = <double>[];
    void flush() {
      if (pending.isEmpty) return;
      parts.add(_Val.lit(List.of(pending)));
      pending.clear();
    }

    for (final v in vals) {
      if (v.isLiteral && v.broadcastTo == null) {
        pending.addAll(v.literal!);
      } else {
        flush();
        parts.add(v);
      }
    }
    flush();
    if (parts.fold<int>(0, (s, v) => s + v.argWidth) != n) throw _Unsupported('$callee() arguments do not add up');
    var acc = parts.first;
    for (final part in parts.skip(1)) {
      acc = _append(acc, part);
    }
    return acc;
  }

  LuminaBlueprintNode _customNodeFor(_Helper h) {
    final node = _add(MaterialNodes.custom, {
      'description': h.description ?? 'Custom',
      'outputType': MaterialValueType.parse(h.returnType)?.label ?? h.returnType,
      'inputs': List<String>.of(h.params),
      'code': h.body,
    });
    _retitle(node);
    return node;
  }

  /// A GLSL built-in the catalog has no node for, as a Custom expression.
  _Val _customCall(String fn, List<_Val> args, MaterialValueType type) {
    final names = <String>[];
    final wired = <_Val>[];
    for (final v in args) {
      if (v.isLiteral && v.broadcastTo == null) {
        names.add(_literalGlsl(v.literal!));
      } else {
        names.add('In${wired.length}');
        wired.add(v);
      }
    }
    return _customExpr('return $fn(${names.join(', ')});', wired, type);
  }

  static String _literalGlsl(List<double> v) =>
      v.length == 1 ? MaterialNodes.formatNumber(v.single) : 'vec${v.length}(${v.map(MaterialNodes.formatNumber).join(', ')})';

  _Val _customExpr(String code, List<_Val> inputs, MaterialValueType type) {
    final node = _add(MaterialNodes.custom, {
      'description': 'Custom',
      'outputType': type.label,
      'inputs': [for (var k = 0; k < inputs.length; k++) 'In$k'],
      'code': code,
    });
    for (var k = 0; k < inputs.length; k++) {
      _input(node, 'In$k', inputs[k], inline: false);
    }
    return _out(node, type);
  }

  // -- Output -------------------------------------------------------------

  void _wireOutputs() {
    const pins = {
      'baseColor': MaterialNodes.baseColor,
      'opacity': MaterialNodes.opacity,
      'metallic': MaterialNodes.metallic,
      'roughness': MaterialNodes.roughness,
      'reflectance': MaterialNodes.specular,
      'ambientOcclusion': MaterialNodes.ambientOcclusion,
      'normal': MaterialNodes.normal,
      'emissive': MaterialNodes.emissive,
      'postLightingColor': MaterialNodes.postLightingColor,
      'postLightingMixFactor': MaterialNodes.postLightingMix,
    };
    for (final e in pins.entries) {
      final v = _fields[e.key];
      if (v == null) continue;
      final source = _materialize(v);
      _wire(source.nodeId!, source.pinId!, MaterialNodes.outputNodeId, e.value);
    }
  }
}
