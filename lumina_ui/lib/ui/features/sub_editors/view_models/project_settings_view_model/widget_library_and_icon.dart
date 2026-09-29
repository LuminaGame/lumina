part of '../project_settings_view_model.dart';

/// Project → Widget library switching and the app icon (choose, default,
/// background, writing the platform icon files).
mixin _ProjectSettingsWidgetLibraryAndIcon on _ProjectSettingsViewModelState {

  // User Interface
  void setWidgetLibrary(String library) {
    if (!kUmgWidgetLibraries.contains(library)) return;
    _widgetLibraryError = null;
    _update((p) => p.copyWith(ui: p.ui.copyWith(widgetLibrary: library)));
  }

  /// Progress / result of the last library switch.
  String? get widgetLibraryStatus => _widgetLibraryStatus;

  /// Why the last switch was refused (e.g. `flutter pub get` failed).
  String? get widgetLibraryError => _widgetLibraryError;

  /// The shadcn components of the project's widgets
  /// (`WBP_Menu: Start (Primary Button)`), which a switch to plain Flutter
  /// would leave uncompilable; empty unless the chosen library is plain.
  List<String> get shadcnWidgetsBlockingPlain {
    if (project.ui.widgetLibrary != kUmgWidgetLibraryFlutter) return const [];
    return [
      for (final e in UmgWidgetCodegen.widgetDocuments(projectDirPath).entries)
        for (final n in UmgWidgetValidator.shadcnNodes(e.value)) '${e.key}: ${n.name} (${n.type.displayName})',
    ];
  }

  /// Makes the pubspec match [to] and resolves it; restores [from] when
  /// `flutter pub get` fails.
  Future<bool> _switchWidgetLibrary(String from, String to) async {
    _widgetLibraryError = null;
    if (!File('$projectDirPath/pubspec.yaml').existsSync()) return true;
    if (!UmgWidgetLibraryService.apply(projectDirPath, to)) return true;
    _widgetLibraryStatus = 'Running flutter pub get…';
    notifyListeners();
    var lastError = '';
    int code;
    try {
      final proc = await _processStarter('flutter', ['pub', 'get'], workingDirectory: projectDirPath);
      final out = proc.stdout.drain<void>();
      final err = proc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((l) {
        if (l.trim().isNotEmpty) lastError = l.trim();
      }).asFuture<void>();
      code = await proc.exitCode;
      await Future.wait([out, err]);
    } catch (e) {
      code = -1;
      lastError = '$e';
    }
    if (code == 0) return true;
    UmgWidgetLibraryService.apply(projectDirPath, from);
    _widgetLibraryStatus = null;
    _widgetLibraryError = 'flutter pub get failed (exit $code)${lastError.isEmpty ? '' : ': $lastError'}. Nothing was changed.';
    _logger.log(_widgetLibraryError!, level: 'error', source: 'ProjectSettings');
    return false;
  }

  /// What the last icon action did ("Wrote 52 app-icon files…").
  String? get iconStatus => _iconStatus;

  /// Why the last icon action failed.
  String? get iconError => _iconError;

  /// The project icon file (null: the Lumina logo).
  File? get iconFile => _working == null ? null : ProjectIconRasterizer.iconFile(projectDirPath, _working!.branding);

  /// Copies [sourcePath] into `<project>/branding/app_icon.<ext>` and makes
  /// it the project icon. The file must be an SVG, PNG, JPG or WebP that
  /// actually renders. Returns why it was refused, or null.
  Future<String?> chooseIcon(String sourcePath) async {
    if (_working == null) return 'No project loaded';
    final source = File(sourcePath);
    final ext = sourcePath.split('.').last.toLowerCase();
    String? problem;
    if (!source.existsSync()) {
      problem = '$sourcePath does not exist';
    } else if (!ProjectIconRasterizer.supportedExtensions.contains(ext)) {
      problem = 'A project icon must be an ${ProjectIconRasterizer.supportedExtensions.join(', ')} file';
    } else {
      try {
        await ProjectIconRasterizer.rasterizeFile(source, size: 64);
      } catch (e) {
        problem = '$sourcePath cannot be used as an icon: $e';
      }
    }
    if (problem != null) {
      _iconError = problem;
      _logger.log(problem, level: 'error', source: 'ProjectSettings');
      notifyListeners();
      return problem;
    }
    final dir = Directory('$projectDirPath/branding')..createSync(recursive: true);
    final rel = 'branding/app_icon.$ext';
    // One icon file in the project: an older one with another extension goes.
    for (final old in dir.listSync().whereType<File>()) {
      if (old.uri.pathSegments.last.startsWith('app_icon.') && !old.path.endsWith('/app_icon.$ext')) old.deleteSync();
    }
    final target = File('$projectDirPath/$rel');
    if (source.absolute.path != target.absolute.path) source.copySync(target.path);
    _iconError = null;
    _iconStatus = 'Copied ${source.uri.pathSegments.last} into $rel. Apply & Save writes it into every platform folder.';
    _update((p) => p.copyWith(branding: p.branding.copyWith(icon: rel)));
    return null;
  }

  /// Back to the Lumina logo.
  void useDefaultIcon() {
    _iconError = null;
    _iconStatus = 'The Lumina logo is the project icon. Apply & Save writes it into every platform folder.';
    _update((p) => p.copyWith(branding: p.branding.copyWith(icon: '')));
  }

  void setIconBackground(String hex) => _update((p) => p.copyWith(branding: p.branding.copyWith(iconBackground: hex.trim())));

  /// Writes the app-icon files of every platform folder the project has, so
  /// `flutter run` shows the icon too (packaging rewrites them per target).
  Future<void> _writeAppIcons(LuminaProject project) async {
    try {
      final master = await ProjectIconRasterizer.masterPng(projectDirPath, project.branding);
      final report = await AppIconService.writeAsync(
        projectDir: projectDirPath,
        masterPng: master,
        appName: project.projectName,
        backgroundArgb: project.branding.iconBackgroundArgb ?? 0xFF000000,
      );
      final written = report.platforms.values.where((p) => p.written).map((p) => p.platform).toList();
      _iconError = null;
      _iconStatus = written.isEmpty
          ? 'No platform folder to write the app icon into (${report.summary()})'
          : 'Wrote ${report.writtenFiles.length} app-icon files for ${written.map(packagingPlatformLabel).join(', ')}';
      _logger.log(_iconStatus!, level: written.isEmpty ? 'warning' : 'success', source: 'ProjectSettings');
    } catch (e) {
      _iconError = 'The app icons were not written: $e';
      _logger.log(_iconError!, level: 'error', source: 'ProjectSettings');
    }
  }
}
