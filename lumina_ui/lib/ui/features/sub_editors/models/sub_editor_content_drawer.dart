import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A sub-editor tab's Content Browser: docked in the tab ([pinned]) or a
/// drawer that opens over its bottom ([open]). The tab's workspace shell
/// shows it; the editor's status bar toggles it.
class SubEditorContentDrawer extends ChangeNotifier {
  bool _pinned;
  bool _open;

  SubEditorContentDrawer({required bool pinned}) : _pinned = pinned, _open = pinned;

  bool get pinned => _pinned;
  bool get open => _open;

  /// Opens or closes the drawer (a pinned panel stays open).
  void toggle() => setOpen(!_open);

  void setOpen(bool value) {
    if (_pinned || value == _open) return;
    _open = value;
    notifyListeners();
  }

  /// Docks the panel in the tab, or turns it back into a closed drawer.
  void setPinned(bool value) {
    if (value == _pinned) return;
    _pinned = value;
    _open = value;
    notifyListeners();
  }
}
