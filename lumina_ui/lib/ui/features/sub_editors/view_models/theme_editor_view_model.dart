import 'dart:io';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:lumina_editor_data/lumina_editor.dart';

/// Selection target in the Theme Editor tree.
class ThemeTreeSelection {
  final String id;
  final String category; // 'tokens', 'component', 'custom', 'typography', 'radius'
  final String? targetKey;

  const ThemeTreeSelection({
    required this.id,
    required this.category,
    this.targetKey,
  });

  static const ThemeTreeSelection colors = ThemeTreeSelection(
    id: 'colors',
    category: 'tokens',
  );
}

/// View model for the Theme Sub-Editor.
class ThemeEditorViewModel extends ChangeNotifier {
  final String assetPath;
  final LuminaAsset? initialAsset;

  late LuminaThemeDocument _doc;
  late LuminaThemeDocument _initialDoc;
  bool _isDirty = false;
  bool _isLoaded = false;
  ThemeTreeSelection _selection = ThemeTreeSelection.colors;

  ThemeEditorViewModel({
    required this.assetPath,
    this.initialAsset,
  }) {
    if (initialAsset != null) {
      _doc = LuminaThemeDocument.fromAsset(initialAsset!);
      _initialDoc = _doc;
      _isLoaded = true;
    } else {
      _doc = LuminaThemeDocument.defaultShadcnDark();
      _initialDoc = _doc;
    }
  }

  LuminaThemeDocument get doc => _doc;
  bool get isDirty => _isDirty;
  bool get isLoaded => _isLoaded;
  ThemeTreeSelection get selection => _selection;

  Future<void> load() async {
    final file = File(assetPath);
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      final asset = LuminaAsset.fromBytes(bytes);
      _doc = LuminaThemeDocument.fromAsset(asset);
    } else {
      _doc = LuminaThemeDocument.defaultShadcnDark();
    }
    _initialDoc = _doc;
    _isLoaded = true;
    _isDirty = false;
    notifyListeners();
  }

  Future<bool> save() async {
    try {
      final file = File(assetPath);
      final parent = file.parent;
      if (!parent.existsSync()) {
        parent.createSync(recursive: true);
      }
      final assetName = file.uri.pathSegments.last.replaceAll('.lmas', '');
      final asset = _doc.toAsset(name: assetName);
      await file.writeAsBytes(asset.toProtoBufferBytes());
      _initialDoc = _doc;
      _isDirty = false;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void selectItem(ThemeTreeSelection selection) {
    _selection = selection;
    notifyListeners();
  }

  void setColor(String token, int argb) {
    final updatedColors = Map<String, int>.from(_doc.colors);
    updatedColors[token] = argb;
    _doc = _doc.copyWith(colors: updatedColors);
    _isDirty = true;
    notifyListeners();
  }

  void setRadius(double radius) {
    _doc = _doc.copyWith(radius: radius);
    _isDirty = true;
    notifyListeners();
  }

  void setTypography({
    String? fontFamily,
    double? baseFontSize,
    double? headlineFontSize,
  }) {
    _doc = _doc.copyWith(
      fontFamily: fontFamily,
      baseFontSize: baseFontSize,
      headlineFontSize: headlineFontSize,
    );
    _isDirty = true;
    notifyListeners();
  }

  bool hasComponentStyle(String componentKey) => _doc.hasComponentStyle(componentKey);

  LuminaComponentStyle? componentStyleOf(String componentKey) => _doc.componentStyles[componentKey];

  void createComponentStyle(String componentKey) {
    final currentColors = _doc.colors;
    LuminaComponentStyle initialStyle;

    switch (componentKey) {
      case 'button':
        initialStyle = LuminaComponentStyle(
          backgroundColor: currentColors['primary'] ?? 0xFF3B82F6,
          foregroundColor: currentColors['primaryForeground'] ?? 0xFFFFFFFF,
          borderRadius: _doc.radius,
          paddingHorizontal: 16.0,
          paddingVertical: 8.0,
          fontSize: _doc.baseFontSize,
          fontWeight: 600,
        );
        break;
      case 'card':
        initialStyle = LuminaComponentStyle(
          backgroundColor: currentColors['card'] ?? 0xFF27272A,
          foregroundColor: currentColors['cardForeground'] ?? 0xFFFAFAFA,
          borderColor: currentColors['border'] ?? 0xFF3F3F46,
          borderWidth: 1.0,
          borderRadius: _doc.radius * 1.5,
          paddingHorizontal: 16.0,
          paddingVertical: 16.0,
        );
        break;
      case 'input':
        initialStyle = LuminaComponentStyle(
          backgroundColor: currentColors['input'] ?? 0xFF1C1C1C,
          foregroundColor: currentColors['foreground'] ?? 0xFFFAFAFA,
          borderColor: currentColors['border'] ?? 0xFF3F3F46,
          borderWidth: 1.0,
          borderRadius: _doc.radius,
          paddingHorizontal: 12.0,
          paddingVertical: 8.0,
          fontSize: _doc.baseFontSize,
        );
        break;
      case 'badge':
        initialStyle = LuminaComponentStyle(
          backgroundColor: currentColors['secondary'] ?? 0xFF3F3F46,
          foregroundColor: currentColors['secondaryForeground'] ?? 0xFFFAFAFA,
          borderRadius: _doc.radius * 2,
          paddingHorizontal: 10.0,
          paddingVertical: 4.0,
          fontSize: 12.0,
          fontWeight: 600,
        );
        break;
      case 'switch':
        initialStyle = LuminaComponentStyle(
          backgroundColor: currentColors['primary'] ?? 0xFF3B82F6,
          borderRadius: _doc.radius * 3,
          customProperties: {
            'inactiveColor': currentColors['muted'] ?? 0xFF3F3F46,
            'thumbColor': 0xFFFFFFFF,
          },
        );
        break;
      case 'slider':
        initialStyle = LuminaComponentStyle(
          backgroundColor: currentColors['primary'] ?? 0xFF3B82F6,
          customProperties: {
            'inactiveTrackColor': currentColors['secondary'] ?? 0xFF3F3F46,
            'thumbColor': currentColors['primary'] ?? 0xFF3B82F6,
          },
        );
        break;
      case 'checkbox':
        initialStyle = LuminaComponentStyle(
          backgroundColor: currentColors['primary'] ?? 0xFF3B82F6,
          foregroundColor: 0xFFFFFFFF,
          borderColor: currentColors['border'] ?? 0xFF3F3F46,
          borderRadius: _doc.radius * 0.7,
        );
        break;
      case 'tabs':
        initialStyle = LuminaComponentStyle(
          backgroundColor: currentColors['muted'] ?? 0xFF27272A,
          foregroundColor: currentColors['foreground'] ?? 0xFFFAFAFA,
          borderRadius: _doc.radius,
          customProperties: {
            'activeTabBackground': currentColors['card'] ?? 0xFF3F3F46,
            'indicatorColor': currentColors['primary'] ?? 0xFF3B82F6,
          },
        );
        break;
      case 'progress':
        initialStyle = LuminaComponentStyle(
          backgroundColor: currentColors['primary'] ?? 0xFF3B82F6,
          customProperties: {
            'trackColor': currentColors['secondary'] ?? 0xFF3F3F46,
            'height': 6.0,
          },
        );
        break;
      case 'dialog':
        initialStyle = LuminaComponentStyle(
          backgroundColor: currentColors['popover'] ?? 0xFF27272A,
          foregroundColor: currentColors['popoverForeground'] ?? 0xFFFAFAFA,
          borderColor: currentColors['border'] ?? 0xFF3F3F46,
          borderWidth: 1.0,
          borderRadius: _doc.radius * 2,
          paddingHorizontal: 20.0,
          paddingVertical: 20.0,
        );
        break;
      default:
        initialStyle = LuminaComponentStyle(
          backgroundColor: currentColors['card'] ?? 0xFF27272A,
          foregroundColor: currentColors['foreground'] ?? 0xFFFAFAFA,
          borderRadius: _doc.radius,
        );
    }

    final updated = Map<String, LuminaComponentStyle>.from(_doc.componentStyles);
    updated[componentKey] = initialStyle;
    _doc = _doc.copyWith(componentStyles: updated);
    _isDirty = true;
    _selection = ThemeTreeSelection(
      id: 'component.$componentKey',
      category: 'component',
      targetKey: componentKey,
    );
    notifyListeners();
  }

  void updateComponentStyle(String componentKey, LuminaComponentStyle style) {
    final updated = Map<String, LuminaComponentStyle>.from(_doc.componentStyles);
    updated[componentKey] = style;
    _doc = _doc.copyWith(componentStyles: updated);
    _isDirty = true;
    notifyListeners();
  }

  void removeComponentStyle(String componentKey) {
    final updated = Map<String, LuminaComponentStyle>.from(_doc.componentStyles);
    updated.remove(componentKey);
    _doc = _doc.copyWith(componentStyles: updated);
    _isDirty = true;
    if (_selection.targetKey == componentKey) {
      _selection = ThemeTreeSelection.colors;
    }
    notifyListeners();
  }

  void createCustomStyle(String name, String targetComponent) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    final initialStyle = componentStyleOf(targetComponent) ??
        LuminaComponentStyle(
          backgroundColor: _doc.colors['primary'] ?? 0xFF3B82F6,
          foregroundColor: 0xFFFFFFFF,
          borderRadius: _doc.radius,
          paddingHorizontal: 16.0,
          paddingVertical: 8.0,
        );

    final customStyle = LuminaCustomStyle(
      name: cleanName,
      targetComponent: targetComponent,
      style: initialStyle,
    );

    final updated = Map<String, LuminaCustomStyle>.from(_doc.customStyles);
    updated[cleanName] = customStyle;
    _doc = _doc.copyWith(customStyles: updated);
    _isDirty = true;
    _selection = ThemeTreeSelection(
      id: 'custom.$cleanName',
      category: 'custom',
      targetKey: cleanName,
    );
    notifyListeners();
  }

  void updateCustomStyle(String name, LuminaCustomStyle customStyle) {
    final updated = Map<String, LuminaCustomStyle>.from(_doc.customStyles);
    updated[name] = customStyle;
    _doc = _doc.copyWith(customStyles: updated);
    _isDirty = true;
    notifyListeners();
  }

  void removeCustomStyle(String name) {
    final updated = Map<String, LuminaCustomStyle>.from(_doc.customStyles);
    updated.remove(name);
    _doc = _doc.copyWith(customStyles: updated);
    _isDirty = true;
    if (_selection.targetKey == name) {
      _selection = ThemeTreeSelection.colors;
    }
    notifyListeners();
  }

  void revert() {
    _doc = _initialDoc;
    _isDirty = false;
    notifyListeners();
  }
}
