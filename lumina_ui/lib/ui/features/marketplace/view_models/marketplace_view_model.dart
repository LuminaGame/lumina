import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart';

import 'package:lumina_ui/ui/features/marketplace/services/marketplace_install_dirs.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_installer.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_license_records.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_service.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_session_store.dart';

/// What the Marketplace window needs from the editor around it.
class MarketplaceHost {
  const MarketplaceHost({
    this.projectRoot,
    this.importRequests,
    this.onProjectContentInstalled,
    this.onPluginsChanged,
    this.openPluginManager,
    this.log,
  });

  /// The open project, or null (asset listings cannot be added then).
  final String? projectRoot;

  /// The editor's background import queue.
  final MarketplaceImportRunner? importRequests;

  /// Assets were installed or removed under this project-relative folder.
  final void Function(String folder)? onProjectContentInstalled;

  /// A plugin was installed or removed: rescan so the Plugin Manager lists it.
  final Future<void> Function()? onPluginsChanged;

  /// Opens Tools → Plugins, where an installed plugin is enabled.
  final VoidCallback? openPluginManager;

  /// The Output Log.
  final void Function(String message, String level)? log;
}

/// The Marketplace window's three views.
enum MarketplaceSection { browse, library, installed }

/// A running (or failed) install of one listing.
class MarketplaceInstallJob {
  MarketplaceInstallJob(this.listing) : cancel = MarketplaceCancelToken();

  final Listing listing;
  final MarketplaceCancelToken cancel;
  MarketplaceInstallProgress? progress;
  String? error;
  bool get running => error == null && progress?.phase != MarketplaceInstallPhase.done;
  double get fraction => progress?.fraction ?? 0;
}

/// The state of Window → Marketplace: the session, the
/// catalogue search, the selected listing, the user's library, the running
/// installs and what is installed.
class MarketplaceViewModel extends ChangeNotifier {
  MarketplaceViewModel({
    required Uri serverUrl,
    this.host = const MarketplaceHost(),
    MarketplaceSessionStore? sessionStore,
    MarketplaceInstallDirs? dirs,
    this.stagingRoot,
    this.pageSize = 24,
  })  : _sessionStore = sessionStore ?? MarketplaceSessionStore(),
        dirs = dirs ?? MarketplaceInstallDirs.resolve(projectRoot: host.projectRoot) {
    _service = _newService(serverUrl);
  }

  /// Creates the HTTP client of every Marketplace connection. A platform
  /// seam: tests hand in a real `dart:io` client that bypasses flutter_test's
  /// HTTP stand-in (the server they talk to is real).
  static http.Client Function() httpClientFactory = http.Client.new;

  final MarketplaceHost host;
  final MarketplaceInstallDirs dirs;
  final Directory? stagingRoot;
  final int pageSize;
  final MarketplaceSessionStore _sessionStore;
  late MarketplaceService _service;
  late MarketplaceInstaller _installer;
  bool _disposed = false;
  bool _started = false;

  MarketplaceService _newService(Uri url) {
    final service = MarketplaceService(serverUrl: url, httpClient: httpClientFactory(), sessionStore: _sessionStore);
    _installer = MarketplaceInstaller(
      dirs: dirs,
      openDownload: service.openDownload,
      serverUrl: service.serverUrl,
      importRunner: host.importRequests,
      stagingRoot: stagingRoot,
    );
    return service;
  }

  MarketplaceService get service => _service;
  MarketplaceInstaller get installer => _installer;
  Uri get serverUrl => _service.serverUrl;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _log(String message, [String level = 'info']) => host.log?.call(message, level);

  String _describe(Object e) => switch (e) {
        MarketplaceException(:final message) => message,
        MarketplaceInstallException(:final message) => message,
        SocketException() || http.ClientException() => 'Cannot reach the Marketplace at $serverUrl.',
        _ => '$e',
      };

  MarketplaceSection _section = MarketplaceSection.browse;
  MarketplaceSection get section => _section;
  set section(MarketplaceSection value) {
    if (_section == value) return;
    _section = value;
    if (value == MarketplaceSection.library && isSignedIn) unawaited(refreshLibrary());
    if (value == MarketplaceSection.installed) refreshInstalled();
    _notify();
  }

  /// Restores the stored session, lists the newest listings and reads what
  /// is installed. Runs once; later calls do nothing.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    refreshInstalled();
    await Future.wait([_restore(), search()]);
  }

  Future<void> _restore() async {
    try {
      final user = await _service.restoreSession();
      if (user != null) {
        _log('Marketplace: signed in as ${user.username} (session restored)');
        await refreshLibrary();
      }
    } catch (e) {
      _log('Marketplace: could not restore the session: ${_describe(e)}', 'warning');
    }
    _notify();
  }

  /// Points the window at another server (Editor Preferences), signed out.
  Future<void> setServerUrl(Uri url) async {
    if (url.toString() == serverUrl.toString() || url.replace(path: '${url.path}/').toString() == serverUrl.toString()) return;
    _service.close();
    _service = _newService(url);
    _results = const [];
    _library = const [];
    _selected = null;
    _started = false;
    _notify();
    await start();
  }

  // --- Session ---------------------------------------------------------------------

  MarketplaceUser? get user => _service.currentUser;
  bool get isSignedIn => _service.isSignedIn;
  bool _sessionBusy = false;
  bool get sessionBusy => _sessionBusy;
  String? _sessionError;
  String? get sessionError => _sessionError;

  Future<bool> _session(Future<void> Function() action) async {
    _sessionBusy = true;
    _sessionError = null;
    _notify();
    try {
      await action();
      return true;
    } catch (e) {
      _sessionError = _describe(e);
      return false;
    } finally {
      _sessionBusy = false;
      _notify();
    }
  }

  Future<bool> signIn(String login, String password) => _session(() async {
        final u = await _service.signIn(login: login.trim(), password: password);
        _log('Marketplace: signed in as ${u.username}', 'success');
        await refreshLibrary();
        if (_selected != null) await select(_selected!);
      });

  Future<bool> signUp({required String email, required String username, required String password, String? displayName}) =>
      _session(() async {
        final u = await _service.signUp(
            email: email.trim(), username: username.trim(), password: password, displayName: displayName);
        _log('Marketplace: created the account ${u.username}', 'success');
        await refreshLibrary();
      });

  Future<void> signOut() async {
    await _session(() => _service.signOut());
    _library = const [];
    _log('Marketplace: signed out');
    _notify();
  }

  // --- Catalogue -------------------------------------------------------------------

  String _query = '';
  String get query => _query;
  ListingCategory? _category;
  ListingCategory? get category => _category;
  List<Listing> _results = const [];
  List<Listing> get results => _results;
  int _total = 0;
  int get total => _total;
  bool _searching = false;
  bool get searching => _searching;
  String? _searchError;
  String? get searchError => _searchError;
  int _searchSeq = 0;

  /// Searches the catalogue (the same `GET /listings` as the web front end).
  Future<void> search({String? query, ListingCategory? category, bool clearCategory = false}) async {
    if (query != null) _query = query.trim();
    if (clearCategory) {
      _category = null;
    } else if (category != null) {
      _category = category;
    }
    final seq = ++_searchSeq;
    _searching = true;
    _searchError = null;
    _notify();
    try {
      final page = await _service.search(SearchQuery(q: _query.isEmpty ? null : _query, category: _category, pageSize: pageSize));
      if (seq != _searchSeq) return;
      _results = page.items;
      _total = page.total;
      for (final l in page.items) {
        if (l.screenshots.isNotEmpty) unawaited(_loadMedia(l.screenshots.first));
      }
    } catch (e) {
      if (seq != _searchSeq) return;
      _searchError = _describe(e);
      _results = const [];
      _total = 0;
    } finally {
      if (seq == _searchSeq) {
        _searching = false;
        _notify();
      }
    }
  }

  Listing? _selected;
  Listing? get selected => _selected;
  bool _loadingListing = false;
  bool get loadingListing => _loadingListing;

  /// Opens [listing]'s details (the full listing: versions, licenses, and
  /// whether it is in the library).
  Future<void> select(Listing listing) async {
    _selected = listing;
    _loadingListing = true;
    _notify();
    try {
      final full = await _service.listing(listing.id);
      if (_selected?.id == listing.id) _selected = full;
      for (final s in full.screenshots) {
        unawaited(_loadMedia(s));
      }
    } catch (e) {
      _log('Marketplace: could not open ${listing.title}: ${_describe(e)}', 'warning');
    } finally {
      _loadingListing = false;
      _notify();
    }
  }

  final Set<String> _mediaLoading = {};

  /// A screenshot's bytes once loaded (null until then).
  Uint8List? media(String url) => _service.cachedMedia(url);

  Future<void> _loadMedia(String url) async {
    if (_service.cachedMedia(url) != null || !_mediaLoading.add(url)) return;
    try {
      await _service.media(url);
      _notify();
    } catch (_) {
      // A missing screenshot leaves the card's placeholder.
    } finally {
      _mediaLoading.remove(url);
    }
  }

  // --- Library ---------------------------------------------------------------------

  List<LibraryEntry> _library = const [];
  List<LibraryEntry> get library => _library;
  bool inLibrary(Listing l) => l.inLibrary == true || _library.any((e) => e.listing.id == l.id);

  Future<void> refreshLibrary() async {
    if (!isSignedIn) return;
    try {
      _library = await _service.library();
    } catch (e) {
      _log('Marketplace: could not load the library: ${_describe(e)}', 'warning');
    }
    _notify();
  }

  /// "Get (Free)".
  Future<bool> get(Listing listing) async {
    try {
      await _service.get(listing.id);
      _log('Marketplace: added ${listing.title} to your library', 'success');
      await refreshLibrary();
      if (_selected?.id == listing.id) await select(listing);
      return true;
    } catch (e) {
      _log('Marketplace: could not get ${listing.title}: ${_describe(e)}', 'error');
      _sessionError = _describe(e);
      _notify();
      return false;
    }
  }

  // --- Installs --------------------------------------------------------------------

  final Map<String, MarketplaceInstallJob> _jobs = {};
  MarketplaceInstallJob? job(String listingId) => _jobs[listingId];

  List<MarketplaceInstallRecord> _installed = const [];
  List<MarketplaceInstallRecord> get installed => _installed;
  MarketplaceInstallRecord? installedRecord(String listingId) {
    for (final r in _installed) {
      if (r.listingId == listingId) return r;
    }
    return null;
  }

  void refreshInstalled() {
    _installed = _installer.installed()..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _notify();
  }

  /// Whether [listing] can be installed from here (asset listings need a
  /// project).
  bool canInstall(Listing listing) =>
      listing.latestVersion != null && (listing.category.installKind != InstallKind.projectContents || dirs.projectRoot != null);

  /// The install button's label for [category].
  static String installLabel(ListingCategory category) => switch (category.installKind) {
        InstallKind.projectContents => 'Add to Project',
        InstallKind.plugin => 'Install Plugin',
        InstallKind.theme => 'Install Theme',
        InstallKind.gameTemplate => 'Install Template',
      };

  /// Downloads and installs the latest version of [listing] ("Get" first
  /// when it is not in the library yet). [folder] places an asset listing in
  /// that Content Browser folder instead of `contents/Marketplace/<Publisher>/`.
  Future<MarketplaceInstallRecord?> install(Listing listing, {String? folder}) async {
    if (_jobs[listing.id]?.running ?? false) return null;
    if (!isSignedIn) {
      _sessionError = 'Sign in to get and install ${listing.title}.';
      _notify();
      return null;
    }
    final job = _jobs[listing.id] = MarketplaceInstallJob(listing);
    _notify();
    var lastPercent = -1;
    try {
      final manifest = await _service.prepareInstall(listing);
      final record = await _installer.install(
        manifest,
        projectFolder: folder,
        cancel: job.cancel,
        onProgress: (p) {
          job.progress = p;
          final percent = (p.fraction * 100).floor();
          if (percent != lastPercent || p.phase != MarketplaceInstallPhase.downloading) {
            lastPercent = percent;
            _notify();
          }
        },
      );
      _log('Marketplace: installed ${listing.title} ${manifest.version} into ${record.installedTo} '
          '(${[for (final l in record.licenses) l.id].join(', ')}; notice ${record.licenseFile})', 'success');
      _jobs.remove(listing.id);
      refreshInstalled();
      await _afterChange(record);
      unawaited(refreshLibrary());
      return record;
    } catch (e) {
      final cancelled = e is MarketplaceInstallException && e.cancelled;
      if (cancelled) {
        _jobs.remove(listing.id);
        _log('Marketplace: cancelled the download of ${listing.title}; nothing was installed', 'warning');
      } else {
        job.error = _describe(e);
        _log('Marketplace: could not install ${listing.title}: ${job.error}', 'error');
      }
      _notify();
      return null;
    }
  }

  void cancelInstall(String listingId) => _jobs[listingId]?.cancel.cancel();

  void dismissInstallError(String listingId) {
    if (_jobs[listingId]?.error != null) _jobs.remove(listingId);
    _notify();
  }

  Future<bool> uninstall(MarketplaceInstallRecord record) async {
    final ok = _installer.uninstall(record);
    _log(ok ? 'Marketplace: removed ${record.title} (${record.installedTo})' : 'Marketplace: could not remove ${record.title}',
        ok ? 'info' : 'error');
    refreshInstalled();
    if (ok) await _afterChange(record);
    return ok;
  }

  Future<void> _afterChange(MarketplaceInstallRecord record) async {
    switch (record.installKind) {
      case InstallKind.projectContents:
        host.onProjectContentInstalled?.call(record.installedTo);
      case InstallKind.plugin:
        await host.onPluginsChanged?.call();
      case InstallKind.theme:
      case InstallKind.gameTemplate:
        break;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final j in _jobs.values) {
      j.cancel.cancel();
    }
    _service.close();
    super.dispose();
  }
}
