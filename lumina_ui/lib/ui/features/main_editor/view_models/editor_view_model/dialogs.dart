part of '../editor_view_model.dart';

/// Prompts and dialogs the commands open.
mixin _EditorDialogs on _EditorViewModelState {
  @override
  void _promptNewLevel(BuildContext? ctx) {
    if (ctx == null) return;
    NewLevelDialog.show(ctx, _self);
  }

  @override
  void _promptOpenLevel(BuildContext? ctx) {
    if (ctx == null) return;
    // The same list `list_levels` returns.
    final levelFiles = this.levelFiles;
    if (levelFiles.isEmpty) return;

    showOverlay(
      ctx,
      const DialogConfiguration(),
      builder: (c) => AlertDialog(
        title: const Text('Open Level'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: levelFiles.length,
            itemBuilder: (context, index) {
              final levelPath = levelFiles[index];
              final levelName = levelPath.split('/').last;
              return GhostButton(
                child: Text(levelName),
                onPressed: () async {
                  // Ask over this dialog, which stays mounted until
                  // the answer (the menu's context is gone by now).
                  await openLevelGuarded(levelPath, context: c);
                  if (c.mounted) Navigator.of(c).pop();
                },
              );
            },
          ),
        ),
        actions: [
          OutlineButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  void _promptNewAsset(BuildContext? ctx) {
    if (ctx == null) return;

    // Simplistic implementation just creating one under 'meshes' for now
    createNewAsset(type: AssetType.filamesh, subFolder: 'meshes');
  }

  @override
  void _promptExitStudio(BuildContext? ctx) {
    if (ctx == null) return;
    if (isBatchImporting) {
      // Closing the project mid-batch waits for it or
      // cancels it (the files in progress finish either way).
      showImportRunningPrompt(ctx, then: () => _promptExitStudio(ctx));
      return;
    }
    if (_project.isDirty) {
      showOverlay(
        ctx,
        const DialogConfiguration(),
        builder: (c) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text('Save before exiting?'),
          actions: [
            PrimaryButton(
              onPressed: () {
                saveLevelAndGenerateCode();
                Navigator.of(c).pop();
                Navigator.of(ctx).pop();
              },
              child: const Text('Save & Exit'),
            ),
            DestructiveButton(
              onPressed: () {
                Navigator.of(c).pop();
                Navigator.of(ctx).pop();
              },
              child: const Text('Discard'),
            ),
            OutlineButton(
              onPressed: () {
                Navigator.of(c).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } else {
      Navigator.of(ctx).pop();
    }
  }

  /// Whether the window may close. A running batch import
  /// is waited for or cancelled first; a dirty level asks Save / Don't Save /
  /// Cancel. Resolves true only once it is safe to quit.
  Future<bool> confirmQuit(BuildContext ctx) {
    if (isBatchImporting) {
      final answer = Completer<bool>();
      showImportRunningPrompt(
        ctx,
        then: () => confirmQuit(ctx).then(answer.complete),
        onKeepEditing: () => answer.complete(false),
      );
      return answer.future;
    }
    final dirtyTabs = [for (var i = 1; i < _openTabs.length; i++) if (_self.isTabDirty(i)) _openTabs[i].title];
    if (!_project.isDirty && dirtyTabs.isEmpty) return Future.value(true);
    final answer = Completer<bool>();
    void finish(BuildContext dialog, bool quit) {
      Navigator.of(dialog).pop();
      if (!answer.isCompleted) answer.complete(quit);
    }

    final what = [if (_project.isDirty) activeLevelName, ...dirtyTabs].join(', ');
    showOverlay(
      ctx,
      const DialogConfiguration(),
      builder: (c) => AlertDialog(
        key: const ValueKey('quit_unsaved_prompt'),
        title: const Text('Unsaved Changes'),
        content: Text('$what has unsaved changes. Save before quitting Lumina Studio?'),
        actions: [
          OutlineButton(
            key: const ValueKey('quit_unsaved_cancel'),
            onPressed: () => finish(c, false),
            child: const Text('Cancel'),
          ),
          DestructiveButton(
            key: const ValueKey('quit_unsaved_dont_save'),
            onPressed: () => finish(c, true),
            child: const Text("Don't Save"),
          ),
          PrimaryButton(
            key: const ValueKey('quit_unsaved_save'),
            onPressed: () async {
              Navigator.of(c).pop();
              final saved = await _saveForQuit();
              if (!saved && ctx.mounted) _showQuitSaveFailed(ctx);
              if (!answer.isCompleted) answer.complete(saved);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    return answer.future;
  }

  /// What the quit sequence is doing right now ("Saving L_Main…", "Closing
  /// plugins…", "Closing editor…"), shown over the editor as a notice that
  /// cannot be dismissed; null while the editor is not quitting.
  final ValueNotifier<String?> quitStatus = ValueNotifier<String?>(null);

  /// How long each plugin's `onProjectClosing` / `onEditorShutdown` may run
  /// while the editor quits before the quit goes on without it.
  Duration quitHookTimeout = const Duration(seconds: 5);

  /// Shows [status] and lets it paint before the step's work starts, so the
  /// notice is on screen while that work runs.
  Future<void> _quitStep(String status) async {
    quitStatus.value = status;
    try {
      final binding = WidgetsBinding.instance;
      binding.scheduleFrame();
      await binding.endOfFrame.timeout(const Duration(milliseconds: 250), onTimeout: () {});
    } catch (_) {
      // No widgets binding (a plain unit test): nothing to paint.
    }
  }

  /// The quit prompt's Save: the level, then every dirty sub-editor tab,
  /// each under its own notice. True when everything was saved; on a
  /// failure the notice goes away and the editor stays open.
  Future<bool> _saveForQuit() async {
    var saved = true;
    try {
      if (_project.isDirty) {
        await _quitStep('Saving $activeLevelName…');
        await saveLevelAndGenerateCode();
      }
      for (var i = _openTabs.length - 1; i >= 1; i--) {
        if (!_self.isTabDirty(i)) continue;
        await _quitStep('Saving ${_openTabs[i].title}…');
        saved = await _self.saveTab(i) && saved;
      }
      saved = saved && !_project.isDirty;
    } catch (e) {
      _logger.log('Saving before quitting failed: $e', level: 'error', source: 'SaveLevel');
      saved = false;
    }
    if (!saved) quitStatus.value = null;
    return saved;
  }

  void _showQuitSaveFailed(BuildContext ctx) {
    showToast(
      context: ctx,
      location: ToastLocation.bottomRight,
      builder: (toastCtx, overlay) => const SurfaceCard(
        child: Basic(
          title: Text('Save failed'),
          content: Text('Lumina Studio stays open; see the Output Log.', key: ValueKey('quit_save_failed')),
        ),
      ),
    );
  }

  /// Runs once the quit is confirmed (saved or discarded): the plugins'
  /// closing hooks, each bounded by [quitHookTimeout], then the final
  /// "Closing editor…" notice, which stays up while the window goes.
  Future<void> prepareQuit() async {
    if (extensionRegistry.registeredPlugins.isNotEmpty) {
      await _quitStep('Closing plugins…');
      await _self.shutdownPlugins(exiting: true, hookTimeout: quitHookTimeout);
    }
    await _quitStep('Closing editor…');
  }

  /// Asks whether to wait for the running batch import or cancel it, then
  /// runs [then] once the queue is idle; "Keep Editing" does neither (and
  /// runs [onKeepEditing]).
  void showImportRunningPrompt(BuildContext ctx, {required VoidCallback then, VoidCallback? onKeepEditing}) {
    final jobs = importJobs;
    showOverlay(
      ctx,
      const DialogConfiguration(),
      builder: (c) => AlertDialog(
        title: const Text('Import in Progress'),
        content: Text(
          '${jobs.headline}.\nWait for the import to finish, or cancel it? '
          'Files already importing finish and are kept either way.',
        ),
        actions: [
          OutlineButton(
            key: const ValueKey('import_running_keep_editing'),
            onPressed: () {
              Navigator.of(c).pop();
              onKeepEditing?.call();
            },
            child: const Text('Keep Editing'),
          ),
          DestructiveButton(
            key: const ValueKey('import_running_cancel'),
            onPressed: () {
              Navigator.of(c).pop();
              cancelImports();
              importQueue.idle.then((_) {
                if (ctx.mounted) then();
              });
            },
            child: const Text('Cancel Import'),
          ),
          PrimaryButton(
            key: const ValueKey('import_running_wait'),
            onPressed: () {
              Navigator.of(c).pop();
              jobs.expand();
              importQueue.idle.then((_) {
                if (ctx.mounted) then();
              });
            },
            child: const Text('Wait'),
          ),
        ],
      ),
    );
  }

  @override
  void _showAboutDialog(BuildContext? ctx) {
    if (ctx == null) return;
    // The engine version and what renders it.
    showAboutLuminaDialog(ctx, engineVersion: engineVersion);
  }
}
