part of '../character_slots.dart';

/// The latest masked bodies, by the content of the body and its garments.
final Map<String, Uint8List> _maskCache = {};

/// Body masks: the body triangles under the garments of the slots that
/// mask the body are left out of its draw.
extension LuminaCharacterSlotMasks on LuminaCharacterSlots {
  /// Recomputes [bodySlot]'s mask from every non-empty slot that masks the
  /// body and follows it, on a worker isolate, and replaces the body's
  /// component with one drawing the masked copy (or the original mesh when
  /// no garment masks it). Completes when the new body has loaded; false
  /// when [bodySlot] is unknown or empty.
  Future<bool> refreshBodyMask(String bodySlot) async {
    final body = slot(bodySlot);
    if (body == null || body.isEmpty) return false;
    final garments = [
      for (final name in names)
        if (slot(name) case final s? when s.masksBody && !s.isEmpty && s.leaderSlot == bodySlot) s,
    ];
    final version = ++_maskVersion;
    final component = body.component;
    if (component is! LuminaAnimatedMeshComponent) return false;
    final bodyPath = resolve(body.mesh);
    if (garments.isEmpty) {
      if (component.meshAssetPath != bodyPath) await component.setMeshAsset(bodyPath, assetProvider: assetProvider);
      return true;
    }
    final read = LuminaAssets.resolve(assetProvider);
    final bodyBytes = await LuminaMeshAssetCache.meshBytes(read, bodyPath);
    // A fitted garment is served by its own component's provider.
    final garmentBytes = [
      for (final g in garments) await LuminaMeshAssetCache.meshBytes(LuminaAssets.resolve(_garmentProvider(g) ?? assetProvider), _garmentPath(g)),
    ];
    // The same body under the same garments (a Blueprint built again, a
    // preview rebuilt after an edit) reuses its mask.
    final cacheKey = [
      LuminaMeshAssetCache.contentDigest(bodyBytes),
      for (final b in garmentBytes) LuminaMeshAssetCache.contentDigest(b),
    ].join('|');
    final Uint8List masked = _maskCache[cacheKey] ?? await Isolate.run<Uint8List>(() {
      LuminaSkinnedMeshData parse(Uint8List b) {
        try {
          return LuminaSkinnedMeshData.fromGlb(b, draco: LuminaGlbLoader.decoders.draco);
        } on UnsupportedError {
          return LuminaSkinnedMeshData.fromGlb(b);
        }
      }

      final bodyData = LuminaSkinnedMeshData.fromGlb(bodyBytes);
      final covered = LuminaBodyMask.compute(bodyData, [for (final b in garmentBytes) parse(b)]);
      return LuminaBodyMask.applyDegenerate(bodyData, covered);
    }, debugName: 'body mask');
    _maskCache.remove(cacheKey);
    _maskCache[cacheKey] = masked;
    while (_maskCache.length > 8) {
      _maskCache.remove(_maskCache.keys.first);
    }
    // A newer mask (another garment changed meanwhile) wins.
    if (version != _maskVersion) return true;
    final key = '$bodyPath#masked-${LuminaMeshAssetCache.contentDigest(masked)}';
    try {
      await component.setMeshAsset(key, assetProvider: providerWith(key, masked));
    } catch (e) {
      developer.log('slot $bodySlot: the masked body did not load: $e', name: 'LuminaCharacterSlots', level: 900);
    }
    return true;
  }

  LuminaAssetProvider? _garmentProvider(LuminaCharacterSlot s) {
    final c = s.component;
    if (c is LuminaSkinnedClothComponent) return c.assetProvider;
    if (c is LuminaAnimatedMeshComponent) return c.assetProvider;
    return null;
  }

  String _garmentPath(LuminaCharacterSlot s) {
    final c = s.component;
    if (c is LuminaSkinnedClothComponent && c.meshAsset != null) return c.meshAsset!;
    if (c is LuminaAnimatedMeshComponent) return c.meshAssetPath;
    return resolve(s.mesh);
  }
}
