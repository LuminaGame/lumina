part of '../editor_view_model.dart';

/// Window → Marketplace: the window's view model, wired to
/// this editor (the open project, the background import queue, the plugin
/// scan, the Output Log), and the Content Browser's Marketplace smart view.
mixin _EditorMarketplace on _EditorViewModelState {
  /// The Marketplace window's state, created on first use against the
  /// server in Editor Preferences (and following it when it changes).
  MarketplaceViewModel get marketplace {
    final existing = _marketplace;
    if (existing != null) return existing;
    final vm = MarketplaceViewModel(
      serverUrl: Uri.parse(editorPreferences.marketplaceUrl),
      host: MarketplaceHost(
        projectRoot: projectDirPath,
        importRequests: _self.importRequests,
        onProjectContentInstalled: (_) {
          if (_disposed) return;
          _refreshAssets();
          sourceControl.refresh();
          notifyListeners();
        },
        onPluginsChanged: _self.rescanPlugins,
        openPluginManager: () => openSubEditorTab('plugins', title: 'Plugins'),
        log: (message, level) => _logger.log(message, level: level, source: 'Marketplace'),
      ),
    );
    editorPreferences.addListener(_followMarketplaceUrl);
    return _marketplace = vm;
  }

  void _followMarketplaceUrl() {
    final url = Uri.tryParse(editorPreferences.marketplaceUrl);
    final vm = _marketplace;
    if (url != null && vm != null) unawaited(vm.setServerUrl(url));
  }

  /// Opens (or focuses) the Marketplace tab.
  void openMarketplace() =>
      openSubEditorTab(EditorViewModel.marketplaceCategory, title: 'Marketplace');

  bool get showMarketplaceAssets => _showMarketplaceAssets;
  set showMarketplaceAssets(bool value) {
    if (_showMarketplaceAssets == value) return;
    _showMarketplaceAssets = value;
    if (value) {
      _showRecentlyModified = false;
      _activeCollection = null;
      _selectedFolder = null;
    }
    notifyListeners();
  }

  void _disposeMarketplace() {
    if (_marketplace == null) return;
    editorPreferences.removeListener(_followMarketplaceUrl);
    _marketplace!.dispose();
    _marketplace = null;
  }
}
