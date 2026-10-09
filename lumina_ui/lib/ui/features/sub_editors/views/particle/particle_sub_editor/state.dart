part of '../particle_sub_editor.dart';

/// The editor's state and the field helpers its panels share.
abstract class _ParticleSubEditorStateBase extends State<ParticleSubEditor> {
  late final ParticleEditorViewModel vm;
  late final bool _ownsViewModel;
  ParticleStage _stage = ParticleStage.spawn;
  int? _selectedColorStop;
  int? _selectedSizePoint;

  // ---------------------------------------------------------------- helpers

  Widget _vector3Row(String keyPrefix, Vector3 v, void Function(Vector3) onCommit) {
    return Row(
      children: [
        for (var axis = 0; axis < 3; axis++) ...[
          Expanded(
            child: _NumField(
              fieldKey: ValueKey('particle_${keyPrefix}_${['x', 'y', 'z'][axis]}'),
              value: v[axis],
              onCommit: (nv) {
                final next = Vector3.copy(v);
                next[axis] = nv;
                onCommit(next);
              },
            ),
          ),
          if (axis < 2) const SizedBox(width: 4),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, {List<Widget> trailing = const []}) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
          const Spacer(),
          ...trailing,
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 3),
        child: Text(text, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
      );

  Widget _error(String field) {
    final message = vm.errorFor(field);
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        message,
        key: ValueKey('particle_error_$field'),
        style: const TextStyle(fontSize: 8, color: EditorColors.logError),
      ),
    );
  }
}
