// design-token-exempt: landmark hues drawn in the 3D viewport over the garment and the body
part of 'garment_sub_editor.dart';

/// The right panel: the landmarks as tree rows (a garment point and a body
/// point under each), a preset to add, a custom name to add, the selected
/// landmark's error.
mixin _GarmentLandmarksPanel on _GarmentEditorBase {
  final TextEditingController _custom = TextEditingController();
  final Set<String> _collapsed = {};

  Widget landmarksPanel() {
    final doc = vm.doc;
    final errors = vm.landmarkErrors();
    final missing = vm.missingPresets;
    return Container(
      color: EditorColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header('LANDMARKS'),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Select<String>(
              key: const ValueKey('garment_add_preset'),
              value: null,
              placeholder: const Text('Add a landmark…', style: TextStyle(fontSize: 11)),
              onChanged: (v) {
                if (v != null) vm.addLandmark(v);
              },
              itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 11)),
              popup: SelectPopup(
                items: SelectItemList(children: [for (final p in missing) SelectItemButton(value: p, child: Text(p))]),
              ).call,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('garment_custom_name'),
                    controller: _custom,
                    placeholder: const Text('Custom name', style: TextStyle(fontSize: 11)),
                    style: const TextStyle(fontSize: 11),
                    onSubmitted: (_) => _addCustom(),
                  ),
                ),
                const SizedBox(width: 4),
                GhostButton(
                  key: const ValueKey('garment_add_custom'),
                  density: ButtonDensity.iconDense,
                  onPressed: _addCustom,
                  child: const Icon(LucideIcons.plus, size: 13),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              key: const ValueKey('garment_landmark_tree'),
              children: [
                for (final l in doc.landmarks) ...[
                  _row(l, errors[l.name]),
                  if (!_collapsed.contains(l.name)) ...[
                    _pointRow(l.name, 'Garment', l.garment, LucideIcons.shirt, _garmentColor),
                    _pointRow(l.name, 'Body', l.body, LucideIcons.personStanding, _bodyColor),
                  ],
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: EditorColors.border))),
            child: Text(
              _hint(),
              key: const ValueKey('garment_pick_hint'),
              style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }

  static const Color _garmentColor = Color(0xFFF59E0B), _bodyColor = Color(0xFF22D3EE);

  String _hint() {
    final selected = vm.selectedLandmark;
    if (selected == null) return 'Select a landmark, then click on the garment or the body.';
    return switch (vm.pickMode) {
      GarmentPickMode.garment => 'Click on the garment where "$selected" is.',
      GarmentPickMode.body => 'Click on the body where "$selected" belongs.',
      GarmentPickMode.none => 'Turn on a pick mode in the toolbar to place "$selected".',
    };
  }

  void _addCustom() {
    if (vm.addLandmark(_custom.text)) _custom.clear();
  }

  Widget _row(LuminaGarmentLandmark l, double? error) {
    final selected = vm.selectedLandmark == l.name;
    final open = !_collapsed.contains(l.name);
    return GestureDetector(
      key: ValueKey('garment_landmark_${l.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => vm.selectLandmark(l.name),
      child: Container(
        height: 24,
        padding: const EdgeInsets.only(left: 4, right: 4),
        color: selected ? EditorColors.selectionBg : null,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => setState(() => open ? _collapsed.add(l.name) : _collapsed.remove(l.name)),
              child: Icon(open ? LucideIcons.chevronDown : LucideIcons.chevronRight, size: 12, color: EditorColors.mutedForeground),
            ),
            const SizedBox(width: 2),
            Icon(l.isComplete ? LucideIcons.mapPinCheck : LucideIcons.mapPin, size: 12, color: l.isComplete ? _bodyColor : EditorColors.mutedForeground),
            const SizedBox(width: 6),
            Expanded(child: Text(l.name, style: const TextStyle(fontSize: 11, color: EditorColors.foreground))),
            if (error != null)
              Text('${error.toStringAsFixed(1)} cm', style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
            GhostButton(
              key: ValueKey('garment_remove_${l.name}'),
              density: ButtonDensity.iconDense,
              onPressed: () => vm.removeLandmark(l.name),
              child: const Icon(LucideIcons.trash2, size: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pointRow(String name, String what, List<double>? p, IconData icon, Color color) => GestureDetector(
    key: ValueKey('garment_point_${name}_$what'),
    behavior: HitTestBehavior.opaque,
    onTap: () {
      vm.selectLandmark(name);
      vm.setPickMode(what == 'Garment' ? GarmentPickMode.garment : GarmentPickMode.body);
    },
    child: Container(
      height: 22,
      padding: const EdgeInsets.only(left: 34, right: 8),
      child: Row(
        children: [
          Icon(icon, size: 11, color: p == null ? EditorColors.mutedForeground : color),
          const SizedBox(width: 6),
          Text(what, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
          const Spacer(),
          Text(
            p == null ? 'not placed' : p.map((v) => v.toStringAsFixed(1)).join(', '),
            style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground),
          ),
        ],
      ),
    ),
  );
}
