part of '../editor_view_model.dart';

/// Registration of every editor command (menus and shortcuts).
mixin _EditorCommands on _EditorViewModelState {
  void _initCommands() {
    commands.register(
      EditorCommand(
        id: 'editor.restart',
        label: 'Restart Editor',
        canExecute: () => true,
        execute: (ctx) => restartEditor(),
      ),
    );
    commands.register(
      EditorCommand(
        id: 'tool.select',
        label: 'Select Object',
        shortcutLabel: 'Q',
        canExecute: () => true,
        execute: (ctx) => setActiveTool('select'),
      ),
    );
    commands.register(
      EditorCommand(
        id: 'tool.translate',
        label: 'Translate Object',
        shortcutLabel: 'W',
        canExecute: () => true,
        execute: (ctx) => setActiveTool('translate'),
      ),
    );
    commands.register(
      EditorCommand(
        id: 'tool.rotate',
        label: 'Rotate Object',
        shortcutLabel: 'E',
        canExecute: () => true,
        execute: (ctx) => setActiveTool('rotate'),
      ),
    );
    commands.register(
      EditorCommand(
        id: 'tool.scale',
        label: 'Scale Object',
        shortcutLabel: 'R',
        canExecute: () => true,
        execute: (ctx) => setActiveTool('scale'),
      ),
    );
    commands.register(
      EditorCommand(
        id: 'view.focusSelected',
        label: 'Focus Selected',
        shortcutLabel: 'F',
        canExecute: () => selectedActor != null,
        execute: (ctx) => focusCameraOnActor(selectedActor!),
      ),
    );

    commands.register(
      EditorCommand(
        id: 'shell.cancel',
        label: 'Cancel',
        shortcutLabel: 'Esc',
        canExecute: () => true, // Real logic later
        execute: (ctx) => cancelActiveOperation(),
      ),
    );

    commands.register(
      EditorCommand(
        id: 'shell.quickOpen',
        label: 'Quick Open',
        shortcutLabel: 'Ctrl+P',
        canExecute: () => true,
        execute: (ctx) => {}, // Handled by ShortcutScope, but registered here
      ),
    );

    commands.registerAll([
      // File
      EditorCommand(
        id: 'file.newLevel',
        label: 'New Level...',
        shortcutLabel: 'Ctrl+N',
        canExecute: () => true,
        execute: (ctx) => _promptNewLevel(ctx),
      ),
      EditorCommand(
        id: 'file.openLevel',
        label: 'Open Level...',
        shortcutLabel: 'Ctrl+O',
        canExecute: () => true,
        execute: (ctx) => _promptOpenLevel(ctx),
      ),
      EditorCommand(
        id: 'file.saveLevel',
        label: 'Save Level',
        shortcutLabel: 'Ctrl+S',
        canExecute: () => _project.isDirty,
        execute: (ctx) => saveLevelAndGenerateCode(),
      ),
      EditorCommand(
        id: 'file.saveAll',
        label: 'Save All',
        shortcutLabel: 'Ctrl+Shift+S',
        canExecute: () => _project.isDirty,
        execute: (ctx) => saveLevelAndGenerateCode(),
      ),
      EditorCommand(
        id: 'file.newAsset',
        label: 'New Asset...',
        shortcutLabel: 'Ctrl+Shift+A',
        canExecute: () => true,
        execute: (ctx) => _promptNewAsset(ctx),
      ),
      EditorCommand(
        id: 'file.importAssetFolder',
        label: 'Import Asset Folder...',
        shortcutLabel: 'Ctrl+Shift+I',
        icon: LucideIcons.folderInput,
        canExecute: () => true,
        execute: (ctx) {
          if (ctx != null) startImportAssetFolder(ctx, _self);
        },
      ),
      EditorCommand(
        id: 'file.exitStudio',
        label: 'Exit Studio',
        shortcutLabel: 'Alt+F4',
        canExecute: () => true,
        execute: (ctx) => _promptExitStudio(ctx),
      ),

      // Outliner
      EditorCommand(
        id: 'outliner.newFolder',
        label: 'New Folder',
        canExecute: () => !_isPlaying,
        execute: (ctx) => createFolderFromSelection(),
      ),
      EditorCommand(
        id: 'outliner.rename',
        label: 'Rename',
        shortcutLabel: 'F2',
        canExecute: () => _selectedActor != null && !_isPlaying,
        execute: (ctx) => requestOutlinerRename(_selectedActor!.id),
      ),

      // Edit
      EditorCommand(
        id: 'edit.undo',
        label: 'Undo',
        shortcutLabel: 'Ctrl+Z',
        canExecute: () => transactions.canUndo && !transactions.isFrozen,
        execute: (ctx) => transactions.undo(),
      ),
      EditorCommand(
        id: 'edit.redo',
        label: 'Redo',
        shortcutLabel: 'Ctrl+Y',
        canExecute: () => transactions.canRedo && !transactions.isFrozen,
        execute: (ctx) => transactions.redo(),
      ),
      EditorCommand(
        id: 'edit.duplicate',
        label: 'Duplicate',
        shortcutLabel: 'Ctrl+D',
        canExecute: () => selectedActor != null,
        execute: (ctx) => duplicateSelectedActor(),
      ),
      EditorCommand(
        id: 'edit.delete',
        label: 'Delete',
        shortcutLabel: 'Del',
        canExecute: () => selectedActor != null,
        execute: (ctx) => deleteSelectedActor(),
      ),
      EditorCommand(
        id: 'edit.projectSettings',
        label: 'Project Settings...',
        canExecute: () => true,
        execute: (ctx) =>
            openSubEditorTab('projectSettings', title: 'Project Settings'),
      ),
      // The active level's Blueprint (also under the toolbar's
      // Blueprints ▸ Open Level Blueprint).
      EditorCommand(
        id: 'edit.levelBlueprint',
        label: 'Level Blueprint',
        shortcutLabel: 'Ctrl+Shift+B',
        canExecute: () => _project.activeLevel.isNotEmpty,
        execute: (ctx) => openLevelBlueprint(),
      ),
      // The user's own editor settings, in the Edit menu.
      EditorCommand(
        id: 'edit.editorPreferences',
        label: 'Editor Preferences...',
        canExecute: () => true,
        execute: (ctx) =>
            openSubEditorTab('editorPreferences', title: 'Editor Preferences'),
      ),

      // View
      // the window's own fullscreen (F11), the same toggle
      // as the fullscreen button in the menu bar row.
      EditorCommand(
        id: 'view.fullscreen',
        label: 'Full Screen',
        shortcutLabel: 'F11',
        icon: LucideIcons.maximize,
        canExecute: () => true,
        execute: (ctx) => (ctx == null ? LuminaWindow.instance : LuminaWindowScope.read(ctx)).toggleFullScreen(),
      ),
      EditorCommand(
        id: 'view.resetCamera',
        label: 'Reset Camera',
        canExecute: () => true,
        execute: (ctx) => resetCamera(),
      ),
      EditorCommand(
        id: 'view.viewportMode.lit',
        label: 'Lit',
        canExecute: () => true,
        execute: (ctx) => setViewportMode('Lit'),
      ),
      EditorCommand(
        id: 'view.viewportMode.unlit',
        label: 'Unlit',
        canExecute: () => true,
        execute: (ctx) => setViewportMode('Unlit'),
      ),
      EditorCommand(
        id: 'view.viewportMode.wireframe',
        label: 'Wireframe',
        canExecute: () => true,
        execute: (ctx) => setViewportMode('Wireframe'),
      ),
      EditorCommand(
        id: 'view.viewportMode.buffer',
        label: 'Buffer Visualization',
        canExecute: () => true,
        execute: (ctx) => setViewportMode('Buffer'),
      ),

      EditorCommand(
        id: 'view.cameraMode.perspective',
        label: 'Perspective',
        canExecute: () => true,
        execute: (ctx) => setCameraMode('Perspective'),
      ),
      EditorCommand(
        id: 'view.cameraMode.top',
        label: 'Top',
        canExecute: () => true,
        execute: (ctx) => setCameraMode('Top'),
      ),
      EditorCommand(
        id: 'view.cameraMode.front',
        label: 'Front',
        canExecute: () => true,
        execute: (ctx) => setCameraMode('Front'),
      ),
      EditorCommand(
        id: 'view.cameraMode.right',
        label: 'Right',
        canExecute: () => true,
        execute: (ctx) => setCameraMode('Right'),
      ),

      // Build
      EditorCommand(
        id: 'build.generateDartCode',
        label: 'Generate Dart Code',
        canExecute: () => true,
        execute: (ctx) => generateDartCode(),
      ),
      EditorCommand(
        id: 'build.buildManager',
        label: 'Build Manager...',
        canExecute: () => true,
        execute: (ctx) =>
            openSubEditorTab('buildManager', title: 'Build Manager'),
      ),
      EditorCommand(
        id: 'build.buildNavigation',
        label: 'Build Navigation',
        canExecute: () => true,
        execute: (ctx) => requestNavigationBuild(),
      ),
      EditorCommand(
        id: 'build.buildAll',
        label: 'Build All',
        canExecute: () => !buildManagerViewModel.isRunning,
        execute: (ctx) {
          openSubEditorTab('buildManager', title: 'Build Manager');
          buildManagerViewModel.buildAll();
        },
      ),
      EditorCommand(
        id: 'build.cookAndPackage',
        label: 'Cook & Package',
        canExecute: () => !buildManagerViewModel.isRunning,
        execute: (ctx) {
          openSubEditorTab('buildManager', title: 'Build Manager');
          _cookAndPackageFromMenu();
        },
      ),

      // Debug
      EditorCommand(
        id: 'debug.togglePie',
        label: 'Play / Stop Simulation',
        shortcutLabel: 'Alt+P',
        canExecute: () => true,
        execute: (ctx) => togglePlaySimulation(),
      ),
      EditorCommand(
        id: 'debug.pausePie',
        label: 'Pause Simulation',
        shortcutLabel: 'Pause',
        canExecute: () => isPlaying && !isPaused,
        execute: (ctx) => togglePauseSimulation(),
      ),
      EditorCommand(
        id: 'debug.stepPie',
        label: 'Step Frame',
        shortcutLabel: 'F10',
        canExecute: () => isPlaying && isPaused,
        execute: (ctx) => stepSimulation(),
      ),
      EditorCommand(
        id: 'debug.stopPie',
        label: 'Stop Simulation',
        shortcutLabel: 'Esc',
        canExecute: () => isPlaying || standalone.isActive,
        // Stop ends PIE, else the standalone game.
        execute: (ctx) => isPlaying ? stopSimulation() : unawaited(stopStandalone()),
      ),
      EditorCommand(
        id: 'debug.playStandalone',
        label: 'Play Standalone',
        canExecute: () => !standalone.isActive,
        execute: (ctx) => unawaited(playStandalone()),
      ),

      // Tools
      EditorCommand(
        id: 'tools.plugins',
        // Plugins → Plugin Manager… (the id stays for shortcuts).
        label: 'Plugin Manager...',
        canExecute: () => true,
        execute: (ctx) => openSubEditorTab('plugins', title: 'Plugins'),
      ),
      // Tools → AI Agent Access (MCP).
      EditorCommand(
        id: 'tools.aiAgentAccess',
        label: 'AI Agent Access (MCP)...',
        canExecute: () => true,
        execute: (ctx) => openSubEditorTab('mcpServer', title: 'AI Agent Access (MCP)'),
      ),
      EditorCommand(
        id: 'tools.clearDerivedDataCache',
        label: 'Clear Derived Data Cache',
        canExecute: () => true,
        execute: (ctx) => unawaited(clearDerivedDataCache()),
      ),
      EditorCommand(
        id: 'tools.plugins.new',
        label: 'New Plugin...',
        canExecute: () => true,
        execute: (ctx) {
          if (ctx != null) {
            final vm = PluginManagerViewModel(registryService: pluginRegistry);
            showNewPluginWizard(ctx, viewModel: vm);
          }
        },
      ),
      EditorCommand(
        id: 'tools.materialEditor',
        label: 'Material Editor',
        canExecute: () => true,
        execute: (ctx) =>
            openSubEditorTab('material', title: 'Material Editor'),
      ),
      EditorCommand(
        id: 'tools.blueprintEditor',
        label: 'Blueprint Editor',
        canExecute: () => true,
        execute: (ctx) =>
            openSubEditorTab('blueprint', title: 'Blueprint Editor'),
      ),
      EditorCommand(
        id: 'tools.meshInspector',
        label: 'Mesh Inspector',
        canExecute: () => true,
        execute: (ctx) => openSubEditorTab('mesh', title: 'Mesh Inspector'),
      ),
      EditorCommand(
        id: 'tools.landscapeEditor',
        label: 'Landscape Editor',
        canExecute: () => true,
        execute: (ctx) =>
            openSubEditorTab('landscape', title: 'Landscape Editor'),
      ),
      EditorCommand(
        id: 'tools.environmentLighting',
        label: 'Environment Lighting',
        canExecute: () => true,
        execute: (ctx) =>
            openSubEditorTab('lighting', title: 'Environment Lighting'),
      ),
      EditorCommand(
        id: 'tools.sequencer',
        label: 'Sequencer',
        canExecute: () => true,
        execute: (ctx) => openSubEditorTab('sequencer', title: 'Sequencer'),
      ),
      EditorCommand(
        id: 'tools.umgDesigner',
        label: 'UMG UI Designer',
        canExecute: () => true,
        execute: (ctx) => openSubEditorTab('umg', title: 'UMG UI Designer'),
      ),
      EditorCommand(
        id: 'tools.navmeshGenerator',
        label: 'Navigation Editor',
        canExecute: () => true,
        execute: (ctx) => openSubEditorTab('navmesh', title: 'Navigation'),
      ),

      // Window
      // browse, get and install Marketplace listings.
      EditorCommand(
        id: 'window.marketplace',
        label: 'Marketplace',
        icon: LucideIcons.store,
        canExecute: () => true,
        execute: (ctx) => _self.openMarketplace(),
      ),
      EditorCommand(
        id: 'window.toggleOutliner',
        label: 'Outliner',
        canExecute: () => true,
        execute: (ctx) {
          layoutState.outlinerVisible = !layoutState.outlinerVisible;
          saveLayoutState();
          notifyListeners();
        },
      ),
      EditorCommand(
        id: 'window.toggleDetails',
        label: 'Details',
        canExecute: () => true,
        execute: (ctx) {
          layoutState.detailsVisible = !layoutState.detailsVisible;
          saveLayoutState();
          notifyListeners();
        },
      ),
      EditorCommand(
        id: 'window.toggleBottomPanel',
        label: 'Bottom Panel',
        canExecute: () => true,
        execute: (ctx) {
          layoutState.bottomVisible = !layoutState.bottomVisible;
          saveLayoutState();
          notifyListeners();
        },
      ),
      // Shows the bottom panel on the Output Log tab and
      // never hides it — the Output Log is a tab, and as with other Window
      // tab entries a click while it is already showing changes nothing. The
      // Window row is checked while it shows (`EditorLayoutState.isOutputLogOpen`).
      EditorCommand(
        id: 'window.showOutputLog',
        label: 'Output Log',
        canExecute: () => true,
        execute: (ctx) {
          layoutState.bottomVisible = true;
          layoutState.activeBottomTab = EditorLayoutState.outputLogTab;
          saveLayoutState();
          notifyListeners();
        },
      ),
      EditorCommand(
        id: 'window.resetLayout',
        label: 'Reset Layout',
        canExecute: () => true,
        execute: (ctx) {
          layoutState.resetToDefault();
          saveLayoutState();
        },
      ),

      // Help
      EditorCommand(
        id: 'help.about',
        label: 'About Lumina Studio',
        canExecute: () => true,
        execute: (ctx) => _showAboutDialog(ctx),
      ),
    ]);
    commands.registerAll(buildSourceControlCommands(_self));
  }
}
