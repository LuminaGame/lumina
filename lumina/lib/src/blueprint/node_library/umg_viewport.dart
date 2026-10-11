part of '../node_library.dart';

// --- Viewport (UMG) ---------------------------------------------

/// A Viewport node: impure (exec in / out) or pure, the Viewport element
/// first. Every one edits the element's preview-scene description.
LuminaBlueprintNodeSpec _viewportNode(String id, String title, List<String> keywords,
        {bool pure = false,
        List<LuminaBlueprintPinSpec> inputs = const [],
        List<LuminaBlueprintPinSpec> outputs = const [],
        String? tooltip,
        bool editorOnly = false}) =>
    LuminaBlueprintNodeSpec(
      id: id,
      title: title,
      category: 'Widget|Viewport',
      kind: pure ? LuminaBlueprintNodeKind.pure : LuminaBlueprintNodeKind.impure,
      headerColor: pure ? _pure : _function,
      keywords: ['widget', 'ui', 'element', 'viewport', '3d', 'preview', 'scene', ...keywords],
      inputs: [if (!pure) _execIn, _element(LuminaViewportNodes.elementType), ...inputs],
      outputs: [if (!pure) _execOut, ...outputs],
      tooltip: tooltip,
      editorOnly: editorOnly,
    );

LuminaBlueprintPinSpec _viewportEnum(String id, String name, String enumName, String d) =>
    LuminaBlueprintPinSpec(id, name, LuminaPinType.enumeration, enumName: enumName, defaultValue: d);

LuminaBlueprintPinSpec _nodeId([String id = 'node_id', String name = 'Node Id']) => _s(id, name);

/// The Viewport element's nodes: they build and change its preview scene
/// (meshes, animation, lights, environment, camera, skeleton overlays, the
/// gizmo and markers). Orbiting, gizmo drags, playback and overlay drawing
/// run inside the widget; the graph receives only the element's events.
final List<LuminaBlueprintNodeSpec> _umgViewportNodes = <LuminaBlueprintNodeSpec>[
  _viewportNode('viewport_add_static_mesh', 'Viewport Add Static Mesh', const ['add', 'mesh', 'static mesh', 'prop'],
      inputs: [_s('mesh', 'Mesh'), _xf('transform', 'Transform')], outputs: [_ret(LuminaPinType.string, name: 'Node Id')]),
  _viewportNode('viewport_add_skeletal_mesh', 'Viewport Add Skeletal Mesh', const ['add', 'skeletal mesh', 'character'],
      inputs: [_s('skeletal_mesh', 'Skeletal Mesh'), _xf('transform', 'Transform')], outputs: [_ret(LuminaPinType.string, name: 'Node Id')]),
  _viewportNode('viewport_remove_node', 'Viewport Remove Node', const ['remove', 'delete', 'node'], inputs: [_nodeId()]),
  _viewportNode('viewport_clear', 'Viewport Clear', const ['clear', 'empty', 'reset', 'remove all']),
  _viewportNode('viewport_set_node_transform', 'Viewport Set Node Transform', const ['transform', 'move', 'location', 'rotation', 'scale'],
      inputs: [_nodeId(), _xf('transform', 'Transform')]),
  _viewportNode('viewport_set_node_visible', 'Viewport Set Node Visible', const ['visible', 'hide', 'show'],
      inputs: [_nodeId(), _b('visible', 'Visible', true)]),
  _viewportNode('viewport_set_node_mesh', 'Viewport Set Node Mesh', const ['mesh', 'swap', 'part', 'replace'],
      inputs: [_nodeId(), _s('mesh', 'Mesh')]),
  _viewportNode('viewport_attach_to_socket', 'Viewport Attach To Socket', const ['attach', 'socket', 'bone', 'parent'],
      inputs: [_nodeId(), _nodeId('parent', 'Parent'), _s('socket', 'Socket')]),
  _viewportNode('viewport_set_material_parameter', 'Viewport Set Material Parameter', const ['material', 'parameter', 'colour', 'color', 'scalar', 'texture'],
      inputs: [_nodeId(), _s('slot', 'Slot', '0'), _s('parameter', 'Parameter', 'baseColorFactor'), _any('value', 'Value')]),
  _viewportNode('viewport_set_morph_target_weight', 'Viewport Set Morph Target Weight', const ['morph', 'blend shape', 'weight'],
      inputs: [_nodeId(), _s('morph', 'Morph'), _f('weight', 'Weight')]),
  _viewportNode('viewport_play_animation', 'Viewport Play Animation', const ['animation', 'play', 'clip', 'anim'],
      inputs: [_nodeId(), _s('animation', 'Animation'), _b('loop', 'Loop', true), _f('play_rate', 'Play Rate', 1.0)]),
  _viewportNode('viewport_stop_animation', 'Viewport Stop Animation', const ['animation', 'stop', 'pause'], inputs: [_nodeId()]),
  _viewportNode('viewport_set_animation_time', 'Viewport Set Animation Time', const ['animation', 'time', 'scrub', 'seek'],
      inputs: [_nodeId(), _f('seconds', 'Seconds')]),
  _viewportNode('viewport_play_animation_file', 'Viewport Play Animation File', const ['animation', 'file', 'motion', 'play', 'editor'],
      inputs: [_nodeId(), _s('path', 'Path')],
      tooltip: 'Editor panels only: plays a motion or animation file a plugin process wrote.',
      editorOnly: true),
  _viewportNode('viewport_add_light', 'Viewport Add Light', const ['light', 'add', 'directional', 'point', 'spot'],
      inputs: [
        _viewportEnum('type', 'Type', LuminaViewportNodes.lightTypeEnum, LuminaViewportLightType.directional),
        _color('color', 'Color'),
        _f('intensity', 'Intensity', 100000.0),
        _xf('transform', 'Transform'),
      ],
      outputs: [_ret(LuminaPinType.string, name: 'Node Id')]),
  _viewportNode('viewport_set_environment', 'Viewport Set Environment', const ['environment', 'sky', 'background', 'ibl', 'transparent'],
      inputs: [
        _viewportEnum('mode', 'Mode', LuminaViewportNodes.environmentEnum, LuminaViewportEnvironmentMode.sky),
        _s('ibl', 'IBL'),
        _f('intensity', 'Intensity', 1.0),
      ]),
  _viewportNode('viewport_set_grid_visible', 'Viewport Set Grid Visible', const ['grid', 'floor'], inputs: [_b('visible', 'Visible', true)]),
  _viewportNode('viewport_set_camera_preset', 'Viewport Set Camera Preset', const ['camera', 'preset', 'front', 'top', 'side'],
      inputs: [_viewportEnum('preset', 'Preset', LuminaViewportNodes.cameraPresetEnum, LuminaViewportCameraPreset.perspective), _b('fit', 'Fit', true)]),
  _viewportNode('viewport_frame_node', 'Viewport Frame Node', const ['camera', 'frame', 'focus', 'fit'], inputs: [_nodeId()]),
  _viewportNode('viewport_set_orbit', 'Viewport Set Orbit', const ['camera', 'orbit', 'yaw', 'pitch', 'distance'],
      inputs: [_f('yaw', 'Yaw'), _f('pitch', 'Pitch'), _f('distance', 'Distance', 400.0)]),
  _viewportNode('viewport_get_camera', 'Viewport Get Camera', const ['camera', 'orbit', 'yaw', 'pitch', 'distance', 'get'],
      pure: true, outputs: [_f('yaw', 'Yaw'), _f('pitch', 'Pitch'), _f('distance', 'Distance')]),
  _viewportNode('viewport_set_interaction', 'Viewport Set Interaction', const ['interaction', 'orbit', 'pan', 'zoom', 'pick', 'auto rotate'],
      inputs: [_b('orbit', 'Orbit', true), _b('pan', 'Pan', true), _b('zoom', 'Zoom', true), _b('pick', 'Pick', true), _f('auto_rotate', 'Auto Rotate')]),
  _viewportNode('viewport_show_skeleton', 'Viewport Show Skeleton', const ['skeleton', 'bones', 'joints', 'overlay'],
      inputs: [_nodeId(), _color('color', 'Color', const [1.0, 0.85, 0.2, 1.0]), _b('joints', 'Joints', true)]),
  _viewportNode('viewport_show_ghost_pose', 'Viewport Show Ghost Pose', const ['ghost', 'pose', 'skeleton', 'compare', 'overlay'],
      inputs: [
        _nodeId(),
        _s('pose_json', 'Pose Json'),
        _s('animation', 'Animation'),
        _f('time', 'Time'),
        _color('color', 'Color', const [0.4, 0.8, 1.0, 0.6]),
        _s('label', 'Label'),
      ]),
  _viewportNode('viewport_hide_skeleton', 'Viewport Hide Skeleton', const ['skeleton', 'hide', 'ghost'], inputs: [_nodeId()]),
  _viewportNode('viewport_set_gizmo', 'Viewport Set Gizmo', const ['gizmo', 'transform', 'translate', 'rotate', 'scale', 'manipulator'],
      inputs: [
        _nodeId(),
        _s('bone', 'Bone'),
        _viewportEnum('mode', 'Mode', LuminaViewportNodes.gizmoModeEnum, 'translate'),
        _viewportEnum('space', 'Space', LuminaViewportNodes.gizmoSpaceEnum, 'world'),
        _f('snap', 'Snap'),
      ]),
  _viewportNode('viewport_hide_gizmo', 'Viewport Hide Gizmo', const ['gizmo', 'hide']),
  _viewportNode('viewport_add_marker', 'Viewport Add Marker', const ['marker', 'label', 'arrow', 'line', 'point', 'annotation'],
      inputs: [
        _s('label', 'Label'),
        _viewportEnum('kind', 'Kind', LuminaViewportNodes.markerKindEnum, 'point'),
        _v('from', 'From'),
        _v('to', 'To'),
        _color('color', 'Color'),
      ],
      outputs: [_ret(LuminaPinType.string, name: 'Marker Id')]),
  _viewportNode('viewport_remove_marker', 'Viewport Remove Marker', const ['marker', 'remove'], inputs: [_s('marker_id', 'Marker Id')]),
];

/// The outputs of a Viewport element's bound [event].
List<LuminaBlueprintPinSpec> _viewportEventOutputs(String? event) => switch (event) {
      LuminaWidgetEvents.onPicked => [_s('node_id', 'Node Id'), _s('bone', 'Bone'), _v('hit_location', 'Hit Location')],
      LuminaWidgetEvents.onGizmoPreview || LuminaWidgetEvents.onGizmoCommit => [
          _s('node_id', 'Node Id'),
          _s('bone', 'Bone'),
          _xf('transform', 'Transform'),
        ],
      LuminaWidgetEvents.onCameraChanged => [_f('yaw', 'Yaw'), _f('pitch', 'Pitch'), _f('distance', 'Distance')],
      LuminaWidgetEvents.onAssetLoadFailed => [_s('asset', 'Asset'), _s('message', 'Message')],
      _ => const [],
    };
