[English](../../en/lumina_ui/marketplace.md)

# Marketplace

Window > Marketplace: çalıştırmalar arasında saklanan bir oturumla Lumina Marketplace'e giriş, katalogda gezinme ve arama, kullanıcının kütüphanesi ve doğrulanmış indirmeler ile kaydedilen lisanslarla listing kurma (asset'ler projeye, eklentiler, temalar ve şablonlar kullanıcı klasörlerine). Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/marketplace/services/marketplace_install_dirs.dart`](#libuifeaturesmarketplaceservicesmarketplace_install_dirsdart)
- [`lib/ui/features/marketplace/services/marketplace_installer.dart`](#libuifeaturesmarketplaceservicesmarketplace_installerdart)
- [`lib/ui/features/marketplace/services/marketplace_license_records.dart`](#libuifeaturesmarketplaceservicesmarketplace_license_recordsdart)
- [`lib/ui/features/marketplace/services/marketplace_service.dart`](#libuifeaturesmarketplaceservicesmarketplace_servicedart)
- [`lib/ui/features/marketplace/services/marketplace_session_store.dart`](#libuifeaturesmarketplaceservicesmarketplace_session_storedart)
- [`lib/ui/features/marketplace/view_models/marketplace_view_model.dart`](#libuifeaturesmarketplaceview_modelsmarketplace_view_modeldart)
- [`lib/ui/features/marketplace/views/marketplace_folder_rail.dart`](#libuifeaturesmarketplaceviewsmarketplace_folder_raildart)
- [`lib/ui/features/marketplace/views/marketplace_listing_card.dart`](#libuifeaturesmarketplaceviewsmarketplace_listing_carddart)
- [`lib/ui/features/marketplace/views/marketplace_listing_detail.dart`](#libuifeaturesmarketplaceviewsmarketplace_listing_detaildart)
- [`lib/ui/features/marketplace/views/marketplace_sign_in_dialog.dart`](#libuifeaturesmarketplaceviewsmarketplace_sign_in_dialogdart)
- [`lib/ui/features/marketplace/views/marketplace_view.dart`](#libuifeaturesmarketplaceviewsmarketplace_viewdart)

## `lib/ui/features/marketplace/services/marketplace_install_dirs.dart`

### `class MarketplaceInstallDirs`

Where each install kind of a Marketplace listing lands.

A manifest's targets are relative to one of these, by the root prefix the server gives them ([manifestRootPrefix]): `contents/Marketplace/…` to the open project, `plugins/<package>/` to the user plugin directory (the one the Plugin Manager scans), `themes/` to the editor themes directory (the theme store reads `<config>/themes/*.json`) and `templates/` to the editor templates directory.

**Yapıcı Metotlar (Constructors):**

- `const MarketplaceInstallDirs({required this.projectRoot, required this.pluginDir, required this.themesDir, required this.templatesDir, required this.editorLicen...`
- `factory MarketplaceInstallDirs.resolve({String? projectRoot, Directory? configDir})`: The open project's directories, the user plugin directory ([UserPluginDir]) and the editor config directory ([LuminaConfigDir]).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `projectRoot` | `final String? projectRoot` | The open project, or null in the launcher (assets cannot install then). |
| `pluginDir` | `final String pluginDir` |  |
| `themesDir` | `final String themesDir` |  |
| `templatesDir` | `final String templatesDir` |  |
| `editorLicensesFile` | `final String editorLicensesFile` | `licenses.json` for the editor-wide installs (plugins, themes, templates). |
| `projectLicensesFile` | `String? get projectLicensesFile` | The project's `contents/Marketplace/licenses.json`. |
| `manifestRootPrefix` | `static String manifestRootPrefix(InstallKind kind)` | The prefix every target of [kind] starts with in an install manifest. |

## `lib/ui/features/marketplace/services/marketplace_installer.dart`

### `typedef MarketplaceImportRunner`

Runs import requests on the editor's background import queue and completes with each file's final state.

### `typedef MarketplaceDownloadOpener`

Opens a manifest URL as a streamed response (`MarketplaceClient.openDownload`).

### `class MarketplaceInstallException`

Why an install stopped. Nothing is left in the destination when one is thrown: the download lives in a staging directory until it is verified, and a failed import removes what it wrote (restoring a previous install).

**Yapıcı Metotlar (Constructors):**

- `const MarketplaceInstallException(this.code, this.message)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `code` | `final String code` | `cancelled`, `unsafe_manifest`, `checksum_mismatch`, `invalid_archive`, `import_failed`, `not_a_plugin`, `invalid_theme`, `no_project`. |
| `message` | `final String message` |  |
| `cancelled` | `bool get cancelled` |  |

### `class MarketplaceCancelToken`

Cancels a running install (the download stops at the next chunk).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `isCancelled` | `bool get isCancelled` |  |
| `cancel` | `void cancel()` |  |

### `enum MarketplaceInstallPhase`

**Değerler:**

- `downloading`
- `verifying`
- `importing`
- `installing`
- `done`

### `class MarketplaceInstallProgress`

**Yapıcı Metotlar (Constructors):**

- `const MarketplaceInstallProgress(this.phase, {this.received = 0, this.total = 0, this.message = ''})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `phase` | `final MarketplaceInstallPhase phase` |  |
| `received` | `final int received` |  |
| `total` | `final int total` |  |
| `message` | `final String message` |  |
| `fraction` | `double get fraction` | 0–1 over the whole install: the download is the first 80 %. |

### `class MarketplaceInstaller`

Installs Marketplace listing versions, per category:

* assets (`project_contents`) into the open project under `contents/Marketplace/<Publisher>/<Listing>/` (or a Content Browser folder the user dropped the listing on) — raw model, texture and audio files through the background import queue, `.lmas` and other files copied as they are; * plugins into the user plugin directory (`<package>/`), where the Plugin Manager lists them; * themes into the editor themes directory (`<name>.json`); * game templates into the editor templates directory (`<Listing>/`).

Every install is transactional: the archive is downloaded into a staging directory, its sha256 and every file's sha256 checked against the manifest, every target checked with [isSafeRelativePath] and against the category's root, and only then moved into place. Each install writes a `LICENSE-<listing>.txt` notice next to what it installed and an entry in the matching `licenses.json`.

**Yapıcı Metotlar (Constructors):**

- `MarketplaceInstaller({required this.dirs, required this.openDownload, required this.serverUrl, this.importRunner, Directory? stagingRoot,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `dirs` | `final MarketplaceInstallDirs dirs` |  |
| `openDownload` | `final MarketplaceDownloadOpener openDownload` |  |
| `importRunner` | `final MarketplaceImportRunner? importRunner` |  |
| `serverUrl` | `final Uri serverUrl` | The server root, for the `source` of license records. |
| `stagingRoot` | `final Directory stagingRoot` | Where downloads are staged (a `lumina_marketplace_*` directory per install, removed afterwards). |
| `sourceFor` | `String sourceFor(InstallManifest m)` | The listing's page on the server, recorded as the license source. |
| `installed` | `List<MarketplaceInstallRecord> installed()` | The records of everything installed into the open project and into the editor (plugins, themes, templates). A project's `licenses.json` also keeps the notice of the game template it was created from; that entry is attribution, not an install of this project, so only its asset entries count here. |
| `installedRecord` | `MarketplaceInstallRecord? installedRecord(String listingId)` |  |
| `validateManifest` | `static void validateManifest(InstallManifest m)` | Checks [m] before anything is downloaded: a known format, a safe folder name, and every target a safe relative path under the root its install kind allows. Throws `unsafe_manifest` otherwise. |
| `install` | `Future<MarketplaceInstallRecord> install(InstallManifest m, {String? projectFolder, void Function(MarketplaceI...` | Downloads, verifies and installs [m]. [projectFolder] (a Content Browser folder, `contents/...`) replaces the default `contents/Marketplace/<Publisher>/` parent of an asset listing: the listing lands in `<projectFolder>/<Listing>/`. |
| `uninstall` | `bool uninstall(MarketplaceInstallRecord record)` | Removes what [record] installed and its license entry. |

## `lib/ui/features/marketplace/services/marketplace_license_records.dart`

### `class MarketplaceInstallRecord`

One installed Marketplace listing version, as `licenses.json` records it: what was installed, where, and under which licenses (so attribution licences such as CC-BY are honoured and an uninstall knows what to remove).

**Yapıcı Metotlar (Constructors):**

- `const MarketplaceInstallRecord({required this.listingId, required this.slug, required this.title, required this.version, required this.category, required this.i...`
- `factory MarketplaceInstallRecord.fromJson(Map<String, Object?> j)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `listingId` | `final String listingId` |  |
| `slug` | `final String slug` |  |
| `title` | `final String title` |  |
| `version` | `final String version` |  |
| `category` | `final ListingCategory category` |  |
| `installKind` | `final InstallKind installKind` |  |
| `publisherUsername` | `final String publisherUsername` |  |
| `publisherDisplayName` | `final String publisherDisplayName` |  |
| `installedTo` | `final String installedTo` | The install folder (or theme file): project-relative for [InstallKind.projectContents] (`contents/Marketplace/lumina/Barrel`), absolute for the editor-wide kinds (plugins, themes, templates). |
| `licenseFile` | `final String licenseFile` | The `LICENSE-<listing>.txt` notice, in the same form as [installedTo]. |
| `licenses` | `final List<LicenseInfo> licenses` |  |
| `installedAt` | `final DateTime installedAt` |  |
| `source` | `final String source` | The listing page on the server it came from. |
| `files` | `final List<String> files` | The installed files, in the same form as [installedTo] (a theme's one file; the `.lmas` assets an import wrote are listed as they land). |
| `attributionRequired` | `bool get attributionRequired` |  |
| `toJson` | `Map<String, Object?> toJson()` |  |

### `class MarketplaceLicenseRecords`

A `licenses.json` file: the project's `contents/Marketplace/licenses.json` for assets, the editor config's `marketplace/licenses.json` for plugins, themes and game templates. One entry per listing (a reinstall replaces it).

**Yapıcı Metotlar (Constructors):**

- `MarketplaceLicenseRecords(this.file)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `file` | `final File file` |  |
| `formatVersion` | `static const int formatVersion` |  |
| `read` | `List<MarketplaceInstallRecord> read()` |  |
| `byListing` | `MarketplaceInstallRecord? byListing(String listingId)` |  |
| `upsert` | `void upsert(MarketplaceInstallRecord record)` |  |
| `remove` | `void remove(String listingId)` |  |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `marketplaceLicenseNotice` | `String marketplaceLicenseNotice(InstallManifest manifest, {required String source, DateTime? installedAt})` | The text of `LICENSE-<listing>.txt`: what the listing is, who published it, where it came from, and each license with its canonical text URL and what it asks of the user. |

## `lib/ui/features/marketplace/services/marketplace_service.dart`

### `class MarketplaceService`

The editor's side of the Lumina Marketplace API, over the shared [MarketplaceClient]: sign-in with the session kept between runs ([MarketplaceSessionStore]), the catalogue, the library, and what an install needs (the listing in the library, its manifest, the download).

**Yapıcı Metotlar (Constructors):**

- `MarketplaceService({required Uri serverUrl, http.Client? httpClient, MarketplaceSessionStore? sessionStore})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `client` | `final MarketplaceClient client` |  |
| `sessionStore` | `final MarketplaceSessionStore sessionStore` |  |
| `async` | `Future<void> get sessionSaved async` | Completes once the stored session reflects the current one (session events arrive a microtask late, so they are let through first). |
| `serverUrl` | `Uri get serverUrl` |  |
| `currentUser` | `MarketplaceUser? get currentUser` |  |
| `isSignedIn` | `bool get isSignedIn` |  |
| `restoreSession` | `Future<MarketplaceUser?> restoreSession() async` | Signs back in with the stored session for this server; null when there is none or the server refused it. |
| `signIn` | `Future<MarketplaceUser> signIn({required String login, required String password}) async` |  |
| `signUp` | `Future<MarketplaceUser> signUp({required String email, required String username, required String password, Str...` |  |
| `signOut` | `Future<void> signOut() async` |  |
| `search` | `Future<ResultPage<Listing>> search(SearchQuery query)` |  |
| `listing` | `Future<Listing> listing(String idOrSlug)` |  |
| `library` | `Future<List<LibraryEntry>> library()` |  |
| `get` | `Future<LibraryEntry> get(String listingId)` | "Get (Free)": adds the listing to the user's library. |
| `prepareInstall` | `Future<InstallManifest> prepareInstall(Listing listing, {String? version}) async` | The install manifest of [version] (the latest when null). The listing is added to the library first when it is not there yet: the server only hands manifests and downloads to people who have it. |
| `openDownload` | `Future<http.StreamedResponse> openDownload(String url)` |  |
| `media` | `Future<Uint8List> media(String url) async` | A screenshot or avatar (`/api/v1/media/<sha256>`), cached. |
| `cachedMedia` | `Uint8List? cachedMedia(String url)` |  |
| `close` | `void close()` |  |

## `lib/ui/features/marketplace/services/marketplace_session_store.dart`

### `class StoredMarketplaceSession`

A signed-in Marketplace session as the editor keeps it between runs.

**Yapıcı Metotlar (Constructors):**

- `const StoredMarketplaceSession({required this.server, required this.refreshToken, this.username})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `server` | `final String server` | The server root the token belongs to (`http://127.0.0.1:8787/`). |
| `refreshToken` | `final String refreshToken` |  |
| `username` | `final String? username` |  |

### `class MarketplaceSessionStore`

Keeps the Marketplace refresh token between editor runs in an encrypted file under the editor's config directory ([LuminaConfigDir], a temp directory in tests): `marketplace/session.json`, AES-256-GCM with a key derived (HKDF-SHA256) from this machine's id, the user name and a random per-file salt, so a copied file does not open on another machine or account. The file is readable by its owner only. Access tokens are never stored; they live in memory for 15 minutes.

**Yapıcı Metotlar (Constructors):**

- `MarketplaceSessionStore({Directory? configDir, this.machineSecret})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `file` | `final File file` |  |
| `machineSecret` | `final List<int>? machineSecret` | Key material instead of [defaultMachineSecret] (tests use it to prove a file from another machine does not open). |
| `defaultMachineSecret` | `static List<int> defaultMachineSecret()` | This machine and account, as key material: `/etc/machine-id` (or the host name where there is none) and the user name. |
| `save` | `Future<void> save(StoredMarketplaceSession session) async` |  |
| `load` | `Future<StoredMarketplaceSession?> load(String server) async` | The stored session for [server], or null when there is none, it is for another server, or it does not decrypt here. |
| `clear` | `void clear()` |  |

## `lib/ui/features/marketplace/view_models/marketplace_view_model.dart`

### `class MarketplaceHost`

What the Marketplace window needs from the editor around it.

**Yapıcı Metotlar (Constructors):**

- `const MarketplaceHost({this.projectRoot, this.importRequests, this.onProjectContentInstalled, this.onPluginsChanged, this.openPluginManager, this.log,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `projectRoot` | `final String? projectRoot` | The open project, or null (asset listings cannot be added then). |
| `importRequests` | `final MarketplaceImportRunner? importRequests` | The editor's background import queue. |
| `onProjectContentInstalled` | `final void Function(String folder)? onProjectContentInstalled` | Assets were installed or removed under this project-relative folder. |
| `onPluginsChanged` | `final Future<void> Function()? onPluginsChanged` | A plugin was installed or removed: rescan so the Plugin Manager lists it. |
| `openPluginManager` | `final VoidCallback? openPluginManager` | Opens Tools → Plugins, where an installed plugin is enabled. |
| `log` | `final void Function(String message, String level)? log` | The Output Log. |

### `enum MarketplaceSection`

The Marketplace window's three views.

**Değerler:**

- `browse`
- `library`
- `installed`

### `class MarketplaceInstallJob`

A running (or failed) install of one listing.

**Yapıcı Metotlar (Constructors):**

- `MarketplaceInstallJob(this.listing)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `listing` | `final Listing listing` |  |
| `cancel` | `final MarketplaceCancelToken cancel` |  |
| `progress` | `MarketplaceInstallProgress? progress` |  |
| `error` | `String? error` |  |
| `running` | `bool get running` |  |
| `fraction` | `double get fraction` |  |

### `class MarketplaceViewModel`

The state of Window → Marketplace: the session, the catalogue search, the selected listing, the user's library, the running installs and what is installed.

**Yapıcı Metotlar (Constructors):**

- `MarketplaceViewModel({required Uri serverUrl, this.host = const MarketplaceHost(), MarketplaceSessionStore? sessionStore, MarketplaceInstallDirs? dirs, this.sta...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `httpClientFactory` | `static http.Client Function() httpClientFactory` | Creates the HTTP client of every Marketplace connection. A platform seam: tests hand in a real `dart:io` client that bypasses flutter_test's HTTP stand-in (the server they talk to is real). |
| `host` | `final MarketplaceHost host` |  |
| `dirs` | `final MarketplaceInstallDirs dirs` |  |
| `stagingRoot` | `final Directory? stagingRoot` |  |
| `pageSize` | `final int pageSize` |  |
| `service` | `MarketplaceService get service` |  |
| `installer` | `MarketplaceInstaller get installer` |  |
| `serverUrl` | `Uri get serverUrl` |  |
| `section` | `MarketplaceSection get section` |  |
| `section` | `set section(MarketplaceSection value)` |  |
| `start` | `Future<void> start() async` | Restores the stored session, lists the newest listings and reads what is installed. Runs once; later calls do nothing. |
| `setServerUrl` | `Future<void> setServerUrl(Uri url) async` | Points the window at another server (Editor Preferences), signed out. |
| `user` | `MarketplaceUser? get user` |  |
| `isSignedIn` | `bool get isSignedIn` |  |
| `sessionBusy` | `bool get sessionBusy` |  |
| `sessionError` | `String? get sessionError` |  |
| `signIn` | `Future<bool> signIn(String login, String password)` |  |
| `signUp` | `Future<bool> signUp({required String email, required String username, required String password, String? displa...` |  |
| `signOut` | `Future<void> signOut() async` |  |
| `query` | `String get query` |  |
| `category` | `ListingCategory? get category` |  |
| `results` | `List<Listing> get results` |  |
| `total` | `int get total` |  |
| `searching` | `bool get searching` |  |
| `searchError` | `String? get searchError` |  |
| `search` | `Future<void> search({String? query, ListingCategory? category, bool clearCategory = false}) async` | Searches the catalogue (the same `GET /listings` as the web front end). |
| `selected` | `Listing? get selected` |  |
| `loadingListing` | `bool get loadingListing` |  |
| `select` | `Future<void> select(Listing listing) async` | Opens [listing]'s details (the full listing: versions, licenses, and whether it is in the library). |
| `media` | `Uint8List? media(String url)` | A screenshot's bytes once loaded (null until then). |
| `library` | `List<LibraryEntry> get library` |  |
| `inLibrary` | `bool inLibrary(Listing l)` |  |
| `refreshLibrary` | `Future<void> refreshLibrary() async` |  |
| `get` | `Future<bool> get(Listing listing) async` | "Get (Free)". |
| `job` | `MarketplaceInstallJob? job(String listingId)` |  |
| `installed` | `List<MarketplaceInstallRecord> get installed` |  |
| `installedRecord` | `MarketplaceInstallRecord? installedRecord(String listingId)` |  |
| `refreshInstalled` | `void refreshInstalled()` |  |
| `canInstall` | `bool canInstall(Listing listing)` | Whether [listing] can be installed from here (asset listings need a project). |
| `installLabel` | `static String installLabel(ListingCategory category)` | The install button's label for [category]. |
| `install` | `Future<MarketplaceInstallRecord?> install(Listing listing, {String? folder}) async` | Downloads and installs the latest version of [listing] ("Get" first when it is not in the library yet). [folder] places an asset listing in that Content Browser folder instead of `contents/Marketplace/<Publisher>/`. |
| `cancelInstall` | `void cancelInstall(String listingId)` |  |
| `dismissInstallError` | `void dismissInstallError(String listingId)` |  |
| `uninstall` | `Future<bool> uninstall(MarketplaceInstallRecord record) async` |  |

## `lib/ui/features/marketplace/views/marketplace_folder_rail.dart`

### `class MarketplaceFolderRail`

The open project's Content Browser folders beside the catalogue: drop an asset listing's card on one to install it there (`<folder>/<Listing>/`) instead of `contents/Marketplace/<Publisher>/` — manual placement.

**Yapıcı Metotlar (Constructors):**

- `const MarketplaceFolderRail({super.key, required this.viewModel, required this.folders})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final MarketplaceViewModel viewModel` |  |
| `folders` | `final List<String> folders` | Project-relative Content Browser folders (`contents`, `contents/Props`, …). |

## `lib/ui/features/marketplace/views/marketplace_listing_card.dart`

### `class MarketplaceListingDrag`

What a Marketplace card carries when it is dragged onto a Content Browser folder (manual placement).

**Yapıcı Metotlar (Constructors):**

- `const MarketplaceListingDrag(this.listing)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `listing` | `final Listing listing` |  |

### `class MarketplaceListingCard`

A catalogue card: screenshot, title, publisher, category and licenses, with an installed / in-library marker. Tapping selects the listing; asset listings can be dragged onto a Content Browser folder.

**Yapıcı Metotlar (Constructors):**

- `const MarketplaceListingCard({super.key, required this.viewModel, required this.listing, required this.width})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final MarketplaceViewModel viewModel` |  |
| `listing` | `final Listing listing` |  |
| `width` | `final double width` |  |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `marketplaceLicenseIds` | `List<String> marketplaceLicenseIds(Listing l)` | The license badges of a listing: one per declared license id. |
| `marketplaceCategoryIcon` | `IconData marketplaceCategoryIcon(ListingCategory c)` | The icon of a listing category. |

## `lib/ui/features/marketplace/views/marketplace_listing_detail.dart`

### `class MarketplaceListingDetail`

The selected listing: screenshots, description, version, the licenses it is published under, and Get / Add to Project (or Install Plugin / Theme / Template) with download progress and Cancel, or the installed version with Uninstall.

**Yapıcı Metotlar (Constructors):**

- `const MarketplaceListingDetail({super.key, required this.viewModel})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final MarketplaceViewModel viewModel` |  |

## `lib/ui/features/marketplace/views/marketplace_sign_in_dialog.dart`

### `class MarketplaceSignInDialog`

**Yapıcı Metotlar (Constructors):**

- `const MarketplaceSignInDialog({super.key, required this.viewModel})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final MarketplaceViewModel viewModel` |  |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `showMarketplaceSignInDialog` | `void showMarketplaceSignInDialog(BuildContext context, MarketplaceViewModel viewModel)` | Sign in to the Marketplace (email or username + password), or create an account. The session is kept for the next editor run. |

## `lib/ui/features/marketplace/views/marketplace_view.dart`

### `class MarketplaceView`

Window → Marketplace: a workspace tab that signs in to the Lumina Marketplace, browses and searches the catalogue the web front end shows, lists the user's library and what is installed, and installs listings — assets into the open project, plugins, themes and templates into the editor.

**Yapıcı Metotlar (Constructors):**

- `const MarketplaceView({super.key, required this.viewModel, this.contentFolders, this.foldersChanged})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `viewModel` | `final MarketplaceViewModel viewModel` |  |
| `contentFolders` | `final List<String> Function()? contentFolders` | The project's Content Browser folders, for the drop rail (none in the launcher). |
| `foldersChanged` | `final Listenable? foldersChanged` | Notifies when [contentFolders] may have changed (the editor). |

---

[Önceki: Kaynak kontrolü](source-control.md) | [Üst: lumina_ui (Lumina Studio)](index.md) | [Sonraki: MCP sunucusu](mcp-server.md)
