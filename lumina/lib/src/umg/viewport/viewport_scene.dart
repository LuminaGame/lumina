import 'dart:convert';

/// The kinds of node a Viewport's preview scene holds.
abstract final class LuminaViewportNodeKind {
  static const String staticMesh = 'staticMesh';
  static const String skeletalMesh = 'skeletalMesh';
  static const String light = 'light';
  static const String marker = 'marker';

  static const List<String> values = [staticMesh, skeletalMesh, light, marker];
}

/// The camera presets of a Viewport.
abstract final class LuminaViewportCameraPreset {
  static const String perspective = 'perspective';
  static const String front = 'front';
  static const String back = 'back';
  static const String left = 'left';
  static const String right = 'right';
  static const String top = 'top';

  static const List<String> values = [perspective, front, back, left, right, top];

  /// The orbit (yaw, pitch) in degrees each preset looks from: yaw 0 looks
  /// at the front of a model facing glTF's forward (authoring −Y), pitch is
  /// positive looking down.
  static (double, double) angles(String preset) => switch (preset) {
        front => (0.0, 0.0),
        back => (180.0, 0.0),
        left => (90.0, 0.0),
        right => (-90.0, 0.0),
        top => (0.0, 89.0),
        _ => (30.0, 15.0),
      };
}

/// The background modes of a Viewport's environment.
abstract final class LuminaViewportEnvironmentMode {
  static const String sky = 'sky';
  static const String color = 'color';
  static const String transparent = 'transparent';

  static const List<String> values = [sky, color, transparent];
}

/// How a Viewport shades its meshes.
abstract final class LuminaViewportViewMode {
  /// The lit scene: the shadowed key light, the description's lights, IBL.
  static const String lit = 'lit';

  /// Base and vertex colours under the IBL alone: no direct lights, no
  /// shadows.
  static const String unlit = 'unlit';

  /// Triangle edges instead of the solid surface.
  static const String wireframe = 'wireframe';

  static const List<String> values = [lit, unlit, wireframe];
}

/// The light types a Viewport adds.
abstract final class LuminaViewportLightType {
  static const String directional = 'directional';
  static const String point = 'point';
  static const String spot = 'spot';

  static const List<String> values = [directional, point, spot];
}

/// A Viewport's preview scene: the JSON-plain description a Viewport
/// element keeps at `elements[<name>].scene`.
///
/// Blueprint calls only edit this description; the Viewport widget diffs it
/// against what it shows ([LuminaViewportSceneDiff]) and applies the
/// difference, so the VM, generated code and a plugin process that writes the
/// same map drive the widget identically. Transforms are authoring space
/// (Z up, centimetres, `{location, rotation, scale}` as the Blueprint
/// Transform pin carries them); only the runtime converts them.
///
/// The object wraps [json] and edits it in place; every value it writes is
/// a JSON value (maps, lists, strings, numbers, booleans, null).
class LuminaViewportScene {
  LuminaViewportScene([Map<String, Object?>? json]) : json = json ?? <String, Object?>{} {
    _normalise();
  }

  /// The scene stored on Viewport element state [element], created empty
  /// when the element has none yet.
  factory LuminaViewportScene.of(Map<String, Object?> element) {
    final stored = element[sceneKey];
    if (stored is Map<String, Object?>) return LuminaViewportScene(stored);
    final scene = LuminaViewportScene(stored is Map ? _plain(stored) as Map<String, Object?> : null);
    element[sceneKey] = scene.json;
    return scene;
  }

  /// [encode]'s inverse.
  factory LuminaViewportScene.decode(String text) => LuminaViewportScene(_plain(jsonDecode(text)) as Map<String, Object?>);

  /// The element state key the description lives under.
  static const String sceneKey = 'scene';

  /// The description, edited in place.
  final Map<String, Object?> json;

  /// The canonical text of the description (its keys in insertion order,
  /// which [decode] keeps), so a round trip is byte-identical.
  String encode() => jsonEncode(json);

  /// A deep copy, sharing nothing with this description.
  LuminaViewportScene copy() => LuminaViewportScene(_plain(json) as Map<String, Object?>);

  void _normalise() {
    json.putIfAbsent('nodes', () => <Object?>[]);
    json.putIfAbsent('environment', () => <String, Object?>{'mode': LuminaViewportEnvironmentMode.sky, 'ibl': '', 'intensity': 1.0});
    json.putIfAbsent('grid', () => true);
    json.putIfAbsent('camera', defaultCamera);
    json.putIfAbsent('skeletonOverlays', () => <Object?>[]);
    json.putIfAbsent('gizmo', () => null);
    json.putIfAbsent('markers', () => <Object?>[]);
    json.putIfAbsent('interaction', defaultInteraction);
    json.putIfAbsent('nextId', () => 1);
  }

  /// The camera a new description starts with: the perspective preset
  /// framing what the scene holds ([autoFrame]).
  static Map<String, Object?> defaultCamera() {
    final (yaw, pitch) = LuminaViewportCameraPreset.angles(LuminaViewportCameraPreset.perspective);
    return <String, Object?>{
      'preset': LuminaViewportCameraPreset.perspective,
      'orbitTarget': <Object?>[0.0, 0.0, 90.0],
      'yaw': yaw,
      'pitch': pitch,
      'distance': 400.0,
      'fov': 45.0,
      'orthographic': false,
      'frame': null,
      'frameSerial': 0,
      'autoFrame': true,
    };
  }

  static Map<String, Object?> defaultInteraction() =>
      <String, Object?>{'orbit': true, 'pan': true, 'zoom': true, 'pick': true, 'autoRotate': 0.0};

  // --- Nodes -----------------------------------------------------------------

  /// Every node, in the order they were added.
  List<Map<String, Object?>> get nodes => [for (final n in _list('nodes')) if (n is Map<String, Object?>) n];

  /// Node [id], or null.
  Map<String, Object?>? node(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final n in nodes) {
      if (n['id'] == id) return n;
    }
    return null;
  }

  /// The id the next added node or marker takes (`<prefix>_<n>`), counted in
  /// the description so the VM and generated code number nodes alike.
  String _nextId(String prefix) {
    final n = json['nextId'] is int ? json['nextId'] as int : 1;
    json['nextId'] = n + 1;
    return '${prefix}_$n';
  }

  /// Adds a node of [kind] and returns its id.
  String addNode(String kind, {String asset = '', Object? transform, Map<String, Object?>? light}) {
    final id = _nextId(switch (kind) {
      LuminaViewportNodeKind.staticMesh => 'mesh',
      LuminaViewportNodeKind.skeletalMesh => 'skeletal',
      LuminaViewportNodeKind.light => 'light',
      _ => 'node',
    });
    _list('nodes').add(<String, Object?>{
      'id': id,
      'kind': kind,
      'asset': asset,
      'transform': plainTransform(transform),
      'visible': true,
      'pickable': kind != LuminaViewportNodeKind.light,
      'parent': null,
      'socket': null,
      'materialParams': <String, Object?>{},
      'morphs': <String, Object?>{},
      'animation': null,
      'light': ?light,
    });
    return id;
  }

  /// Removes node [id], the nodes attached to it, and the overlays and gizmo
  /// that point at them; false when there is no such node.
  bool removeNode(String id) {
    if (node(id) == null) return false;
    final gone = <String>{id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final n in nodes) {
        if (gone.contains(n['parent']) && gone.add('${n['id']}')) grew = true;
      }
    }
    _list('nodes').removeWhere((n) => n is Map && gone.contains(n['id']));
    _list('skeletonOverlays').removeWhere((o) => o is Map && gone.contains(o['node']));
    final gizmo = json['gizmo'];
    if (gizmo is Map && gone.contains(gizmo['node'])) json['gizmo'] = null;
    final camera = this.camera;
    if (gone.contains(camera['frame'])) camera['frame'] = null;
    return true;
  }

  /// Removes every node, overlay, marker and the gizmo; the camera,
  /// environment and interaction stay.
  void clear() {
    json['nodes'] = <Object?>[];
    json['skeletonOverlays'] = <Object?>[];
    json['markers'] = <Object?>[];
    json['gizmo'] = null;
    camera['frame'] = null;
  }

  bool setNodeTransform(String id, Object? transform) => _edit(id, (n) => n['transform'] = plainTransform(transform));

  bool setNodeVisible(String id, bool visible) => _edit(id, (n) => n['visible'] = visible);

  /// Swaps the mesh node [id] shows (a part swap); its transform, socket,
  /// material parameters and animation stay.
  bool setNodeAsset(String id, String asset) => _edit(id, (n) => n['asset'] = asset);

  /// Attaches node [id] to node [parent] at [socket] (a socket or bone name
  /// of a skeletal mesh; '' for its origin). An empty [parent] detaches.
  bool attachToSocket(String id, String parent, String socket) {
    if (parent == id) return false;
    return _edit(id, (n) {
      n['parent'] = parent.isEmpty ? null : parent;
      n['socket'] = parent.isEmpty || socket.isEmpty ? null : socket;
    });
  }

  /// Sets material parameter [parameter] of material slot [slot] (an index
  /// or a slot name, as text) on node [id]: a colour `[r, g, b, a]`, a
  /// scalar or a texture asset path.
  bool setMaterialParameter(String id, String slot, String parameter, Object? value) => _edit(id, (n) {
        final all = _map(n, 'materialParams');
        final params = all[slot] is Map<String, Object?> ? all[slot] as Map<String, Object?> : <String, Object?>{};
        params[parameter] = _plain(value);
        all[slot] = params;
      });

  bool setMorphTargetWeight(String id, String morph, double weight) => _edit(id, (n) => _map(n, 'morphs')[morph] = weight);

  /// Plays animation asset [asset] (project path) on node [id].
  bool playAnimation(String id, String asset, {bool loop = true, double rate = 1.0}) => _edit(id, (n) {
        n['animation'] = <String, Object?>{'asset': asset, 'loop': loop, 'rate': rate, 'time': 0.0, 'playing': true, 'serial': _serial(n)};
      });

  /// Plays an animation or motion file at [path] on node [id] (editor only:
  /// a file a plugin process wrote).
  bool playAnimationFile(String id, String path, {bool loop = true, double rate = 1.0}) => _edit(id, (n) {
        n['animation'] = <String, Object?>{'file': path, 'loop': loop, 'rate': rate, 'time': 0.0, 'playing': true, 'serial': _serial(n)};
      });

  /// Stops node [id]'s animation where it is.
  bool stopAnimation(String id) => _edit(id, (n) {
        final a = n['animation'];
        if (a is Map) a['playing'] = false;
      });

  /// Shows node [id]'s animation at [seconds] without playing it.
  bool setAnimationTime(String id, double seconds) => _edit(id, (n) {
        final a = n['animation'];
        if (a is! Map) return;
        a['time'] = seconds;
        a['playing'] = false;
      });

  static int _serial(Map<String, Object?> node) {
    final a = node['animation'];
    final s = a is Map && a['serial'] is int ? a['serial'] as int : 0;
    return s + 1;
  }

  /// Adds a light node.
  String addLight(String type, List<double> color, double intensity, Object? transform) => addNode(
        LuminaViewportNodeKind.light,
        transform: transform,
        light: <String, Object?>{'type': type, 'color': color.map((c) => c.toDouble()).toList(), 'intensity': intensity},
      );

  bool _edit(String id, void Function(Map<String, Object?> node) change) {
    final n = node(id);
    if (n == null) return false;
    change(n);
    return true;
  }

  // --- Environment, grid, interaction ----------------------------------------

  Map<String, Object?> get environment => _map(json, 'environment');

  void setEnvironment(String mode, {String ibl = '', double intensity = 1.0}) {
    json['environment'] = <String, Object?>{
      'mode': LuminaViewportEnvironmentMode.values.contains(mode) ? mode : LuminaViewportEnvironmentMode.sky,
      'ibl': ibl,
      'intensity': intensity,
    };
  }

  /// The shading of the meshes ([LuminaViewportViewMode]); unknown values
  /// read as lit.
  String get viewMode {
    final m = json['viewMode'];
    return LuminaViewportViewMode.values.contains(m) ? m! as String : LuminaViewportViewMode.lit;
  }

  set viewMode(String mode) =>
      json['viewMode'] = LuminaViewportViewMode.values.contains(mode) ? mode : LuminaViewportViewMode.lit;

  bool get gridVisible => json['grid'] != false;
  set gridVisible(bool visible) => json['grid'] = visible;

  Map<String, Object?> get interaction => _map(json, 'interaction');

  void setInteraction({bool orbit = true, bool pan = true, bool zoom = true, bool pick = true, double autoRotate = 0.0}) {
    json['interaction'] = <String, Object?>{'orbit': orbit, 'pan': pan, 'zoom': zoom, 'pick': pick, 'autoRotate': autoRotate};
  }

  /// Degrees per second the camera turns on its own; 0 when it does not.
  double get autoRotate => _num(interaction['autoRotate'], 0.0);

  // --- Camera ----------------------------------------------------------------

  Map<String, Object?> get camera => _map(json, 'camera');

  double get yaw => _num(camera['yaw'], 0.0);
  double get pitch => _num(camera['pitch'], 0.0);
  double get distance => _num(camera['distance'], 400.0);

  /// Applies camera [preset]; [fit] frames every node from it.
  void setCameraPreset(String preset, {bool fit = true}) {
    final p = LuminaViewportCameraPreset.values.contains(preset) ? preset : LuminaViewportCameraPreset.perspective;
    final (yaw, pitch) = LuminaViewportCameraPreset.angles(p);
    final c = camera
      ..['preset'] = p
      ..['yaw'] = yaw
      ..['pitch'] = pitch
      ..['orthographic'] = p != LuminaViewportCameraPreset.perspective;
    if (fit) _requestFrame(c, '*');
  }

  /// Frames node [id] (the runtime fits its bounds); '*' frames every node.
  void frameNode(String id) {
    camera['autoFrame'] = false;
    _requestFrame(camera, id);
  }

  /// Whether the runtime frames every mesh each time the set of meshes
  /// changes (once they load), as long as the player has not moved the
  /// camera: true until the description places it (`Set Orbit`, the orbit
  /// target, `Frame Node`) or the player's released drag writes it back.
  bool get autoFrame => camera['autoFrame'] == true;

  void _requestFrame(Map<String, Object?> c, String id) {
    c['frame'] = id;
    c['frameSerial'] = (c['frameSerial'] is int ? c['frameSerial'] as int : 0) + 1;
  }

  /// Sets the orbit; the preset becomes perspective unless only the
  /// distance changed on an orthographic preset.
  void setOrbit(double yaw, double pitch, double distance) {
    camera
      ..['autoFrame'] = false
      ..['yaw'] = yaw
      ..['pitch'] = pitch.clamp(-89.0, 89.0)
      ..['distance'] = distance < 1.0 ? 1.0 : distance;
  }

  /// The orbit target, authoring space.
  List<double> get orbitTarget => _vec(camera['orbitTarget'], const [0.0, 0.0, 0.0]);
  set orbitTarget(List<double> target) => camera
    ..['autoFrame'] = false
    ..['orbitTarget'] = [for (final v in target.take(3)) v.toDouble()];

  // --- Overlays --------------------------------------------------------------

  List<Map<String, Object?>> get skeletonOverlays =>
      [for (final o in _list('skeletonOverlays')) if (o is Map<String, Object?>) o];

  Map<String, Object?>? skeletonOverlay(String nodeId) {
    for (final o in skeletonOverlays) {
      if (o['node'] == nodeId) return o;
    }
    return null;
  }

  /// Draws node [nodeId]'s skeleton in [color] (with joint dots when [joints]).
  void showSkeleton(String nodeId, List<double> color, {bool joints = true}) {
    final o = _overlay(nodeId);
    o['color'] = [for (final c in color) c.toDouble()];
    o['joints'] = joints;
  }

  /// Draws a ghost skeleton of node [nodeId] at [pose] (joint → `[x, y, z,
  /// qx, qy, qz, qw]` local transforms), or at [animation] sampled at [time].
  void showGhostPose(String nodeId, {Map<String, Object?>? pose, String? animation, double time = 0.0, List<double>? color, String label = ''}) {
    final o = _overlay(nodeId);
    o['ghostPose'] = pose == null ? null : _plain(pose);
    o['ghostAnimation'] = animation == null || animation.isEmpty ? null : <String, Object?>{'asset': animation, 'time': time};
    if (color != null) o['ghostColor'] = [for (final c in color) c.toDouble()];
    o['label'] = label;
  }

  /// Hides node [nodeId]'s skeleton and ghost; false when none is shown.
  bool hideSkeleton(String nodeId) {
    final list = _list('skeletonOverlays');
    final before = list.length;
    list.removeWhere((o) => o is Map && o['node'] == nodeId);
    return list.length != before;
  }

  Map<String, Object?> _overlay(String nodeId) {
    final existing = skeletonOverlay(nodeId);
    if (existing != null) return existing;
    final o = <String, Object?>{
      'node': nodeId,
      'color': <Object?>[1.0, 0.85, 0.2, 1.0],
      'joints': true,
      'ghostPose': null,
      'ghostAnimation': null,
      'ghostColor': <Object?>[0.4, 0.8, 1.0, 0.6],
      'label': '',
    };
    _list('skeletonOverlays').add(o);
    return o;
  }

  /// The transform gizmo, or null when hidden.
  Map<String, Object?>? get gizmo => json['gizmo'] is Map<String, Object?> ? json['gizmo'] as Map<String, Object?> : null;

  /// Shows the gizmo on node [nodeId] (on [bone] of a skeletal mesh).
  void setGizmo(String nodeId, {String? bone, String mode = 'translate', String space = 'world', double snap = 0.0}) {
    json['gizmo'] = <String, Object?>{
      'node': nodeId,
      'bone': bone == null || bone.isEmpty ? null : bone,
      'mode': const ['translate', 'rotate', 'scale'].contains(mode) ? mode : 'translate',
      'space': space == 'local' ? 'local' : 'world',
      'snap': snap,
    };
  }

  void hideGizmo() => json['gizmo'] = null;

  List<Map<String, Object?>> get markers => [for (final m in _list('markers')) if (m is Map<String, Object?>) m];

  /// Adds a marker (a labelled point, line or arrow, authoring space) and
  /// returns its id.
  String addMarker(String label, String kind, List<double> from, List<double> to, List<double> color) {
    final id = _nextId('marker');
    _list('markers').add(<String, Object?>{
      'id': id,
      'label': label,
      'kind': const ['point', 'line', 'arrow'].contains(kind) ? kind : 'point',
      'from': [for (final v in from) v.toDouble()],
      'to': [for (final v in to) v.toDouble()],
      'color': [for (final c in color) c.toDouble()],
    });
    return id;
  }

  bool removeMarker(String id) {
    final list = _list('markers');
    final before = list.length;
    list.removeWhere((m) => m is Map && m['id'] == id);
    return list.length != before;
  }

  // --- Helpers ---------------------------------------------------------------

  List<Object?> _list(String key) {
    final v = json[key];
    if (v is List<Object?>) return v;
    final list = <Object?>[if (v is List) ...v];
    json[key] = list;
    return list;
  }

  static Map<String, Object?> _map(Map<String, Object?> owner, String key) {
    final v = owner[key];
    if (v is Map<String, Object?>) return v;
    final map = v is Map ? Map<String, Object?>.from(v) : <String, Object?>{};
    owner[key] = map;
    return map;
  }

  static double _num(Object? v, double fallback) => v is num ? v.toDouble() : fallback;

  static List<double> _vec(Object? v, List<double> fallback) {
    if (v is! List || v.length < 3) return fallback;
    return [for (final e in v.take(3)) e is num ? e.toDouble() : 0.0];
  }

  /// A Blueprint Transform (`{location, rotation, scale}`) as JSON; anything
  /// else is the identity.
  static Map<String, Object?> plainTransform(Object? t) {
    List<double> three(Object? v, double fill) {
      if (v is List) return [for (var i = 0; i < 3; i++) i < v.length && v[i] is num ? (v[i] as num).toDouble() : fill];
      final xyz = _xyz(v);
      return xyz ?? [fill, fill, fill];
    }

    final m = t is Map ? t : const {};
    return <String, Object?>{
      'location': three(m['location'], 0.0),
      'rotation': three(m['rotation'], 0.0),
      'scale': three(m['scale'], 1.0),
    };
  }

  /// `x`/`y`/`z` of a vector-like object (vector_math's Vector3, a rotator),
  /// read dynamically so this file stays pure data.
  static List<double>? _xyz(Object? v) {
    if (v == null) return null;
    try {
      final d = v as dynamic;
      if (d.toList is Function) {
        final list = d.toList() as List;
        return [for (var i = 0; i < 3; i++) i < list.length ? (list[i] as num).toDouble() : 0.0];
      }
    } catch (_) {}
    try {
      final d = v as dynamic;
      return [(d.x as num).toDouble(), (d.y as num).toDouble(), (d.z as num).toDouble()];
    } catch (_) {
      return null;
    }
  }

  /// [value] as plain JSON: maps with string keys, lists, and vector-like
  /// values as lists.
  static Object? _plain(Object? value) {
    if (value == null || value is String || value is bool || value is num) return value;
    if (value is Map) return <String, Object?>{for (final e in value.entries) '${e.key}': _plain(e.value)};
    if (value is List) return <Object?>[for (final e in value) _plain(e)];
    return _xyz(value) ?? '$value';
  }

  /// [value] as plain JSON (public for the Blueprint library and the widget).
  static Object? plain(Object? value) => _plain(value);
}
