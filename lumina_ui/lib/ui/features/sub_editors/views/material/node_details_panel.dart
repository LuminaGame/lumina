import 'package:lumina_editor_data/lumina_editor.dart' hide BoxShape;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';
import 'package:lumina_ui/ui/features/sub_editors/models/material_logic_nodes.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_graph_editor.dart';
import 'package:lumina_ui/ui/core/property_editors/asset_picker_select.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/pin_literal_editor.dart';

/// The Details panel of the material graph: the selected
/// expression's settings — constant
/// values, parameter names and defaults, the texture a TextureSample reads,
/// TexCoord tiling, mask channels, a Compare's operator, and a Custom node's
/// inputs and GLSL.
/// Every committed edit is one undo step.
class MaterialNodeDetailsPanel extends StatelessWidget {
  final MaterialEditorViewModel viewModel;

  const MaterialNodeDetailsPanel({super.key, required this.viewModel});

  MaterialGraphEditor get _editor => viewModel.graph.editor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_editor, viewModel.graph, viewModel]),
      builder: (context, _) {
        final selected = _editor.selectedNodeIds;
        final node = selected.length == 1 ? _editor.node(selected.single) : null;
        return Container(
          color: EditorColors.card,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.slidersHorizontal, size: 13, color: EditorColors.mutedForeground),
                  SizedBox(width: 6),
                  Text('DETAILS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
                ],
              ),
              const SizedBox(height: 10),
              if (node == null)
                Text(
                  selected.length > 1
                      ? '${selected.length} nodes selected'
                      : 'Select a node to edit its properties. Right-click the graph or drag from a pin to add one.',
                  style: const TextStyle(fontSize: 10.5, color: EditorColors.mutedForeground),
                )
              else
                ..._details(node),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _details(LuminaBlueprintNode node) {
    final spec = MaterialNodes.spec(node.registryId);
    final problems = _editor.problems(node);
    return [
      Text(spec?.title ?? node.registryId,
          key: const ValueKey('material_details_title'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
      if (spec != null && spec.tooltip.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(spec.tooltip, style: const TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
      ],
      for (final p in problems)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(p.message,
              style: TextStyle(fontSize: 10, color: p.isError ? EditorColors.destructive : EditorColors.warning)),
        ),
      const SizedBox(height: 10),
      ..._settings(node),
      ..._inlineConstants(node),
    ];
  }

  Widget _row(String label, Widget editor) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 86, child: Text(label, style: const TextStyle(fontSize: 10.5, color: EditorColors.mutedForeground))),
            Expanded(child: Align(alignment: Alignment.centerLeft, child: editor)),
          ],
        ),
      );

  Widget _number(LuminaBlueprintNode node, String key, {String? literalKey}) => BlueprintPinLiteralEditor(
        keyPrefix: 'material_details_${node.id}_$key',
        type: LuminaPinType.float,
        value: node.literals[literalKey ?? key] ?? 0.0,
        expanded: true,
        onCommit: (v) => _editor.setProperty(node.id, literalKey ?? key, v),
      );

  Widget _text(LuminaBlueprintNode node, String key) => BlueprintPinLiteralEditor(
        keyPrefix: 'material_details_${node.id}_$key',
        type: LuminaPinType.name,
        value: node.literals[key] ?? '',
        expanded: true,
        onCommit: (v) {
          final s = '$v'.trim();
          if (s.isNotEmpty) _editor.setProperty(node.id, key, s);
        },
      );

  /// A 2–4 component value, one float field per channel.
  Widget _vector(LuminaBlueprintNode node, String key, List<String> labels) {
    final raw = node.literals[key];
    final values = [
      for (var i = 0; i < labels.length; i++) raw is List && i < raw.length && raw[i] is num ? (raw[i] as num).toDouble() : 0.0,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(width: 14, child: Text(labels[i], style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
                BlueprintPinLiteralEditor(
                  keyPrefix: 'material_details_${node.id}_${key}_$i',
                  type: LuminaPinType.float,
                  value: values[i],
                  expanded: true,
                  onCommit: (v) {
                    if (v is! num) return;
                    final next = [...values]..[i] = v.toDouble();
                    final changed = _editor.setProperty(node.id, key, next);
                    // A parameter's new default is also what the preview shows.
                    if (changed && node.registryId == MaterialNodes.vectorParameter && key == 'default') {
                      viewModel.setParam('${node.literals['name']}', next);
                    }
                  },
                ),
              ],
            ),
          ),
        if (labels.length >= 3)
          Container(
            key: ValueKey('material_details_swatch_${node.id}'),
            width: 48,
            height: 14,
            decoration: BoxDecoration(
              color: Color.fromARGB(
                255,
                (values[0].clamp(0.0, 1.0) * 255).round(),
                (values[1].clamp(0.0, 1.0) * 255).round(),
                (values[2].clamp(0.0, 1.0) * 255).round(),
              ),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: EditorColors.border),
            ),
          ),
      ],
    );
  }

  List<Widget> _settings(LuminaBlueprintNode node) {
    switch (node.registryId) {
      case MaterialNodes.output:
        return [
          Text(
            'Shading ${viewModel.shading.name} · blend ${viewModel.blending.name}. '
            'Set them under Material Settings on the right; pins this model does not use are marked unused.',
            style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
          ),
        ];
      case MaterialNodes.constant:
        return [_row('Value', _number(node, 'value'))];
      case MaterialNodes.constant2:
        return [_row('Value', _vector(node, 'value', const ['R', 'G']))];
      case MaterialNodes.constant3:
        return [_row('Value', _vector(node, 'value', const ['R', 'G', 'B']))];
      case MaterialNodes.constant4:
        return [_row('Value', _vector(node, 'value', const ['R', 'G', 'B', 'A']))];
      case MaterialNodes.scalarParameter:
        return [
          _row('Parameter', _text(node, 'name')),
          _row('Default', BlueprintPinLiteralEditor(
            keyPrefix: 'material_details_${node.id}_default',
            type: LuminaPinType.float,
            value: node.literals['default'] ?? 0.0,
            expanded: true,
            onCommit: (v) {
              if (_editor.setProperty(node.id, 'default', v)) viewModel.setParam('${node.literals['name']}', v);
            },
          )),
        ];
      case MaterialNodes.vectorParameter:
        return [
          _row('Parameter', _text(node, 'name')),
          _row('Default', _vector(node, 'default', const ['R', 'G', 'B', 'A'])),
        ];
      case MaterialNodes.textureParameter:
        return [_row('Parameter', _text(node, 'name')), ..._textureBinding('${node.literals['name']}')];
      case MaterialNodes.textureSample:
        final tex = viewModel.graph.graph.wireInto(node.id, 'tex');
        return [
          if (tex == null)
            _row('Parameter', _text(node, 'parameter'))
          else
            const Text('The texture comes from the TextureParameter wired into Tex.',
                style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
          if (tex == null) ..._textureBinding('${node.literals['parameter']}'),
        ];
      case MaterialNodes.textureCoordinate:
        return [
          _row(
            'Coordinate',
            Select<int>(
              key: ValueKey('material_details_${node.id}_index'),
              value: (node.literals['index'] as num?)?.toInt() ?? 0,
              itemBuilder: (context, v) => Text('UV$v', style: const TextStyle(fontSize: 10)),
              onChanged: (v) {
                if (v != null) _editor.setProperty(node.id, 'index', v);
              },
              popup: const SelectPopup(
                items: SelectItemList(children: [
                  SelectItemButton(value: 0, child: Text('UV0')),
                  SelectItemButton(value: 1, child: Text('UV1')),
                ]),
              ).call,
            ),
          ),
          _row('U Tiling', _number(node, 'uTiling')),
          _row('V Tiling', _number(node, 'vTiling')),
        ];
      case MaterialNodes.componentMask:
        return [
          _row(
            'Channels',
            Row(
              children: [
                for (final c in const ['r', 'g', 'b', 'a']) ...[
                  Checkbox(
                    key: ValueKey('material_details_${node.id}_mask_$c'),
                    state: node.literals[c] == true ? CheckboxState.checked : CheckboxState.unchecked,
                    onChanged: (s) => _editor.setProperty(node.id, c, s == CheckboxState.checked),
                  ),
                  Text(c.toUpperCase(), style: const TextStyle(fontSize: 10)),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ];
      case MaterialNodes.custom:
        return [
          _row('Description', _text(node, 'description')),
          _row(
            'Output Type',
            Select<String>(
              key: ValueKey('material_details_${node.id}_outputType'),
              value: '${node.literals['outputType'] ?? 'float3'}',
              itemBuilder: (context, v) => Text(v, style: const TextStyle(fontSize: 10)),
              onChanged: (v) {
                if (v != null) _editor.setProperty(node.id, 'outputType', v);
              },
              popup: const SelectPopup(
                items: SelectItemList(children: [
                  SelectItemButton(value: 'float', child: Text('float')),
                  SelectItemButton(value: 'float2', child: Text('float2')),
                  SelectItemButton(value: 'float3', child: Text('float3')),
                  SelectItemButton(value: 'float4', child: Text('float4')),
                ]),
              ).call,
            ),
          ),
          _row(
            'Inputs',
            BlueprintPinLiteralEditor(
              keyPrefix: 'material_details_${node.id}_inputs',
              type: LuminaPinType.string,
              value: MaterialNodes.customInputs(node).join(', '),
              expanded: true,
              onCommit: (v) => _editor.setProperty(node.id, 'inputs', [
                for (final s in '$v'.split(',')) if (s.trim().isNotEmpty) s.trim(),
              ]),
            ),
          ),
          const Text('Code (a function body over the inputs; return the output type)',
              style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
          const SizedBox(height: 4),
          _CodeField(
            key: ValueKey('material_details_${node.id}_code'),
            code: '${node.literals['code'] ?? ''}',
            onApply: (code) => _editor.setProperty(node.id, 'code', code),
          ),
        ];
      case MaterialNodes.setVertexVariable:
        final readers = _editor.nodes
            .where((n) => n.registryId == MaterialNodes.vertexVariable && n.literals['name'] == node.literals['name'])
            .length;
        return [
          _row('Variable', _text(node, 'name')),
          Text(
            'Computed once per vertex (the .mat vertex block) from what is wired into Value, then interpolated '
            'across each triangle. ${readers == 0 ? 'No Vertex Variable node reads it yet.' : 'Read by $readers Vertex Variable node${readers == 1 ? '' : 's'}.'} '
            'A material has at most ${MaterialNodes.maxVariables} variables (${MaterialNodes.maxVariablesWithColor} when it reads the vertex colour).',
            key: ValueKey('material_details_${node.id}_variable_help'),
            style: const TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
          ),
        ];
      case MaterialNodes.vertexVariable:
        final names = _editor.declaredVariables;
        final current = '${node.literals['name'] ?? ''}';
        return [
          _row(
            'Variable',
            names.isEmpty
                ? _text(node, 'name')
                : Select<String>(
                    key: ValueKey('material_details_${node.id}_variable'),
                    value: current,
                    itemBuilder: (context, v) => Text(v, style: const TextStyle(fontSize: 10)),
                    onChanged: (v) {
                      if (v != null) _editor.setProperty(node.id, 'name', v);
                    },
                    popup: SelectPopup(
                      items: SelectItemList(children: [
                        for (final name in {...names, if (current.isNotEmpty) current})
                          SelectItemButton(
                            key: ValueKey('material_details_variable_option_$name'),
                            value: name,
                            child: Text(name),
                          ),
                      ]),
                    ).call,
                  ),
          ),
          if (names.isEmpty)
            const Text(
              'No variable yet: add a Set Vertex Variable node and wire what the vertex stage computes into it.',
              style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
            ),
        ];
      case MaterialNodes.worldPosition:
        return [
          _row(
            'Space',
            Select<String>(
              key: ValueKey('material_details_${node.id}_space'),
              value: '${node.literals['space'] ?? MaterialNodes.absoluteSpace}',
              itemBuilder: (context, v) => Text(
                v == MaterialNodes.cameraRelativeSpace ? 'Camera-relative' : 'Absolute world',
                style: const TextStyle(fontSize: 10),
              ),
              onChanged: (v) {
                if (v != null) _editor.setProperty(node.id, 'space', v);
              },
              popup: const SelectPopup(
                items: SelectItemList(children: [
                  SelectItemButton(value: MaterialNodes.absoluteSpace, child: Text('Absolute world')),
                  SelectItemButton(value: MaterialNodes.cameraRelativeSpace, child: Text('Camera-relative')),
                ]),
              ).call,
            ),
          ),
        ];
      case MaterialLogicNodes.compare:
        return [
          _row(
            'Operator',
            MaterialGraphEditor.compareOperatorSelect(
              node,
              keyPrefix: 'material_details_compare_op',
              onChanged: (op) => _editor.setProperty(node.id, 'op', op),
            ),
          ),
        ];
      case MaterialLogicNodes.ifNode:
        return [
          const Text(
            'Written as the GLSL conditional (Condition ? Then : Else): picks Then where Condition holds, else Else; both are evaluated, '
            'so an if / else chain that only assigns locals reads back as If nodes.',
            style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
          ),
        ];
      case MaterialNodes.customFragment:
        return [
          const Text(
            'The fragment the graph could not express, emitted verbatim. Delete this node to build the material from the graph.',
            style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground),
          ),
          const SizedBox(height: 6),
          _CodeField(
            key: ValueKey('material_details_${node.id}_code'),
            code: '${node.literals['code'] ?? ''}',
            lines: 14,
            onApply: (code) => _editor.setProperty(node.id, 'code', code),
          ),
        ];
      default:
        return const [];
    }
  }

  /// The texture bound to sampler [parameter], picked from the project's
  /// real TEXTURE assets (the same binding the panel on the right edits).
  List<Widget> _textureBinding(String parameter) {
    final param = viewModel.parameters.where((p) => p.name == parameter && p.isSampler).firstOrNull;
    if (param == null) return const [];
    final textures = viewModel.availableTextures;
    final bound = viewModel.textureAssetFor(param);
    return [
      _row(
        'Texture',
        textures.isEmpty
            ? const Text('No textures in this project yet.', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground))
            : AssetPickerSelect(
                key: ValueKey('material_details_texture_$parameter'),
                keyPrefix: 'texture_picker',
                assets: textures,
                selectedPath: bound?.lmasPath,
                placeholder: 'Unassigned',
                thumbnailSize: 28,
                onSelected: (a) => viewModel.graph.bindTexture(parameter, a),
                onCleared: () => viewModel.graph.bindTexture(parameter, null),
              ),
      ),
    ];
  }

  /// Unconnected inputs' constants (also edited inline on the node).
  List<Widget> _inlineConstants(LuminaBlueprintNode node) {
    final pins = MaterialNodes.inputsOf(node).where((p) => p.defaultValue != null).toList();
    final graph = viewModel.graph.graph;
    final free = pins.where((p) => graph.wireInto(node.id, p.id) == null).toList();
    if (free.isEmpty) return const [];
    return [
      const Divider(height: 16),
      const Text('CONSTANTS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.mutedForeground)),
      const SizedBox(height: 6),
      for (final p in free)
        _row(
          p.name,
          BlueprintPinLiteralEditor(
            keyPrefix: 'material_details_${node.id}_const_${p.id}',
            type: LuminaPinType.float,
            value: node.literals[p.id] ?? p.defaultValue,
            expanded: true,
            onCommit: (v) => _editor.setLiteral(node.id, p.id, v),
          ),
        ),
    ];
  }
}

/// A multi-line GLSL field applied with a button, so half-typed code is not
/// compiled into the graph on every keystroke.
class _CodeField extends StatefulWidget {
  final String code;
  final int lines;
  final ValueChanged<String> onApply;

  const _CodeField({super.key, required this.code, required this.onApply, this.lines = 8});

  @override
  State<_CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<_CodeField> {
  late final TextEditingController _controller = TextEditingController(text: widget.code);

  @override
  void didUpdateWidget(covariant _CodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code && _controller.text == oldWidget.code) _controller.text = widget.code;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          maxLines: widget.lines,
          minLines: widget.lines,
          style: const TextStyle(fontSize: 10, fontFamily: EditorTypography.monoFamily),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: SecondaryButton(
            key: const ValueKey('material_details_apply_code'),
            onPressed: () => widget.onApply(_controller.text),
            child: const Text('Apply code', style: TextStyle(fontSize: 10)),
          ),
        ),
      ],
    );
  }
}
