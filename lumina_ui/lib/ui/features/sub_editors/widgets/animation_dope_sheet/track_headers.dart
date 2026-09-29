part of '../animation_dope_sheet_widget.dart';

/// Left column of track headers (sequence, bone, notify and curve rows).
mixin _DopeSheetTrackHeaders on _AnimationDopeSheetWidgetStateBase {

  Widget _buildTrackHeaders(
    BuildContext context,
    AnimationEditorViewModel vm,
    int animatedBoneCount,
    List<AnimBoneTrackInfo> filteredBones,
  ) {
    return Container(
      width: 230,
      color: EditorColors.card,
      child: Column(
        children: [
          // Header space matching ruler height
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            alignment: Alignment.centerLeft,
            color: EditorColors.background,
            child: const Text(
              'TRACKS & CHANNELS',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground),
            ),
          ),
          const Divider(height: 1),

          // Scrollable Track Headers
          Expanded(
            child: SingleChildScrollView(
              controller: _verticalHeadersScroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Master Animation Sequence Track Header
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    color: EditorColors.cardHeader,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Icon(LucideIcons.film, size: 13, color: EditorColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            vm.activeClip?.name ?? 'Animation Track',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EditorColors.foreground),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: EditorColors.background,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '${vm.duration.toStringAsFixed(2)}s',
                            style: const TextStyle(fontSize: 9, color: EditorColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Bone Tracks Group Header with Expand / Collapse
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _expandBoneTracks = !_expandBoneTracks),
                          child: Icon(
                            _expandBoneTracks ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                            size: 14,
                            color: EditorColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.bone, size: 13, color: EditorColors.chart4),
                        const SizedBox(width: 6),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _expandBoneTracks = !_expandBoneTracks),
                            child: Text(
                              'Animated Bones ($animatedBoneCount)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Expanded Bone Rows (with sub-tracks tree for Location X/Y/Z, Rotation P/Y/R, Scale X/Y/Z)
                  if (_expandBoneTracks) ...[
                    // Search bar
                    Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      color: EditorColors.background,
                      child: TextField(
                        initialValue: vm.boneSearchQuery,
                        placeholder: const Text('Filter animated bones...', style: TextStyle(fontSize: 10)),
                        style: const TextStyle(fontSize: 10),
                        onChanged: (val) => vm.setBoneSearchQuery(val),
                      ),
                    ),
                    const Divider(height: 1),

                    ...filteredBones.expand((b) {
                      final isSelected = vm.selectedKeyframeIds.any((id) => id.startsWith('bone_${b.boneName}_'));
                      final isExpanded = _expandedBones.contains(b.boneName);
                      final subTracks = b.subTracks;

                      return [
                        // Main Bone Row (height: 26)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            final keyId = 'bone_${b.boneName}_${b.startTime.toStringAsFixed(3)}';
                            vm.selectKeyframe(keyId);
                            vm.seek(b.startTime);
                          },
                          child: Container(
                            height: 26,
                            padding: const EdgeInsets.only(left: 8, right: 8),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              color: isSelected ? EditorColors.chart4.withOpacity(0.15) : Colors.transparent,
                              border: Border(bottom: BorderSide(color: EditorColors.border.withOpacity(0.3))),
                            ),
                            child: Row(
                              children: [
                                if (subTracks.isNotEmpty)
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() {
                                        if (isExpanded) {
                                          _expandedBones.remove(b.boneName);
                                        } else {
                                          _expandedBones.add(b.boneName);
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 4, left: 2),
                                      child: Icon(
                                        isExpanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                                        size: 13,
                                        color: isExpanded ? EditorColors.chart4 : EditorColors.mutedForeground,
                                      ),
                                    ),
                                  )
                                else
                                  const SizedBox(width: 18),
                                Icon(
                                  isSelected ? LucideIcons.check : LucideIcons.circleDot,
                                  size: 10,
                                  color: EditorColors.chart4,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    b.boneName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontFamily: EditorTypography.monoFamily,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      // a tint of the bone-track violet (EditorColors.chart4) for text on a violet fill
                                      color: isSelected ? const Color(0xFFE9D5FF) : EditorColors.foreground,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (subTracks.isNotEmpty && !isExpanded)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      color: EditorColors.card,
                                      borderRadius: BorderRadius.circular(2),
                                      border: Border.all(color: EditorColors.border),
                                    ),
                                    child: Text(
                                      '${subTracks.length}',
                                      style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground),
                                    ),
                                  ),
                                Text(
                                  '${(b.endTime - b.startTime).toStringAsFixed(2)}s',
                                  style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Expanded Sub-Track Component Rows (height: 22 each)
                        if (isExpanded)
                          ...subTracks.map((st) {
                            final isSubSelected = vm.selectedKeyframeIds.any((id) => id.contains(st.label));
                            final char = st.label.contains('.X') || st.label.contains('(P)')
                                ? (st.label.contains('(P)') ? 'P' : 'X')
                                : (st.label.contains('.Y') || st.label.contains('(Y)')
                                    ? 'Y'
                                    : (st.label.contains('(R)') ? 'R' : 'Z'));

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                final targetTime = st.hasVariation ? st.startTime : vm.positionSeconds;
                                final keyId = 'bone_${b.boneName}_${st.label}_${targetTime.toStringAsFixed(3)}';
                                vm.selectKeyframe(keyId);
                                if (st.hasVariation) {
                                  vm.seek(st.startTime);
                                }
                              },
                              child: Container(
                                height: 22,
                                padding: const EdgeInsets.only(left: 28, right: 8),
                                alignment: Alignment.centerLeft,
                                decoration: BoxDecoration(
                                  color: isSubSelected ? st.color.withOpacity(0.12) : EditorColors.background.withOpacity(0.4),
                                  border: Border(bottom: BorderSide(color: EditorColors.border.withOpacity(0.2))),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: st.hasVariation ? st.color.withOpacity(0.2) : EditorColors.mutedForeground.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(2),
                                        border: Border.all(
                                          color: st.hasVariation ? st.color.withOpacity(0.5) : EditorColors.border,
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        char,
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: st.hasVariation ? st.color : EditorColors.mutedForeground,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        st.label,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontFamily: EditorTypography.monoFamily,
                                          fontWeight: isSubSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSubSelected
                                              ? st.color
                                              : (st.hasVariation ? EditorColors.foreground : EditorColors.mutedForeground),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (!st.hasVariation)
                                      Text(
                                        '(${st.staticValue.toStringAsFixed(2)})',
                                        style: const TextStyle(fontSize: 8.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.mutedForeground),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ];
                    }),
                  ],

                  // Notifies Row Header
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Icon(LucideIcons.bell, size: 13, color: EditorColors.logWarning),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Notifies',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${vm.notifies.length}',
                          style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Curves Row Header
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        const Icon(LucideIcons.activity, size: 13, color: EditorColors.primary),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Curves',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${vm.curves.length}',
                          style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Per-Curve Subrows
                  ...vm.curves.map((curve) => Container(
                        height: 26,
                        padding: const EdgeInsets.only(left: 24, right: 8),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            const Icon(LucideIcons.spline, size: 11, color: EditorColors.mutedForeground),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                curve.name,
                                style: const TextStyle(fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
