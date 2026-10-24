part of 'garment_sub_editor.dart';

/// The left panel: the garment's meshes, slot, fit and cloth options, and
/// its placement on the reference body.
mixin _GarmentDetailsPanel on _GarmentEditorBase {
  Widget detailsPanel() {
    final doc = vm.doc;
    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header('GARMENT'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: [
                _label('Source Mesh'),
                AssetPickerSelect(
                  key: const ValueKey('garment_source_mesh'),
                  keyPrefix: 'garment_source',
                  assets: vm.meshAssets,
                  selectedPath: doc.sourceMesh.isEmpty ? null : doc.sourceMesh,
                  placeholder: 'Pick the mesh the garment is made of',
                  onSelected: (a) => vm.setSourceMesh(a.relativePath),
                  onCleared: () => vm.setSourceMesh(''),
                ),
                const SizedBox(height: 10),
                _label('Reference Body'),
                AssetPickerSelect(
                  key: const ValueKey('garment_reference_body'),
                  keyPrefix: 'garment_body',
                  assets: vm.skeletalMeshAssets,
                  selectedPath: doc.referenceBody.isEmpty ? null : doc.referenceBody,
                  placeholder: 'The body it is fitted on',
                  onSelected: (a) => vm.setReferenceBody(a.relativePath),
                  onCleared: () => vm.setReferenceBody(''),
                ),
                const SizedBox(height: 10),
                _label('Preview On'),
                AssetPickerSelect(
                  key: const ValueKey('garment_preview_body'),
                  keyPrefix: 'garment_preview',
                  assets: vm.skeletalMeshAssets,
                  selectedPath: vm.previewBodyChoice.isEmpty ? null : vm.previewBodyChoice,
                  placeholder: 'The reference body',
                  clearLabel: '— the reference body —',
                  onSelected: (a) => vm.setPreviewBody(a.relativePath),
                  onCleared: () => vm.setPreviewBody(''),
                ),
                const SizedBox(height: 14),
                _section('FIT'),
                _label('Slot'),
                Select<String>(
                  key: const ValueKey('garment_slot'),
                  value: doc.slot,
                  onChanged: (v) {
                    if (v != null) vm.setSlot(v);
                  },
                  itemBuilder: (context, item) => Text(item, style: const TextStyle(fontSize: 11)),
                  popup: SelectPopup(
                    items: SelectItemList(
                      children: [
                        for (final s in {...LuminaGarmentDocument.slots, doc.slot}) SelectItemButton(value: s, child: Text(s)),
                      ],
                    ),
                  ).call,
                ),
                const SizedBox(height: 8),
                _label('Thickness'),
                SliderField(
                  key: const ValueKey('garment_thickness'),
                  value: doc.thickness,
                  defaultValue: const LuminaGarmentDocument().thickness,
                  min: LuminaGarmentDocument.minThickness,
                  max: LuminaGarmentDocument.maxThickness,
                  hardMin: LuminaGarmentDocument.minThickness,
                  hardMax: LuminaGarmentDocument.maxThickness,
                  unit: 'cm',
                  fractionDigits: 2,
                  onChanged: vm.setThickness,
                  onCommit: vm.setThickness,
                  onReset: () => vm.setThickness(const LuminaGarmentDocument().thickness),
                ),
                const SizedBox(height: 14),
                _section('CLOTH'),
                Row(
                  children: [
                    Checkbox(
                      key: const ValueKey('garment_simulate'),
                      state: doc.simulateAsCloth ? CheckboxState.checked : CheckboxState.unchecked,
                      onChanged: (s) => vm.setSimulateAsCloth(s == CheckboxState.checked),
                    ),
                    const SizedBox(width: 6),
                    const Text('Simulate as cloth', style: TextStyle(fontSize: 10, color: EditorColors.foreground)),
                  ],
                ),
                const SizedBox(height: 6),
                _label('Cloth Settings'),
                AssetPickerSelect(
                  key: const ValueKey('garment_cloth_settings'),
                  keyPrefix: 'garment_cloth',
                  assets: vm.clothSettingsAssets,
                  selectedPath: doc.clothSettingsAsset.isEmpty ? null : doc.clothSettingsAsset,
                  enabled: doc.simulateAsCloth,
                  onSelected: (a) => vm.setClothSettings(a.relativePath),
                  onCleared: () => vm.setClothSettings(''),
                ),
                const SizedBox(height: 6),
                _label('Settle After Fit'),
                SliderField(
                  key: const ValueKey('garment_settle_steps'),
                  value: doc.settleSteps.toDouble(),
                  defaultValue: 0,
                  min: 0,
                  max: LuminaGarmentDocument.maxSettleSteps.toDouble(),
                  hardMin: 0,
                  hardMax: LuminaGarmentDocument.maxSettleSteps.toDouble(),
                  unit: 'steps',
                  fractionDigits: 0,
                  onChanged: (v) => vm.setSettleSteps(v.round()),
                  onCommit: (v) => vm.setSettleSteps(v.round()),
                  onReset: () => vm.setSettleSteps(0),
                ),
                const SizedBox(height: 14),
                _section('PLACEMENT'),
                _vector('Location', 'location', doc.location, const [0, 0, 0], 'cm', (v) => vm.setPlacement(location: v)),
                _vector('Rotation', 'rotation', doc.rotation, const [0, 0, 0], '°', (v) => vm.setPlacement(rotation: v)),
                _vector('Scale', 'scale', doc.scale, const [1, 1, 1], null, (v) => vm.setPlacement(scale: v)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
  );

  Widget _section(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
  );

  Widget _vector(String label, String key, List<double> value, List<double> defaults, String? unit, ValueChanged<List<double>> set) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(label),
            VectorRow(
              keyPrefix: 'garment_$key',
              value: value,
              defaultValue: defaults,
              unit: unit,
              revision: vm.revision,
              onChanged: set,
              onCommit: set,
              onReset: () => set(defaults),
            ),
          ],
        ),
      );
}
