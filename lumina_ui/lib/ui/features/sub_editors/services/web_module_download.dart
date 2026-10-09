import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:lumina_core/lumina_core.dart' show FlutterFilamentWebInstall, FlutterFilamentWebPrebuilt, LuminaRelease;
import 'package:lumina_editor_data/lumina_editor.dart' show EngineLoggerService;

import 'package:lumina_ui/ui/features/sub_editors/services/flutter_filament_web_module.dart';

/// Where a [WebModuleDownload] stands.
enum WebModuleDownloadPhase { idle, downloading, ready, failed }

/// Downloads flutter_filament's WebAssembly module for the web packaging
/// target ([FlutterFilamentWebPrebuilt.ensure]) in the background: started
/// at launch ([startAtLaunch]) and from Project Settings ▸ Packaging
/// ([start], [retry]). Listeners hear every progress step; the module is
/// found through [FlutterFilamentWebModule.locate] once [phase] is
/// [WebModuleDownloadPhase.ready].
class WebModuleDownload extends ChangeNotifier {
  WebModuleDownload({
    Directory? root,
    String? requestedTag,
    this.baseUrl,
    this.apiUrl,
    List<String>? packageRoots,
    EngineLoggerService? logger,
  })  :
        // ignore: prefer_initializing_formals
        _root = root,
        requestedTag = requestedTag ?? LuminaRelease.version,
        // ignore: prefer_initializing_formals
        _packageRoots = packageRoots,
        _logger = logger ?? EngineLoggerService();

  /// The editor's shared download.
  static WebModuleDownload instance = WebModuleDownload();

  final Directory? _root;

  /// Where the module is unpacked: `<root>/module` (default
  /// [FlutterFilamentWebPrebuilt.defaultRoot], read on every use so a
  /// redirected data folder applies).
  Directory get root => _root ?? FlutterFilamentWebPrebuilt.defaultRoot();

  /// The editor version the module is fetched for (its release tag; empty
  /// in a development build, which takes the newest release with a module).
  final String requestedTag;

  /// Replace the GitHub release download and listing URLs (tests, mirrors).
  final String? baseUrl;
  final String? apiUrl;

  final List<String>? _packageRoots;
  final EngineLoggerService _logger;

  WebModuleDownloadPhase _phase = WebModuleDownloadPhase.idle;
  double _progress = 0;
  String? _message;
  String? _error;
  FlutterFilamentWebInstall? _install;
  Future<bool>? _running;
  bool _disposed = false;

  WebModuleDownloadPhase get phase => _phase;
  bool get isDownloading => _phase == WebModuleDownloadPhase.downloading;

  /// 0..1 while downloading.
  double get progress => _progress;

  /// The latest progress message.
  String? get message => _message;

  /// Why the last run failed.
  String? get error => _error;

  /// What the last successful run installed.
  FlutterFilamentWebInstall? get install => _install;

  /// The launch step: nothing when a local package build exists (it wins
  /// anyway), otherwise [start] — which reuses an install made for this
  /// editor version without the network and replaces one made for another.
  /// Never throws; a failure is logged and shown in Packaging with a retry.
  Future<bool> startAtLaunch() async {
    if (FlutterFilamentWebModule.locatePackageBuild(packageRoots: _packageRoots) != null) return true;
    return start();
  }

  /// Downloads the module unless an install for [requestedTag] is there
  /// ([force] downloads anyway). A call while one runs joins it. Resolves to
  /// whether a module is installed afterwards.
  Future<bool> start({bool force = false}) => _running ??= _run(force).whenComplete(() => _running = null);

  /// [start] again after a failure.
  Future<bool> retry() => start();

  Future<bool> _run(bool force) async {
    _phase = WebModuleDownloadPhase.downloading;
    _progress = 0;
    _error = null;
    _message = 'Checking the flutter_filament web module…';
    _notify();
    try {
      final install = await FlutterFilamentWebPrebuilt.ensure(
        requestedTag: requestedTag,
        root: root,
        baseUrl: baseUrl,
        apiUrl: apiUrl,
        force: force,
        onProgress: (fraction, message) {
          _progress = fraction;
          _message = message;
          _notify();
        },
      );
      _install = install;
      _phase = WebModuleDownloadPhase.ready;
      _progress = 1;
      _message = 'flutter_filament web module ${install.tag} is installed';
      _logger.log('${_message!} (${install.directory.path})', level: 'success', source: 'WebModule');
      _notify();
      return true;
    } catch (e) {
      _phase = WebModuleDownloadPhase.failed;
      _error = '$e';
      _message = null;
      _logger.log('Could not download the flutter_filament web module: $e', level: 'warning', source: 'WebModule');
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
