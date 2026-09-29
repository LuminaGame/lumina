/// One geometry section's material assignment in a mesh sub-editor.
///
/// Slots are keyed by section index (`element_0`, `element_1`, …), never by the
/// source GLB's material *name* — two sections may legitimately share a name.
/// Shared by the Static Mesh and Skeletal Mesh editors.
class MaterialSlotBinding {
  final int index;
  final String slotName;
  String? assignedMaterialPath;
  String? assignedMaterialId;
  bool isHighlighted;
  bool isIsolated;

  /// Per-sampler texture overrides, keyed by the parameter name the bound
  /// material declares (e.g. `baseColorMap`). Empty when the slot uses the
  /// material's own defaults.
  final Map<String, MaterialTextureBinding> textureBindings;

  /// The material name the source mesh itself declares for this section, when it
  /// has one. An unbound slot is not "nothing applied" — the mesh ships its own
  /// material, and the editor has to say which one.
  final String? sourceMaterialName;

  /// Sampler parameter names the currently bound material declares. Empty for an
  /// unbound slot, and refreshed when the binding changes — never a guessed
  /// PBR list.
  List<String> samplerNames;

  MaterialSlotBinding({
    required this.index,
    required this.slotName,
    this.assignedMaterialPath,
    this.assignedMaterialId,
    this.isHighlighted = false,
    this.isIsolated = false,
    this.sourceMaterialName,
    Map<String, MaterialTextureBinding>? textureBindings,
    List<String>? samplerNames,
  })  : textureBindings = textureBindings ?? <String, MaterialTextureBinding>{},
        samplerNames = samplerNames ?? const [];

  bool get isBound => assignedMaterialPath != null;

  /// What this section actually renders with right now: the bound asset's file
  /// name when a material was picked, otherwise the mesh's own material name.
  String get effectiveMaterialLabel {
    final path = assignedMaterialPath;
    if (path != null) return path.split(RegExp(r'[/\\]')).last;
    final source = sourceMaterialName;
    if (source != null && source.isNotEmpty) return source;
    return '— none —';
  }
}

/// A texture `.lmas` bound to one sampler parameter of a slot's material.
class MaterialTextureBinding {
  final String assetId;
  final String assetPath;

  const MaterialTextureBinding({required this.assetId, required this.assetPath});

  Map<String, dynamic> toJson() => {'assetId': assetId, 'assetPath': assetPath};

  factory MaterialTextureBinding.fromJson(Map<String, dynamic> json) => MaterialTextureBinding(
        assetId: json['assetId'] as String? ?? '',
        assetPath: json['assetPath'] as String? ?? '',
      );
}
