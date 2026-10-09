part of '../launcher_view.dart';

/// The launcher state its mixins share: the loading and opening fields.
abstract class _LauncherViewStateBase extends State<LauncherView> {
  late final LauncherViewModel _viewModel;
  late bool _loadingInitialProject;
  String _initialLoadingStatus = 'Opening project…';
  double? _initialLoadingProgress = 0.20;
  String? _startupError;

  late bool _loadingLauncher;
  String _launcherLoadingStatus = 'Scanning projects…';
  double? _launcherLoadingProgress = 0.25;

  LuminaProject? _openingProject;
  String _openingProjectStatus = 'Opening project…';
  double? _openingProjectProgress = 0.30;

  /// "Checking project editor…" while the resolver runs.
  bool _resolving = false;
}
