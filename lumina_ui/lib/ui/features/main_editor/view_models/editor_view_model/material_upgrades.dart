part of '../editor_view_model.dart';

/// Brings the project's material assets to the linked Filament release once
/// they are scanned: a material compiled for another material version (which
/// the engine refuses, so it would draw nothing) or whose `.mat` source uses
/// what the release deprecated is rewritten and compiled again
/// ([MaterialAssetUpgrader]), in the background, one at a time. Each asset is
/// checked once per session; every upgrade, and every material that could not
/// be upgraded, is reported to the Output Log.
mixin _EditorMaterialUpgrades on _EditorViewModelState {
  final Set<String> _materialUpgradeChecked = {};
  bool _materialUpgradeRunning = false;
  Future<void>? _materialUpgradePass;

  /// Completes once the pass started by the last asset scan is done.
  Future<void> get materialUpgradesIdle => _materialUpgradePass ?? Future.value();

  @override
  void _upgradeStaleMaterials() {
    if (!_autoUpgradeMaterials || _disposed || _materialUpgradeRunning) return;
    final paths = [
      for (final a in _realAssets)
        if (a.type == AssetType.filamat && a.lmasPath != null && _materialUpgradeChecked.add(a.lmasPath!)) a.lmasPath!,
    ];
    if (paths.isEmpty) return;
    _materialUpgradeRunning = true;
    _materialUpgradePass = _runMaterialUpgrades(paths);
  }

  Future<void> _runMaterialUpgrades(List<String> paths) async {
    try {
      final outcomes = await MaterialAssetUpgrader().upgradeAll(paths);
      if (_disposed) return;
      for (final o in outcomes) {
        _logger.log(o.describe(), level: o.upgraded ? 'info' : 'warning', source: 'MaterialUpgrade');
      }
      // The viewport draws a material again when its file changed.
      if (outcomes.any((o) => o.upgraded)) notifyListeners();
    } catch (e, st) {
      _logger.log('Material upgrade failed: $e\n$st', level: 'error', source: 'MaterialUpgrade');
    } finally {
      _materialUpgradeRunning = false;
    }
  }
}
