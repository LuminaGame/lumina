/// The editor's entry point as a library: `lib/main.dart` (the
/// stock editor, which is also the launcher) and every generated project
/// editor host (`<project>/.lumina/editor/lib/main.dart`) call
/// [runLuminaEditor]; a host passes its compiled-in plugins and [EditorHostInfo].
library;

import 'dart:async';
import 'dart:io';

import 'package:lumina/data/services/workspace_paths.dart';
import 'package:lumina/lumina.dart' show EngineBootstrap, EngineLoggerService, LuminaMedia, LuminaRtxController, PluginHostPatcherService;
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'ui/core/host/editor_host.dart';
import 'ui/core/host/redirection_trust_guard.dart';
import 'ui/core/services/crash_reporter.dart';
import 'ui/core/services/plugin_process/plugin_process_entry.dart';
import 'ui/core/theme/editor_theme.dart';
import 'ui/core/theme/editor_theme_store.dart';
import 'ui/core/window/lumina_window.dart';
import 'ui/core/widgets/crash_report_view.dart';
import 'ui/core/window/window_controls.dart';
import 'ui/features/engine_bootstrap/view_models/engine_bootstrap_view_model.dart';
import 'ui/features/engine_bootstrap/views/engine_bootstrap_view.dart';
import 'ui/features/launcher/views/launcher_view.dart';
import 'ui/features/main_editor/services/editor_graphics_preferences.dart';
import 'ui/features/main_editor/services/editor_preferences.dart';

export 'ui/core/host/editor_host.dart' show EditorHostInfo, EditorLaunchArgs, LuminaEditorHost, EditorAssets, EditorHandOff;

final ValueNotifier<ThemeMode> appThemeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

/// The NGX SDK `tool/dlss/fetch_sdk.dart` fetched into the engine checkout, when
/// there is one; the editor's DLSS button needs its runtime.
String? _dlssSdkDir() {
  final root = LuminaWorkspace.findSourceRoot();
  if (root == null) return null;
  final dir = Directory(p.join(root, 'lumina', 'flutter_filament', 'build', 'dlss-sdk'));
  return dir.existsSync() ? dir.path : null;
}

Future<void> runLuminaEditor(
  List<String> args, {
  List<LuminaEditorPlugin> plugins = const [],
  Map<String, LuminaPluginProcess Function()> processes = const {},
  EditorHostInfo? host,
}) async {
  // `--lumina-plugin-process <name>`: this executable runs one isolated
  // plugin's process part for the editor that started it. No window is
  // shown (the runner shows it on the first frame, and none is drawn), no
  // crash session starts, no plugin registry loads.
  if (args.contains(PluginProcessLaunch.flag)) {
    LuminaEditorHost.pluginProcesses = processes;
    // Platform channels (path_provider, …) work in the process part; no
    // view is attached, so no frame is rendered.
    WidgetsFlutterBinding.ensureInitialized();
    exit(await runPluginProcessFromArgs(args, processes) ?? kPluginProcessUsageExit);
  }
  // Started by a process that enforces Windows redirection trust (an
  // installer's finish page does), the editor and everything it runs could
  // not traverse the junctions of the engine checkout and projects: a copy
  // without the policy takes over before any window shows.
  if (!RedirectionTrustGuard.startup(args)) exit(0);
  WidgetsFlutterBinding.ensureInitialized();
  // Uncaught errors become crash reports the user may send; a session that
  // never closes cleanly is reported at the next launch.
  final crashReporter = CrashReporter(serverUrl: () => Uri.parse(_crashReportServer))..install();
  LuminaMedia.ensureInitialized();
  EditorGraphicsPreferences().apply();
  // The viewport's shared Vulkan engine is created later; the ray query (and,
  // with the NGX runtime, DLSS) extensions must be asked for before it exists.
  if (Platform.isWindows || Platform.isLinux) {
    LuminaRtxController.requestExtensions(dlssRuntimeDir: _dlssSdkDir());
  }
  LuminaEditorHost.info = host;
  LuminaEditorHost.args = EditorLaunchArgs.parse(args);
  // `--no-plugins` opens the project without its code plugins even in a
  // project editor (the escape hatch when a plugin breaks the editor).
  LuminaEditorHost.plugins = LuminaEditorHost.args.noPlugins ? const [] : plugins;
  LuminaEditorHost.pluginProcesses = LuminaEditorHost.args.noPlugins ? const {} : processes;
  // An installed release (no source checkout around it) works on the engine
  // source of its own release, fetched once into the per-user data folder:
  // a complete checkout is used straight away (offline too), otherwise the
  // first-launch screen fetches it before the launcher.
  EngineBootstrapViewModel? bootstrap;
  if (host == null && EngineBootstrap.needed) {
    final release = EngineBootstrap.release();
    final ready = release.readyCheckout();
    if (ready != null) {
      EngineBootstrap.activate(ready);
    } else {
      bootstrap = EngineBootstrapViewModel(release);
    }
  } else if (host == null) {
    await _migrateEnginePluginBlock();
  } else if (LuminaWorkspace.findSourceRoot() == null) {
    // A project editor built from a fetched release checkout: the workspace
    // is that checkout (the binary lives in the project, not under it).
    final checkout = EngineBootstrap.readMarker(host.engineRoot);
    if (checkout != null) EngineBootstrap.activate(checkout);
  }
  await EditorAssets.configure();
  await windowManager.ensureInitialized();

  final windowOptions = WindowOptions(
    size: const Size(1920, 1080),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  // Restores the saved size/position/maximized state over
  // these options, turns the window manager's close into a request (the
  // editor asks about unsaved work first), then shows the window — all before
  // the first frame.
  await LuminaWindow.instance.startup(windowOptions);
  // Registered before the editor's own guards, so it runs last: only a
  // close every guard agreed to removes the session marker.
  LuminaWindow.instance.addCloseGuard(() async {
    await crashReporter.endSession();
    return true;
  });
  // Restarts and hand-offs (a plugin install's restart, opening a project
  // editor, returning to the launcher, Quit) exit on purpose: clean closes.
  EditorHandOff.beforeExit.add(crashReporter.endSession);
  try {
    // Reports a session that died before it writes this one's marker.
    await crashReporter.startSession();
  } on FileSystemException catch (e) {
    EngineLoggerService().log('Crash reporting is off: $e', level: 'warning', source: 'CrashReporter');
  }
  unawaited(_loadCrashReportServer());
  // The remembered editor theme (a JSON file under
  // ~/.config/lumina/themes/, or a built-in) is active before the first frame.
  EditorThemeController.instance.reload();
  runApp(LuminaStudioApp(bootstrap: bootstrap));
}

/// Where crash reports go: the marketplace server of the editor preferences
/// (the default until they are read).
String _crashReportServer = EditorPreferences.defaultMarketplaceUrl;

Future<void> _loadCrashReportServer() async {
  try {
    _crashReportServer = EditorPreferences.load().marketplaceUrl;
  } catch (e) {
    EngineLoggerService().log('Crash reports go to the default server: $e', level: 'warning', source: 'CrashReporter');
  }
}

/// An engine checkout an older editor patched (a generated plugin
/// block in `lumina_ui/pubspec.yaml`) is cleaned once; projects keep their
/// `enabled_plugins` and get their editor host on the next Open.
Future<void> _migrateEnginePluginBlock() async {
  try {
    final pubspec = File(p.join(LuminaEditorHost.uiRoot, 'pubspec.yaml'));
    if (await PluginHostPatcherService().removeEnginePluginBlock(pubspec)) {
      EngineLoggerService().log(
        'Removed the generated plugin block from ${pubspec.path} (backup: pubspec.yaml.lmbak): project code plugins now '
        "build into each project's own editor.",
        level: 'warning',
        source: 'Plugins',
      );
    }
  } on FileSystemException catch (e) {
    EngineLoggerService().log('Could not clean the engine plugin block: $e', level: 'warning', source: 'Plugins');
  }
}

class LuminaStudioApp extends StatelessWidget {
  const LuminaStudioApp({super.key, this.bootstrap});

  /// Set when the engine source of this release still has to be fetched:
  /// the first-launch screen runs it, then the launcher opens.
  final EngineBootstrapViewModel? bootstrap;

  @override
  Widget build(BuildContext context) {
    // The active editor theme drives the shadcn theme;
    // activating another one (Editor Preferences → Appearance, or the
    // launcher's light/dark switch) rebuilds from here.
    return EditorThemeScope(
      controller: EditorThemeController.instance,
      child: Builder(
        builder: (context) {
          EditorThemeScope.of(context);
          return ShadcnApp(
            title: 'Lumina Studio Engine',
            // The active theme's palette, radius and type scale. Every widget
            // and smoke test builds the same theme through this function.
            theme: luminaEditorTheme(),
            // `--project <dir>` opens that project straight away
            // (through the same resolver as the launcher's Open).
            home: bootstrap == null
                ? LauncherView(initialProjectDir: LuminaEditorHost.args.project)
                : _FirstLaunch(bootstrap: bootstrap!),
            // Lumina's own window chrome: resize border, F11, and the window
            // every title bar's controls act on. lumina_ui's `assets/…` keys
            // resolve in a project editor host too.
            builder: (context, child) => DefaultAssetBundle(
              bundle: EditorAssets.bundle,
              child: LuminaWindowFrame(
                window: LuminaWindow.instance,
                child: CrashReporter.instance == null
                    ? (child ?? const SizedBox.shrink())
                    : CrashReportOverlay(reporter: CrashReporter.instance!, child: child ?? const SizedBox.shrink()),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The first-launch screen until the engine checkout is ready, then the
/// launcher.
class _FirstLaunch extends StatefulWidget {
  const _FirstLaunch({required this.bootstrap});

  final EngineBootstrapViewModel bootstrap;

  @override
  State<_FirstLaunch> createState() => _FirstLaunchState();
}

class _FirstLaunchState extends State<_FirstLaunch> {
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    if (_ready) return LauncherView(initialProjectDir: LuminaEditorHost.args.project);
    return EngineBootstrapView(viewModel: widget.bootstrap, onReady: (_) => setState(() => _ready = true));
  }
}
