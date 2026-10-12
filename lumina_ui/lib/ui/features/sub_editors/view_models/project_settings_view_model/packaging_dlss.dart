part of '../project_settings_view_model.dart';

/// Packaging ▸ Bundle NVIDIA DLSS runtime: the option, the DLSS SDK of the
/// flutter_filament the game builds against, its fetch and its licence.
mixin _ProjectSettingsPackagingDlss on _ProjectSettingsViewModelState {
  DlssSdk? _dlssSdk;
  bool _dlssSdkLooked = false;
  bool _dlssSdkLocating = false;

  /// Turns bundling of NVIDIA's DLSS runtime into Windows / Linux packages on
  /// or off in the working copy.
  void setBundleDlssRuntime(bool on) =>
      _update((p) => p.copyWith(packaging: p.packaging.copyWith(bundleDlssRuntime: on)));

  /// The DLSS SDK packages would take the runtime from; null before
  /// [refreshDlssSdk] finished or when no flutter_filament with the DLSS
  /// tooling was found.
  DlssSdk? get dlssSdk => _dlssSdk;

  /// [refreshDlssSdk] has finished at least once.
  bool get dlssSdkLooked => _dlssSdkLooked;

  bool get isLocatingDlssSdk => _dlssSdkLocating;

  DlssSdkDownload get dlssSdkDownload => _dlssSdkDownload;

  /// Locates the SDK again (off the UI isolate).
  Future<void> refreshDlssSdk() async {
    if (_dlssSdkLocating) return;
    _dlssSdkLocating = true;
    notifyListeners();
    try {
      _dlssSdk = await DlssSdk.locate(projectDirPath, fallbackPackageRoots: _dlssFallbackPackageRoots);
    } catch (e) {
      _logger.log('Could not read the DLSS SDK: $e', level: 'warning', source: 'Packaging');
      _dlssSdk = null;
    }
    _dlssSdkLooked = true;
    _dlssSdkLocating = false;
    if (!_disposed) notifyListeners();
  }

  /// Fetches the SDK's missing files, then reads it again; true when complete.
  Future<bool> fetchDlssSdk() async {
    final sdk = _dlssSdk;
    if (sdk == null) return false;
    final ok = await _dlssSdkDownload.start(sdk);
    _logger.log(ok ? (_dlssSdkDownload.message ?? 'DLSS SDK fetched') : 'DLSS SDK fetch failed: ${_dlssSdkDownload.error}',
        level: ok ? 'success' : 'error', source: 'Packaging');
    if (!_disposed) await refreshDlssSdk();
    return ok;
  }

  /// NVIDIA's licence text from the fetched SDK, or null when it is missing.
  Future<String?> readDlssLicense() async {
    final sdk = _dlssSdk;
    if (sdk == null) return null;
    final file = File(sdk.licenseFile);
    if (!await file.exists()) return null;
    return file.readAsString();
  }
}
