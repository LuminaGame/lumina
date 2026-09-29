import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart';

import 'marketplace_session_store.dart';

/// The editor's side of the Lumina Marketplace API, over the
/// shared [MarketplaceClient]: sign-in with the session kept between runs
/// ([MarketplaceSessionStore]), the catalogue, the library, and what an
/// install needs (the listing in the library, its manifest, the download).
class MarketplaceService {
  MarketplaceService({required Uri serverUrl, http.Client? httpClient, MarketplaceSessionStore? sessionStore})
      : client = MarketplaceClient(
            baseUrl: serverUrl, httpClient: _GracefulClient(httpClient ?? http.Client()), keepRefreshToken: true),
        sessionStore = sessionStore ?? MarketplaceSessionStore() {
    // The refresh token rotates on every refresh (also the transparent one
    // after an expired access token), so the stored one follows it.
    _sessionSub = client.sessionChanges.listen((user) {
      if (_closed) return;
      final token = client.refreshToken;
      if (user != null && token != null) {
        _store(() => this.sessionStore.save(
            StoredMarketplaceSession(server: client.baseUrl.toString(), refreshToken: token, username: user.username)));
      } else if (user == null) {
        _store(() async => this.sessionStore.clear());
      }
    });
  }

  final MarketplaceClient client;
  final MarketplaceSessionStore sessionStore;
  late final StreamSubscription<MarketplaceUser?> _sessionSub;
  final Map<String, Uint8List> _media = {};

  /// Session-file writes, one after another in the order the session changed
  /// (a save for a rotated token must not land after a sign-out's clear).
  Future<void> _storeOps = Future<void>.value();

  void _store(Future<void> Function() op) => _storeOps = _storeOps.then((_) => op()).catchError((Object _) {});

  /// Completes once the stored session reflects the current one (session
  /// events arrive a microtask late, so they are let through first).
  Future<void> get sessionSaved async {
    await Future<void>.delayed(Duration.zero);
    await _storeOps;
  }
  bool _closed = false;

  Uri get serverUrl => client.baseUrl;
  MarketplaceUser? get currentUser => client.currentUser;
  bool get isSignedIn => client.isSignedIn;

  /// Signs back in with the stored session for this server; null when there
  /// is none or the server refused it.
  Future<MarketplaceUser?> restoreSession() async {
    final stored = await sessionStore.load(serverUrl.toString());
    if (stored == null) return null;
    final session = await client.restoreSession(refreshToken: stored.refreshToken);
    if (session == null) sessionStore.clear();
    await sessionSaved;
    return session?.user;
  }

  Future<MarketplaceUser> signIn({required String login, required String password}) async {
    final user = (await client.logIn(login: login, password: password)).user;
    await sessionSaved;
    return user;
  }

  Future<MarketplaceUser> signUp({
    required String email,
    required String username,
    required String password,
    String? displayName,
  }) async =>
      (await client.signUp(email: email, username: username, password: password, displayName: displayName)).user;

  Future<void> signOut() async {
    await client.logOut();
    await sessionSaved;
  }

  Future<ResultPage<Listing>> search(SearchQuery query) => client.search(query);

  Future<Listing> listing(String idOrSlug) => client.listing(idOrSlug);

  Future<List<LibraryEntry>> library() => client.library();

  /// "Get (Free)": adds the listing to the user's library.
  Future<LibraryEntry> get(String listingId) => client.getListing(listingId);

  /// The install manifest of [version] (the latest when null). The listing
  /// is added to the library first when it is not there yet: the server only
  /// hands manifests and downloads to people who have it.
  Future<InstallManifest> prepareInstall(Listing listing, {String? version}) async {
    if (listing.inLibrary != true) await client.getListing(listing.id);
    final v = version ?? listing.latestVersion?.version;
    if (v == null) throw MarketplaceException(409, 'conflict', '${listing.title} has no published version yet.');
    return client.manifest(listing.id, v);
  }

  Future<http.StreamedResponse> openDownload(String url) => client.openDownload(url);

  /// A screenshot or avatar (`/api/v1/media/<sha256>`), cached.
  Future<Uint8List> media(String url) async => _media[url] ??= await client.downloadUrl(url);

  Uint8List? cachedMedia(String url) => _media[url];

  void close() {
    _closed = true;
    unawaited(_sessionSub.cancel());
    client.close();
  }
}

/// Closes the underlying client only once no request or response body is in
/// flight: closing the editor's Marketplace tab while screenshots are still
/// loading must not tear connections down under them.
class _GracefulClient extends http.BaseClient {
  _GracefulClient(this._inner);

  final http.Client _inner;
  int _active = 0;
  bool _closeRequested = false;
  bool _closed = false;

  void _release() {
    _active--;
    if (_closeRequested && _active == 0) _closeNow();
  }

  void _closeNow() {
    if (_closed) return;
    _closed = true;
    _inner.close();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closeRequested) throw http.ClientException('The Marketplace connection was closed.', request.url);
    _active++;
    final http.StreamedResponse response;
    try {
      response = await _inner.send(request);
    } catch (_) {
      _release();
      rethrow;
    }
    var released = false;
    void releaseOnce() {
      if (released) return;
      released = true;
      _release();
    }

    final body = response.stream.transform(StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleDone: (sink) {
        releaseOnce();
        sink.close();
      },
      handleError: (e, st, sink) {
        releaseOnce();
        sink.addError(e, st);
      },
    ));
    final controller = StreamController<List<int>>(sync: true);
    controller.onListen = () {
      final sub = body.listen(controller.add, onError: controller.addError, onDone: controller.close);
      controller
        ..onPause = sub.pause
        ..onResume = sub.resume
        ..onCancel = () async {
          releaseOnce();
          await sub.cancel();
        };
    };
    return http.StreamedResponse(
      controller.stream,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() {
    _closeRequested = true;
    if (_active == 0) _closeNow();
  }
}
