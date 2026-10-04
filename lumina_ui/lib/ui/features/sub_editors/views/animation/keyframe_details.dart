part of '../animation_sub_editor.dart';

/// Right sidebar tab switcher and the keyframe details inspector
/// (transform, interpolation, curve and notify sections).
mixin _AnimationKeyframeDetails on _AnimationSubEditorStateBase {

  Widget _buildRightSidebar() {
    final vm = _viewModel;
    final selectedKey = vm.selectedKeyframeDetails;

    return Column(
      children: [
        // Tabs Header
        Container(
          padding: const EdgeInsets.all(6),
          color: EditorColors.card,
          child: Row(
            children: [
              Expanded(
                child: GhostButton(
                  size: ButtonSize.small,
                  onPressed: () => setState(() => _activeRightTab = 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.keyRound,
                        size: 11,
                        color: _activeRightTab == 0 ? EditorColors.warning : EditorColors.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          selectedKey != null ? 'Key: ${selectedKey.targetName}' : 'Key Details',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: _activeRightTab == 0 ? FontWeight.bold : FontWeight.normal,
                            color: _activeRightTab == 0 ? EditorColors.warning : EditorColors.mutedForeground,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: GhostButton(
                  size: ButtonSize.small,
                  onPressed: () => setState(() => _activeRightTab = 1),
                  child: Text(
                    'Curves (${vm.curves.length})',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: _activeRightTab == 1 ? FontWeight.bold : FontWeight.normal,
                      color: _activeRightTab == 1 ? Colors.cyan : EditorColors.mutedForeground,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: GhostButton(
                  size: ButtonSize.small,
                  onPressed: () => setState(() => _activeRightTab = 2),
                  child: Text(
                    'BlendSpace',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: _activeRightTab == 2 ? FontWeight.bold : FontWeight.normal,
                      color: _activeRightTab == 2 ? Colors.green : EditorColors.mutedForeground,
                    ),
                  ),
                ),
              ),
              // Posing and cycle tools of a sequence authored here.
              if (vm.isAuthored) ...[
                const SizedBox(width: 2),
                Expanded(
                  child: GhostButton(
                    key: const ValueKey('anim_right_tab_pose'),
                    size: ButtonSize.small,
                    onPressed: () => setState(() => _activeRightTab = 3),
                    child: Text(
                      'Pose',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: _activeRightTab == 3 ? FontWeight.bold : FontWeight.normal,
                        color: _activeRightTab == 3 ? Colors.pink : EditorColors.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),

        Expanded(
          child: _activeRightTab == 0
              ? _buildKeyframeDetailsPanel()
              : _activeRightTab == 1
                  ? _buildCurvesPanel()
                  : _activeRightTab == 3 && vm.isAuthored
                      ? _buildPoseToolsPanel()
                      : _buildBlendSpacePanel(),
        ),
      ],
    );
  }

  Widget _buildKeyframeDetailsPanel() {
    final vm = _viewModel;
    final details = vm.selectedKeyframeDetails;

    if (details == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: EditorColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: EditorColors.warning.withValues(alpha: 0.3)),
                ),
                child: const Icon(LucideIcons.keyRound, size: 22, color: EditorColors.warning),
              ),
              const SizedBox(height: 12),
              const Text(
                'No Keyframe Selected',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground),
              ),
              const SizedBox(height: 6),
              const Text(
                'Click on any keyframe diamond (◆) on the Dope Sheet or select a bone track to inspect and edit its exact Transform properties.',
                style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // A bone key of a sequence authored here: editable.
    if (vm.isAuthored && details.type == 'Bone Keyframe') return _buildAuthoredKeyPanel(details);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Header Summary Card
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
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: EditorColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(LucideIcons.keyRound, size: 14, color: EditorColors.warning),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          details.targetName,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          details.type,
                          style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: EditorColors.background,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: EditorColors.border),
                    ),
                    child: Text(
                      'Frame ${details.frame}',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: EditorTypography.monoFamily, color: EditorColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Timecode:', style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
                  Text('${details.time.toStringAsFixed(4)}s', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Bone Transform Sections
        if (details.location != null || details.rotationEuler != null || details.scale != null) ...[
          LuminaTransformWidget(
            location: details.location ?? const [0.0, 0.0, 0.0],
            rotation: details.rotationEuler ?? const [0.0, 0.0, 0.0],
            scale: details.scale ?? const [1.0, 1.0, 1.0],
            rotationQuat: details.rotationQuat,
            showHeaders: true,
            useEulerLabels: true,
            showRotationUnit: true,
          ),
          const SizedBox(height: 12),
        ],

        if (details.interpolation != null) ...[
          _buildTransformSectionHeader('INTERPOLATION', LucideIcons.spline),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: EditorColors.card,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: EditorColors.border),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.spline, size: 12, color: EditorColors.primary),
                const SizedBox(width: 6),
                Text(
                  details.interpolation!,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Curve Keyframe Value Editor
        if (details.curveValue != null) ...[
          _buildTransformSectionHeader('FLOAT CURVE VALUE', LucideIcons.activity),
          const SizedBox(height: 6),
          TextField(
            initialValue: details.curveValue!.toStringAsFixed(3),
            style: const TextStyle(fontSize: 11, fontFamily: EditorTypography.monoFamily),
            onSubmitted: (val) {
              final parsed = double.tryParse(val.trim());
              if (parsed != null) {
                vm.updateSelectedCurveKeyframeValue(parsed);
              }
            },
          ),
          const SizedBox(height: 12),
        ],

        // Notify Event details
        if (details.notifyType != null) ...[
          _buildTransformSectionHeader('NOTIFY EVENT TYPE', LucideIcons.bellRing),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: EditorColors.card,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: EditorColors.border),
            ),
            child: Text(
              details.notifyType!,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EditorColors.logWarning),
            ),
          ),
          const SizedBox(height: 12),
        ],

        const Divider(height: 1),
        const SizedBox(height: 12),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlineButton(
                size: ButtonSize.small,
                onPressed: () => vm.seek(details.time),
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
              size: ButtonSize.small,
              onPressed: () => vm.deleteSelectedKeys(),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.trash2, size: 11),
                  SizedBox(width: 4),
                  Text('Delete', style: TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget _buildTransformSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 12, color: EditorColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground, letterSpacing: 0.5),
        ),
      ],
    );
  }
}
