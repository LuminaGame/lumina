import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/pose_search_database_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/pose_search/pose_search_fields.dart';

/// Details: the selected clip's tags, cost bias and sampling range, the
/// search settings, and the schema (sample rate, trajectory times and
/// weights, the bones with their position / velocity weights).
class PoseSearchDetailsPanel extends StatelessWidget {
  final PoseSearchDatabaseEditorViewModel viewModel;

  const PoseSearchDetailsPanel({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final d = vm.document;
    final s = d.schema;
    final i = vm.selectedClip;
    final clip = i == null || i >= d.clips.length ? null : d.clips[i];
    return Container(
      color: EditorColors.sidebar,
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          poseSearchSection(clip == null ? 'Clip' : 'Clip: ${clip.clip}'),
          if (clip == null)
            const Text('Select a database clip.', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground))
          else ...[
            poseSearchField(
                'Tags',
                PoseSearchTextField(
                    key: ValueKey('psd_tags_$i'), value: clip.tags.join(', '), placeholder: 'walk, crouch', onCommit: (t) => vm.setTags(i!, t))),
            poseSearchField(
                'Cost Bias',
                PoseSearchNumberField(
                    key: ValueKey('psd_cost_bias_$i'),
                    value: clip.costBias,
                    onCommit: (v) => vm.updateClip(i!, (c) => c.copyWith(costBias: v)))),
            poseSearchField(
                'Search From (s)',
                PoseSearchNumberField(
                    key: ValueKey('psd_sampling_start_$i'),
                    value: clip.samplingStart,
                    onCommit: (v) => vm.updateClip(i!, (c) => c.copyWith(samplingStart: v < 0 ? 0 : v)))),
            poseSearchField(
                'Search To (s, 0 = end)',
                PoseSearchNumberField(
                    key: ValueKey('psd_sampling_end_$i'),
                    value: clip.samplingEnd,
                    onCommit: (v) => vm.updateClip(i!, (c) => c.copyWith(samplingEnd: v < 0 ? 0 : v)))),
          ],
          const Divider(),
          poseSearchSection('Search'),
          poseSearchField('Search Interval (s)',
              PoseSearchNumberField(key: const ValueKey('psd_search_interval'), value: d.searchInterval, onCommit: (v) => vm.setSettings(searchInterval: v))),
          poseSearchField('Continuing Bias',
              PoseSearchNumberField(key: const ValueKey('psd_continuing_bias'), value: d.continuingPoseBias, onCommit: (v) => vm.setSettings(continuingPoseBias: v))),
          poseSearchField('Looping Cost Bias',
              PoseSearchNumberField(key: const ValueKey('psd_looping_bias'), value: d.loopingCostBias, onCommit: (v) => vm.setSettings(loopingCostBias: v))),
          poseSearchField('Blend Time (s)',
              PoseSearchNumberField(key: const ValueKey('psd_blend_time'), value: d.blendTime, onCommit: (v) => vm.setSettings(blendTime: v))),
          poseSearchField('Exclude End (s)',
              PoseSearchNumberField(key: const ValueKey('psd_exclude_end'), value: d.excludeEndSeconds, onCommit: (v) => vm.setSettings(excludeEndSeconds: v))),
          const Divider(),
          poseSearchSection('Schema'),
          poseSearchField(
              'Sample Rate (Hz)',
              PoseSearchNumberField(
                  key: const ValueKey('psd_sample_rate'),
                  value: s.sampleRate,
                  onCommit: (v) => v > 0 ? vm.setSchema((x) => x.copyWith(sampleRate: v)) : null)),
          poseSearchField(
              'Trajectory Times (s)',
              PoseSearchTextField(
                  key: const ValueKey('psd_trajectory_times'),
                  value: s.trajectoryTimes.map((t) => '$t').join(', '),
                  onCommit: vm.setTrajectoryTimes)),
          poseSearchField(
              'Trajectory Position',
              PoseSearchNumberField(
                  key: const ValueKey('psd_trajectory_position_weight'),
                  value: s.trajectoryPositionWeight,
                  onCommit: (v) => vm.setSchema((x) => x.copyWith(trajectoryPositionWeight: v < 0 ? 0 : v)))),
          poseSearchField(
              'Trajectory Facing',
              PoseSearchNumberField(
                  key: const ValueKey('psd_trajectory_facing_weight'),
                  value: s.trajectoryFacingWeight,
                  onCommit: (v) => vm.setSchema((x) => x.copyWith(trajectoryFacingWeight: v < 0 ? 0 : v)))),
          poseSearchField(
              'Root Bone',
              PoseSearchTextField(
                  key: const ValueKey('psd_root_bone'),
                  value: s.rootBone,
                  placeholder: 'root (auto)',
                  onCommit: (t) => vm.setSchema((x) => x.copyWith(rootBone: t.trim())))),
          poseSearchField(
              'Mesh Yaw Offset (°)',
              PoseSearchNumberField(
                  key: const ValueKey('psd_mesh_yaw'),
                  value: s.meshYawOffsetDegrees,
                  onCommit: (v) => vm.setSchema((x) => x.copyWith(meshYawOffsetDegrees: v)))),
          const SizedBox(height: 6),
          const Text('BONES (position weight · velocity weight)',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
          const SizedBox(height: 4),
          for (final b in s.bones)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Expanded(flex: 3, child: Text(b.name, style: const TextStyle(fontSize: 10, color: EditorColors.foreground))),
                Expanded(
                    flex: 2,
                    child: PoseSearchNumberField(
                        key: ValueKey('psd_bone_pos_${b.name}'),
                        value: b.position,
                        onCommit: (v) => vm.setBoneWeights(b.name, position: v))),
                const SizedBox(width: 4),
                Expanded(
                    flex: 2,
                    child: PoseSearchNumberField(
                        key: ValueKey('psd_bone_vel_${b.name}'),
                        value: b.velocity,
                        onCommit: (v) => vm.setBoneWeights(b.name, velocity: v))),
                GhostButton(
                  key: ValueKey('psd_bone_remove_${b.name}'),
                  size: ButtonSize.small,
                  density: ButtonDensity.icon,
                  onPressed: () => vm.removeBone(b.name),
                  child: const Icon(LucideIcons.x, size: 11),
                ),
              ]),
            ),
          PoseSearchTextField(
            key: const ValueKey('psd_add_bone'),
            value: '',
            placeholder: 'Add bone (e.g. hand_l), Enter',
            onCommit: (t) => vm.addBone(t),
          ),
        ],
      ),
    );
  }
}
