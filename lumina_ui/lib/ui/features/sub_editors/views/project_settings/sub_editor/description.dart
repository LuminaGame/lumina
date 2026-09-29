part of '../../project_settings_sub_editor.dart';

/// Description & Branding category, including the project icon picker.
mixin _ProjectSettingsDescription on _ProjectSettingsSubEditorStateBase {

  // Description & Branding
  @override
  Widget _buildDescription() {
    final p = _vm.project;
    return _section('Description & Branding', [
      _row(
        'Project Name',
        TextField(
          key: const ValueKey('project_settings_name'),
          controller: _controllerFor('name', p.projectName),
          focusNode: _focusFor('name'),
          onChanged: _vm.setProjectName,
        ),
        help: 'Letters, digits and underscores only',
      ),
      _row('Engine Version', Align(alignment: Alignment.centerLeft, child: SecondaryBadge(child: Text(p.engineVersion)))),
      _row(
        'Description',
        TextField(
          key: const ValueKey('project_settings_description'),
          controller: _controllerFor('description', p.description),
          focusNode: _focusFor('description'),
          maxLines: 3,
          onChanged: _vm.setDescription,
        ),
      ),
      _row(
        'Project Icon',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              key: const ValueKey('project_settings_icon_preview'),
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: _iconBackgroundColor(p.branding) ?? EditorColors.background,
                border: Border.all(color: EditorColors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: _iconPreview(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                p.branding.usesDefaultIcon ? 'Lumina logo (default)' : p.branding.icon,
                key: const ValueKey('project_settings_icon_path'),
                style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground),
              ),
            ),
            OutlineButton(
              key: const ValueKey('project_settings_icon_choose'),
              onPressed: _chooseIcon,
              child: const Text('Choose…', style: TextStyle(fontSize: 10)),
            ),
            const SizedBox(width: 6),
            GhostButton(
              key: const ValueKey('project_settings_icon_default'),
              onPressed: p.branding.usesDefaultIcon ? null : _vm.useDefaultIcon,
              child: const Text('Use Lumina Logo', style: TextStyle(fontSize: 10)),
            ),
          ]),
          if (_vm.iconStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_vm.iconStatus!, key: const ValueKey('project_settings_icon_status'), style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
            ),
          if (_vm.iconError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_vm.iconError!, key: const ValueKey('project_settings_icon_error'), style: const TextStyle(fontSize: 9, color: EditorColors.logError)),
            ),
        ]),
        help: 'The app icon of every packaged target: window, launcher, file manager, browser tab. SVG, PNG, JPG or WebP.',
      ),
      _row(
        'Icon Background',
        Row(children: [
          Container(
            key: const ValueKey('project_settings_icon_background_swatch'),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _iconBackgroundColor(p.branding) ?? Colors.transparent,
              border: Border.all(color: EditorColors.border),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: TextField(
              key: const ValueKey('project_settings_icon_background'),
              controller: _controllerFor('icon_background', p.branding.iconBackground),
              focusNode: _focusFor('icon_background'),
              onChanged: _vm.setIconBackground,
            ),
          ),
        ]),
        help: 'Behind the icon where a platform needs an opaque one (Android adaptive, iOS, web maskable)',
      ),
      _row(
        'Monochrome Icon',
        Row(children: [
          Image.asset('assets/logo_white.png', height: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('assets/logo_white.png — monochrome system tray icon of the editor; not used as an app icon',
                style: TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
          ),
        ]),
        help: 'System tray',
      ),
    ]);
  }

  /// The effective project icon: its file (SVG or raster), or the Lumina logo.
  Widget _iconPreview() {
    final file = _vm.iconFile;
    if (file == null) return Image.asset(ProjectIconRasterizer.defaultIconAsset, fit: BoxFit.contain);
    if (!file.existsSync()) return const Icon(LucideIcons.imageOff, size: 20, color: EditorColors.logError);
    return file.path.toLowerCase().endsWith('.svg')
        ? SvgPicture.file(file, key: ValueKey('icon_${file.lastModifiedSync().microsecondsSinceEpoch}'), fit: BoxFit.contain)
        : Image.file(file, key: ValueKey('icon_${file.lastModifiedSync().microsecondsSinceEpoch}'), fit: BoxFit.contain);
  }

  Future<void> _chooseIcon() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose the project icon',
      type: FileType.custom,
      allowedExtensions: ProjectIconRasterizer.supportedExtensions,
    );
    final path = result?.files.single.path;
    if (path != null) await _vm.chooseIcon(path);
  }
}

Color? _iconBackgroundColor(ProjectBrandingSettings b) {
  final argb = b.iconBackgroundArgb;
  return argb == null ? null : Color(argb);
}
