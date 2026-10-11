part of '../node_library.dart';

const String _poseCategory = 'Animation|Pose Authoring';
const List<String> _poseKeywords = ['pose', 'ik', 'handle', 'mannequin', 'posing'];

LuminaBlueprintPinSpec get _poseHandle => _s('handle', 'Handle', 'hand_r');

LuminaBlueprintNodeSpec _poseNode(String id, String title, List<String> keywords, List<LuminaBlueprintPinSpec> inputs,
        List<LuminaBlueprintPinSpec> outputs,
        {bool pure = false}) =>
    LuminaBlueprintNodeSpec(
      id: id,
      title: title,
      category: _poseCategory,
      kind: pure ? LuminaBlueprintNodeKind.pure : LuminaBlueprintNodeKind.impure,
      headerColor: pure ? _pure : _function,
      keywords: [..._poseKeywords, ...keywords],
      inputs: [if (!pure) _execIn, ...inputs],
      outputs: [if (!pure) _execOut, ...outputs],
    );

/// Built-in nodes: posing a character through handles
/// (`LuminaPoseAuthoringComponent`, on the owner).
final List<LuminaBlueprintNodeSpec> _poseAuthoringNodes = <LuminaBlueprintNodeSpec>[
  _poseNode('add_pose_authoring', 'Add Pose Authoring', const ['add', 'component', 'skeletal mesh'], [
    _comp(LuminaBlueprintNodeLibrary._skel, 'mesh', 'Mesh'),
  ], [
    _ret(LuminaPinType.object, cls: LuminaBlueprintObjectClass.component('LuminaPoseAuthoringComponent')),
  ]),
  _poseNode('set_pose_handle_target', 'Set Pose Handle Target', const ['target', 'move', 'drag', 'hand', 'foot'], [
    _poseHandle,
    _v('location', 'Location'),
    _b('use_rotation', 'Use Rotation'),
    _rot('rotation', 'Rotation'),
  ], [
    _ret(LuminaPinType.boolean),
  ]),
  _poseNode('get_pose_handle_transform', 'Get Pose Handle Transform', const ['transform', 'location', 'where'], [_poseHandle],
      [_v('location', 'Location'), _rot('rotation', 'Rotation')],
      pure: true),
  _poseNode('clear_pose_handle', 'Clear Pose Handle', const ['clear', 'release'], [_poseHandle], const []),
  _poseNode('reset_pose', 'Reset Pose', const ['reset', 'reference', 'rest', 'clear'], const [], const []),
  _poseNode('find_nearest_pose_handle', 'Find Nearest Pose Handle', const ['nearest', 'closest', 'grab', 'pick'], [
    _v('location', 'Location'),
    _f('max_distance', 'Max Distance', 10.0),
  ], [
    _s('handle', 'Handle'),
    _f('distance', 'Distance'),
  ], pure: true),
  _poseNode('capture_pose', 'Capture Pose', const ['capture', 'snapshot', 'save'], [_s('name', 'Name', 'Pose')],
      [_s('pose', 'Pose')],
      pure: true),
  _poseNode('apply_pose', 'Apply Pose', const ['apply', 'restore', 'load'], [
    _s('pose', 'Pose'),
    _f('blend_time', 'Blend Time'),
  ], [
    _ret(LuminaPinType.boolean),
  ]),
  _poseNode('save_pose', 'Save Pose', const ['save', 'slot', 'store'], [
    _s('slot', 'Slot', 'Poses'),
    _s('name', 'Name', 'Pose'),
  ], [
    _ret(LuminaPinType.boolean),
  ]),
  _poseNode('load_pose', 'Load Pose', const ['load', 'slot', 'restore'], [
    _s('slot', 'Slot', 'Poses'),
    _s('name', 'Name', 'Pose'),
    _f('blend_time', 'Blend Time'),
  ], [
    _ret(LuminaPinType.boolean),
  ]),
  LuminaBlueprintNodeSpec(
    id: 'event_pose_handle_changed',
    title: 'Event On Pose Handle Changed',
    category: 'Events',
    kind: LuminaBlueprintNodeKind.event,
    headerColor: _event,
    keywords: const [..._poseKeywords, 'changed', 'moved', 'event'],
    outputs: [_execOut, _s('handle', 'Handle')],
  ),
];
