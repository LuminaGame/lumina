part of '../material_editor_view_model.dart';

/// Reads the declared parameters out of the material source.
extension _MaterialParameterParsing on MaterialEditorViewModel {
  /// Re-reads the header's parameters, keeping each surviving parameter's
  /// panel value and texture binding.
  void _reparseParametersKeepingValues() {
    final previous = {for (final p in _parameters) p.name: p};
    _parseParameters();
    for (final p in _parameters) {
      final old = previous[p.name];
      if (old == null || old.type != p.type) continue;
      p.value = old.value;
      p.textureRef = old.textureRef;
      p.resolvedTexturePath = old.resolvedTexturePath;
    }
  }

  /// Parses declared parameters from the parameters block or material inputs in the source.
  void _parseParameters() {
    _parameters = [];
    final text = _currentCode;

    // 1. Parse parameter items in material header / parameters block
    final headerSection = text.contains('fragment {') 
        ? text.substring(0, text.indexOf('fragment {')) 
        : text;

    if (headerSection.contains('parameters') || headerSection.contains('type')) {
      final itemBlockRegex = RegExp(r'\{([^{}]+)\}');
      for (final itemMatch in itemBlockRegex.allMatches(headerSection)) {
        final itemText = itemMatch.group(1) ?? '';
        final typeMatch = RegExp(r'type\s*:\s*([a-zA-Z0-9_]+)').firstMatch(itemText);
        final nameMatch = RegExp(r'name\s*:\s*([a-zA-Z0-9_]+)').firstMatch(itemText);
        final defaultMatch = RegExp(r'default\s*:\s*(\[[^\]]+\]|[^,}]+)').firstMatch(itemText);

        if (typeMatch == null || nameMatch == null) continue;

        final typeStr = typeMatch.group(1)?.toLowerCase() ?? '';
        final name = nameMatch.group(1) ?? '';
        final defaultStr = defaultMatch?.group(1)?.trim();

        if (name.isEmpty) continue;

        MaterialParamType type = MaterialParamType.floatType;
        dynamic defaultVal;
        bool isSampler = false;
        double min = 0.0;
        double max = 1.0;

        if (typeStr == 'float') {
          type = MaterialParamType.floatType;
          defaultVal = double.tryParse(defaultStr ?? '') ?? 0.5;
          if (name.toLowerCase().contains('normal')) max = 5.0;
        } else if (typeStr == 'float4' || typeStr == 'float3' || typeStr == 'vec4' || typeStr == 'vec3' || typeStr == 'color') {
          type = MaterialParamType.colorType;
          defaultVal = _parseColorDefault(defaultStr);
        } else if (typeStr.contains('sampler')) {
          type = MaterialParamType.sampler2dType;
          isSampler = true;
        } else if (typeStr == 'bool') {
          type = MaterialParamType.boolType;
          defaultVal = defaultStr == 'true';
        }

        _parameters.add(MaterialParamModel(
          name: name,
          type: type,
          value: defaultVal,
          min: min,
          max: max,
          isSampler: isSampler,
        ));
      }
    }

    // 2. If no parameters array was defined, extract from uniforms and standard material inputs
    if (_parameters.isEmpty) {
      final declared = extractDeclaredParameters();
      for (final name in declared) {
        if (name.startsWith('material.') || name.startsWith('materialParams.')) continue;
        if (name.toLowerCase().contains('map') || name.toLowerCase().contains('tex') || name.toLowerCase().contains('sampler')) {
          _parameters.add(MaterialParamModel(
            name: name,
            type: MaterialParamType.sampler2dType,
            isSampler: true,
          ));
        } else if (name.toLowerCase().contains('color') || name.toLowerCase().contains('emissive')) {
          _parameters.add(MaterialParamModel(
            name: name,
            type: MaterialParamType.colorType,
            value: [1.0, 1.0, 1.0, 1.0],
          ));
        } else {
          _parameters.add(MaterialParamModel(
            name: name,
            type: MaterialParamType.floatType,
            value: 0.5,
            min: 0.0,
            max: name.toLowerCase().contains('normal') ? 5.0 : 1.0,
          ));
        }
      }
    }

    // 3. Fallback defaults, only when the material never said what it declares.
    // A header that explicitly reads `parameters : []` is an answer, not a gap —
    // fabricating a PBR set there makes the inspector lie and hands the compiler
    // uniforms the shader does not use.
    final declaresParameterBlock = RegExp(r'parameters\s*:\s*\[').hasMatch(text);
    if (_parameters.isEmpty && !declaresParameterBlock) {
      _parameters = [
        MaterialParamModel(name: 'roughness', type: MaterialParamType.floatType, value: 0.3, min: 0.0, max: 1.0),
        MaterialParamModel(name: 'metallic', type: MaterialParamType.floatType, value: 0.8, min: 0.0, max: 1.0),
        MaterialParamModel(name: 'normalStrength', type: MaterialParamType.floatType, value: 1.0, min: 0.0, max: 5.0),
        MaterialParamModel(name: 'baseColor', type: MaterialParamType.colorType, value: [0.0, 0.9, 0.46, 1.0]),
        MaterialParamModel(name: 'albedoMap', type: MaterialParamType.sampler2dType, isSampler: true),
      ];
    }

    // 4. Restore saved defaults from asset metadata
    if (_asset?.metadata['parameter_defaults'] != null) {
      try {
        dynamic parsed = _asset!.metadata['parameter_defaults'];
        if (parsed is String) {
          parsed = jsonDecode(parsed);
        }
        if (parsed is Map) {
          for (final entry in parsed.entries) {
            final param = _parameters.where((p) => p.name == entry.key).firstOrNull;
            if (param != null) {
              param.value = entry.value;
            }
          }
        }
      } catch (_) {}
    }

    // 5. Restore saved texture references
    if (_asset?.references != null) {
      for (final ref in _asset!.references) {
        if (ref.slotName.isNotEmpty) {
          final param = _parameters.where((p) => p.name == ref.slotName).firstOrNull;
          if (param != null) {
            param.textureRef = ref;
            param.resolvedTexturePath = resolveProjectPath(ref.assetPath);
          }
        }
      }
    }
  }

  /// The declared `default : [r, g, b(, a)]` of a colour/vector parameter as
  /// the four floats of the `float4` uniform it compiles to ([uniformTypeFor]):
  /// a missing alpha is opaque. White when nothing (or nothing numeric) is
  /// declared.
  static List<double> _parseColorDefault(String? declared) {
    final numbers = RegExp(r'-?\d*\.?\d+(?:[eE][-+]?\d+)?')
        .allMatches(declared ?? '')
        .map((m) => double.tryParse(m.group(0)!))
        .whereType<double>()
        .take(4)
        .toList();
    if (numbers.isEmpty) return [1.0, 1.0, 1.0, 1.0];
    while (numbers.length < 4) {
      numbers.add(1.0);
    }
    return numbers;
  }

  /// The project root this material lives in: the nearest ancestor owning a
}
