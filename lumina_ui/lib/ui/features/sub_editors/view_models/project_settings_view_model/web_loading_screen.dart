part of '../project_settings_view_model.dart';

/// The web build's loading screen: style fields, logo, the written
/// loading screen and its browser preview.
mixin _ProjectSettingsWebLoadingScreen on _ProjectSettingsViewModelState {

  // Web Loading Style

  /// The working copy's web loading screen style.
  ProjectWebLoadingStyle get webLoadingStyle => project.packaging.webLoadingStyle;

  /// [webLoadingStyle] with the project's fallbacks applied (what the page shows).
  ResolvedWebLoadingStyle get resolvedWebLoadingStyle => webLoadingStyle.resolve(project);

  void updateWebLoadingStyle(ProjectWebLoadingStyle Function(ProjectWebLoadingStyle style) edit) =>
      _update((p) => p.copyWith(packaging: p.packaging.copyWith(webLoadingStyle: edit(p.packaging.webLoadingStyle))));

  void setWebLoadingBackground(String hex) => updateWebLoadingStyle((s) => s.copyWith(background: hex.trim()));
  void setWebLoadingAccent(String hex) => updateWebLoadingStyle((s) => s.copyWith(accent: hex.trim()));
  void setWebLoadingText(String hex) => updateWebLoadingStyle((s) => s.copyWith(text: hex.trim()));
  void setWebLoadingGradient(String hex) => updateWebLoadingStyle((s) => s.copyWith(gradient: hex.trim()));
  void setWebLoadingTitle(String title) => updateWebLoadingStyle((s) => s.copyWith(title: title));
  void setWebLoadingSubtitle(String subtitle) => updateWebLoadingStyle((s) => s.copyWith(subtitle: subtitle));
  void setWebLoadingProgressStyle(String style) => updateWebLoadingStyle((s) => s.copyWith(progressStyle: style));
  void setWebLoadingFadeMs(int ms) => updateWebLoadingStyle((s) => s.copyWith(fadeMs: ms.clamp(0, ProjectWebLoadingStyle.maxFadeMs)));

  /// Turns the gradient on (fading the background to a darker shade of
  /// itself) or off.
  void setWebLoadingGradientEnabled(bool on) {
    if (!on) return setWebLoadingGradient('');
    if (webLoadingStyle.gradient.isNotEmpty) return;
    final argb = ResolvedWebLoadingStyle.argb(resolvedWebLoadingStyle.background);
    int darker(int shift) => (((argb >> shift) & 0xFF) * 0.35).round();
    String hex(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
    setWebLoadingGradient('#${hex(darker(16))}${hex(darker(8))}${hex(darker(0))}');
  }

  /// What the last loading-screen action did.
  String? get webLoadingStatus => _webLoadingStatus;

  /// Why the last loading-screen action failed.
  String? get webLoadingError => _webLoadingError;

  /// The chosen logo image, or null when the logo is the project icon or none.
  File? get webLoadingLogoFile {
    final logo = webLoadingStyle.logo;
    if (logo == ProjectWebLoadingStyle.logoFromIcon || logo == ProjectWebLoadingStyle.logoNone || logo.isEmpty) return null;
    return File('$projectDirPath/$logo');
  }

  /// Copies [sourcePath] into `<project>/branding/web_loading_logo.<ext>` and
  /// makes it the loading screen's logo. Returns why it was refused, or null.
  Future<String?> chooseWebLoadingLogo(String sourcePath) async {
    if (_working == null) return 'No project loaded';
    final source = File(sourcePath);
    final ext = sourcePath.split('.').last.toLowerCase();
    String? problem;
    if (!source.existsSync()) {
      problem = '$sourcePath does not exist';
    } else if (!ProjectWebLoadingStyle.logoExtensions.contains(ext)) {
      problem = 'A web loading logo must be a ${ProjectWebLoadingStyle.logoExtensions.join(', ')} file';
    }
    if (problem != null) {
      _webLoadingError = problem;
      _logger.log(problem, level: 'error', source: 'ProjectSettings');
      notifyListeners();
      return problem;
    }
    final dir = Directory('$projectDirPath/branding')..createSync(recursive: true);
    final rel = 'branding/web_loading_logo.$ext';
    for (final old in dir.listSync().whereType<File>()) {
      if (old.uri.pathSegments.last.startsWith('web_loading_logo.') && !old.path.endsWith('/web_loading_logo.$ext')) old.deleteSync();
    }
    final target = File('$projectDirPath/$rel');
    if (source.absolute.path != target.absolute.path) source.copySync(target.path);
    _webLoadingError = null;
    _webLoadingStatus = 'Copied ${source.uri.pathSegments.last} into $rel';
    updateWebLoadingStyle((s) => s.copyWith(logo: rel));
    return null;
  }

  /// The loading screen shows the project icon.
  void useProjectIconAsWebLoadingLogo() => updateWebLoadingStyle((s) => s.copyWith(logo: ProjectWebLoadingStyle.logoFromIcon));

  /// The loading screen shows no logo.
  void useNoWebLoadingLogo() => updateWebLoadingStyle((s) => s.copyWith(logo: ProjectWebLoadingStyle.logoNone));

  /// The project icon as the loading screen's logo (512 px), or null when
  /// the style names another logo.
  Future<Uint8List?> _webLoadingIconPng(LuminaProject project) async =>
      project.packaging.webLoadingStyle.resolve(project).logo == ProjectWebLoadingStyle.logoFromIcon
          ? ProjectIconRasterizer.masterPng(projectDirPath, project.branding, size: 512)
          : null;

  Future<void> _writeWebLoadingScreen(LuminaProject project) async {
    try {
      final report = WebLoadingScreenService.write(projectDir: projectDirPath, project: project, iconPng: await _webLoadingIconPng(project));
      _webLoadingError = report.warnings.isEmpty ? null : report.warnings.join('; ');
      _webLoadingStatus = 'Wrote the web loading screen (${report.files.join(', ')})';
      _logger.log(_webLoadingStatus!, level: 'success', source: 'ProjectSettings');
    } catch (e) {
      _webLoadingError = 'The web loading screen was not written: $e';
      _logger.log(_webLoadingError!, level: 'error', source: 'ProjectSettings');
    }
  }

  /// Where the browser preview is served, once opened.
  Uri? get webLoadingPreviewUrl => _webLoadingPreviewUrl;

  /// Where the browser preview's page is written.
  String get webLoadingPreviewDir => '${project.packaging.outputDirIn(projectDirPath)}/web_loading_preview';

  /// Writes the working copy's loading screen (the same generated page, in
  /// its preview mode: no game behind it, a demo progress) into
  /// [webLoadingPreviewDir], serves it on localhost and opens it in the
  /// browser. Returns the URL, or null when it could not be served.
  Future<Uri?> previewWebLoadingInBrowser() async {
    if (_working == null) return null;
    final Uri url;
    try {
      final dir = webLoadingPreviewDir;
      final report = WebLoadingScreenService.write(
        projectDir: projectDirPath,
        project: project,
        iconPng: await _webLoadingIconPng(project),
        outDir: dir,
        preview: true,
      );
      _webLoadingError = report.warnings.isEmpty ? null : report.warnings.join('; ');
      url = await _webLoadingPreview.start(dir);
    } catch (e) {
      _webLoadingError = 'The loading screen preview could not be served: $e';
      _logger.log(_webLoadingError!, level: 'error', source: 'ProjectSettings');
      notifyListeners();
      return null;
    }
    _webLoadingPreviewUrl = url;
    _webLoadingStatus = 'Previewing the loading screen at $url';
    notifyListeners();
    try {
      await (openUrl ?? BuildManagerViewModel.openInSystemBrowser)(url);
      _logger.log('Opened the web loading screen preview at $url', level: 'success', source: 'ProjectSettings');
    } catch (e) {
      _webLoadingError = 'Could not open a browser ($e). Open $url yourself.';
    }
    if (!_disposed) notifyListeners();
    return url;
  }
}
