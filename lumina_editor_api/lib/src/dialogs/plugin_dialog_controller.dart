import 'package:flutter/widgets.dart';

typedef PluginDialogBuilder = Widget Function(BuildContext context, PluginDialogController controller);

/// Controller managing a single plugin dialog's lifecycle, status bar info,
/// progress, and minimize/restore transitions.
class PluginDialogController extends ChangeNotifier {
  final String id;
  final String pluginId;
  final String pluginName;
  final IconData? pluginIcon;
  final String title;
  String minimizedTitle;
  String? statusText;
  double? progress;
  bool isMinimized;
  bool isClosed;
  final bool barrierDismissible;
  final double width;
  final double height;
  final PluginDialogBuilder builder;
  VoidCallback? onCancelled;
  VoidCallback? onCompleted;

  /// Arbitrary background task data (e.g. active [PluginDownloader]) preserved
  /// across minimize and restore.
  dynamic taskData;

  /// Custom key-value state preserved across minimize and restore.
  final Map<String, dynamic> customState = {};

  VoidCallback? _onMinimizeRequested;
  VoidCallback? _onCloseRequested;
  void Function(BuildContext context)? _onRestoreRequested;

  PluginDialogController({
    String? id,
    required this.pluginId,
    required this.pluginName,
    this.pluginIcon,
    required this.title,
    String? minimizedTitle,
    this.statusText,
    this.progress,
    this.isMinimized = false,
    this.isClosed = false,
    this.barrierDismissible = false,
    this.width = 640,
    this.height = 670,
    required this.builder,
    this.onCancelled,
    this.onCompleted,
    this.taskData,
  })  : id = id ?? '${pluginId}_${DateTime.now().microsecondsSinceEpoch}',
        minimizedTitle = minimizedTitle ?? title;

  /// Internal hook used by [showPluginDialog] to register minimize callback.
  void attachOverlayHandlers({
    required VoidCallback onMinimize,
    required VoidCallback onClose,
    required void Function(BuildContext context) onRestore,
  }) {
    _onMinimizeRequested = onMinimize;
    _onCloseRequested = onClose;
    _onRestoreRequested = onRestore;
  }

  /// Updates the dialog's live status text and progress bar.
  void updateStatus({String? text, double? progress, bool notify = true}) {
    var changed = false;
    if (text != null && text != statusText) {
      statusText = text;
      changed = true;
    }
    if (progress != null && progress != this.progress) {
      this.progress = progress;
      changed = true;
    }
    if (changed && notify) {
      notifyListeners();
      PluginDialogManager.instance.notify();
    }
  }

  /// Minimizes the dialog into the editor status bar.
  void minimize() {
    if (isClosed || isMinimized) return;
    isMinimized = true;
    notifyListeners();
    _onMinimizeRequested?.call();
    PluginDialogManager.instance.notify();
  }

  /// Restores the minimized dialog back onto the screen.
  void restore(BuildContext context) {
    if (isClosed || !isMinimized) return;
    isMinimized = false;
    notifyListeners();
    _onRestoreRequested?.call(context);
    PluginDialogManager.instance.notify();
  }

  /// Closes the dialog completely and cleans up.
  void close() {
    if (isClosed) return;
    isClosed = true;
    notifyListeners();
    _onCloseRequested?.call();
    PluginDialogManager.instance.unregister(this);
  }
}

/// Global registry of active and minimized plugin dialogs.
class PluginDialogManager extends ChangeNotifier {
  PluginDialogManager._();
  static final PluginDialogManager instance = PluginDialogManager._();

  final List<PluginDialogController> _dialogs = [];

  List<PluginDialogController> get activeDialogs =>
      List.unmodifiable(_dialogs.where((d) => !d.isClosed));

  List<PluginDialogController> get minimizedDialogs =>
      List.unmodifiable(_dialogs.where((d) => d.isMinimized && !d.isClosed));

  void register(PluginDialogController controller) {
    if (!_dialogs.any((d) => d.id == controller.id)) {
      _dialogs.add(controller);
      notifyListeners();
    }
  }

  void unregister(PluginDialogController controller) {
    final before = _dialogs.length;
    _dialogs.removeWhere((d) => d.id == controller.id);
    if (_dialogs.length != before) {
      notifyListeners();
    }
  }

  void notify() => notifyListeners();

  /// Clears all dialogs (e.g. on editor shutdown or in tests).
  void clear() {
    for (final d in _dialogs) {
      d.isClosed = true;
    }
    _dialogs.clear();
    notifyListeners();
  }
}
