part of '../animation_sub_editor.dart';

/// Authoring a sequence made in the editor: the bone gizmo and skeleton in
/// the viewport, Auto Key / Key in the toolbar, the bone key panel and the
/// editor's shortcuts (Ctrl+Z / Ctrl+Y, Delete, K).
mixin _AnimationAuthoring on _AnimationSubEditorStateBase {
  GizmoMode? _shownGizmoMode;

  /// The gizmo's tool decides whether the target is locked (only the root
  /// and pelvis translate): rebuild with the new target when it changes.
  void _onGizmoToolChanged() {
    if (_gizmo.mode == _shownGizmoMode || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _gizmo.addListener(_onGizmoToolChanged);
  }

  @override
  void dispose() {
    _gizmo.removeListener(_onGizmoToolChanged);
    _gizmo.dispose();
    super.dispose();
  }

  bool get _typingInAField =>
      FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() != null;

  bool _handleAuthoringKey(KeyEvent event) {
    final vm = _viewModel;
    final keyboard = HardwareKeyboard.instance;
    final ctrl = keyboard.isControlPressed || keyboard.isMetaPressed;
    final key = event.logicalKey;
    // A text field keeps its own undo, Delete and letters.
    if (_typingInAField) return false;
    if (ctrl && key == LogicalKeyboardKey.keyZ) {
      keyboard.isShiftPressed ? vm.redo() : vm.undo();
      return true;
    }
    if (ctrl && key == LogicalKeyboardKey.keyY) {
      vm.redo();
      return true;
    }
    if ((key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) && vm.selectedKeyframeIds.isNotEmpty) {
      vm.deleteSelectedKeys();
      return true;
    }
    if (vm.isAuthored && !ctrl && key == LogicalKeyboardKey.keyK) {
      vm.keyPendingOrSelected();
      return true;
    }
    // Pose tools: I (IK mode), O (onion skin), Ctrl+C / Ctrl+V /
    // Ctrl+Shift+V (copy, paste, paste mirrored).
    if (vm.isAuthored && !ctrl && key == LogicalKeyboardKey.keyI) {
      _setIkMode(!vm.ikMode);
      return true;
    }
    if (vm.isAuthored && !ctrl && key == LogicalKeyboardKey.keyO) {
      vm.setOnionSkin(enabled: !vm.onionSkin.enabled);
      return true;
    }
    if (vm.isAuthored && ctrl && key == LogicalKeyboardKey.keyC) {
      vm.copyPose();
      return true;
    }
    if (vm.isAuthored && ctrl && key == LogicalKeyboardKey.keyV) {
      vm.pastePose(mirrored: keyboard.isShiftPressed);
      return true;
    }
    return false;
  }

  @override
  List<Widget> _authoringToolbarItems() {
    final vm = _viewModel;
    final clip = vm.authoredClip;
    if (vm.isPoseLibrary) {
      final poses = vm.libraryPoses;
      return [
        const SizedBox(width: 12),
        OutlineBadge(
          key: const ValueKey('anim_pose_library_badge'),
          child: Text(
            'Pose library · ${poses.length} pose${poses.length == 1 ? '' : 's'}'
            '${poses.isEmpty ? '' : ': ${poses.map((p) => p.name).join(', ')}'} — apply them from the Pose tab of a sequence',
            style: const TextStyle(fontSize: 9),
          ),
        ),
      ];
    }
    if (clip == null) return const [];
    return [
      const SizedBox(width: 12),
      OutlineBadge(
        child: Text('Authored · ${clip.lengthFrames} frames @ ${vm.frameRate.toStringAsFixed(vm.frameRate == vm.frameRate.roundToDouble() ? 0 : 2)} FPS',
            style: const TextStyle(fontSize: 9)),
      ),
      const SizedBox(width: 12),
      Tooltip(
        tooltip: (context) => const TooltipContainer(
          child: Text('Auto Key: releasing a bone gizmo keys the changed channels at the playhead frame.\n'
              'Off: changes preview only; a scrub reverts them unless you press Key.'),
        ),
        child: Toggle(
          key: const ValueKey('anim_auto_key'),
          value: vm.autoKey,
          onChanged: vm.setAutoKey,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.keyRound, size: 11, color: vm.autoKey ? EditorColors.logError : EditorColors.mutedForeground),
              const SizedBox(width: 4),
              Text('Auto Key', style: TextStyle(fontSize: 9, color: vm.autoKey ? EditorColors.logError : EditorColors.mutedForeground)),
            ],
          ),
        ),
      ),
      const SizedBox(width: 6),
      Tooltip(
        tooltip: (context) => const TooltipContainer(
          child: Text('Key (K): keys the posed but unkeyed bones at the playhead, or the selected bone\'s whole transform.'),
        ),
        child: OutlineButton(
          key: const ValueKey('anim_key_button'),
          size: ButtonSize.small,
          onPressed: vm.hasPendingPreview || vm.selectedBone != null ? vm.keyPendingOrSelected : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.key, size: 11),
              const SizedBox(width: 4),
              Text(vm.hasPendingPreview ? 'Key *' : 'Key', style: const TextStyle(fontSize: 9.5)),
            ],
          ),
        ),
      ),
      const SizedBox(width: 6),
      GhostButton(
        key: const ValueKey('anim_undo'),
        size: ButtonSize.small,
        onPressed: vm.transactions.canUndo ? vm.undo : null,
        child: const Icon(LucideIcons.undo2, size: 12),
      ),
      GhostButton(
        key: const ValueKey('anim_redo'),
        size: ButtonSize.small,
        onPressed: vm.transactions.canRedo ? vm.redo : null,
        child: const Icon(LucideIcons.redo2, size: 12),
      ),
      if (vm.selectedBone != null) ...[
        const SizedBox(width: 8),
        Icon(LucideIcons.bone, size: 11, color: Colors.amber.withValues(alpha: 0.9)),
        const SizedBox(width: 4),
        Text(vm.selectedBone!, key: const ValueKey('anim_selected_bone'), style: const TextStyle(fontSize: 10, color: Colors.amber)),
      ],
    ];
  }

  Widget _buildViewport() {
    final vm = _viewModel;
    final authored = vm.isAuthored;
    // Set from the build that shows it: the viewport is rebuilt with it in
    // the same frame.
    _shownGizmoMode = _gizmo.mode;
    // In IK mode the gizmo moves the chain's target or pole (translate).
    final ik = authored && vm.ikMode ? vm.ikGizmoTarget : null;
    _gizmo.setTarget(!authored
        ? null
        : ik != null
            ? SubEditorGizmoTarget(
                id: ik.id,
                pivot: ik.pivot,
                rotation: ik.rotation,
                locked: _gizmo.mode != GizmoMode.translate,
                lockedHint: ik.lockedHint,
              )
            : vm.gizmoTarget(_gizmo.mode));
    return SubEditor3DViewport(
      key: const ValueKey('anim_viewport'),
      title: 'Animation Viewport — ${widget.assetName}',
      glbMesh: vm.glbMesh,
      meshSourcePath: vm.previewMeshSourcePath,
      playbackController: vm.playbackController,
      showShapeSelector: !authored,
      yUpCamera: authored,
      transformGizmo: authored ? _gizmo : null,
      jointLocalPose: vm.jointLocalPose,
      // The skeleton drawn over the mesh in the pose shown, the selected
      // bone highlighted (hidden while playing).
      showBones: authored && !vm.isPlaying,
      selectedNode: authored ? vm.allBones.where((n) => n.name == vm.selectedBone).firstOrNull : null,
      ghostSkeletons: _ghostSkeletons(),
      overlayMarkers: _ikMarkers(),
      overlayPaths: _rootPaths(),
      // Draw Path: floor clicks become root path points.
      onFloorTap: authored && _drawingRootPath ? vm.addRootPathPoint : null,
    );
  }

  Widget _numberRow(
    String section,
    List<String> labels,
    List<double> values,
    bool keyed,
    int decimals,
    void Function(int axis, double value) onCommit,
  ) {
    const accents = [EditorColors.destructive, EditorColors.chart3, EditorColors.accent];
    return Row(
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Text(labels[i], style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: accents[i])),
          const SizedBox(width: 3),
          Expanded(
            child: SequencerNumberField(
              key: ValueKey('anim_key_${section}_$i'),
              value: values[i],
              decimals: decimals,
              keyed: keyed,
              accent: accents[i],
              onCommit: (v) => onCommit(i, v),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget _buildAuthoredKeyPanel(SelectedKeyframeDetails d) {
    final vm = _viewModel;
    final clip = vm.authoredClip!;
    final bone = d.targetName;
    final frame = d.frame;
    final loc = d.location!;
    final euler = d.rotationEuler!;
    final scale = d.scale!;
    bool keyed(String path) => clip.hasKey(bone, frame, path);

    return ListView(
      key: const ValueKey('anim_bone_key_panel'),
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: EditorColors.card,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: EditorColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.bone, size: 14, color: EditorColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(bone,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const Text('Frame', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 52,
                    child: SequencerNumberField(
                      key: const ValueKey('anim_key_frame'),
                      value: frame.toDouble(),
                      decimals: 0,
                      onCommit: (v) => vm.moveSelectedBoneKeysToFrame(v.round().clamp(0, clip.lengthFrames)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Bone key · ${d.time.toStringAsFixed(3)} s · local space',
                  style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildTransformSectionHeader('ROTATION (LOCAL, DEGREES)', LucideIcons.rotate3d),
        const SizedBox(height: 6),
        _numberRow('rot', const ['X', 'Y', 'Z'], euler, keyed(AuthoredChannel.rotation), 2, (axis, v) {
          final e = [...euler]..[axis] = v;
          vm.setBoneKey(bone, frame, rotation: SelectedKeyframeDetails.eulerXyzToQuaternion(e[0], e[1], e[2]));
        }),
        const SizedBox(height: 12),
        _buildTransformSectionHeader('TRANSLATION', LucideIcons.move),
        const SizedBox(height: 6),
        _numberRow('loc', const ['X', 'Y', 'Z'], loc, keyed(AuthoredChannel.translation), 4, (axis, v) {
          vm.setBoneKey(bone, frame, translation: [...loc]..[axis] = v);
        }),
        const SizedBox(height: 12),
        _buildTransformSectionHeader('SCALE', LucideIcons.maximize2),
        const SizedBox(height: 6),
        _numberRow('scale', const ['X', 'Y', 'Z'], scale, keyed(AuthoredChannel.scale), 3, (axis, v) {
          if (v <= 0) return;
          vm.setBoneKey(bone, frame, scale: [...scale]..[axis] = v);
        }),
        const SizedBox(height: 12),
        _buildTransformSectionHeader('INTERPOLATION (THIS BONE\'S CHANNELS)', LucideIcons.spline),
        const SizedBox(height: 6),
        Select<String>(
          key: const ValueKey('anim_key_interpolation'),
          value: d.interpolation,
          onChanged: (v) {
            if (v != null) vm.setBoneInterpolation(bone, AuthoredInterpolation.fromLabel(v));
          },
          itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 10)),
          popup: SelectPopup(
            items: SelectItemList(
              children: [
                for (final i in AuthoredInterpolation.values)
                  SelectItemButton(value: i.label, child: Text(i.label, style: const TextStyle(fontSize: 10))),
              ],
            ),
          ).call,
        ),
        const SizedBox(height: 4),
        const Text('glTF interpolates per channel: Cubic eases in and out of every key.',
            style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlineButton(
                size: ButtonSize.small,
                onPressed: () => vm.seek(d.time),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.play, size: 11),
                    SizedBox(width: 4),
                    Text('Seek to Key', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            DestructiveButton(
              key: const ValueKey('anim_key_delete'),
              size: ButtonSize.small,
              onPressed: vm.deleteSelectedKeys,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.trash2, size: 11),
                  SizedBox(width: 4),
                  Text('Delete Key', style: TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
