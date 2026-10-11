part of '../slot_inspector.dart';

/// The Appearance section and the Container groups.
extension _UmgSlotInspectorAppearance on UmgSlotInspector {
  // ---------------------------------------------------------------------------
  // Appearance
  // ---------------------------------------------------------------------------

  Widget _appearanceSection(BuildContext context, UmgNode node) {
    final props = node.props;
    final rows = <Widget>[];
    final isRoot = vm.document.parentOf(node.id) == null;
    if (isRoot) {
      rows.add(_label('Widget Theme'));
      rows.add(UmgThemeHelper.buildDocumentThemePicker(vm: vm));
      rows.add(const SizedBox(height: 8));
    }

    if (props.containsKey('color')) {
      rows.add(_label('Color and Tint'));
      rows.add(_propColor(node, 'Color', 'color', key_: ValueKey('umg_color_${node.id}')));
      rows.add(const SizedBox(height: 4));
    }
    if (props.containsKey('fontSize')) {
      rows.add(_propNumber(node, 'Font Size', 'fontSize', 8, 96, unit: 'pt'));
    }
    if (node.type == UmgWidgetType.text) rows.add(_propText(node, 'Text', 'text'));
    if (node.type == UmgWidgetType.button) {
      rows.add(_propText(node, 'Label', 'label'));
      rows.add(const SizedBox(height: 6));
      rows.add(_label('Component Theme Override'));
      rows.add(UmgThemeHelper.buildNodeThemePicker(vm: vm, node: node));
      rows.add(const SizedBox(height: 6));
      rows.add(_label('Button Style'));
      rows.add(UmgThemeHelper.buildButtonStylePicker(vm: vm, node: node));
    }
    if (node.type == UmgWidgetType.checkBox) {
      rows.add(_propText(node, 'Label', 'label'));
      rows.add(_switchRow('Checked', props['checked'] == true, ValueKey('umg_checked_${node.id}'), (v) => vm.setProp(node.id, 'checked', v)));
    }
    if (node.type == UmgWidgetType.editableText) {
      rows.add(_propText(node, 'Text', 'text'));
      rows.add(_propText(node, 'Hint', 'hint'));
    }
    if (node.type == UmgWidgetType.comboBox) {
      rows.add(UmgComboBoxOptionsEditor(key: ValueKey('umg_combo_options_${node.id}'), vm: vm, node: node));
    }
    if (node.type == UmgWidgetType.progressBar) rows.add(_propNumber(node, 'Percent', 'percent', 0, 1, fractionDigits: 2));
    if (node.type == UmgWidgetType.slider) rows.add(_propNumber(node, 'Value', 'value', 0, 1, fractionDigits: 2));
    if (node.type == UmgWidgetType.border) {
      rows.add(_propNumber(node, 'Padding', 'padding', 0, 200));
      // Border stays for old documents; Container replaces it.
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: OutlineButton(
          key: ValueKey('umg_convert_to_container_${node.id}'),
          onPressed: () => vm.convertBorderToContainer(node.id),
          child: const Text('Convert to Container', style: TextStyle(fontSize: 9)),
        ),
      ));
    }
    if (node.type == UmgWidgetType.container) rows.addAll(_containerSections(node));
    if (node.type.isShadcn) rows.addAll(_shadcnFields(node));
    if (node.type == UmgWidgetType.sizeBox) {
      rows.add(_propNumber(node, 'Width', 'width', 1, 8192));
      rows.add(_propNumber(node, 'Height', 'height', 1, 8192));
    }
    if (node.type == UmgWidgetType.gridPanel) rows.add(_propNumber(node, 'Columns', 'columns', 1, 32, fractionDigits: 0, asInt: true));
    if (node.type == UmgWidgetType.widgetSwitcher) rows.add(_propNumber(node, 'Active Index', 'activeIndex', 0, 64, fractionDigits: 0, asInt: true));
    if (node.type == UmgWidgetType.scrollBox) {
      rows.add(_label('Orientation'));
      rows.add(EnumField(
        value: props['orientation']?.toString() ?? 'vertical',
        enumValues: const ['vertical', 'horizontal'],
        onCommit: (v) => vm.setProp(node.id, 'orientation', v),
      ));
    }
    if (node.type == UmgWidgetType.image) {
      rows.add(_label('Image Brush · Draw As'));
      rows.add(EnumField(
        value: props['drawAs']?.toString() ?? 'image',
        enumValues: const ['image', 'box', 'border'],
        onCommit: (v) => vm.setProp(node.id, 'drawAs', v),
      ));
      rows.add(const SizedBox(height: 4));
      rows.add(_label('Texture (TEXTURE .lmas)'));
      final textures = vm.textureAssets;
      final current = props['texture']?.toString() ?? '';
      rows.add(AssetPickerSelect(
        key: ValueKey('umg_texture_select_${node.id}'),
        keyPrefix: 'umg_texture_${node.id}',
        assets: textures,
        selectedPath: current.isEmpty ? null : current,
        placeholder: '(none)',
        onSelected: (t) => vm.bindTexture(node.id, t),
        onCleared: () => vm.bindTexture(node.id, null),
      ));
      if (textures.isEmpty) rows.add(_hint('No TEXTURE assets in this project yet — import one in the Content Browser.'));
      rows.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: GhostButton(onPressed: vm.refreshTextures, child: const Text('Rescan textures', style: TextStyle(fontSize: 9))),
      ));
    }
    if (node.type == UmgWidgetType.viewport) rows.addAll(_viewportSections(node));
    if (node.type.isTextBearing) rows.addAll(_textEffects(node));
    if (rows.isEmpty) rows.add(_hint('${node.type.displayName} has no appearance properties.'));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  // ---------------------------------------------------------------------------
  // Viewport
  // ---------------------------------------------------------------------------

  /// A Viewport's Details: background, grid, camera preset, interaction,
  /// render scale, max FPS, and the design-time preview content (a mesh
  /// and an animation picked with the asset picker; the designer only).
  List<Widget> _viewportSections(UmgNode node) {
    final p = node.props;
    Widget picker(String label, String key, List<RealAssetInfo> assets, String hint) {
      final current = p[key]?.toString() ?? '';
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label),
        AssetPickerSelect(
          key: ValueKey('umg_viewport_${key}_${node.id}'),
          keyPrefix: 'umg_viewport_${key}_${node.id}',
          assets: assets,
          selectedPath: current.isEmpty ? null : current,
          placeholder: '(none)',
          onSelected: (a) => vm.setProp(node.id, key, a.relativePath),
          onCleared: () => vm.setProp(node.id, key, ''),
        ),
        if (assets.isEmpty) _hint(hint),
      ]);
    }

    return [
      _label('Background'),
      EnumField(
        key: ValueKey('umg_viewport_background_${node.id}'),
        value: p['background']?.toString() ?? 'sky',
        enumValues: const ['sky', 'color', 'transparent'],
        onCommit: (v) => vm.setProp(node.id, 'background', v),
      ),
      _switchRow('Grid', p['grid'] != false, ValueKey('umg_viewport_grid_${node.id}'), (v) => vm.setProp(node.id, 'grid', v)),
      _label('Camera Preset'),
      EnumField(
        key: ValueKey('umg_viewport_camera_${node.id}'),
        value: p['cameraPreset']?.toString() ?? 'perspective',
        enumValues: const ['perspective', 'front', 'back', 'left', 'right', 'top'],
        onCommit: (v) => vm.setProp(node.id, 'cameraPreset', v),
      ),
      const SizedBox(height: 4),
      _label('Interaction'),
      for (final (key, label) in const [('orbit', 'Orbit'), ('pan', 'Pan'), ('zoom', 'Zoom'), ('pick', 'Pick')])
        _switchRow(label, p[key] != false, ValueKey('umg_viewport_${key}_${node.id}'), (v) => vm.setProp(node.id, key, v)),
      _propNumber(node, 'Auto Rotate', 'autoRotate', -360, 360, unit: 'deg/s'),
      _propNumber(node, 'Render Scale', 'renderScale', 0.25, 1, fractionDigits: 2),
      _propNumber(node, 'Max FPS', 'maxFps', 1, 240, fractionDigits: 0, asInt: true),
      const SizedBox(height: 6),
      picker('Preview Mesh (design time)', 'previewMesh', vm.meshAssets, 'No meshes in this project yet — import one in the Content Browser.'),
      picker('Preview Animation (design time)', 'previewAnimation', vm.animationAssets, 'No animations in this project yet.'),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: GhostButton(onPressed: vm.refreshTextures, child: const Text('Rescan assets', style: TextStyle(fontSize: 9))),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Container
  // ---------------------------------------------------------------------------

  /// Background / Border / Corners / Spacing / Shadow / Size & Alignment of
  /// a Container; every edit is one undo step.
  List<Widget> _containerSections(UmgNode node) {
    final p = node.props;
    final gradient = p['gradient'] is Map ? Map<String, dynamic>.from(p['gradient'] as Map) : null;
    final gradientType = gradient?['type']?.toString() ?? 'none';
    final gradientColors = (gradient?['colors'] as List?)?.map((c) => c.toString()).toList() ?? const ['#FB7C01FF', '#1B1B22FF'];
    final radius = p['cornerRadius'];
    final perCorner = radius is List;
    final shadows = p['shadows'] is List ? (p['shadows'] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : <Map<String, dynamic>>[];
    final shadow = shadows.isEmpty ? null : shadows.first;
    List<double> quad(Object? v) => v is List && v.length >= 4 ? [for (final e in v.take(4)) e is num ? e.toDouble() : 0.0] : (v is num ? List.filled(4, v.toDouble()) : [0.0, 0.0, 0.0, 0.0]);
    final textures = vm.textureAssets;
    final image = p['backgroundImage']?.toString() ?? '';

    void setGradient(Map<String, dynamic>? g) => vm.setProp(node.id, 'gradient', g);
    Map<String, dynamic> gradientWith(String key, Object value) => {
          'type': gradientType == 'none' ? 'linear' : gradientType,
          'colors': gradientColors,
          'begin': gradient?['begin'] ?? 'centerLeft',
          'end': gradient?['end'] ?? 'centerRight',
          'center': gradient?['center'] ?? 'center',
          'radius': gradient?['radius'] ?? 0.5,
          key: value,
        };
    void setShadow(String key, Object value, {bool commit = true}) {
      final next = Map<String, dynamic>.of(shadow ?? const {'color': '#00000066', 'offsetX': 0.0, 'offsetY': 4.0, 'blur': 12.0, 'spread': 0.0});
      next[key] = value;
      vm.beginInteraction('Shadow ${node.name}');
      vm.previewProp(node.id, 'shadows', [next, ...shadows.skip(1)]);
      if (commit) vm.endInteraction();
    }

    const alignNames = ['fill', ...['topLeft', 'topCenter', 'topRight', 'centerLeft', 'center', 'centerRight', 'bottomLeft', 'bottomCenter', 'bottomRight']];
    return [
      const SizedBox(height: 4),
      _groupHeader('Background', LucideIcons.paintBucket, ValueKey('umg_group_background_${node.id}')),
      _label('Background Color'),
      _propColor(node, 'Background Color', 'backgroundColor', alpha: true),
      const SizedBox(height: 4),
      _label('Gradient'),
      EnumField(
        key: ValueKey('umg_gradient_type_${node.id}'),
        value: gradientType,
        enumValues: const ['none', 'linear', 'radial'],
        onCommit: (v) => setGradient(v == 'none' ? null : gradientWith('type', v)),
      ),
      if (gradient != null) ...[
        _label('Gradient Start'),
        _colorRow(node, 'umg_gradient_start_${node.id}', gradientColors.first, (v) => setGradient(gradientWith('colors', [v, ...gradientColors.skip(1)]))),
        _label('Gradient End'),
        _colorRow(node, 'umg_gradient_end_${node.id}', gradientColors.last, (v) => setGradient(gradientWith('colors', [...gradientColors.take(gradientColors.length - 1), v]))),
        if (gradientType == 'linear') ...[
          _label('Begin'),
          EnumField(value: gradient['begin']?.toString() ?? 'centerLeft', enumValues: alignNames.skip(1).toList(), onCommit: (v) => setGradient(gradientWith('begin', v))),
          _label('End'),
          EnumField(value: gradient['end']?.toString() ?? 'centerRight', enumValues: alignNames.skip(1).toList(), onCommit: (v) => setGradient(gradientWith('end', v))),
        ] else ...[
          _label('Center'),
          EnumField(value: gradient['center']?.toString() ?? 'center', enumValues: alignNames.skip(1).toList(), onCommit: (v) => setGradient(gradientWith('center', v))),
          _numberRow(node, 'Radius', 'gradient_radius', (gradient['radius'] as num?)?.toDouble() ?? 0.5, 0.5, (v) => setGradient(gradientWith('radius', v)), min: 0, max: 2, slider: true),
        ],
      ],
      _label('Background Image (TEXTURE .lmas)'),
      AssetPickerSelect(
        key: ValueKey('umg_bg_texture_select_${node.id}'),
        keyPrefix: 'umg_bg_texture_${node.id}',
        assets: textures,
        selectedPath: image.isEmpty ? null : image,
        placeholder: '(none)',
        onSelected: (t) => vm.bindTexture(node.id, t),
        onCleared: () => vm.bindTexture(node.id, null),
      ),
      _label('Image Fit'),
      EnumField(
        value: p['backgroundFit']?.toString() ?? 'cover',
        enumValues: const ['cover', 'contain', 'fill', 'fitWidth', 'fitHeight', 'none', 'scaleDown'],
        onCommit: (v) => vm.setProp(node.id, 'backgroundFit', v),
      ),
      const SizedBox(height: 4),
      _groupHeader('Border', LucideIcons.square, ValueKey('umg_group_border_${node.id}')),
      _label('Border Color'),
      _propColor(node, 'Border Color', 'borderColor', alpha: true),
      _propSlider(node, 'Width', 'borderWidth', 0, 32, unit: 'px'),
      for (final (i, side) in const ['Top', 'Right', 'Bottom', 'Left'].indexed)
        _switchRow('$side Side', (p['borderSides'] is List && (p['borderSides'] as List).length > i) ? (p['borderSides'] as List)[i] != false : true,
            ValueKey('umg_border_side_${side.toLowerCase()}_${node.id}'), (v) {
          final sides = [for (var j = 0; j < 4; j++) (p['borderSides'] is List && (p['borderSides'] as List).length > j) ? (p['borderSides'] as List)[j] != false : true];
          sides[i] = v;
          vm.setProp(node.id, 'borderSides', sides);
        }),
      const SizedBox(height: 4),
      _groupHeader('Corners', LucideIcons.squareRoundCorner, ValueKey('umg_group_corners_${node.id}')),
      _switchRow('Per Corner', perCorner, ValueKey('umg_corner_per_corner_${node.id}'), (v) {
        final q = quad(radius);
        vm.setProp(node.id, 'cornerRadius', v ? q : q.first);
      }),
      if (!perCorner)
        _propSlider(node, 'Radius', 'cornerRadius', 0, 128, unit: 'px')
      else
        for (final (i, corner) in const ['Top Left', 'Top Right', 'Bottom Right', 'Bottom Left'].indexed)
          _numberRow(node, corner, 'corner_$i', quad(radius)[i], 0, (v) {
            final q = quad(node.props['cornerRadius']);
            q[i] = v;
            return q;
          }.call, min: 0, max: 128, slider: true, listKey: 'cornerRadius'),
      const SizedBox(height: 4),
      _groupHeader('Spacing', LucideIcons.move, ValueKey('umg_group_spacing_${node.id}')),
      for (final key in const ['padding', 'margin'])
        for (final (i, side) in const ['Left', 'Top', 'Right', 'Bottom'].indexed)
          _numberRow(node, '${key == 'padding' ? 'Padding' : 'Margin'} $side', '${key}_$i', quad(p[key])[i], 0, (v) {
            final q = quad(node.props[key]);
            q[i] = v;
            return q;
          }.call, min: 0, max: 512, listKey: key),
      const SizedBox(height: 4),
      _groupHeader('Shadow', LucideIcons.squareStack, ValueKey('umg_group_box_shadow_${node.id}')),
      _switchRow('Drop Shadow', shadow != null, ValueKey('umg_box_shadow_enabled_${node.id}'), (v) {
        vm.setProp(node.id, 'shadows', v ? [const {'color': '#00000066', 'offsetX': 0.0, 'offsetY': 4.0, 'blur': 12.0, 'spread': 0.0}] : <Map<String, dynamic>>[]);
      }),
      if (shadow != null) ...[
        _label('Shadow Color'),
        _colorRow(node, 'umg_box_shadow_color_${node.id}', shadow['color']?.toString() ?? '#00000066', (v) => setShadow('color', v)),
        for (final (key, label, min, max) in const [('offsetX', 'Offset X', -64.0, 64.0), ('offsetY', 'Offset Y', -64.0, 64.0), ('blur', 'Blur', 0.0, 64.0), ('spread', 'Spread', -32.0, 32.0)])
          _numberRow(node, label, 'box_shadow_$key', (shadow[key] as num?)?.toDouble() ?? 0, 0, (v) => setShadow(key, v, commit: false),
              min: min, max: max, slider: key == 'blur', onCommitOverride: (v) => setShadow(key, v)),
      ],
      const SizedBox(height: 4),
      _groupHeader('Size & Alignment', LucideIcons.scaling, ValueKey('umg_group_size_${node.id}')),
      _hint('0 = automatic size.'),
      for (final (key, label) in const [('width', 'Width'), ('height', 'Height'), ('minWidth', 'Min Width'), ('maxWidth', 'Max Width'), ('minHeight', 'Min Height'), ('maxHeight', 'Max Height')])
        _numberRow(node, label, 'size_$key', (p[key] as num?)?.toDouble() ?? 0, 0, (v) => v <= 0 ? null : v, min: 0, max: 8192, listKey: key),
      _label('Child Alignment'),
      EnumField(
        key: ValueKey('umg_container_alignment_${node.id}'),
        value: p['alignment']?.toString() ?? 'fill',
        enumValues: alignNames,
        onCommit: (v) => vm.setProp(node.id, 'alignment', v == 'fill' ? null : v),
      ),
    ];
  }

  /// A colour field with alpha committing through [onCommit] (one step).
  Widget _colorRow(UmgNode node, String key, String value, void Function(String) onCommit) => ColorField(
        key: ValueKey(key),
        value: value,
        defaultValue: value,
        showAlpha: true,
        onChanged: (_) {},
        onCommit: onCommit,
        onReset: () {},
      );

  /// A number row: [toValue] maps the edited number to the prop value stored
  /// under [listKey] (the whole list for a side / corner, null for "auto");
  /// without [listKey] the caller applies it in [toValue] itself. Scrubbing
  /// previews, release commits one undo step.
  Widget _numberRow(
    UmgNode node,
    String label,
    String id,
    double value,
    double defaultValue,
    Object? Function(double v) toValue, {
    double? min,
    double? max,
    bool slider = false,
    String? listKey,
    void Function(double v)? onCommitOverride,
  }) {
    void preview(double v) {
      final next = toValue(v);
      if (listKey == null) return;
      vm.beginInteraction('$label ${node.name}');
      vm.previewProp(node.id, listKey, next);
    }

    void commit(double v) {
      if (onCommitOverride != null) return onCommitOverride(v);
      preview(v);
      vm.endInteraction();
    }

    final field = slider
        ? SliderField(
            key: ValueKey('umg_prop_${id}_${node.id}'),
            value: value,
            defaultValue: defaultValue,
            min: min ?? 0,
            max: max ?? 100,
            fractionDigits: 1,
            onChanged: preview,
            onCommit: commit,
            onReset: () => commit(defaultValue),
          )
        : ScrubNumericField(
            key: ValueKey('umg_prop_${id}_${node.id}'),
            label: '',
            value: value,
            defaultValue: defaultValue,
            min: min,
            max: max,
            fractionDigits: 1,
            onChanged: preview,
            onCommit: commit,
            onReset: () => commit(defaultValue),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        SizedBox(width: 64, child: Text(label, style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground))),
        Expanded(child: field),
      ]),
    );
  }
}
