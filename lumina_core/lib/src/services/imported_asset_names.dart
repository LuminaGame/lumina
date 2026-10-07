/// The names an import gives the materials and textures it extracts from a
/// mesh file named [baseName] (prefixes: `M_`, `T_`).
abstract final class ImportedAssetNames {
  /// `M_Wood` stays, `MI_Wood` → `M_Wood`, a name holding the file's name
  /// gets `M_`, anything else becomes `M_<file>_<name>`.
  static String material(String raw, String baseName) {
    if (raw.startsWith('M_') || raw.startsWith('m_')) return raw;
    if (raw.startsWith('MI_')) return 'M_${raw.substring(3)}';
    if (raw.toLowerCase().contains(baseName.toLowerCase())) return 'M_$raw';
    return 'M_${baseName}_$raw';
  }

  /// `T_Wood_N` stays, `MI_…`/`M_…` swap the prefix for `T_`, a name holding
  /// the file's name gets `T_`, anything else becomes `T_<file>_<name>`.
  static String texture(String raw, String baseName) {
    if (raw.startsWith('T_') || raw.startsWith('t_')) return raw;
    if (raw.startsWith('MI_')) return 'T_${raw.substring(3)}';
    if (raw.startsWith('M_')) return 'T_${raw.substring(2)}';
    if (raw.toLowerCase().contains(baseName.toLowerCase())) return 'T_$raw';
    return 'T_${baseName}_$raw';
  }
}
