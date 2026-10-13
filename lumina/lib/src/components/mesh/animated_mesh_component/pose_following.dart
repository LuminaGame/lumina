part of '../animated_mesh_component.dart';

/// Pose following: a skinned mesh taking its leader's joint transforms by
/// bone name, updated by the leader right after the leader's own pose.
extension _PoseFollowing on LuminaAnimatedMeshComponent {
  void _setPoseLeader(LuminaAnimatedMeshComponent? leader) {
    if (identical(leader, _poseLeader)) return;
    for (var l = leader; l != null; l = l._poseLeader) {
      if (identical(l, this)) throw StateError('a pose leader cycle: $meshAssetPath would follow itself');
    }
    _poseLeader?._followers.remove(this);
    _poseLeader = leader;
    leader?._followers.add(this);
    _disposePairs();
  }

  Future<void> _poseLinkReady() async {
    final leader = _poseLeader;
    await loaded;
    _jointsByName();
    await _nodeNames;
    if (leader == null) return;
    await leader.loaded;
    leader._jointsByName();
    await leader._nodeNames;
  }

  /// Whether the leader drives this component now (registered and loaded;
  /// otherwise this component animates on its own).
  bool get _follows {
    final leader = _poseLeader;
    return leader != null && leader.isRegistered && leader._animator != null;
  }

  void _disposePairs() {
    _pairs?.dispose();
    _pairs = null;
    _pairsLeaderLoad = -1;
  }

  void _driveFollowers(double deltaTime) {
    if (_followers.isEmpty) return;
    for (var i = 0; i < _followers.length; i++) {
      final follower = _followers[i];
      if (follower.isRegistered) follower._followLeader(deltaTime);
    }
  }

  /// This component's joints (and their ancestors) by node name, or null
  /// while the node names are still being read from the mesh file.
  Map<String, int>? _jointsByName() {
    final cached = _namedJoints;
    if (cached != null) return cached;
    final asset = _asset;
    if (asset == null) return null;
    final names = _loadedNodeNames;
    if (names == null) {
      _nodeNames ??= _readNodeNames(meshAssetPath, assetProvider).then((n) => _loadedNodeNames = n);
      return null;
    }
    final out = <String, int>{};
    for (final name in names) {
      if (name.isEmpty || out.containsKey(name)) continue;
      for (final e in asset.getEntitiesByName(name)) {
        if (_jointSet.contains(e)) {
          out[name] = e;
          break;
        }
      }
    }
    return _namedJoints = out;
  }

  void _followLeader(double deltaTime) {
    final animator = _animator, leader = _poseLeader;
    final engine = owner?.world?.nativeEngine;
    if (animator == null || leader == null || leader._asset == null || engine == null) return;
    final tm = FilamentTransformManager(engine);
    var pairs = _pairs;
    if (pairs == null || _pairsLeaderLoad != leader._loadVersion) {
      _disposePairs();
      final mine = _jointsByName(), theirs = leader._jointsByName();
      if (mine == null || theirs == null) {
        // Names still loading: animate on its own this frame.
        _apply(deltaTime);
        return;
      }
      pairs = _pairs = _buildPairs(tm, leader, mine, theirs);
      _pairsLeaderLoad = leader._loadVersion;
    }
    // Its own pose first, for the bones the leader does not pose.
    if (_poseDriver == null || !_applyPoseDriver(tm, deltaTime)) _applyClip(animator, deltaTime);
    tm.copyPoses(pairs);
    _applyJointOverrides(tm);
    _applyPoseModifiers(tm, deltaTime);
    animator.updateBoneMatrices();
    _driveFollowers(deltaTime);
  }

  FilamentPosePairs _buildPairs(
    FilamentTransformManager tm,
    LuminaAnimatedMeshComponent leader,
    Map<String, int> mine,
    Map<String, int> theirs,
  ) {
    final nameOf = {for (final e in mine.entries) e.value: e.key};
    final leaderNameOf = {for (final e in theirs.entries) e.value: e.key};
    final depthOf = <int, int>{};
    int depth(int e) => depthOf.putIfAbsent(e, () {
      final p = tm.getParent(e);
      return p == 0 ? 0 : depth(p) + 1;
    });
    final entries = mine.entries.toList()..sort((a, b) => depth(a.value).compareTo(depth(b.value)));
    final src = <int>[], dst = <int>[], modes = <int>[];
    final followed = <String>[], unmatched = <String>[];
    for (final entry in entries) {
      final source = theirs[entry.key];
      if (source == null) {
        unmatched.add(entry.key);
        continue;
      }
      final myParent = tm.getParent(entry.value), theirParent = tm.getParent(source);
      final myParentName = nameOf[myParent];
      final theirParentName = leaderNameOf[theirParent];
      src.add(source);
      dst.add(entry.value);
      // A bone under the same-named parent copies its local transform; one
      // under another parent takes the leader bone's world transform.
      modes.add(myParentName == theirParentName ? 0 : 1);
      followed.add(entry.key);
    }
    _followedBones = List.unmodifiable(followed);
    _unmatchedBones = List.unmodifiable(unmatched);
    return FilamentPosePairs(src, dst, modes);
  }
}

/// The node names of the glTF file a mesh path names (cached per path and
/// provider; an unreadable file gives none).
final Map<(String, Object?), Future<List<String>>> _nodeNameCache = {};

Future<List<String>> _readNodeNames(String path, LuminaAssetProvider? provider) {
  return _nodeNameCache.putIfAbsent((path, provider), () async {
    try {
      final bytes = await LuminaMeshAssetCache.meshBytes(LuminaAssets.resolve(provider), path);
      return luminaGlbNodeNames(bytes);
    } catch (e) {
      developer.log('pose follower: cannot read the node names of $path: $e', name: 'LuminaAnimatedMeshComponent', level: 900);
      return const <String>[];
    }
  });
}

/// The `nodes[].name` of a GLB (empty names for unnamed nodes).
List<String> luminaGlbNodeNames(Uint8List glb) {
  final data = ByteData.sublistView(glb);
  if (glb.length < 20 || data.getUint32(0, Endian.little) != 0x46546C67) return const [];
  final length = data.getUint32(12, Endian.little);
  final json = jsonDecode(utf8.decode(Uint8List.sublistView(glb, 20, 20 + length))) as Map<String, dynamic>;
  final nodes = json['nodes'] as List<dynamic>? ?? const [];
  return [for (final n in nodes) (n as Map<String, dynamic>)['name'] as String? ?? ''];
}
