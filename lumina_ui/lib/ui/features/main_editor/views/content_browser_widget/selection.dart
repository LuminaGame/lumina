part of '../content_browser_widget.dart';

/// Asset selection: click/shift/ctrl handling, display names and
/// reveal-in-browser requests.
mixin _ContentBrowserSelection on _ContentBrowserWidgetStateBase {

  @override
  String _displayName(String fileName) {
    if (fileName.contains('.')) {
      return fileName.substring(0, fileName.lastIndexOf('.'));
    }
    return fileName;
  }

  void _handleAssetClick(
    RealAssetInfo asset,
    List<RealAssetInfo> filteredAssets,
  ) {
    final isCtrl =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final path = asset.relativePath;

    setState(() {
      if (isShift && _lastSelectedAssetPath != null) {
        final lastIdx = filteredAssets.indexWhere(
          (a) => a.relativePath == _lastSelectedAssetPath,
        );
        final currentIdx = filteredAssets.indexWhere(
          (a) => a.relativePath == path,
        );

        if (lastIdx != -1 && currentIdx != -1) {
          final start = math.min(lastIdx, currentIdx);
          final end = math.max(lastIdx, currentIdx);

          if (!isCtrl) {
            _selectedAssetPaths.clear();
          }

          for (int i = start; i <= end; i++) {
            _selectedAssetPaths.add(filteredAssets[i].relativePath);
          }
        } else {
          _selectedAssetPaths.add(path);
          _lastSelectedAssetPath = path;
        }
      } else if (isCtrl) {
        if (_selectedAssetPaths.contains(path)) {
          _selectedAssetPaths.remove(path);
        } else {
          _selectedAssetPaths.add(path);
          _lastSelectedAssetPath = path;
        }
      } else {
        _selectedAssetPaths.clear();
        _selectedAssetPaths.add(path);
        _lastSelectedAssetPath = path;
      }
    });
  }

  /// Selects the asset "Browse to asset" asked for, once per request.
  void _applyRevealRequest(EditorViewModel vm) {
    final serial = vm.contentBrowserRevealSerial;
    final path = vm.contentBrowserRevealPath;
    if (serial == _handledRevealSerial || path == null) return;
    _handledRevealSerial = serial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _searchDebouncer?.cancel();
        _searchController.clear();
        _selectedFolderTile = null;
        _selectedAssetPaths
          ..clear()
          ..add(path);
        _lastSelectedAssetPath = path;
      });
    });
  }
}
