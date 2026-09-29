part of '../../project_settings_sub_editor.dart';

/// Editor chrome (header, load error, category nav, category body, footer)
/// and the shared section / row / select builders.
mixin _ProjectSettingsLayout on _ProjectSettingsSubEditorStateBase {

  Widget _buildHeader() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          Image.asset('assets/logo_color.png', height: 18),
          const SizedBox(width: 8),
          const Text('Project Settings',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
          const SizedBox(width: 16),
          SizedBox(
            width: 220,
            height: 26,
            child: TextField(
              key: const ValueKey('project_settings_search'),
              controller: _searchController,
              placeholder: const Text('Search settings...', style: TextStyle(fontSize: 10)),
              onChanged: _vm.setFilterQuery,
            ),
          ),
          const Spacer(),
          if (widget.onClose != null)
            GhostButton(onPressed: widget.onClose!, child: const Icon(LucideIcons.x, size: 14)),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.triangleAlert, size: 28, color: EditorColors.logError),
          const SizedBox(height: 8),
          Text(_vm.loadError ?? 'No project loaded', style: const TextStyle(fontSize: 11, color: EditorColors.foreground)),
          const SizedBox(height: 8),
          OutlineButton(onPressed: _vm.load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildNav() {
    final visible = _vm.visibleCategories;
    if (!visible.contains(_activeCategory) && visible.isNotEmpty) {
      _activeCategory = visible.first;
    }
    return Container(
      width: 220,
      color: EditorColors.cardHeader,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SETTINGS CATEGORY',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.primary)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final (i, cat) in visible.indexed) ...[
                  // The plugins' pages under their own heading.
                  if (ProjectSettingsViewModel.isPluginCategory(cat) && (i == 0 || !ProjectSettingsViewModel.isPluginCategory(visible[i - 1])))
                    const Padding(
                      key: ValueKey('project_settings_nav_plugins_header'),
                      padding: EdgeInsets.fromLTRB(2, 10, 2, 6),
                      child: Text('PLUGINS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: EditorColors.primary)),
                    ),
                  GestureDetector(
                    key: ValueKey('project_settings_nav_$cat'),
                    onTap: () => setState(() => _activeCategory = cat),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: _activeCategory == cat
                            ? EditorColors.primary.withValues(alpha: 0.2)
                            : EditorColors.cardHeader,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _vm.categoryTitle(cat),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: _activeCategory == cat ? FontWeight.bold : FontWeight.normal,
                                color: _activeCategory == cat ? EditorColors.primary : EditorColors.foreground,
                              ),
                            ),
                          ),
                          if (_vm.errorCount(cat) > 0)
                            DestructiveBadge(
                              child: Text('${_vm.errorCount(cat)}', style: const TextStyle(fontSize: 9)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('No settings match your search', style: TextStyle(fontSize: 10, color: EditorColors.mutedForeground)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBody() {
    final errors = _vm.validationErrors[_activeCategory] ?? const [];
    final warnings = _vm.validationWarnings[_activeCategory] ?? const [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(_vm.categoryTitle(_activeCategory).toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: EditorColors.primary)),
        const SizedBox(height: 12),
        // One child whatever the message count: the category's editors keep
        // their list slot, so a field whose half-typed value adds an error
        // (a background colour typed character by character) keeps its
        // element and its focus.
        Column(
          key: const ValueKey('project_settings_messages'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in errors) _messageRow(e, isError: true),
            for (final w in warnings) _messageRow(w, isError: false),
            if (errors.isNotEmpty || warnings.isNotEmpty) const SizedBox(height: 8),
          ],
        ),
        switch (_activeCategory) {
          ProjectSettingsCategory.description => _buildDescription(),
          ProjectSettingsCategory.graphics => _buildGraphics(),
          ProjectSettingsCategory.input => _buildInput(),
          ProjectSettingsCategory.mapsAndModes => _buildMapsAndModes(),
          ProjectSettingsCategory.physics => _buildPhysics(),
          ProjectSettingsCategory.packaging => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _buildPackaging(),
              // Only a web build has the HTML loading screen.
              if (_vm.project.packaging.isSelected('web')) WebLoadingStyleSection(viewModel: _vm, section: _section, row: _row),
            ]),
          ProjectSettingsCategory.userInterface => _buildUserInterface(),
          _ => _buildPluginSection(),
        },
      ],
    );
  }

  /// A plugin's page, editing its `plugin_settings` block.
  Widget _buildPluginSection() {
    final entry = _vm.pluginSectionOf(_activeCategory);
    if (entry == null) return const SizedBox.shrink();
    final (plugin, section) = entry;
    return KeyedSubtree(
      key: ValueKey('project_settings_plugin_section_${plugin}_${section.id}'),
      child: Builder(builder: (context) => section.builder(context, _vm.pluginHandle(plugin))),
    );
  }

  Widget _messageRow(String text, {required bool isError}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(isError ? LucideIcons.circleX : LucideIcons.triangleAlert,
              size: 12, color: isError ? EditorColors.logError : Colors.amber),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 10, color: isError ? EditorColors.logError : Colors.amber))),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final dirty = _vm.isDirty;
    final hasErrors = _vm.validationErrors.values.any((l) => l.isNotEmpty);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: EditorColors.cardHeader,
      child: Row(
        children: [
          if (dirty)
            const OutlineBadge(child: Text('Unsaved changes', style: TextStyle(fontSize: 9)))
          else
            const Text('All settings saved', style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          if (_vm.manifestPath != null) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(_vm.manifestPath!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
            ),
          ] else
            const Spacer(),
          OutlineButton(
            key: const ValueKey('project_settings_revert'),
            onPressed: dirty ? () => _vm.revert() : null,
            child: const Text('Revert'),
          ),
          const SizedBox(width: 8),
          PrimaryButton(
            key: const ValueKey('project_settings_apply'),
            onPressed: (dirty && !hasErrors) ? () => _vm.apply() : null,
            child: const Text('Apply & Save'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- sections

  @override
  Widget _section(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: EditorColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: EditorColors.cardHeader,
            child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: EditorColors.foreground)),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }

  /// A labelled settings row. Rows that do not match the search are dimmed
  /// (state preserved) and matching rows get a highlight.
  @override
  Widget _row(String label, Widget control, {String? help}) {
    final matches = _vm.rowMatches(label) || (help != null && _vm.rowMatches(help));
    final searching = _vm.filterQuery.isNotEmpty;
    return Opacity(
      opacity: searching && !matches ? 0.35 : 1.0,
      child: Container(
        key: ValueKey('project_settings_row_$label'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: searching && matches ? EditorColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 170,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: EditorColors.foreground)),
                  if (help != null)
                    Text(help, style: const TextStyle(fontSize: 8.5, color: EditorColors.mutedForeground)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: control),
          ],
        ),
      ),
    );
  }

  @override
  Widget _select(String value, List<String> options, void Function(String) onChanged, {String Function(String)? label}) {
    final safeValue = options.contains(value) ? value : (options.isNotEmpty ? options.first : value);
    return Select<String>(
      value: safeValue,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      itemBuilder: (context, item) => Text(label?.call(item) ?? item, style: const TextStyle(fontSize: 10.5)),
      popup: SelectPopup(
        items: SelectItemList(
          children: [
            for (final o in options)
              SelectItemButton(value: o, child: Text(label?.call(o) ?? o, style: const TextStyle(fontSize: 10.5))),
          ],
        ),
      ).call,
    );
  }
}
