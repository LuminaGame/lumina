[English](../../en/lumina_ui/source-control.md)

# Kaynak kontrolü

Editördeki Git entegrasyonu: gerçek `git` CLI'ı üzerinde çalışan git servisi, kaynak kontrolü view model'i ve menüsü ile commit, geçmiş, geri alma, kimlik ve repo başlatma diyalogları ve durum rozeti. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/ui/features/source_control/source_control_commands.dart`](#libuifeaturessource_controlsource_control_commandsdart)
- [`lib/ui/features/source_control/views/commit_dialog.dart`](#libuifeaturessource_controlviewscommit_dialogdart)
- [`lib/ui/features/source_control/views/history_dialog.dart`](#libuifeaturessource_controlviewshistory_dialogdart)
- [`lib/ui/features/source_control/views/identity_form.dart`](#libuifeaturessource_controlviewsidentity_formdart)
- [`lib/ui/features/source_control/views/init_repo_prompt.dart`](#libuifeaturessource_controlviewsinit_repo_promptdart)
- [`lib/ui/features/source_control/views/revert_dialog.dart`](#libuifeaturessource_controlviewsrevert_dialogdart)
- [`lib/ui/features/source_control/views/source_control_badge.dart`](#libuifeaturessource_controlviewssource_control_badgedart)
- [`lib/ui/features/source_control/view_models/source_control_view_model.dart`](#libuifeaturessource_controlview_modelssource_control_view_modeldart)
- [`lib/ui/features/source_control/services/git_service.dart`](#libuifeaturessource_controlservicesgit_servicedart)

## `lib/ui/features/source_control/source_control_commands.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`List<EditorCommand> buildSourceControlCommands(EditorViewModel vm)`**: `Tools → Source Control` commands registered into the editor's command registry (Commit…, History for Active Level, Refresh, Initialize).
- **`List<String> sourceControlPathsForAsset(EditorViewModel vm, RealAssetInfo asset)`**: Project-relative git paths an asset tile represents: its `.lmas` and, when different, the raw file the tile was scanned from.
- **`List<MenuItem> sourceControlAssetMenuItems(BuildContext context, EditorViewModel vm, RealAssetInfo asset)`**: Content Browser context-menu entries for one asset (`Commit`, `History`, `Revert File`). Empty when the project is not a repository, so the menu is unchanged on hosts without git.

## `lib/ui/features/source_control/views/commit_dialog.dart`

### `class CommitDialog`

Changelist-style commit dialog: every changed file grouped under `Assets (.lmas)` / `Levels` / `Generated code (lib/)` / `Project`, a checkbox per row (default all checked), status chip, path, diff summary (`+n −m` for text, `binary · old → new` for `.lmas`), per-row Revert, a validated commit-message box and a Commit button that stages exactly the checked paths.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `SourceControlViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `preChecked` | `Set<String>? preChecked` | `preChecked` alanını (field/property) ve ilişkili veriyi saklar. |
| `onClose` | `VoidCallback? onClose` | `onClose` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<CommitDialog> createState() => _CommitDialogState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _CommitDialogState`

`_CommitDialogState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `vm` | `SourceControlViewModel get vm` | `vm` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _GroupHeader`

`_GroupHeader`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `title` | `String title` | `title` alanını (field/property) ve ilişkili veriyi saklar. |
| `count` | `int count` | `count` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/source_control/views/history_dialog.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`void showHistoryDialog(BuildContext context, SourceControlViewModel viewModel, String path)`**: `showHistoryDialog` işlemini gerçekleştirir.

### `class HistoryDialog`

Per-asset commit list from `git log --follow` (renames followed).

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `SourceControlViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `path` | `String path` | `path` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<HistoryDialog> createState() => _HistoryDialogState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _HistoryDialogState`

`_HistoryDialogState`: Kullanıcı arayüzünü (UI) oluşturan ve kullanıcı etkileşimlerini dinleyen shadcn_flutter bileşenidir.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `initState` | `void initState()` | `initState` işlemini gerçekleştirir. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class _HistoryRow`

`_HistoryRow`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `entry` | `GitLogEntry entry` | `entry` alanını (field/property) ve ilişkili veriyi saklar. |
| `index` | `int index` | `index` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/source_control/views/identity_form.dart`

### `class GitIdentityForm`

One-time setup form shown when git refuses to commit because `user.name`/`user.email` are unset. Writes a **repo-local** identity via `git config` — never the Studio user's mail, never global config.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `SourceControlViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `createState` | `State<GitIdentityForm> createState() => _GitIdentityFormState()` | Yeni bir `State` örneği veya ilişkili GPU kaynağını oluşturur ve yapılandırır. |

### `class _GitIdentityFormState`

`_GitIdentityFormState`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `class` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/source_control/views/init_repo_prompt.dart`

### `class InitRepoPrompt`

Dismissible banner shown under the menu bar when the opened project has no `.git`: `Initialize Git Repository` runs `git init` + `.gitignore` + the initial commit; `Not now` persists the dismissal next to the project.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `viewModel` | `SourceControlViewModel viewModel` | `viewModel` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/source_control/views/revert_dialog.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`void showRevertDialog(BuildContext context, SourceControlViewModel viewModel, String path)`**: Confirm dialog naming the file, then `git restore -- <path>`; untracked files are offered a delete instead. The view model fires its reload hook afterwards so in-memory editor state matches disk.

## `lib/ui/features/source_control/views/source_control_badge.dart`

**Üst Düzey Fonksiyonlar (Top-level Functions):**

- **`Color sourceControlStateColor(GitFileState state) => switch (state)`**: Colour per working-tree state (amber modified, green added/untracked, red deleted, purple conflict, blue renamed).

### `class SourceControlBadge`

Small corner badge (`M`, `A`, `?`, `D`, `R`, `C`) for one file state. Renders nothing when [state] is null — which is also the git-absent path.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `state` | `GitFileState? state` | `state` alanını (field/property) ve ilişkili veriyi saklar. |
| `path` | `String path` | `path` alanını (field/property) ve ilişkili veriyi saklar. |
| `size` | `double size` | `size` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

### `class SourceControlBadgeOverlay`

Overlays a [SourceControlBadge] on the top-right corner of [child] (Content Browser tiles). Layout is untouched when [state] is null.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `state` | `GitFileState? state` | `state` alanını (field/property) ve ilişkili veriyi saklar. |
| `path` | `String path` | `path` alanını (field/property) ve ilişkili veriyi saklar. |
| `child` | `Widget child` | `child` alanını (field/property) ve ilişkili veriyi saklar. |
| `build` | `Widget build(BuildContext context)` | Deklaratif alt nesne veya widget ağacını inşa eder. |

## `lib/ui/features/source_control/view_models/source_control_view_model.dart`

### `class SourceControlMenuEntry`

One entry of the `Tools → Source Control` submenu model. The menu bar renders [enabled] as the item's enabled state and [tooltip] as a label above the entries when git is unavailable.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `id` | `String id` | `id` alanını (field/property) ve ilişkili veriyi saklar. |
| `label` | `String label` | `label` alanını (field/property) ve ilişkili veriyi saklar. |
| `enabled` | `bool enabled` | `enabled` alanını (field/property) ve ilişkili veriyi saklar. |
| `tooltip` | `String? tooltip` | `tooltip` alanını (field/property) ve ilişkili veriyi saklar. |

### `class ChangelistGroup`

Changed files grouped under one commit-dialog header.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `title` | `String title` | `title` alanını (field/property) ve ilişkili veriyi saklar. |
| `entries` | `List<GitFileStatus> entries` | `entries` alanını (field/property) ve ilişkili veriyi saklar. |

### `class SourceControlViewModel`

Editor-side state over [GitService]: caches the `git status` map the Content Browser badges read (O(1) lookups, no git call per tile), exposes availability / repository probes, the init-prompt state, the changelist grouping for the commit dialog, and revert/commit/history operations.  `refresh()` is single-flight: concurrent callers join the in-flight future, so a burst of save/asset events costs one `git status`.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `service` | `GitService service` | `service` alanını (field/property) ve ilişkili veriyi saklar. |
| `projectRoot` | `String get projectRoot` | `projectRoot` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isAvailable` | `bool get isAvailable` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isRepo` | `bool get isRepo` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `isProbed` | `bool get isProbed` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `identityRequired` | `bool get identityRequired` | `identityRequired` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `initPromptDismissed` | `bool get initPromptDismissed` | `initPromptDismissed` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `lastError` | `String? get lastError` | `lastError` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `lastCommitHash` | `String? get lastCommitHash` | `lastCommitHash` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `isBusy` | `bool get isBusy` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `shouldPromptInit` | `bool get shouldPromptInit` | True when the project has no repository of its own and the user has not dismissed the init banner (git must be present for the prompt to matter). |
| `changes` | `List<GitFileStatus> get changes` | `changes` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `hasChanges` | `bool get hasChanges` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |
| `whenIdle` | `Future<void> get whenIdle` | Completes when every in-flight refresh/commit/init/revert has settled. |
| `stateFor` | `GitFileState? stateFor(String path)` | `stateFor` işlemini gerçekleştirir. |
| `statusFor` | `GitFileStatus? statusFor(String path)` | `statusFor` işlemini gerçekleştirir. |
| `stateForAny` | `GitFileState? stateForAny(Iterable<String> paths)` | First matching state across several candidate paths (an asset tile may represent a `.lmas` plus its raw payload sibling). |
| `folderState` | `GitFileState? folderState(String folder)` | Aggregated state for a folder: conflict > deleted > modified > added/untracked. |
| `isLevelDirty` | `bool isLevelDirty(String levelName)` | The active level is dirty when its `.lmas` or generated `L_*.dart` differs from HEAD. |
| `summaryFor` | `GitDiffSummary? summaryFor(String path)` | `summaryFor` işlemini gerçekleştirir. |
| `groupedChanges` | `List<ChangelistGroup> get groupedChanges` | Changelists in commit-dialog order: Assets / Levels / Generated code / Project. |
| `menuEntries` | `List<SourceControlMenuEntry> get menuEntries` | `menuEntries` özelliğinin anlık değerini okuyan getter erişimcisi. |
| `refresh` | `Future<void> refresh()` | Re-probes git availability + repository state and reloads the status map. Concurrent callers share the in-flight future (single-flight). |
| `didChangeAppLifecycleState` | `void didChangeAppLifecycleState(AppLifecycleState state)` | `didChangeAppLifecycleState` işlemini gerçekleştirir. |
| `loadSummaries` | `Future<Map<String, GitDiffSummary>> loadSummaries()` | Loads diff summaries for every current change (commit dialog rows). |
| `initRepository` | `Future<bool> initRepository()` | `git init` + `.gitignore` + initial commit. Returns true on success. An identity failure leaves the repo initialised & staged and flips [identityRequired] so the UI can collect a repo-local identity. |
| `dismissInitPrompt` | `Future<void> dismissInitPrompt()` | `dismissInitPrompt` işlemini gerçekleştirir. |
| `clearError` | `void clearError()` | Koleksiyon veya tampon içeriğini tamamen temizler. |
| `dispose` | `void dispose()` | Yerel FFI göstericilerini, dinleyicileri ve bellek bloklarını serbest bırakır. |

## `lib/ui/features/source_control/services/git_service.dart`

### `enum GitFileState`

Working-tree state of one path, derived from `git status --porcelain=v2`.

### `extension GitFileStateBadge`

`GitFileStateBadge`: İlgili modülün veri modelini veya temel işlevselliğini temsil eden `extension` yapısıdır.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `badgeLabel` | `String get badgeLabel` | Single-letter badge label used on Content Browser tiles. |
| `description` | `String get description` | `description` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class GitFileStatus`

One entry of `git status`, with paths relative to the project root.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `path` | `String path` | `path` alanını (field/property) ve ilişkili veriyi saklar. |
| `origPath` | `String? origPath` | `origPath` alanını (field/property) ve ilişkili veriyi saklar. |
| `state` | `GitFileState state` | `state` alanını (field/property) ve ilişkili veriyi saklar. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class GitDiffSummary`

`git diff --numstat` result for one path.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `path` | `String path` | `path` alanını (field/property) ve ilişkili veriyi saklar. |
| `isBinary` | `bool isBinary` | `isBinary` alanını (field/property) ve ilişkili veriyi saklar. |
| `added` | `int added` | `added` alanını (field/property) ve ilişkili veriyi saklar. |
| `removed` | `int removed` | `removed` alanını (field/property) ve ilişkili veriyi saklar. |
| `oldSize` | `int? oldSize` | `oldSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `newSize` | `int? newSize` | `newSize` alanını (field/property) ve ilişkili veriyi saklar. |
| `formatBytes` | `static String formatBytes(int? bytes)` | `formatBytes` işlemini gerçekleştirir. |
| `label` | `String get label` | `+12 −4` for text, `binary · 1.2 KB → 1.3 KB` for binary files. |

### `class GitLogEntry`

One row of `git log --follow` for a path.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `hash` | `String hash` | `hash` alanını (field/property) ve ilişkili veriyi saklar. |
| `author` | `String author` | `author` alanını (field/property) ve ilişkili veriyi saklar. |
| `date` | `DateTime date` | `date` alanını (field/property) ve ilişkili veriyi saklar. |
| `subject` | `String subject` | `subject` alanını (field/property) ve ilişkili veriyi saklar. |
| `abbrevHash` | `String get abbrevHash` | `abbrevHash` özelliğinin anlık değerini okuyan getter erişimcisi. |

### `class GitException`

A git invocation that exited non-zero.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `command` | `String command` | `command` alanını (field/property) ve ilişkili veriyi saklar. |
| `exitCode` | `int exitCode` | `exitCode` alanını (field/property) ve ilişkili veriyi saklar. |
| `stderr` | `String stderr` | `stderr` alanını (field/property) ve ilişkili veriyi saklar. |
| `isIdentityError` | `bool get isIdentityError` | True when git refused because `user.name`/`user.email` are unset. |
| `toString` | `String toString()` | `toString` işlemini gerçekleştirir. |

### `class GitService`

Thin, porcelain-only wrapper over the real `git` CLI.  Every call goes through [Process.run] (or the injected [GitProcessRunner]) with `workingDirectory` = [projectRoot]; machine-readable flags only (`--porcelain=v2 -z`, `--numstat -z`, `--format` with unit separators) so parsing never depends on locale or git's human output.

**Fonksiyonlar, Metotlar ve Erişimciler:**

| Metot / Getter | İmzası | Ne İşe Yarar? |
| :--- | :--- | :--- |
| `projectRoot` | `String projectRoot` | `projectRoot` alanını (field/property) ve ilişkili veriyi saklar. |
| `configOverrides` | `List<String> configOverrides` | Extra leading args, e.g. `['-c', 'user.name=…']` — tests use it to pin an identity; production leaves it empty. |
| `isGitAvailable` | `Future<bool> isGitAvailable()` | Probes `git --version` once and caches the answer. |
| `isRepository` | `Future<bool> isRepository()` | True when [projectRoot] is inside a git work tree. |
| `hasOwnRepository` | `bool hasOwnRepository() => Directory('$projectRoot/.git').existsSync() \...` | True when `.git` lives directly in [projectRoot] (vs. a parent repo). |
| `commitAll` | `Future<String> commitAll(String message)` | Commits everything currently staged (used to finish [init] after an identity has been configured). |
| `status` | `Future<List<GitFileStatus>> status()` | `git status --porcelain=v2 -z --untracked-files=all -- .` parsed into project-relative [GitFileStatus] entries. Rename records (`2`) carry two NUL-separated paths; untracked (`?`) and unmerged (`u`) records are mapped to their own states. |
| `diffSummary` | `Future<GitDiffSummary> diffSummary(String path)` | `git diff HEAD --numstat -z -- <path>`; `-\t-` means binary, in which case sizes come from disk and `git cat-file -s HEAD:<path>`. Untracked files are diffed against `/dev/null` with `--no-index`. |
| `headHash` | `Future<String> headHash()` | `headHash` işlemini gerçekleştirir. |
| `headHashOf` | `Future<String?> headHashOf(String path)` | Hash of the last commit touching [path], or null when HEAD has no such path. |
| `restoreFile` | `Future<void> restoreFile(String path)` | Discards index + working-tree changes of [path] back to HEAD. |
| `hasIdentity` | `Future<bool> hasIdentity()` | Mevcut durumun veya yeteneğin doğruluğunu kontrol eder (`bool` döndürür). |

---

[Önceki: Eklenti yöneticisi](plugin-manager.md) | [Üst: lumina_ui (Lumina Studio)](index.md) | [Sonraki: Marketplace](marketplace.md)
