part of '../animation_sub_editor.dart';

/// The Pose tab of an authored sequence and its viewport overlays: onion
/// skin, pose copy / paste / mirror, the mirror pairs, loop helpers, the
/// pose library, two-bone IK and root motion.
mixin _AnimationPoseTools on _AnimationSubEditorStateBase {
  final TextEditingController _poseNameController = TextEditingController(text: 'Pose');
  double _poseWeight = 100;
  bool _poseSelectedOnly = false;
  int? _pinFrom;
  int? _pinTo;
  String? _pairA;
  String? _pairB;

  // Ghost colours: before / after the playhead and the loop seam.
  static const Color _ghostBefore = Color(0xFFFF8A65);
  static const Color _ghostAfter = Color(0xFF4FC3F7);
  static const Color _ghostSeam = Color(0xFF69F0AE);
  static const Color _ikTargetColor = Color(0xFFFFEB3B);
  static const Color _ikPoleColor = Color(0xFFE040FB);
  static const Color _rootPathColor = Color(0xFF00E676);

  @override
  void dispose() {
    _poseNameController.dispose();
    super.dispose();
  }

  @override
  void _setIkMode(bool value) {
    _viewModel.setIkMode(value);
    if (value) _gizmo.setMode(GizmoMode.translate);
  }

  /// The onion skins (and the loop seam) for the viewport.
  @override
  List<SubEditorGhostSkeleton> _ghostSkeletons() {
    final vm = _viewModel;
    if (!vm.isAuthored || vm.isPlaying) return const [];
    return [
      for (final g in vm.ghostPoses)
        SubEditorGhostSkeleton(
          jointLocalPose: g.jointLocalPose,
          color: g.seam ? _ghostSeam : (g.before ? _ghostBefore : _ghostAfter),
          opacity: g.opacity,
          label: g.seam ? 'frame 0 (loop)' : '${g.frame}',
        ),
    ];
  }

  /// The IK chain's target and pole.
  @override
  List<SubEditorOverlayMarker> _ikMarkers() {
    final vm = _viewModel;
    final chain = vm.ikChainName;
    if (!vm.isAuthored || !vm.ikMode || chain == null || vm.isPlaying) return const [];
    final target = vm.ikTargetPosition;
    final pole = vm.ikPolePosition;
    final skel = vm.skeleton!;
    final c = vm.ikChains.where((c) => c.name == chain).firstOrNull;
    final elbow = c == null ? null : vm.boneWorldPosition(skel.names[c.lower]!);
    return [
      if (target != null)
        SubEditorOverlayMarker(position: target, color: _ikTargetColor, shape: SubEditorMarkerShape.diamond, label: '$chain target'),
      if (pole != null)
        SubEditorOverlayMarker(position: pole, color: _ikPoleColor, shape: SubEditorMarkerShape.ring, label: '$chain pole', lineTo: elbow),
    ];
  }

  @override
  List<SubEditorOverlayPath> _rootPaths() {
    final vm = _viewModel;
    if (!vm.isAuthored || vm.rootPath.isEmpty) return const [];
    return [SubEditorOverlayPath(points: vm.rootPath, color: _rootPathColor)];
  }

  /// The viewport's onion skin switch (bottom left).
  Widget _onionSkinHud() {
    final vm = _viewModel;
    final o = vm.onionSkin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: EditorColors.card.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EditorColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Toggle(
            key: const ValueKey('anim_onion_skin_toggle'),
            value: o.enabled,
            onChanged: (v) => vm.setOnionSkin(enabled: v),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.layers, size: 11, color: o.enabled ? _ghostAfter : EditorColors.mutedForeground),
                const SizedBox(width: 4),
                Text('Onion Skin (O)', style: TextStyle(fontSize: 9, color: o.enabled ? _ghostAfter : EditorColors.mutedForeground)),
              ],
            ),
          ),
          if (o.enabled) ...[
            const SizedBox(width: 6),
            Text('${o.before} before · ${o.after} after · ${(o.opacity * 100).round()} %',
                style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          ],
          if (vm.ikMode) ...[
            const SizedBox(width: 8),
            OutlineBadge(child: Text('IK ${vm.ikChainName ?? ''}${vm.ikDragsPole ? ' · pole' : ''}', style: const TextStyle(fontSize: 9))),
          ],
          if (_drawingRootPath) ...[
            const SizedBox(width: 8),
            OutlineBadge(child: Text('Click the floor: path point ${vm.rootPath.length + 1}', style: const TextStyle(fontSize: 9))),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: _buildTransformSectionHeader(title, icon),
      );

  Widget _button(String key, String label, IconData icon, VoidCallback? onPressed, {bool primary = false}) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11),
        const SizedBox(width: 4),
        Flexible(child: Text(label, style: const TextStyle(fontSize: 9.5), overflow: TextOverflow.ellipsis)),
      ],
    );
    return primary
        ? PrimaryButton(key: ValueKey(key), size: ButtonSize.small, onPressed: onPressed, child: child)
        : OutlineButton(key: ValueKey(key), size: ButtonSize.small, onPressed: onPressed, child: child);
  }

  /// One of a set of choices: filled when chosen.
  Widget _choice(String key, String label, bool chosen, VoidCallback onPressed) {
    final child = Text(label, style: const TextStyle(fontSize: 9.5));
    return chosen
        ? PrimaryButton(key: ValueKey(key), size: ButtonSize.small, onPressed: onPressed, child: child)
        : OutlineButton(key: ValueKey(key), size: ButtonSize.small, onPressed: onPressed, child: child);
  }

  Widget _pair(Widget a, Widget b) => Row(children: [Expanded(child: a), const SizedBox(width: 6), Expanded(child: b)]);

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
      );

  Widget _intField(String key, int value, int max, ValueChanged<int> onCommit) => SizedBox(
        width: 52,
        child: SequencerNumberField(
          key: ValueKey(key),
          value: value.toDouble(),
          decimals: 0,
          onCommit: (v) => onCommit(v.round().clamp(0, max)),
        ),
      );

  Widget _boneSelect(String key, String? value, List<String> bones, ValueChanged<String?> onChanged) => Select<String>(
        key: ValueKey(key),
        value: value,
        placeholder: const Text('Bone', style: TextStyle(fontSize: 10)),
        onChanged: onChanged,
        itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
        popup: SelectPopup(
          items: SelectItemList(
            children: [
              for (final b in bones) SelectItemButton(value: b, child: Text(b, style: const TextStyle(fontSize: 10))),
            ],
          ),
        ).call,
      );

  @override
  Widget _buildPoseToolsPanel() {
    final vm = _viewModel;
    final clip = vm.authoredClip!;
    final o = vm.onionSkin;
    final seam = vm.loopSeamDegrees ?? 0;
    final mirror = vm.mirrorTable;
    final bones = [for (final j in vm.skeleton?.joints ?? const <int>[]) ?vm.skeleton!.names[j]];
    final lib = vm.libraryPoses;
    final pinFrom = (_pinFrom ?? 0).clamp(0, clip.lengthFrames);
    final pinTo = (_pinTo ?? clip.lengthFrames).clamp(0, clip.lengthFrames);

    return ListView(
      key: const ValueKey('anim_pose_tools_panel'),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      children: [
        // Onion skin.
        _section('ONION SKIN', LucideIcons.layers),
        Row(
          children: [
            Checkbox(
              key: const ValueKey('anim_onion_skin_enabled'),
              state: o.enabled ? CheckboxState.checked : CheckboxState.unchecked,
              onChanged: (s) => vm.setOnionSkin(enabled: s == CheckboxState.checked),
              trailing: const Text('Ghost the nearest keyed poses', style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Text('Before', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
            const SizedBox(width: 4),
            _intField('anim_onion_before', o.before, 5, (v) => vm.setOnionSkin(before: v)),
            const SizedBox(width: 10),
            const Text('After', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
            const SizedBox(width: 4),
            _intField('anim_onion_after', o.after, 5, (v) => vm.setOnionSkin(after: v)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Text('Opacity', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(
                key: const ValueKey('anim_onion_opacity'),
                value: SliderValue.single(o.opacity),
                min: 0.05,
                max: 1.0,
                onChanged: (v) => vm.setOnionSkin(opacity: v.value),
              ),
            ),
            const SizedBox(width: 6),
            Text('${(o.opacity * 100).round()} %', style: const TextStyle(fontSize: 9.5)),
          ],
        ),

        // Pose clipboard and mirror.
        _section('POSE', LucideIcons.personStanding),
        _pair(
          _button('anim_pose_copy', 'Copy Pose', LucideIcons.copy, vm.copyPose),
          _button('anim_pose_copy_selected', 'Copy Selected', LucideIcons.bone,
              vm.selectedBone == null ? null : () => vm.copyPose(selectedOnly: true)),
        ),
        const SizedBox(height: 6),
        _pair(
          _button('anim_pose_paste', 'Paste', LucideIcons.clipboardPaste, vm.hasPoseClipboard ? vm.pastePose : null),
          _button('anim_pose_paste_mirrored', 'Paste Mirrored', LucideIcons.flipHorizontal2,
              vm.hasPoseClipboard ? () => vm.pastePose(mirrored: true) : null),
        ),
        const SizedBox(height: 6),
        _button('anim_pose_mirror_selected',
            vm.selectedBone == null ? 'Mirror Selected' : 'Mirror ${vm.selectedBone} → ${mirror?.partnerOf(vm.selectedBone!) ?? '—'}',
            LucideIcons.flipHorizontal, vm.selectedBone == null ? null : vm.mirrorSelected),
        _note(vm.poseClipboardLabel == null
            ? 'Ctrl+C copies the pose at the playhead, Ctrl+V pastes it, Ctrl+Shift+V pastes it mirrored.'
            : 'Clipboard: ${vm.poseClipboardLabel}'),

        // Mirror pairs.
        _section('MIRROR PAIRS', LucideIcons.arrowLeftRight),
        _note('${(mirror?.pairs.length ?? 0) ~/ 2} left/right pairs from the bone names (_l/_r, Left/Right, .L/.R); '
            'the mirror plane comes from the rest pose.'),
        for (final e in vm.mirrorOverrides.entries)
          Row(
            children: [
              Expanded(child: Text('${e.key} ↔ ${e.value}', style: const TextStyle(fontSize: 10))),
              GhostButton(
                key: ValueKey('anim_mirror_pair_remove_${e.key}'),
                size: ButtonSize.small,
                onPressed: () => vm.removeMirrorPair(e.key),
                child: const Icon(LucideIcons.x, size: 11),
              ),
            ],
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _boneSelect('anim_mirror_pair_a', _pairA, bones, (v) => setState(() => _pairA = v))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('↔', style: TextStyle(fontSize: 11))),
            Expanded(child: _boneSelect('anim_mirror_pair_b', _pairB, bones, (v) => setState(() => _pairB = v))),
            const SizedBox(width: 4),
            _button('anim_mirror_pair_add', 'Pair', LucideIcons.plus,
                _pairA != null && _pairB != null && _pairA != _pairB ? () => vm.setMirrorPair(_pairA!, _pairB!) : null),
          ],
        ),

        // Loop.
        _section('LOOP', LucideIcons.repeat),
        Text(
          seam < 0.01 ? 'Seamless: the last frame matches frame 0' : 'Seam: up to ${seam.toStringAsFixed(1)}° between frame 0 and frame ${clip.lengthFrames}',
          key: const ValueKey('anim_loop_seam'),
          style: TextStyle(fontSize: 10, color: seam < 0.01 ? _ghostSeam : EditorColors.warning),
        ),
        const SizedBox(height: 6),
        _pair(
          _button('anim_loop_copy_first_to_last', 'Copy First → Last', LucideIcons.repeat, vm.copyFirstToLast),
          _button('anim_loop_match_selected', 'Match Selected to First', LucideIcons.bone,
              vm.selectedBone == null && vm.selectedBoneKeys.isEmpty ? null : vm.matchSelectedToFirst),
        ),
        const SizedBox(height: 4),
        Checkbox(
          key: const ValueKey('anim_loop_show_seam'),
          state: vm.showLoopSeam ? CheckboxState.checked : CheckboxState.unchecked,
          onChanged: (s) => vm.setShowLoopSeam(s == CheckboxState.checked),
          trailing: const Text('Show frame 0 as a ghost (the seam)', style: TextStyle(fontSize: 10)),
        ),

        // Pose library.
        _section('POSE LIBRARY', LucideIcons.bookmark),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('anim_pose_library_name'),
                controller: _poseNameController,
                style: const TextStyle(fontSize: 10),
              ),
            ),
            const SizedBox(width: 6),
            _button('anim_pose_library_save', 'Save Pose', LucideIcons.save,
                () => vm.savePoseToLibrary(_poseNameController.text, selectedOnly: _poseSelectedOnly)),
          ],
        ),
        const SizedBox(height: 4),
        Checkbox(
          key: const ValueKey('anim_pose_library_selected_only'),
          state: _poseSelectedOnly ? CheckboxState.checked : CheckboxState.unchecked,
          onChanged: (s) => setState(() => _poseSelectedOnly = s == CheckboxState.checked),
          trailing: const Text('Only the selected bone and its children', style: TextStyle(fontSize: 10)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Text('Weight', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(
                key: const ValueKey('anim_pose_library_weight'),
                value: SliderValue.single(_poseWeight),
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: (v) => setState(() => _poseWeight = v.value),
              ),
            ),
            const SizedBox(width: 6),
            Text('${_poseWeight.round()} %', style: const TextStyle(fontSize: 9.5)),
          ],
        ),
        if (lib.isEmpty) _note('No saved poses for this skeleton yet.'),
        for (final p in lib)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const Icon(LucideIcons.bookmark, size: 11, color: EditorColors.mutedForeground),
                const SizedBox(width: 4),
                Expanded(child: Text('${p.name} · ${p.bones.length} bones', style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)),
                _button('anim_pose_apply_${p.name}', 'Apply', LucideIcons.check,
                    () => vm.applyLibraryPose(p.name, weight: _poseWeight / 100)),
                GhostButton(
                  key: ValueKey('anim_pose_rename_${p.name}'),
                  size: ButtonSize.small,
                  onPressed: () => vm.renameLibraryPose(p.name, _poseNameController.text),
                  child: const Icon(LucideIcons.pencil, size: 11),
                ),
                GhostButton(
                  key: ValueKey('anim_pose_delete_${p.name}'),
                  size: ButtonSize.small,
                  onPressed: () => vm.deleteLibraryPose(p.name),
                  child: const Icon(LucideIcons.trash2, size: 11),
                ),
              ],
            ),
          ),
        _note('Saved per skeleton in PoseLibrary.lmas next to its clips; rename takes the name field.'),

        // Two-bone IK.
        _section('TWO-BONE IK', LucideIcons.footprints),
        Row(
          children: [
            Toggle(
              key: const ValueKey('anim_ik_mode'),
              value: vm.ikMode,
              onChanged: _setIkMode,
              child: Text('IK Mode (I)', style: TextStyle(fontSize: 9.5, color: vm.ikMode ? _ikTargetColor : EditorColors.mutedForeground)),
            ),
            const SizedBox(width: 8),
            Expanded(child: _note(vm.ikMode ? 'Drag the gizmo: keys rotations on release (Auto Key).' : 'Off: the gizmo turns bones.')),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final c in vm.ikChains)
              _choice('anim_ik_chain_${c.name}', c.name, vm.ikChainName == c.name, () {
                if (!vm.ikMode) _setIkMode(true);
                vm.selectIkChain(c.name);
              }),
          ],
        ),
        const SizedBox(height: 6),
        _pair(
          _choice('anim_ik_drag_target', 'Drag Target', !vm.ikDragsPole, () => vm.setIkDragsPole(false)),
          _choice('anim_ik_drag_pole', 'Drag Pole', vm.ikDragsPole, () => vm.setIkDragsPole(true)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Text('Pin end', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
            const SizedBox(width: 4),
            _intField('anim_ik_pin_from', pinFrom, clip.lengthFrames, (v) => setState(() => _pinFrom = v)),
            const Text(' – ', style: TextStyle(fontSize: 9.5)),
            _intField('anim_ik_pin_to', pinTo, clip.lengthFrames, (v) => setState(() => _pinTo = v)),
            const SizedBox(width: 6),
            Expanded(
              child: _button('anim_ik_pin', 'Pin & Bake', LucideIcons.pin,
                  vm.ikChainName == null ? null : () => vm.pinIkChain(vm.ikChainName!, from: pinFrom, to: pinTo)),
            ),
          ],
        ),
        _note('Pin keeps the hand or foot where it is at the first frame through the range, baked to rotation keys.'),

        // Root motion.
        _section('ROOT MOTION', LucideIcons.move),
        _pair(
          _button('anim_root_extract', 'Extract from Pelvis', LucideIcons.arrowDownToLine, vm.extractRootMotion),
          _button('anim_root_zero', 'Zero Root', LucideIcons.circleSlash, vm.zeroRootMotion),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Toggle(
              key: const ValueKey('anim_root_draw_path'),
              value: _drawingRootPath,
              onChanged: (v) => setState(() => _drawingRootPath = v),
              child: Text('Draw Path', style: TextStyle(fontSize: 9.5, color: _drawingRootPath ? _rootPathColor : EditorColors.mutedForeground)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _button('anim_root_key_path', 'Key Path (${vm.rootPath.length})', LucideIcons.route,
                  vm.rootPath.isEmpty ? null : vm.keyRootPath),
            ),
            GhostButton(
              key: const ValueKey('anim_root_clear_path'),
              size: ButtonSize.small,
              onPressed: vm.rootPath.isEmpty ? null : vm.clearRootPath,
              child: const Icon(LucideIcons.eraser, size: 11),
            ),
          ],
        ),
        _note('Extract moves the pelvis\'s travel onto the root and turns Enable Root Motion on; Zero Root puts it back. '
            'Draw Path: click the floor, then Key Path spreads the points over the clip.'),
      ],
    );
  }
}
