import 'dart:io';

import 'dart:ui' show Color, ColorSpace;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show BoxDecoration, RenderDecoratedBox, RenderObject, RendererBinding;
import 'package:flutter/services.dart' show ServicesBinding, SystemChannels;
import 'package:flutter/widgets.dart' show BuildContext, Element, InheritedNotifier, WidgetsBinding;
import 'package:lumina_core/lumina_core.dart';

import 'package:lumina_ui/ui/core/theme/editor_theme_data.dart';

/// The theme every [EditorThemeColor] — so every `EditorColors` token —
/// resolves through. [apply] swaps it and refreshes the
/// whole running editor without a restart.
abstract final class EditorTheme {
  static final ValueNotifier<EditorThemeData> _current = ValueNotifier(EditorThemeData.luminaDark);

  /// The active theme; notifies when [apply] swaps it.
  static ValueListenable<EditorThemeData> get listenable => _current;

  static EditorThemeData get current => _current.value;

  /// Makes [theme] the active one. Every `EditorColors` token reads it from
  /// the next paint on; widgets that baked a colour into a const subtree or a
  /// laid-out paragraph are rebuilt, repainted and re-laid out here.
  static void apply(EditorThemeData theme) {
    if (identical(theme, _current.value)) return;
    _current.value = theme;
    refreshAll();
  }

  /// Rebuilds every element, repaints every render object and re-lays out
  /// all text (a paragraph keeps the colours it was built with, so the same
  /// "fonts changed" broadcast the engine sends is replayed to discard them).
  static void refreshAll() {
    final binding = WidgetsBinding.instance;
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    binding.rootElement?.visitChildren(rebuild);
    void repaint(RenderObject r) {
      if (r is RenderDecoratedBox) {
        // A box decoration's painter caches its Paint (colour included);
        // swapping the decoration out and back drops the painter.
        final decoration = r.decoration;
        r.decoration = const BoxDecoration();
        r.decoration = decoration;
      }
      r.markNeedsPaint();
      r.visitChildren(repaint);
    }

    for (final view in RendererBinding.instance.renderViews) {
      repaint(view);
    }
    // Delivered through the binary messenger rather than straight into
    // `channelBuffers`, so the test binding's messenger sees it too (in the
    // app the default messenger forwards it to `channelBuffers`).
    // ignore: deprecated_member_use
    ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.system.name,
      SystemChannels.system.codec.encodeMessage(<String, Object>{'type': 'fontsChange'}),
      (_) {},
    );
    binding.scheduleFrame();
  }

  /// Back to Lumina Dark without touching any file (tests).
  @visibleForTesting
  static void resetForTest() => _current.value = EditorThemeData.luminaDark;
}

/// A `const` colour whose value is the active theme's [token].
/// The `int` is the default theme's value, used only if
/// the active theme somehow lacks the token.
///
/// `dart:ui` reads a colour through its `a`/`r`/`g`/`b`/`colorSpace` getters
/// (painting, text styles, `withValues`), so overriding them makes every
/// `EditorColors` token — including the ones inside `const` widgets — follow
/// the theme from the next paint on.
class EditorThemeColor extends Color {
  const EditorThemeColor(this.token, super.value);

  final String token;

  Color get _resolved => EditorTheme.current.colors[token] ?? Color.from(alpha: super.a, red: super.r, green: super.g, blue: super.b);

  @override
  double get a => _resolved.a;

  @override
  double get r => _resolved.r;

  @override
  double get g => _resolved.g;

  @override
  double get b => _resolved.b;

  @override
  ColorSpace get colorSpace => _resolved.colorSpace;

  @override
  String toString() => 'EditorThemeColor($token: ${EditorThemeData.formatColor(_resolved)})';
}

/// Where themes live: the three built-ins in code, the user's own as
/// `<name>.json` files in `themes/` under [LuminaConfigDir], and the active
/// theme's name in `editor_preferences.json` (`"theme"`).
class EditorThemeStore {
  EditorThemeStore({Directory? configDir}) : configDir = LuminaConfigDir.resolve(explicit: configDir);

  final Directory configDir;

  static const String preferencesFile = 'editor_preferences.json';
  static const String preferenceKey = 'theme';

  Directory get themesDir => Directory('${configDir.path}/themes');

  /// The file a user theme called [name] is kept in.
  File fileFor(String name) => File('${themesDir.path}/${slug(name)}.json');

  static String slug(String name) {
    final s = name.trim().replaceAll(RegExp(r'[^A-Za-z0-9 _.-]'), '').replaceAll(RegExp(r'\s+'), '_');
    return s.isEmpty ? 'theme' : s;
  }

  /// The user's themes on disk, by name (a file that does not parse still
  /// loads, with the defaults and a warning).
  List<EditorThemeData> loadUserThemes() {
    if (!themesDir.existsSync()) return const [];
    final out = <EditorThemeData>[];
    final files = themesDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      try {
        final base = f.uri.pathSegments.last.replaceAll('.json', '');
        final theme = EditorThemeData.decode(f.readAsStringSync(), fallbackName: base);
        if (EditorThemeData.isBuiltInName(theme.name) || out.any((t) => t.name == theme.name)) continue;
        out.add(theme);
      } on FileSystemException catch (e) {
        debugPrint('[EditorThemeStore] could not read ${f.path}: $e');
      }
    }
    return out;
  }

  void writeUserTheme(EditorThemeData theme) {
    if (EditorThemeData.isBuiltInName(theme.name)) {
      throw ArgumentError('${theme.name} is a built-in theme and cannot be overwritten');
    }
    themesDir.createSync(recursive: true);
    // The canonical text (trailing newline included), byte-stable, replaced
    // atomically (temp file + rename).
    final target = fileFor(theme.name);
    final temp = File('${target.path}.tmp-$pid');
    temp.writeAsStringSync(theme.encode(), flush: true);
    temp.renameSync(target.path);
  }

  void deleteUserTheme(String name) {
    final f = fileFor(name);
    if (f.existsSync()) f.deleteSync();
  }

  String? readActiveName() {
    try {
      final decoded = ConfigJsonFile(File('${configDir.path}/$preferencesFile')).read();
      final v = decoded is Map ? decoded[preferenceKey] : null;
      return v is String ? v : null;
    } catch (e) {
      debugPrint('[EditorThemeStore] preferences unreadable: $e');
      return null;
    }
  }

  void writeActiveName(String name) {
    try {
      ConfigJsonFile(File('${configDir.path}/$preferencesFile')).update(
        (current) => {...?(current is Map<String, dynamic> ? current : null), preferenceKey: name},
        isValid: (value) => value is Map<String, dynamic>,
        pretty: true,
      );
    } catch (e) {
      debugPrint('[EditorThemeStore] could not save the active theme: $e');
    }
  }
}

/// The Appearance page's model: the theme list, the active theme, and the
/// operations on user themes. Activating a theme applies it at once
/// ([EditorTheme.apply]) and remembers it for the next start.
class EditorThemeController extends ChangeNotifier {
  EditorThemeController({EditorThemeStore? store}) : store = store ?? EditorThemeStore() {
    reload();
  }

  static EditorThemeController? _instance;

  /// The app's controller (config dir from [LuminaConfigDir]).
  static EditorThemeController get instance => _instance ??= EditorThemeController();

  @visibleForTesting
  static set instance(EditorThemeController value) => _instance = value;

  final EditorThemeStore store;

  List<EditorThemeData> _user = const [];
  String _activeName = EditorThemeData.luminaDark.name;

  List<EditorThemeData> get themes => [...EditorThemeData.builtIns, ..._user];
  List<EditorThemeData> get userThemes => _user;
  String get activeName => _activeName;
  EditorThemeData get active => byName(_activeName) ?? EditorThemeData.luminaDark;

  EditorThemeData? byName(String name) => themes.where((t) => t.name == name).firstOrNull;
  bool isBuiltIn(String name) => EditorThemeData.isBuiltInName(name);

  /// Re-reads the config dir and applies the remembered theme.
  void reload() {
    _user = store.loadUserThemes();
    final remembered = store.readActiveName();
    _activeName = remembered != null && byName(remembered) != null ? remembered : EditorThemeData.luminaDark.name;
    EditorTheme.apply(active);
    notifyListeners();
  }

  void activate(String name) {
    final theme = byName(name);
    if (theme == null) return;
    _activeName = name;
    store.writeActiveName(name);
    EditorTheme.apply(theme);
    notifyListeners();
  }

  /// A name no theme has yet: [base], then "[base] 2", "[base] 3", …
  String uniqueName(String base) {
    if (byName(base) == null) return base;
    for (var i = 2;; i++) {
      final candidate = '$base $i';
      if (byName(candidate) == null) return candidate;
    }
  }

  /// A user copy of [name], saved to disk.
  EditorThemeData duplicate(String name, {String? newName}) {
    final source = byName(name) ?? EditorThemeData.luminaDark;
    final copy = source.copyWith(name: uniqueName(newName ?? '${source.name} Copy'));
    save(copy);
    return copy;
  }

  /// Saves a user theme; if it is the active one, applies it again.
  void save(EditorThemeData theme) {
    store.writeUserTheme(theme);
    _user = store.loadUserThemes();
    if (theme.name == _activeName) EditorTheme.apply(byName(theme.name)!);
    notifyListeners();
  }

  bool rename(String name, String newName) {
    final theme = byName(name);
    final target = newName.trim();
    if (theme == null || isBuiltIn(name) || target.isEmpty || byName(target) != null) return false;
    store.deleteUserTheme(name);
    store.writeUserTheme(theme.copyWith(name: target));
    _user = store.loadUserThemes();
    if (_activeName == name) {
      _activeName = target;
      store.writeActiveName(target);
    }
    notifyListeners();
    return true;
  }

  bool delete(String name) {
    if (isBuiltIn(name) || byName(name) == null) return false;
    store.deleteUserTheme(name);
    _user = store.loadUserThemes();
    if (_activeName == name) {
      activate(EditorThemeData.luminaDark.name);
    } else {
      notifyListeners();
    }
    return true;
  }

  /// Imports a `.json` theme: it joins the list under its own name (made
  /// unique), with any warnings its tokens raised.
  EditorThemeData importFile(File file) {
    final base = file.uri.pathSegments.last.replaceAll(RegExp(r'\.json$'), '');
    final parsed = EditorThemeData.decode(file.readAsStringSync(), fallbackName: base);
    final theme = parsed.copyWith(name: uniqueName(parsed.name), warnings: parsed.warnings);
    store.writeUserTheme(theme);
    _user = store.loadUserThemes();
    notifyListeners();
    return theme;
  }

  /// Writes [name]'s canonical JSON to [file].
  void exportTo(String name, File file) {
    final theme = byName(name);
    if (theme == null) throw ArgumentError('no theme called $name');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(theme.encode(), flush: true);
  }
}

/// Puts the [EditorThemeController] above `ShadcnApp`:
/// what builds the app depends on it, so activating a theme rebuilds the
/// shadcn theme too; the Appearance page finds its controller here.
class EditorThemeScope extends InheritedNotifier<EditorThemeController> {
  const EditorThemeScope({super.key, required EditorThemeController controller, required super.child}) : super(notifier: controller);

  /// The controller in scope, or the app's [EditorThemeController.instance].
  static EditorThemeController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EditorThemeScope>()?.notifier ?? EditorThemeController.instance;
}
