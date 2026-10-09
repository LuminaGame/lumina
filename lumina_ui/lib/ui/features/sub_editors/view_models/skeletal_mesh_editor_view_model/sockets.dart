part of '../skeletal_mesh_editor_view_model.dart';

/// Sockets: their preview meshes, authoring and bone retargeting options.
mixin _SkeletalMeshSockets on _SkeletalMeshEditorViewModelState {
  /// A socket's stored preview path (project-relative, or absolute) as a file.
  String? resolvePreviewAssetPath(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    final normalised = stored.replaceAll(r'\', '/');
    final isAbsolute = normalised.startsWith('/') || RegExp(r'^[A-Za-z]:/').hasMatch(normalised);
    if (isAbsolute) return stored;
    final root = projectRoot;
    return root == null ? null : '$root/$normalised';
  }

  /// The meshes previewed on sockets, each at `entityWorld × G_bone × offset`.
  /// A socket whose mesh is still being read, or whose bone or file is missing, has none.
  List<SkeletalSocketAttachment> get socketAttachments {
    final mesh = _glbMesh;
    if (mesh == null) return const [];
    final result = <SkeletalSocketAttachment>[];
    for (final socket in _sockets) {
      final path = resolvePreviewAssetPath(socket.previewAssetPath);
      if (path == null) continue;
      final preview = _previewMeshes[path];
      if (preview == null) {
        _loadPreviewMesh(path);
        continue;
      }
      final world = SkeletalSocketMath.worldTransform(mesh, socket);
      if (world == null) continue;
      result.add(SkeletalSocketAttachment(
        socketName: socket.name,
        boneName: socket.parentBone,
        assetPath: path,
        mesh: preview,
        localOffset: SkeletalSocketMath.localOffset(socket),
        restWorld: world,
      ));
    }
    return result;
  }

  /// Reads a preview mesh once; the attachment appears when it is parsed.
  void _loadPreviewMesh(String path) {
    if (_previewMeshes.containsKey(path)) return;
    _previewMeshes[path] = null;
    AssetRepository.loadMeshFromDisk(path).then((mesh) {
      if (_disposed || mesh == null) return;
      _previewMeshes[path] = mesh;
      notifyListeners();
    });
  }

  /// Completes once every socket's preview mesh has been read (tests, MCP).
  Future<void> loadSocketPreviews() async {
    for (final socket in _sockets) {
      final path = resolvePreviewAssetPath(socket.previewAssetPath);
      if (path == null || _previewMeshes[path] != null) continue;
      final mesh = await AssetRepository.loadMeshFromDisk(path);
      if (_disposed) return;
      _previewMeshes[path] = mesh;
    }
    notifyListeners();
  }

  String _generateUniqueSocketName(String baseName) {
    if (!_sockets.any((s) => s.name == baseName)) {
      return baseName;
    }
    int counter = 1;
    while (_sockets.any((s) => s.name == '${baseName}_$counter')) {
      counter++;
    }
    return '${baseName}_$counter';
  }

  bool addSocket({String? parentBone, String? name}) {
    final parent = parentBone ?? _selectedBone?.name ?? (_allBones.isNotEmpty ? _allBones.first.name : 'root');
    final baseName = name ?? '${parent}_socket';
    final uniqueName = _generateUniqueSocketName(baseName);

    final socket = SkeletalMeshSocket(
      name: uniqueName,
      parentBone: parent,
      relativeLocation: [0.0, 0.0, 0.0],
      relativeRotation: [0.0, 0.0, 0.0],
      relativeScale: [1.0, 1.0, 1.0],
    );

    _sockets.add(socket);
    _selectedSocket = socket;
    _isDirty = true;
    notifyListeners();
    return true;
  }

  bool renameSocket(String oldName, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return false;
    if (_sockets.any((s) => s.name == trimmed && s.name != oldName)) {
      return false; // Name must be unique
    }

    final index = _sockets.indexWhere((s) => s.name == oldName);
    if (index >= 0) {
      _sockets[index].name = trimmed;
      if (_selectedSocket?.name == oldName) {
        _selectedSocket = _sockets[index];
      }
      _isDirty = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool reparentSocket(String socketName, String newParentBone) {
    final socket = _sockets.where((s) => s.name == socketName).firstOrNull;
    if (socket != null) {
      socket.parentBone = newParentBone;
      _isDirty = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void setSocketTransform(
    String socketName, {
    List<double>? location,
    List<double>? rotation,
    List<double>? scale,
  }) {
    final socket = _sockets.where((s) => s.name == socketName).firstOrNull;
    if (socket != null) {
      if (location != null && location.length == 3) {
        socket.relativeLocation = List.from(location);
      }
      if (rotation != null && (rotation.length == 3 || rotation.length == 4)) {
        socket.relativeRotation = List.from(rotation);
      }
      if (scale != null && scale.length == 3) {
        socket.relativeScale = List.from(scale);
      }
      _isDirty = true;
      notifyListeners();
    }
  }

  void setSocketPreviewAsset(String socketName, String? assetPath) {
    final socket = _sockets.where((s) => s.name == socketName).firstOrNull;
    if (socket != null) {
      socket.previewAssetPath = assetPath;
      _isDirty = true;
      notifyListeners();
    }
  }

  bool removeSocket(String socketName) {
    final index = _sockets.indexWhere((s) => s.name == socketName);
    if (index >= 0) {
      _sockets.removeAt(index);
      if (_selectedSocket?.name == socketName) {
        _selectedSocket = null;
      }
      _isDirty = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void setBoneRetargeting(String boneName, String option) {
    _boneRetargeting[boneName] = option;
    _isDirty = true;
    notifyListeners();
  }

  List<SkeletalMeshSocket> getSocketsForBone(String boneName) {
    return _sockets.where((s) => s.parentBone == boneName).toList();
  }
}
