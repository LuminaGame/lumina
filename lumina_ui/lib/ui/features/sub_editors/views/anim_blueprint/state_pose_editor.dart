import 'package:lumina/lumina.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../../../core/property_editors/asset_picker_select.dart';
import '../../../../core/theme/editor_theme.dart';
import '../../services/anim_graph_asset_service.dart';
import '../../view_models/anim_blueprint_editor_view_model.dart';
import '../blend_space/blend_space_grid.dart';

/// A state's pose (a state graph, reduced to what lumina's anim blueprints
/// play): Play Clip from the target mesh's clips, a Blend Space Player on
/// Blend Spaces made for this mesh sampled by X / Y variables with a play
/// rate from a speed variable, or Hold Pose.
class AnimStatePoseEditor extends StatelessWidget {
  final AnimBlueprintEditorViewModel viewModel;
  final String state;

  const AnimStatePoseEditor({super.key, required this.viewModel, required this.state});

  static String shortName(String? path) => (path ?? '').split('/').last.replaceAll('.lmas', '');

  List<String> _numericVariables() => [
        for (final v in viewModel.document.variables)
          if (v.type == LuminaPinType.float || v.type == LuminaPinType.integer) v.name,
      ];

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final s = vm.machine?.state(state);
    if (s == null) {
      return const Center(child: Text('State not found', style: TextStyle(color: EditorColors.mutedForeground)));
    }
    final pose = s.pose;
    final numeric = _numericVariables();

    Widget kindButton(LuminaAnimPoseKind kind, String label, IconData icon) {
      final active = pose.kind == kind;
      final child = Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ]);
      void pick() {
        switch (kind) {
          case LuminaAnimPoseKind.clip:
            vm.setStatePose(state, LuminaAnimPose.clip(vm.clips.isEmpty ? '' : vm.clips.first));
          case LuminaAnimPoseKind.blendSpace:
            vm.setStatePose(
                state,
                LuminaAnimPose.blendSpace(vm.blendSpacePaths.isEmpty ? '' : vm.blendSpacePaths.first,
                    xVariable: numeric.isEmpty ? '' : numeric.first));
          case LuminaAnimPoseKind.hold:
            vm.setStatePose(state, const LuminaAnimPose.hold());
        }
      }

      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: active
            ? PrimaryButton(key: ValueKey('pose_kind_${kind.name}'), size: ButtonSize.small, onPressed: pick, child: child)
            : OutlineButton(key: ValueKey('pose_kind_${kind.name}'), size: ButtonSize.small, onPressed: pick, child: child),
      );
    }

    Widget select(String key, String? value, List<String> items, ValueChanged<String?> onChanged,
        {String placeholder = 'None', bool allowNone = false, String Function(String)? label}) {
      return Select<String>(
        key: ValueKey(key),
        value: value != null && items.contains(value) ? value : null,
        placeholder: Text(placeholder, style: const TextStyle(fontSize: 11, color: EditorColors.mutedForeground)),
        itemBuilder: (context, item) => Text(label?.call(item) ?? item, style: const TextStyle(fontSize: 11)),
        onChanged: onChanged,
        popup: SelectPopup(
          items: SelectItemList(
            children: [
              if (allowNone) SelectItemButton(key: ValueKey('${key}_none'), value: '', child: const Text('None')),
              for (final i in items)
                SelectItemButton(
                  key: ValueKey('${key}_item_$i'),
                  value: i,
                  child: Text(label?.call(i) ?? i, style: const TextStyle(fontSize: 11)),
                ),
            ],
          ),
        ).call,
      );
    }

    Widget field(String label, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground))),
              Expanded(child: child),
            ],
          ),
        );

    final space = pose.blendSpace == null ? null : vm.stateBlendSpaces[pose.blendSpace];
    final anim = vm.preview.animInstance;
    double? live(String? v) {
      final x = v == null ? null : anim?.variables[v];
      return x is num ? x.toDouble() : null;
    }

    return Container(
      color: EditorColors.background,
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Row(
            children: [
              const Icon(LucideIcons.squareStack, size: 14, color: EditorColors.primary),
              const SizedBox(width: 6),
              Text('STATE: ${s.name}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.primary)),
              const SizedBox(width: 8),
              if (vm.machine!.entryState == s.name) const OutlineBadge(child: Text('ENTRY', style: TextStyle(fontSize: 9))),
              const Spacer(),
              if (vm.previewState == s.name)
                const OutlineBadge(
                  child: Text('ACTIVE IN PREVIEW', style: TextStyle(fontSize: 9, color: Color(0xFFFFB300))), // preview amber
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            kindButton(LuminaAnimPoseKind.clip, 'Play Clip', LucideIcons.clapperboard),
            kindButton(LuminaAnimPoseKind.blendSpace, 'Blend Space Player', LucideIcons.grid2x2),
            kindButton(LuminaAnimPoseKind.hold, 'Hold Pose', LucideIcons.pause),
          ]),
          const SizedBox(height: 16),
          if (pose.kind == LuminaAnimPoseKind.clip) ...[
            field(
              'Clip',
              AssetPickerSelect(
                key: const ValueKey('pose_clip'),
                keyPrefix: 'pose_clip',
                assets: vm.clipAssets,
                selectedPath: vm.clipAssets
                    .where((a) => AnimGraphAssetService.baseName(a.fileName) == pose.clip)
                    .firstOrNull
                    ?.relativePath,
                placeholder: vm.clips.isEmpty ? 'The target mesh has no clips' : 'Pick a clip',
                allowClear: false,
                onSelected: (a) {
                  final clip = AnimGraphAssetService.baseName(a.fileName);
                  if (clip.isNotEmpty) vm.setStatePose(state, LuminaAnimPose.clip(clip, rate: pose.rate));
                },
              ),
            ),
            field(
              'Play Rate',
              _NumberField(
                key: const ValueKey('pose_rate'),
                value: pose.rate,
                onCommit: (v) => vm.setStatePose(state, LuminaAnimPose.clip(pose.clip ?? '', rate: v)),
              ),
            ),
          ],
          if (pose.kind == LuminaAnimPoseKind.blendSpace) ...[
            field(
              'Blend Space',
              AssetPickerSelect(
                key: const ValueKey('pose_bs'),
                keyPrefix: 'pose_bs',
                assets: vm.blendSpaceAssets,
                selectedPath: pose.blendSpace,
                placeholder: vm.blendSpacePaths.isEmpty ? 'No Blend Space for this mesh' : 'Pick a Blend Space',
                allowClear: false,
                onSelected: (a) => vm.setStatePose(state, _bs(pose, blendSpace: a.relativePath)),
              ),
            ),
            field(
              'X (${space != null && space.axes.isNotEmpty ? space.axes[0].name : 'axis 1'})',
              select('pose_x', pose.xVariable, numeric, (v) {
                if (v != null && v.isNotEmpty) vm.setStatePose(state, _bs(pose, xVariable: v));
              }, placeholder: 'Pick a variable'),
            ),
            if (space == null || space.axes.length > 1)
              field(
                'Y (${space != null && space.axes.length > 1 ? space.axes[1].name : 'axis 2'})',
                select('pose_y', pose.yVariable, numeric, (v) => vm.setStatePose(state, _bs(pose, yVariable: v ?? '')),
                    allowNone: true),
              ),
            field(
              'Rate From',
              select('pose_rate_var', pose.rateVariable, numeric,
                  (v) => vm.setStatePose(state, _bs(pose, rateVariable: v ?? '')),
                  allowNone: true, placeholder: 'Fixed rate'),
            ),
            if (pose.rateVariable != null)
              field(
                'Rate Reference',
                _NumberField(
                  key: const ValueKey('pose_rate_reference'),
                  value: pose.rateReference,
                  onCommit: (v) => vm.setStatePose(state, _bs(pose, rateReference: v)),
                ),
              )
            else
              field(
                'Play Rate',
                _NumberField(
                  key: const ValueKey('pose_rate'),
                  value: pose.rate,
                  onCommit: (v) => vm.setStatePose(state, _bs(pose, rate: v)),
                ),
              ),
            if (space != null) ...[
              const SizedBox(height: 6),
              const Text('The preview plays the nearest sample (lumina crossfades between two clips).',
                  style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
              const SizedBox(height: 6),
              SizedBox(
                height: 200,
                child: BlendSpaceGrid(
                  key: const ValueKey('pose_bs_grid'),
                  document: space,
                  point: (live(pose.xVariable) ?? 0, live(pose.yVariable) ?? 0),
                  highlightClip: vm.previewClip,
                  readOnly: true,
                ),
              ),
            ],
          ],
          if (pose.kind == LuminaAnimPoseKind.hold)
            const Text('The state keeps the pose it entered with (the clip freezes).',
                style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
        ],
      ),
    );
  }

  static LuminaAnimPose _bs(
    LuminaAnimPose p, {
    String? blendSpace,
    String? xVariable,
    String? yVariable,
    double? rate,
    String? rateVariable,
    double? rateReference,
  }) {
    String? orNull(String? v) => v == null || v.isEmpty ? null : v;
    return LuminaAnimPose.blendSpace(
      blendSpace ?? p.blendSpace ?? '',
      xVariable: xVariable ?? p.xVariable ?? '',
      yVariable: yVariable != null ? orNull(yVariable) : p.yVariable,
      rate: rate ?? p.rate,
      rateVariable: rateVariable != null ? orNull(rateVariable) : p.rateVariable,
      rateReference: rateReference ?? p.rateReference,
      minRate: p.minRate,
      maxRate: p.maxRate,
    );
  }
}

/// A number field committing on Enter or focus loss.
class _NumberField extends StatefulWidget {
  final double value;
  final ValueChanged<double> onCommit;

  const _NumberField({super.key, required this.value, required this.onCommit});

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _c = TextEditingController(text: '${widget.value}');
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && '${widget.value}' != _c.text) _c.text = '${widget.value}';
  }

  void _commit() {
    final v = double.tryParse(_c.text);
    if (v != null && v != widget.value) widget.onCommit(v);
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TextField(controller: _c, focusNode: _focus, style: const TextStyle(fontSize: 11), onSubmitted: (_) => _commit());
}
