part of '../project_settings_view_model.dart';

/// Packaging > Android (Meta Quest): the working copy's Android settings and
/// the read-only preview of the manifest a build would compose.
mixin _ProjectSettingsPackagingAndroid on _ProjectSettingsViewModelState {
  ProjectAndroidSettings get androidSettings => (_working?.packaging ?? const ProjectPackagingSettings()).android;

  void _setAndroid(ProjectAndroidSettings android) {
    _update((p) => p.copyWith(packaging: p.packaging.copyWith(android: android)));
    _androidPreviewStale = true;
  }

  /// The XR profile ([kAndroidXrProfiles]); Quest applies its SDK floors,
  /// arm64 only and Impeller off.
  void setAndroidXrProfile(String profile) => _setAndroid(androidSettings.withXrProfile(profile));
  void setAndroidApplicationId(String id) => _setAndroid(androidSettings.copyWith(applicationId: id.trim()));
  void setAndroidVersionName(String v) => _setAndroid(androidSettings.copyWith(versionName: v.trim()));
  void setAndroidVersionCode(String v) {
    final code = int.tryParse(v.trim());
    if (code != null && code > 0) _setAndroid(androidSettings.copyWith(versionCode: code));
  }

  void setAndroidMinSdk(String v) {
    final level = int.tryParse(v.trim());
    if (level != null && level > 0) _setAndroid(androidSettings.copyWith(minSdk: level));
  }

  void setAndroidTargetSdk(String v) {
    final level = int.tryParse(v.trim());
    if (level != null && level > 0) _setAndroid(androidSettings.copyWith(targetSdk: level));
  }

  void setAndroidRefreshRate(int hz) => _setAndroid(androidSettings.copyWith(refreshRate: hz));
  void setAndroidMultiview(bool on) => _setAndroid(androidSettings.copyWith(multiview: on));
  void setAndroidImpeller(bool on) => _setAndroid(androidSettings.copyWith(impeller: on));
  void setAndroidKeystorePath(String v) => _setAndroid(androidSettings.copyWith(keystorePath: v.trim()));
  void setAndroidKeyAlias(String v) => _setAndroid(androidSettings.copyWith(keyAlias: v.trim()));

  /// The id a build uses (the default when the field is empty).
  String get androidApplicationId => androidSettings.applicationIdFor(_working?.projectName ?? 'game');

  /// Why the application id field is invalid, or null.
  String? get androidApplicationIdProblem => ProjectAndroidSettings.applicationIdProblem(androidSettings.applicationId);

  bool _androidPreviewStale = true;
  bool _androidPreviewLoading = false;
  ComposedAndroidManifest? _androidPreview;
  String? _androidPreviewError;

  /// The manifest the next Android build composes, line by line with each
  /// line's source; null until [refreshAndroidPreview] finished.
  ComposedAndroidManifest? get androidManifestPreview => _androidPreview;
  bool get androidPreviewLoading => _androidPreviewLoading;

  /// Why there is no preview (no Android app in the project, unreadable
  /// plugins), or null.
  String? get androidPreviewError => _androidPreviewError;
  bool get androidPreviewStale => _androidPreviewStale;

  /// Composes the preview off the working copy (nothing is written).
  Future<void> refreshAndroidPreview() async {
    final project = _working;
    if (project == null || _androidPreviewLoading) return;
    _androidPreviewLoading = true;
    _androidPreviewStale = false;
    notifyListeners();
    try {
      final plugins = await AndroidPackagingHooks.enabledPluginsOf(projectDirPath, project);
      final preview = await AndroidPackaging.preview(projectDirPath, project, plugins);
      _androidPreview = preview;
      _androidPreviewError = preview == null
          ? 'The project has no Android app yet (android/app/src/main/AndroidManifest.xml): '
              'run `flutter create --platforms=android .` in the project folder.'
          : null;
    } catch (e) {
      _androidPreview = null;
      _androidPreviewError = 'The manifest could not be composed: $e';
    } finally {
      _androidPreviewLoading = false;
      if (!_disposed) notifyListeners();
    }
  }
}
