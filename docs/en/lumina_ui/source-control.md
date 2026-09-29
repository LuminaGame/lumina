[Türkçe](../../tr/lumina_ui/source-control.md)

# Source control

Git integration in the editor: the git service over the real `git` CLI, the source control view model and its menu, and the commit, history, revert, identity and init-repository dialogs, plus the status badge. File paths are relative to the `lumina_ui/` package directory.

**On this page:**

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

**Top-level Functions:**

- **`List<EditorCommand> buildSourceControlCommands(EditorViewModel vm)`**: `Tools → Source Control` commands registered into the editor's command registry (Commit…, History for Active Level, Refresh, Initialize).
- **`List<String> sourceControlPathsForAsset(EditorViewModel vm, RealAssetInfo asset)`**: Project-relative git paths an asset tile represents: its `.lmas` and, when different, the raw file the tile was scanned from.
- **`List<MenuItem> sourceControlAssetMenuItems(BuildContext context, EditorViewModel vm, RealAssetInfo asset)`**: Content Browser context-menu entries for one asset (`Commit`, `History`, `Revert File`). Empty when the project is not a repository, so the menu is unchanged on hosts without git.

## `lib/ui/features/source_control/views/commit_dialog.dart`

### `class CommitDialog`

Changelist-style commit dialog: every changed file grouped under `Assets (.lmas)` / `Levels` / `Generated code (lib/)` / `Project`, a checkbox per row (default all checked), status chip, path, diff summary (`+n −m` for text, `binary · old → new` for `.lmas`), per-row Revert, a validated commit-message box and a Commit button that stages exactly the checked paths.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `SourceControlViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `preChecked` | `Set<String>? preChecked` | Holds the `preChecked` property or configuration state. |
| `onClose` | `VoidCallback? onClose` | Holds the `onClose` property or configuration state. |
| `createState` | `State<CommitDialog> createState() => _CommitDialogState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _CommitDialogState`

`_CommitDialogState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `vm` | `SourceControlViewModel get vm` | Getter accessor returning the current value of `vm`. |
| `initState` | `void initState()` | Executes `initState` operation. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _GroupHeader`

`_GroupHeader`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `title` | `String title` | Holds the `title` property or configuration state. |
| `count` | `int count` | Holds the `count` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/source_control/views/history_dialog.dart`

**Top-level Functions:**

- **`void showHistoryDialog(BuildContext context, SourceControlViewModel viewModel, String path)`**: Executes `showHistoryDialog` operation.

### `class HistoryDialog`

Per-asset commit list from `git log --follow` (renames followed).

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `SourceControlViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `path` | `String path` | Holds the `path` property or configuration state. |
| `createState` | `State<HistoryDialog> createState() => _HistoryDialogState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _HistoryDialogState`

`_HistoryDialogState`: shadcn_flutter UI component rendering interface elements and listening to interactions.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `initState` | `void initState()` | Executes `initState` operation. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class _HistoryRow`

`_HistoryRow`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `entry` | `GitLogEntry entry` | Holds the `entry` property or configuration state. |
| `index` | `int index` | Holds the `index` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/source_control/views/identity_form.dart`

### `class GitIdentityForm`

One-time setup form shown when git refuses to commit because `user.name`/`user.email` are unset. Writes a **repo-local** identity via `git config` — never the Studio user's mail, never global config.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `SourceControlViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `createState` | `State<GitIdentityForm> createState() => _GitIdentityFormState()` | Creates, configures, and returns a new `State` instance or associated GPU resource. |

### `class _GitIdentityFormState`

`_GitIdentityFormState`: `class` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/source_control/views/init_repo_prompt.dart`

### `class InitRepoPrompt`

Dismissible banner shown under the menu bar when the opened project has no `.git`: `Initialize Git Repository` runs `git init` + `.gitignore` + the initial commit; `Not now` persists the dismissal next to the project.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `viewModel` | `SourceControlViewModel viewModel` | Holds the `viewModel` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/source_control/views/revert_dialog.dart`

**Top-level Functions:**

- **`void showRevertDialog(BuildContext context, SourceControlViewModel viewModel, String path)`**: Confirm dialog naming the file, then `git restore -- <path>`; untracked files are offered a delete instead. The view model fires its reload hook afterwards so in-memory editor state matches disk.

## `lib/ui/features/source_control/views/source_control_badge.dart`

**Top-level Functions:**

- **`Color sourceControlStateColor(GitFileState state) => switch (state)`**: Colour per working-tree state (amber modified, green added/untracked, red deleted, purple conflict, blue renamed).

### `class SourceControlBadge`

Small corner badge (`M`, `A`, `?`, `D`, `R`, `C`) for one file state. Renders nothing when [state] is null — which is also the git-absent path.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `state` | `GitFileState? state` | Holds the `state` property or configuration state. |
| `path` | `String path` | Holds the `path` property or configuration state. |
| `size` | `double size` | Holds the `size` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

### `class SourceControlBadgeOverlay`

Overlays a [SourceControlBadge] on the top-right corner of [child] (Content Browser tiles). Layout is untouched when [state] is null.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `state` | `GitFileState? state` | Holds the `state` property or configuration state. |
| `path` | `String path` | Holds the `path` property or configuration state. |
| `child` | `Widget child` | Holds the `child` property or configuration state. |
| `build` | `Widget build(BuildContext context)` | Constructs and returns the declarative element or widget hierarchy. |

## `lib/ui/features/source_control/view_models/source_control_view_model.dart`

### `class SourceControlMenuEntry`

One entry of the `Tools → Source Control` submenu model. The menu bar renders [enabled] as the item's enabled state and [tooltip] as a label above the entries when git is unavailable.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `id` | `String id` | Holds the `id` property or configuration state. |
| `label` | `String label` | Holds the `label` property or configuration state. |
| `enabled` | `bool enabled` | Holds the `enabled` property or configuration state. |
| `tooltip` | `String? tooltip` | Holds the `tooltip` property or configuration state. |

### `class ChangelistGroup`

Changed files grouped under one commit-dialog header.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `title` | `String title` | Holds the `title` property or configuration state. |
| `entries` | `List<GitFileStatus> entries` | Holds the `entries` property or configuration state. |

### `class SourceControlViewModel`

Editor-side state over [GitService]: caches the `git status` map the Content Browser badges read (O(1) lookups, no git call per tile), exposes availability / repository probes, the init-prompt state, the changelist grouping for the commit dialog, and revert/commit/history operations.  `refresh()` is single-flight: concurrent callers join the in-flight future, so a burst of save/asset events costs one `git status`.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `service` | `GitService service` | Holds the `service` property or configuration state. |
| `projectRoot` | `String get projectRoot` | Getter accessor returning the current value of `projectRoot`. |
| `isAvailable` | `bool get isAvailable` | Checks current state or capability and returns a boolean value. |
| `isRepo` | `bool get isRepo` | Checks current state or capability and returns a boolean value. |
| `isProbed` | `bool get isProbed` | Checks current state or capability and returns a boolean value. |
| `identityRequired` | `bool get identityRequired` | Getter accessor returning the current value of `identityRequired`. |
| `initPromptDismissed` | `bool get initPromptDismissed` | Getter accessor returning the current value of `initPromptDismissed`. |
| `lastError` | `String? get lastError` | Getter accessor returning the current value of `lastError`. |
| `lastCommitHash` | `String? get lastCommitHash` | Getter accessor returning the current value of `lastCommitHash`. |
| `isBusy` | `bool get isBusy` | Checks current state or capability and returns a boolean value. |
| `shouldPromptInit` | `bool get shouldPromptInit` | True when the project has no repository of its own and the user has not dismissed the init banner (git must be present for the prompt to matter). |
| `changes` | `List<GitFileStatus> get changes` | Getter accessor returning the current value of `changes`. |
| `hasChanges` | `bool get hasChanges` | Checks current state or capability and returns a boolean value. |
| `whenIdle` | `Future<void> get whenIdle` | Completes when every in-flight refresh/commit/init/revert has settled. |
| `stateFor` | `GitFileState? stateFor(String path)` | Executes `stateFor` operation. |
| `statusFor` | `GitFileStatus? statusFor(String path)` | Executes `statusFor` operation. |
| `stateForAny` | `GitFileState? stateForAny(Iterable<String> paths)` | First matching state across several candidate paths (an asset tile may represent a `.lmas` plus its raw payload sibling). |
| `folderState` | `GitFileState? folderState(String folder)` | Aggregated state for a folder: conflict > deleted > modified > added/untracked. |
| `isLevelDirty` | `bool isLevelDirty(String levelName)` | The active level is dirty when its `.lmas` or generated `L_*.dart` differs from HEAD. |
| `summaryFor` | `GitDiffSummary? summaryFor(String path)` | Executes `summaryFor` operation. |
| `groupedChanges` | `List<ChangelistGroup> get groupedChanges` | Changelists in commit-dialog order: Assets / Levels / Generated code / Project. |
| `menuEntries` | `List<SourceControlMenuEntry> get menuEntries` | Getter accessor returning the current value of `menuEntries`. |
| `refresh` | `Future<void> refresh()` | Re-probes git availability + repository state and reloads the status map. Concurrent callers share the in-flight future (single-flight). |
| `didChangeAppLifecycleState` | `void didChangeAppLifecycleState(AppLifecycleState state)` | Executes `didChangeAppLifecycleState` operation. |
| `loadSummaries` | `Future<Map<String, GitDiffSummary>> loadSummaries()` | Loads diff summaries for every current change (commit dialog rows). |
| `initRepository` | `Future<bool> initRepository()` | `git init` + `.gitignore` + initial commit. Returns true on success. An identity failure leaves the repo initialised & staged and flips [identityRequired] so the UI can collect a repo-local identity. |
| `dismissInitPrompt` | `Future<void> dismissInitPrompt()` | Executes `dismissInitPrompt` operation. |
| `clearError` | `void clearError()` | Clears all elements from the collection or buffer. |
| `dispose` | `void dispose()` | Releases native FFI pointers, event subscriptions, and allocated memory. |

## `lib/ui/features/source_control/services/git_service.dart`

### `enum GitFileState`

Working-tree state of one path, derived from `git status --porcelain=v2`.

### `extension GitFileStateBadge`

`GitFileStateBadge`: `extension` representing the data model or functionality of the module.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `badgeLabel` | `String get badgeLabel` | Single-letter badge label used on Content Browser tiles. |
| `description` | `String get description` | Getter accessor returning the current value of `description`. |

### `class GitFileStatus`

One entry of `git status`, with paths relative to the project root.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `path` | `String path` | Holds the `path` property or configuration state. |
| `origPath` | `String? origPath` | Holds the `origPath` property or configuration state. |
| `state` | `GitFileState state` | Holds the `state` property or configuration state. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `class GitDiffSummary`

`git diff --numstat` result for one path.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `path` | `String path` | Holds the `path` property or configuration state. |
| `isBinary` | `bool isBinary` | Holds the `isBinary` property or configuration state. |
| `added` | `int added` | Holds the `added` property or configuration state. |
| `removed` | `int removed` | Holds the `removed` property or configuration state. |
| `oldSize` | `int? oldSize` | Holds the `oldSize` property or configuration state. |
| `newSize` | `int? newSize` | Holds the `newSize` property or configuration state. |
| `formatBytes` | `static String formatBytes(int? bytes)` | Executes `formatBytes` operation. |
| `label` | `String get label` | `+12 −4` for text, `binary · 1.2 KB → 1.3 KB` for binary files. |

### `class GitLogEntry`

One row of `git log --follow` for a path.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `hash` | `String hash` | Holds the `hash` property or configuration state. |
| `author` | `String author` | Holds the `author` property or configuration state. |
| `date` | `DateTime date` | Holds the `date` property or configuration state. |
| `subject` | `String subject` | Holds the `subject` property or configuration state. |
| `abbrevHash` | `String get abbrevHash` | Getter accessor returning the current value of `abbrevHash`. |

### `class GitException`

A git invocation that exited non-zero.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `command` | `String command` | Holds the `command` property or configuration state. |
| `exitCode` | `int exitCode` | Holds the `exitCode` property or configuration state. |
| `stderr` | `String stderr` | Holds the `stderr` property or configuration state. |
| `isIdentityError` | `bool get isIdentityError` | True when git refused because `user.name`/`user.email` are unset. |
| `toString` | `String toString()` | Executes `toString` operation. |

### `class GitService`

Thin, porcelain-only wrapper over the real `git` CLI.  Every call goes through [Process.run] (or the injected [GitProcessRunner]) with `workingDirectory` = [projectRoot]; machine-readable flags only (`--porcelain=v2 -z`, `--numstat -z`, `--format` with unit separators) so parsing never depends on locale or git's human output.

**Functions, Methods & Accessors:**

| Method / Getter | Signature | Purpose & Description |
| :--- | :--- | :--- |
| `projectRoot` | `String projectRoot` | Holds the `projectRoot` property or configuration state. |
| `configOverrides` | `List<String> configOverrides` | Extra leading args, e.g. `['-c', 'user.name=…']` — tests use it to pin an identity; production leaves it empty. |
| `isGitAvailable` | `Future<bool> isGitAvailable()` | Probes `git --version` once and caches the answer. |
| `isRepository` | `Future<bool> isRepository()` | True when [projectRoot] is inside a git work tree. |
| `hasOwnRepository` | `bool hasOwnRepository() => Directory('$projectRoot/.git').existsSync() \...` | True when `.git` lives directly in [projectRoot] (vs. a parent repo). |
| `commitAll` | `Future<String> commitAll(String message)` | Commits everything currently staged (used to finish [init] after an identity has been configured). |
| `status` | `Future<List<GitFileStatus>> status()` | `git status --porcelain=v2 -z --untracked-files=all -- .` parsed into project-relative [GitFileStatus] entries. Rename records (`2`) carry two NUL-separated paths; untracked (`?`) and unmerged (`u`) records are mapped to their own states. |
| `diffSummary` | `Future<GitDiffSummary> diffSummary(String path)` | `git diff HEAD --numstat -z -- <path>`; `-\t-` means binary, in which case sizes come from disk and `git cat-file -s HEAD:<path>`. Untracked files are diffed against `/dev/null` with `--no-index`. |
| `headHash` | `Future<String> headHash()` | Executes `headHash` operation. |
| `headHashOf` | `Future<String?> headHashOf(String path)` | Hash of the last commit touching [path], or null when HEAD has no such path. |
| `restoreFile` | `Future<void> restoreFile(String path)` | Discards index + working-tree changes of [path] back to HEAD. |
| `hasIdentity` | `Future<bool> hasIdentity()` | Checks current state or capability and returns a boolean value. |

---

[Previous: Plugin manager](plugin-manager.md) | [Up: lumina_ui (Lumina Studio)](index.md) | [Next: Marketplace](marketplace.md)
