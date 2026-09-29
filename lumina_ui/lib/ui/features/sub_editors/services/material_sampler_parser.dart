/// Extracts the sampler parameter names a Filament `.mat` source declares.
///
/// Used by the mesh sub-editors to show one texture row per sampler the bound
/// material actually has. A material that declares no samplers yields an empty
/// list — the parser never falls back to a guessed PBR set, because a row the
/// material cannot consume would be a dead control.
class MaterialSamplerParser {
  static final RegExp _itemBlock = RegExp(r'\{([^{}]+)\}');
  static final RegExp _type = RegExp(r'type\s*:\s*([a-zA-Z0-9_]+)');
  static final RegExp _name = RegExp(r'name\s*:\s*([a-zA-Z0-9_]+)');
  static final RegExp _uniformSampler =
      RegExp(r'\bsampler2d\b\s+([a-zA-Z0-9_]+)', caseSensitive: false);

  /// Sampler names in declaration order, de-duplicated.
  static List<String> declaredSamplers(String matSource) {
    if (matSource.trim().isEmpty) return const [];

    // The `parameters : [ … ]` block lives in the material header, before the
    // fragment shader body — restrict to it so shader-local declarations do not
    // masquerade as material parameters.
    final fragmentAt = matSource.indexOf('fragment {');
    final header = fragmentAt >= 0 ? matSource.substring(0, fragmentAt) : matSource;

    final names = <String>[];
    for (final item in _itemBlock.allMatches(header)) {
      final body = item.group(1) ?? '';
      final type = _type.firstMatch(body)?.group(1)?.toLowerCase();
      final name = _name.firstMatch(body)?.group(1);
      if (type == null || name == null || name.isEmpty) continue;
      if (!type.contains('sampler')) continue;
      if (!names.contains(name)) names.add(name);
    }

    if (names.isEmpty) {
      // Materials written without a `parameters` block declare their samplers as
      // plain uniforms instead.
      for (final match in _uniformSampler.allMatches(header)) {
        final name = match.group(1);
        if (name == null || name.isEmpty) continue;
        if (!names.contains(name)) names.add(name);
      }
    }

    return names;
  }
}
