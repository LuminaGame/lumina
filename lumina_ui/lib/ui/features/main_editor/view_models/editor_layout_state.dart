import 'dart:convert';
import 'package:flutter/foundation.dart';

/// The main editor shell's persisted layout.
///
/// The shell is Outliner over Details in one left column, the viewport in the
/// centre and the Content Browser / Output Log / Blueprint panel along the
/// bottom. [outlinerWidth] is the left column's width, [detailsHeight] the
/// Details pane's height under the Outliner, [bottomHeight] the bottom
/// panel's. The bottom panel is open and pinned by default; unpinned it is a
/// Content Drawer whose open state is [bottomVisible] and which the status
/// bar's folder button opens and closes.
///
/// The Content Browser's Sources rail is part of the
/// layout too: [sourcesWidth] is the rail's width beside the asset grid and
/// [expandedFolders] the folders open in its tree (only `contents` by
/// default). [resetSerial] changes on every [resetToDefault], so a pane that
/// ignores a new initial size can be re-created.
class EditorLayoutState extends ChangeNotifier {
  static const double defaultOutlinerWidth = 220.0;
  static const double defaultDetailsHeight = 320.0;
  static const double defaultBottomHeight = 240.0;

  /// The prototype's `w-36` Sources column, and the splitter's limits.
  static const double defaultSourcesWidth = 144.0;
  static const double minSourcesWidth = 110.0;
  static const double maxSourcesWidth = 480.0;
  static const Set<String> defaultExpandedFolders = {'contents'};

  /// The right dock of `PanelDefaultDock.right` plugin panels.
  static const double defaultRightWidth = 340.0;
  static const double minRightWidth = 260.0;

  double outlinerWidth;
  double detailsHeight;
  double bottomHeight;
  bool outlinerVisible;
  bool detailsVisible;
  bool bottomVisible;
  bool bottomPinned;
  int activeBottomTab;
  double sourcesWidth;
  Set<String> expandedFolders;

  /// The right dock's width, which plugin panels are open (a
  /// right-dock panel is closed until shown) and the right dock's active tab.
  double rightWidth;
  Map<String, bool> pluginPanelVisible;
  String? activeRightPanel;
  int resetSerial = 0;

  EditorLayoutState({
    this.outlinerWidth = defaultOutlinerWidth,
    this.detailsHeight = defaultDetailsHeight,
    this.bottomHeight = defaultBottomHeight,
    this.outlinerVisible = true,
    this.detailsVisible = true,
    this.bottomVisible = true,
    this.bottomPinned = true,
    this.activeBottomTab = 0,
    double sourcesWidth = defaultSourcesWidth,
    Set<String>? expandedFolders,
    double rightWidth = defaultRightWidth,
    Map<String, bool>? pluginPanelVisible,
    this.activeRightPanel,
  })  : sourcesWidth = clampSourcesWidth(sourcesWidth),
        expandedFolders = expandedFolders ?? {...defaultExpandedFolders},
        rightWidth = clampRightWidth(rightWidth),
        pluginPanelVisible = pluginPanelVisible ?? {};

  static double clampRightWidth(double width) => width < minRightWidth ? minRightWidth : width;

  static double clampSourcesWidth(double width) => width.clamp(minSourcesWidth, maxSourcesWidth).toDouble();

  /// Unknown and old keys (`detailsWidth` from the three-column layout) are
  /// ignored. A file without `bottomPinned` predates the Content Drawer: its
  /// bottom panel comes up open and pinned, the new arrangement's default.
  factory EditorLayoutState.fromJson(Map<String, dynamic> json) {
    final legacy = !json.containsKey('bottomPinned');
    return EditorLayoutState(
      outlinerWidth: (json['outlinerWidth'] as num?)?.toDouble() ?? defaultOutlinerWidth,
      detailsHeight: (json['detailsHeight'] as num?)?.toDouble() ?? defaultDetailsHeight,
      bottomHeight: (json['bottomHeight'] as num?)?.toDouble() ?? defaultBottomHeight,
      outlinerVisible: json['outlinerVisible'] as bool? ?? true,
      detailsVisible: json['detailsVisible'] as bool? ?? true,
      bottomVisible: legacy ? true : (json['bottomVisible'] as bool? ?? true),
      bottomPinned: legacy ? true : (json['bottomPinned'] as bool? ?? true),
      activeBottomTab: json['activeBottomTab'] as int? ?? 0,
      sourcesWidth: (json['sourcesWidth'] as num?)?.toDouble() ?? defaultSourcesWidth,
      expandedFolders: (json['expandedFolders'] as List?)?.whereType<String>().toSet(),
      rightWidth: (json['rightWidth'] as num?)?.toDouble() ?? defaultRightWidth,
      pluginPanelVisible: (json['pluginPanelVisible'] as Map?)?.map((k, v) => MapEntry('$k', v == true)),
      activeRightPanel: json['activeRightPanel'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'outlinerWidth': outlinerWidth,
      'detailsHeight': detailsHeight,
      'bottomHeight': bottomHeight,
      'outlinerVisible': outlinerVisible,
      'detailsVisible': detailsVisible,
      'bottomVisible': bottomVisible,
      'bottomPinned': bottomPinned,
      'activeBottomTab': activeBottomTab,
      'sourcesWidth': sourcesWidth,
      'expandedFolders': (expandedFolders.toList()..sort()),
      'rightWidth': rightWidth,
      'pluginPanelVisible': pluginPanelVisible,
      'activeRightPanel': activeRightPanel,
    };
  }

  String encode() => jsonEncode(toJson());

  /// The bottom panel's built-in tabs (Content Browser, Output Log).
  static const int contentBrowserTab = 0;
  static const int outputLogTab = 1;

  // What the Window menu's checkbox rows show.
  bool get isOutlinerOpen => outlinerVisible;
  bool get isDetailsOpen => detailsVisible;
  bool get isBottomPanelOpen => bottomVisible;

  /// The Output Log is a tab: open while the bottom panel shows it.
  bool get isOutputLogOpen => bottomVisible && activeBottomTab == outputLogTab;

  void resetToDefault() {
    outlinerWidth = defaultOutlinerWidth;
    detailsHeight = defaultDetailsHeight;
    bottomHeight = defaultBottomHeight;
    outlinerVisible = true;
    detailsVisible = true;
    bottomVisible = true;
    bottomPinned = true;
    activeBottomTab = 0;
    sourcesWidth = defaultSourcesWidth;
    expandedFolders = {...defaultExpandedFolders};
    rightWidth = defaultRightWidth;
    pluginPanelVisible = {};
    activeRightPanel = null;
    resetSerial++;
    notifyListeners();
  }
}

/// One layout flag as a [ValueListenable]: [read] of the
/// current layout, re-read whenever [source] notifies. [source] is the view
/// model, which notifies on every layout change and replaces the layout when
/// it loads one, so a menu row bound to it stays current while it is open.
class EditorLayoutFlag implements ValueListenable<bool> {
  EditorLayoutFlag(this._source, this._layout, this._read);

  final Listenable _source;
  final EditorLayoutState Function() _layout;
  final bool Function(EditorLayoutState layout) _read;

  @override
  bool get value => _read(_layout());

  @override
  void addListener(VoidCallback listener) => _source.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _source.removeListener(listener);
}
