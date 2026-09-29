part of '../build_pipeline_service.dart';

// --- host toolchain probe --------------------------------------------------

/// One `flutter doctor` section, e.g. `[!] Android toolchain`.
class ToolchainStatus {
  final String name;
  final bool ready;

  /// The section's `✗` problems (or its `!` warnings when it has none),
  /// each with its indented hint lines joined in.
  final List<String> issues;
  const ToolchainStatus({required this.name, required this.ready, this.issues = const []});
}

/// What the host can `flutter build`, learned from a real `flutter doctor -v`
/// run — never a hardcoded platform list — and, per packaging platform, why
/// it cannot: the host, the doctor toolchain, or the
/// engine's native build.
class HostBuildTargets {
  final bool flutterAvailable;
  final String? flutterVersion;

  /// Platform ids ([kPackagingPlatforms]) whose toolchain is ready here.
  final List<String> targets;
  final String? error;
  final String rawDoctor;

  /// Doctor sections by platform id (`android` → Android toolchain; `macos`
  /// and `ios` share Xcode). Empty when constructed without a doctor run.
  final Map<String, ToolchainStatus> toolchains;

  /// `Feature flags:` from the doctor, or null when it printed none.
  final List<String>? featureFlags;

  /// The host OS (`Platform.operatingSystem` when null).
  final String? operatingSystem;

  const HostBuildTargets({
    required this.flutterAvailable,
    this.flutterVersion,
    this.targets = const [],
    this.error,
    this.rawDoctor = '',
    this.toolchains = const {},
    this.featureFlags,
    this.operatingSystem,
  });

  String get hostOs => operatingSystem ?? Platform.operatingSystem;

  /// The doctor section a platform's builds need; web needs none (Chrome is
  /// only for running).
  static const Map<String, String> toolchainNames = {
    'linux': 'Linux toolchain',
    'windows': 'Visual Studio',
    'macos': 'Xcode',
    'ios': 'Xcode',
    'android': 'Android toolchain',
  };

  static String labelFor(String target) {
    final id = target == 'apk' ? 'android' : target;
    return '${packagingPlatformLabel(id)} (flutter build ${flutterBuildSubcommand(id)})';
  }

  /// Why this host cannot build [platform] at all, or null.
  static String? hostReason(String platform, String os) => switch (platform) {
        'windows' when os != 'windows' => 'Windows builds need a Windows host: `flutter build windows` runs only on Windows.',
        'macos' when os != 'macos' => 'macOS builds need a Mac with Xcode: `flutter build macos` runs only on macOS.',
        'ios' when os != 'macos' => 'iOS builds need a Mac with Xcode: `flutter build ios` runs only on macOS.',
        'linux' when os != 'linux' => 'Linux builds need a Linux host: `flutter build linux` runs only on Linux.',
        _ => null,
      };

  /// Why the Flutter toolchain for [platform] is not ready, or null.
  String? toolchainReason(String platform) {
    if (!flutterAvailable) return error ?? 'the Flutter SDK is not available on this host';
    if (hostReason(platform, hostOs) != null) return null;
    if (platform == 'web') {
      final flags = featureFlags;
      return flags != null && !flags.contains('enable-web')
          ? 'web builds are disabled in the Flutter config (run `flutter config --enable-web`).'
          : null;
    }
    final name = toolchainNames[platform];
    if (name == null) return null;
    final status = toolchains[platform];
    if (status != null) {
      if (status.ready) return null;
      return 'flutter doctor: $name is not ready${status.issues.isEmpty ? '' : ' — ${status.issues.join(' ')}'}';
    }
    return targets.contains(platform) ? null : 'flutter doctor reports no ready $name.';
  }

  /// Why a Lumina game cannot be built for [target] yet, or null when it can.
  /// A ready Flutter toolchain is not enough: every game renders
  /// through flutter_filament, whose native-assets hook (`hook/build.dart`)
  /// links the Filament libraries only on Linux, macOS and Windows, and whose web
  /// build needs its WebAssembly module, looked up through
  /// the dependencies of [packageRoots] ([FlutterFilamentWebModule.locate]).
  static String? engineUnsupportedReason(String target, {List<String>? packageRoots}) => switch (target) {
        'linux' || 'macos' || 'windows' => null,
        'web' => FlutterFilamentWebModule.locate(packageRoots: packageRoots) == null ? FlutterFilamentWebModule.missingReason : null,
        'android' || 'apk' => 'flutter_filament has no Android build of the Filament libraries to link yet.',
        'ios' => 'flutter_filament does not link Filament for iOS (hook/build.dart has no iOS branch).',
        _ => 'Not available for Lumina games: flutter_filament has no native build for this platform.',
      };

  /// Every reason [platform] cannot be packaged here: host, toolchain and
  /// engine, in that order. Empty means buildable. [engineReason] replaces
  /// [engineUnsupportedReason] (the editor looks the web module up once).
  List<String> reasonsFor(String platform, {String? Function(String platform)? engineReason}) => [
        ?hostReason(platform, hostOs),
        ?toolchainReason(platform),
        ?(engineReason ?? engineUnsupportedReason)(platform),
      ];

  static Future<HostBuildTargets>? _shared;

  /// One `flutter doctor -v` per editor process, shared by Project Settings
  /// and the Build Manager.
  static Future<HostBuildTargets> shared() => _shared ??= probe();

  static Future<HostBuildTargets> probe({BuildProcessStarter? processStarter, String? operatingSystem, Duration timeout = const Duration(seconds: 90)}) async {
    final starter = processStarter ?? defaultBuildProcessStarter;
    try {
      final proc = await starter('flutter', ['doctor', '-v']);
      final out = StringBuffer();
      final outDone = proc.stdout.transform(utf8.decoder).listen(out.write).asFuture<void>();
      final errDone = proc.stderr.transform(utf8.decoder).listen(out.write).asFuture<void>();
      final code = await proc.exitCode.timeout(timeout, onTimeout: () {
        proc.kill();
        return -1;
      });
      await Future.wait([outDone, errDone]);
      final parsed = parseDoctor(out.toString(), operatingSystem: operatingSystem ?? Platform.operatingSystem);
      if (!parsed.flutterAvailable) {
        return HostBuildTargets(
            flutterAvailable: false, error: 'flutter doctor exited with $code without reporting a Flutter install', rawDoctor: out.toString());
      }
      return parsed;
    } catch (e) {
      return HostBuildTargets(flutterAvailable: false, error: 'flutter is not available: $e');
    }
  }

  /// Parses `flutter doctor -v` text: every toolchain section with its
  /// status and problems; only `[✓]` ones the host OS can build for count as
  /// ready (never iOS/macOS from Linux).
  static HostBuildTargets parseDoctor(String text, {required String operatingSystem}) {
    final clean = text.replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '');
    final version = RegExp(r'Flutter version (\S+)').firstMatch(clean)?.group(1) ??
        RegExp(r'\[[✓√]\]\s*Flutter \(Channel \S+, ([\d.]+[^,\s]*)').firstMatch(clean)?.group(1);
    final hasFlutter = RegExp(r'\[[✓√!]\]\s*Flutter\b').hasMatch(clean);
    final flagsLine = RegExp(r'Feature flags:\s*(.*)$', multiLine: true).firstMatch(clean)?.group(1);
    final flags = flagsLine?.split(',').map((f) => f.trim()).where((f) => f.isNotEmpty).toList();

    // Sections: `[✓] Name - …` then indented detail lines.
    final sections = <String, ToolchainStatus>{};
    String? name;
    var ready = false;
    var errors = <String>[];
    var warnings = <String>[];
    List<String>? current;
    void close() {
      if (name != null) sections[name] = ToolchainStatus(name: name, ready: ready, issues: errors.isNotEmpty ? errors : warnings);
    }

    for (final line in clean.split('\n')) {
      final head = RegExp(r'^\[([✓√!✗X☠])\]\s*(.*?)(?:\s+-\s+.*)?(?:\s+\[\d+(?:\.\d+)?m?s\])?\s*$').firstMatch(line);
      if (head != null) {
        close();
        final mark = head.group(1)!;
        name = head.group(2)!.replaceAll(RegExp(r'\s*\(.*$'), '').trim();
        ready = mark == '✓' || mark == '√';
        errors = <String>[];
        warnings = <String>[];
        current = null;
        continue;
      }
      if (name == null) continue;
      final item = RegExp(r'^\s+([•✗!X])\s+(.*)$').firstMatch(line);
      if (item != null) {
        final mark = item.group(1)!;
        final body = item.group(2)!.trim();
        if (mark == '✗' || mark == 'X') {
          errors.add('✗ $body');
          current = errors;
        } else if (mark == '!') {
          warnings.add('! $body');
          current = warnings;
        } else {
          current = null;
        }
        continue;
      }
      // A hint line under a problem (deeper indent) joins it.
      if (current != null && current.isNotEmpty && RegExp(r'^\s{5,}\S').hasMatch(line) && !line.trim().startsWith('-')) {
        current[current.length - 1] = '${current.last} ${line.trim()}';
      } else if (line.trim().isEmpty) {
        current = null;
      }
    }
    close();

    ToolchainStatus? section(String prefix) {
      for (final e in sections.entries) {
        if (e.key.startsWith(prefix)) return e.value;
      }
      return null;
    }

    final toolchains = <String, ToolchainStatus>{
      for (final e in toolchainNames.entries)
        if (section(e.value) != null) e.key: section(e.value)!,
    };
    bool readyOn(String platform, String os) => operatingSystem == os && (toolchains[platform]?.ready ?? false);
    final targets = <String>[
      if (readyOn('linux', 'linux')) 'linux',
      if (readyOn('windows', 'windows')) 'windows',
      if (readyOn('macos', 'macos')) 'macos',
      if (toolchains['android']?.ready ?? false) 'android',
      if (readyOn('ios', 'macos')) 'ios',
      if (hasFlutter && (flags == null || flags.contains('enable-web'))) 'web',
    ];
    return HostBuildTargets(
      flutterAvailable: hasFlutter,
      flutterVersion: version,
      targets: targets,
      rawDoctor: clean,
      toolchains: toolchains,
      featureFlags: flags,
      operatingSystem: operatingSystem,
    );
  }
}
