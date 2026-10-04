part of '../details_widget.dart';

/// Several selected actors: shared transform rows and component
/// properties edited together.
mixin _DetailsMultiSelection on _DetailsWidgetStateBase {

  Widget _buildMultiEditPanel(BuildContext context) {
    final actors = widget.viewModel.selectedActors;
    final view = MultiEditService.computeMultiEditView(actors);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('${actors.length} Actors Selected', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8.0),
            children: [
              _buildMultiTransformSection('Transform', view),
              const Divider(),
              ...view.components.map((comp) => _buildMultiComponentSection(comp)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMultiTransformSection(String title, MultiEditView view) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
        const SizedBox(height: 8),
        _buildMultiTransformRow('Location', view.locationCommon, view.locationMixed, widget.viewModel.updateActorLocation),
        const SizedBox(height: 4),
        _buildMultiTransformRow('Rotation', view.rotationCommon, view.rotationMixed, widget.viewModel.updateActorRotation),
        const SizedBox(height: 4),
        _buildMultiTransformRow('Scale', view.scaleCommon, view.scaleMixed, widget.viewModel.updateActorScale),
      ],
    );
  }

  Widget _buildMultiTransformRow(String label, List<double> values, List<bool> mixed, void Function(List<double>, {bool isCommit, bool relative, int? axis}) updater) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
        Expanded(
          child: VectorRow(
            value: values,
            defaultValue: label == 'Scale' ? [1.0, 1.0, 1.0] : [0.0, 0.0, 0.0],
            isMixedPerAxis: mixed,
            onChanged: (v) => updater(v, isCommit: false, relative: false),
            onCommit: (v) => updater(v, isCommit: true, relative: false),
            // One axis at a time, never the first actor's values for the
            // others: typing sets that axis on every actor, a scrub
            // moves each actor's own value (scrubbing is relative).
            onAxisCommit: (axis, v) => updater(_DetailsWidgetState._onAxis(axis, v), isCommit: true, axis: axis),
            onAxisScrub: (axis, delta, end) => updater(_DetailsWidgetState._onAxis(axis, delta), isCommit: end, relative: true, axis: axis),
            onReset: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildMultiComponentSection(MultiEditComponentBlock comp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              state: comp.isMixedEnabled ? CheckboxState.indeterminate : (comp.commonEnabled == true ? CheckboxState.checked : CheckboxState.unchecked),
              onChanged: (v) {
                if (v != CheckboxState.indeterminate) {
                  final firstMatch = widget.viewModel.selectedActors.expand((a)=>a.components).firstWhere((c)=>c.type == comp.componentType);
                  widget.viewModel.toggleComponentEnabledWithTransaction('', firstMatch.id, v == CheckboxState.checked);
                }
              },
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(comp.componentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            IconButton.ghost(
              icon: const Icon(LucideIcons.x, size: 12, color: Colors.red),
              onPressed: () => widget.viewModel.removeComponentTypeFromSelectionWithTransaction(comp.componentType),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...comp.properties.map((prop) => _buildMultiPropertyRow(comp, prop)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMultiPropertyRow(MultiEditComponentBlock comp, MultiEditComponentProperty prop) {
    Widget editorWidget = const SizedBox();
    switch (prop.descriptor.editor) {
      case PropertyEditorType.boolean:
        editorWidget = Checkbox(
          state: prop.isMixed ? CheckboxState.indeterminate : (prop.commonValue == true ? CheckboxState.checked : CheckboxState.unchecked),
          onChanged: (v) {
            if (v != CheckboxState.indeterminate) {
              widget.viewModel.applyPropertyToSelection(comp.componentType, prop.propertyId, v == CheckboxState.checked);
            }
          },
        );
        break;
      case PropertyEditorType.float:
        editorWidget = SliderField(
          value: (prop.commonValue as num?)?.toDouble() ?? 0.0,
          defaultValue: (prop.descriptor.defaultValue as num?)?.toDouble() ?? 0.0,
          min: prop.descriptor.min ?? 0.0,
          max: prop.descriptor.max ?? 100.0,
          hardMin: prop.descriptor.hardMin,
          hardMax: prop.descriptor.hardMax,
          unit: prop.descriptor.unit,
          isMixed: prop.isMixed,
          onChanged: (v) {
            for (final actor in widget.viewModel.selectedActors) {
              final match = actor.components.where((c) => c.type == comp.componentType).firstOrNull;
              if (match != null) {
                widget.viewModel.updateComponentProperty(actor.id, match.id, prop.propertyId, v);
              }
            }
          },
          onCommit: (v) => widget.viewModel.applyPropertyToSelection(comp.componentType, prop.propertyId, v),
          onReset: () {},
        );
        break;
      case PropertyEditorType.integer:
        editorWidget = SliderField(
          value: (prop.commonValue as num?)?.toDouble() ?? 0.0,
          defaultValue: (prop.descriptor.defaultValue as num?)?.toDouble() ?? 0.0,
          min: prop.descriptor.min ?? 0.0,
          max: prop.descriptor.max ?? 100.0,
          hardMin: prop.descriptor.hardMin,
          hardMax: prop.descriptor.hardMax,
          unit: prop.descriptor.unit,
          isMixed: prop.isMixed,
          onChanged: (v) {
            for (final actor in widget.viewModel.selectedActors) {
              final match = actor.components.where((c) => c.type == comp.componentType).firstOrNull;
              if (match != null) {
                widget.viewModel.updateComponentProperty(actor.id, match.id, prop.propertyId, v.toInt());
              }
            }
          },
          onCommit: (v) => widget.viewModel.applyPropertyToSelection(comp.componentType, prop.propertyId, v.toInt()),
          onReset: () {},
        );
        break;
      case PropertyEditorType.dropdown:
        editorWidget = EnumField(
          value: prop.commonValue as String? ?? '',
          enumValues: prop.descriptor.enumValues ?? [],
          isRadioGroup: false,
          isMixed: prop.isMixed,
          onCommit: (v) => widget.viewModel.applyPropertyToSelection(comp.componentType, prop.propertyId, v),
        );
        break;
      case PropertyEditorType.vector3:
        List<double> vals = prop.commonValue is List ? (prop.commonValue as List).map((e) => (e as num).toDouble()).toList() : [0.0, 0.0, 0.0];
        editorWidget = VectorRow(
          value: vals,
          defaultValue: (prop.descriptor.defaultValue as List?)?.map((e)=>(e as num).toDouble()).toList() ?? [0.0,0.0,0.0],
          isMixedPerAxis: prop.isMixedPerAxis ?? [prop.isMixed, prop.isMixed, prop.isMixed],
          onChanged: (v) {
            for (final actor in widget.viewModel.selectedActors) {
              final match = actor.components.where((c) => c.type == comp.componentType).firstOrNull;
              if (match != null) {
                widget.viewModel.updateComponentProperty(actor.id, match.id, prop.propertyId, v);
              }
            }
          },
          onCommit: (v) => widget.viewModel.applyPropertyToSelection(comp.componentType, prop.propertyId, v),
          // One axis on each actor's own vector.
          onAxisCommit: (axis, v) => widget.viewModel.applyPropertyToSelection(comp.componentType, prop.propertyId, _DetailsWidgetState._onAxis(axis, v), axis: axis),
          onAxisScrub: (axis, delta, end) {
            if (end) widget.viewModel.applyPropertyToSelection(comp.componentType, prop.propertyId, _DetailsWidgetState._onAxis(axis, delta), relative: true, axis: axis);
          },
          onReset: () {},
        );
        break;
      case PropertyEditorType.color:
        editorWidget = ColorField(
          value: prop.commonValue as String? ?? '#FFFFFF',
          defaultValue: (prop.descriptor.defaultValue as String?) ?? '#FFFFFF',
          isMixed: prop.isMixed,
          onChanged: (v) {
            for (final actor in widget.viewModel.selectedActors) {
              final match = actor.components.where((c) => c.type == comp.componentType).firstOrNull;
              if (match != null) {
                widget.viewModel.updateComponentProperty(actor.id, match.id, prop.propertyId, v);
              }
            }
          },
          onCommit: (v) => widget.viewModel.applyPropertyToSelection(comp.componentType, prop.propertyId, v),
          onReset: () {},
        );
        break;
      case PropertyEditorType.assetRef:
        editorWidget = AssetRefField(
          value: prop.commonValue as Map<String, dynamic>?,
          slotName: prop.propertyId,
          assetType: prop.descriptor.type ?? 'LuminaAsset',
          isMixed: prop.isMixed,
          viewModel: widget.viewModel,
          onCommit: (v) => widget.viewModel.applyPropertyToSelection(comp.componentType, prop.propertyId, v),
        );
        break;
      case PropertyEditorType.curve:
      case PropertyEditorType.collisionMatrix:
      default:
        editorWidget = const SizedBox();
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: prop.descriptor.editor == PropertyEditorType.vector3 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Row(
              children: [
                Expanded(child: Text(prop.descriptor.label, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
                if (prop.descriptor.unit != null)
                  Text(' (${prop.descriptor.unit})', style: const TextStyle(fontSize: 8, color: EditorColors.mutedForeground)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: editorWidget),
        ],
      ),
    );
  }
}
