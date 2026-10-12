import 'package:flutter/foundation.dart';
import 'package:lumina_editor_data/lumina_editor.dart';

enum DlssSdkDownloadPhase { idle, running, done, failed }

/// Fetches the NVIDIA DLSS SDK from Project Settings ▸ Packaging: the same
/// pinned, verified files `tool/dlss/fetch_sdk.dart` downloads, with byte
/// progress, an error and a retry.
class DlssSdkDownload extends ChangeNotifier {
  DlssSdkDownload({DlssSdkFetcher? fetcher}) : _fetcher = fetcher ?? DlssSdkFetcher();

  final DlssSdkFetcher _fetcher;

  DlssSdkDownloadPhase _phase = DlssSdkDownloadPhase.idle;
  double? _progress;
  String? _message;
  String? _error;
  bool _disposed = false;

  DlssSdkDownloadPhase get phase => _phase;
  bool get isRunning => _phase == DlssSdkDownloadPhase.running;

  /// 0..1 while running.
  double? get progress => _progress;
  String? get message => _message;
  String? get error => _error;

  /// Fetches every missing file of [sdk]; true when the SDK is complete.
  Future<bool> start(DlssSdk sdk) async {
    if (isRunning) return false;
    _phase = DlssSdkDownloadPhase.running;
    _progress = 0;
    _error = null;
    _message = 'Fetching the NVIDIA DLSS SDK ${sdk.version}…';
    _notify();
    try {
      final result = await _fetcher.fetch(sdk, onProgress: (p) {
        _progress = p.fraction;
        final mb = (p.bytesDone / (1024 * 1024)).toStringAsFixed(1);
        final total = (p.bytesTotal / (1024 * 1024)).toStringAsFixed(1);
        _message = '${p.filesDone}/${p.filesTotal} files, $mb of $total MB${p.currentFile == null ? '' : ' (${p.currentFile})'}';
        _notify();
      }, isCancelled: () => _disposed);
      _phase = DlssSdkDownloadPhase.done;
      _progress = 1;
      _message = 'DLSS SDK ${sdk.version}: ${result.downloaded} downloaded, ${result.alreadyPresent} already present, all verified';
      _notify();
      return true;
    } catch (e) {
      _phase = DlssSdkDownloadPhase.failed;
      _progress = null;
      _error = '$e';
      _message = null;
      _notify();
      return false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
