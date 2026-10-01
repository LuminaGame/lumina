/// The arguments of `tool/package-windows.sh`, the MSIX
/// version derived from `pubspec.yaml`, and the shared `msix_config` block.
library;

/// How the package is signed.
enum PackagingMode {
  /// The stable Lumina development certificate (local and team testing).
  selfSigned,

  /// A certificate from the environment, timestamped (distribution).
  publish,

  /// Unsigned, with the Partner Center publisher from `msix_config`: the
  /// Microsoft Store signs what it is sent.
  store,
}

/// A refusal or failure with the exit code the script returns:
/// 64 for usage / signing-input problems, 2 off Windows, 1 for a failed build
/// or verification.
class PackagingException implements Exception {
  final int exitCode;
  final String message;

  const PackagingException(this.exitCode, this.message);

  /// A usage or configuration problem (EX_USAGE).
  const PackagingException.usage(this.message) : exitCode = 64;

  @override
  String toString() => message;
}

final RegExp _msixVersion = RegExp(r'^\d{1,5}\.\d{1,5}\.\d{1,5}\.\d{1,5}$');

/// The parsed command line of `tool/package-windows.sh`.
class PackageWindowsOptions {
  final PackagingMode mode;

  /// `a.b.c.d` from `--version`; null → from `pubspec.yaml` ([resolveVersion],
  /// [storeMsixVersion]).
  final String? version;

  /// The output folder (`--output`, default `build/msix`), relative to
  /// `lumina_ui/` unless absolute.
  final String output;
  final bool skipBuild;

  /// Publish mode only: the App Installer feed folder (`msix:publish`).
  final String? appInstaller;
  final bool dryRun;
  final bool help;

  const PackageWindowsOptions({
    this.mode = PackagingMode.selfSigned,
    this.version,
    this.output = defaultOutput,
    this.skipBuild = false,
    this.appInstaller,
    this.dryRun = false,
    this.help = false,
  });

  static const String defaultOutput = 'build/msix';

  static const String usage = '''
Usage: tool/package-windows.sh [options]

Builds an MSIX package of Lumina Studio (Windows only).

Without --publish or --store the package is self-signed with the stable
Lumina development certificate (windows/packaging/dev/, created on first use).

Options:
  --publish               Sign for distribution with the certificate from the
                          environment (LUMINA_MSIX_PUBLISHER and either
                          LUMINA_MSIX_CERT_PATH + LUMINA_MSIX_CERT_PASSWORD or
                          LUMINA_MSIX_SIGNTOOL_OPTIONS; LUMINA_MSIX_TIMESTAMP_URL
                          optional). Never falls back to self-signing.
  --store                 An unsigned Microsoft Store package with the Partner
                          Center publisher from msix_config (the Store signs it).
  --version a.b.c.d       Package version (default: from the pubspec version,
                          M.m.p[-dev.N|-rc.N] → (M+1).m.(p*1000+s).0; see
                          storeMsixVersion).
  --output <dir>          Output folder (default: build/msix).
  --skip-build            Reuse build/windows/x64/runner/Release instead of building.
  --appinstaller <folder> With --publish: also write an App Installer feed there (msix:publish).
  --dry-run               Print the plan and the exact msix command; touch nothing.
  -h, --help              Show this help.
''';

  /// Parses [args]; throws a [PackagingException] (exit 64) on bad usage.
  static PackageWindowsOptions parse(List<String> args) {
    var mode = PackagingMode.selfSigned;
    String? version;
    var output = defaultOutput;
    var skipBuild = false;
    String? appInstaller;
    var dryRun = false;
    var help = false;

    String valueOf(String option, List<String> args, int i, String? inline) {
      if (inline != null) {
        if (inline.isEmpty) throw PackagingException.usage('$option needs a value.\n\n$usage');
        return inline;
      }
      if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
        throw PackagingException.usage('$option needs a value.\n\n$usage');
      }
      return args[i + 1];
    }

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      final eq = arg.startsWith('--') ? arg.indexOf('=') : -1;
      final name = eq == -1 ? arg : arg.substring(0, eq);
      final inline = eq == -1 ? null : arg.substring(eq + 1);
      switch (name) {
        case '--publish':
          if (mode == PackagingMode.store) throw const PackagingException.usage(_storeAndPublish);
          mode = PackagingMode.publish;
        case '--store':
          if (mode == PackagingMode.publish) throw const PackagingException.usage(_storeAndPublish);
          mode = PackagingMode.store;
        case '--skip-build':
          skipBuild = true;
        case '--dry-run':
          dryRun = true;
        case '-h' || '--help':
          help = true;
        case '--version':
          version = valueOf(name, args, i, inline);
          if (inline == null) i++;
          if (!_msixVersion.hasMatch(version)) {
            throw PackagingException.usage('--version must be four numbers in the a.b.c.d format (e.g. 1.2.3.4), got "$version".');
          }
        case '--output':
          output = valueOf(name, args, i, inline);
          if (inline == null) i++;
        case '--appinstaller':
          appInstaller = valueOf(name, args, i, inline);
          if (inline == null) i++;
        default:
          throw PackagingException.usage('Unknown option "$arg".\n\n$usage');
      }
    }
    if (appInstaller != null && mode != PackagingMode.publish) {
      throw const PackagingException.usage('--appinstaller is only for --publish builds (an App Installer feed of a signed package).');
    }
    if (mode == PackagingMode.store && version != null) checkStoreVersion(version);
    return PackageWindowsOptions(
      mode: mode,
      version: version,
      output: output,
      skipBuild: skipBuild,
      appInstaller: appInstaller,
      dryRun: dryRun,
      help: help,
    );
  }

  /// [version], or the one derived from [pubspecYaml].
  String resolveVersion(String pubspecYaml) => version ?? msixVersionFromPubspec(pubspecYaml);
}

const String _storeAndPublish = '--store and --publish exclude each other: a Store package is unsigned (the Store signs it), '
    'a --publish package is signed with your certificate.';

/// The Microsoft Store's version rules for [version] (`a.b.c.d`): the fourth
/// section stays 0 (the Store's own) and the first is not 0. Throws a
/// [PackagingException] (64) naming the rule.
void checkStoreVersion(String version) {
  final parts = version.split('.').map(int.parse).toList();
  if (parts[3] != 0) {
    throw PackagingException.usage('--store: the fourth section of the version is reserved for the Store and must be 0, got "$version".');
  }
  if (parts[0] == 0) {
    throw PackagingException.usage('--store: the first section of the version cannot be 0, got "$version".');
  }
}

/// The highest patch number the scheme of [storeMsixVersion] fits in a
/// section (64·1000 + 999 ≤ 65535).
const int maxStorePatch = 64;

/// The MSIX version of a release version — the one scheme the release
/// workflow (`tool/release/release_info.dart`) and this tool use, valid for
/// the Microsoft Store and strictly increasing with semver order:
///
/// `M.m.p[-dev.N|-rc.N]` → `(M+1).m.(p*1000 + s).0`, where `s` is `N` for
/// `dev.N` (1–499), `500+N` for `rc.N` (1–498) and `999` for a final release.
/// The major is shifted because the Store refuses a first section of 0; the
/// fourth section stays 0 because the Store owns it. A `+build` suffix is
/// ignored. Anything else (another pre-release label, a number out of range,
/// a patch above [maxStorePatch]) throws a [PackagingException] (64).
String storeMsixVersion(String semver) {
  final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$').firstMatch(semver.trim());
  if (m == null) throw PackagingException.usage('"$semver" is not a semantic version (M.m.p[-dev.N|-rc.N]).');
  final major = int.parse(m.group(1)!), minor = int.parse(m.group(2)!), patch = int.parse(m.group(3)!);
  final pre = m.group(4);
  int stage;
  if (pre == null) {
    stage = 999;
  } else {
    final p = RegExp(r'^(dev|rc)\.(\d+)$').firstMatch(pre);
    if (p == null) {
      throw PackagingException.usage('"$semver": only dev.N and rc.N pre-releases map to an MSIX version, got "-$pre".');
    }
    final n = int.parse(p.group(2)!);
    final (low, high, base) = p.group(1) == 'dev' ? (1, 499, 0) : (1, 498, 500);
    if (n < low || n > high) {
      throw PackagingException.usage('"$semver": ${p.group(1)}.N must be $low–$high to map to an MSIX version.');
    }
    stage = base + n;
  }
  if (patch > maxStorePatch) {
    throw PackagingException.usage('"$semver": the patch number must be at most $maxStorePatch to map to an MSIX version '
        '(patch*1000 + 999 must fit in 65535); raise the minor instead.');
  }
  if (major + 1 > 65535 || minor > 65535) {
    throw PackagingException.usage('"$semver": a version section exceeds 65535.');
  }
  return '${major + 1}.$minor.${patch * 1000 + stage}.0';
}

/// The MSIX version of `pubspec.yaml`'s `version:` ([storeMsixVersion]).
String msixVersionFromPubspec(String pubspecYaml) {
  final match = RegExp(r'''^version:\s*['"]?([^\s'"#]+)''', multiLine: true).firstMatch(pubspecYaml);
  if (match == null) {
    throw const PackagingException.usage('pubspec.yaml has no "version:"; pass --version a.b.c.d.');
  }
  return storeMsixVersion(match.group(1)!);
}

/// The `msix_config:` block of `pubspec.yaml` (the identity both modes share;
/// signing values come only from the command line).
class MsixConfig {
  final Map<String, String> values;

  const MsixConfig(this.values);

  String? get identityName => values['identity_name'];
  String? get displayName => values['display_name'];
  String? get publisherDisplayName => values['publisher_display_name'];
  String? get outputName => values['output_name'];
  String? get executionAlias => values['execution_alias'];
  String get architecture => values['architecture'] ?? 'x64';
  String? get logoPath => values['logo_path'];

  /// `TargetDeviceFamily MinVersion` (msix's own default when unset).
  String get osMinVersion => values['os_min_version'] ?? '10.0.17763.0';

  /// The Store / Partner Center publisher, when the config records one.
  String? get storePublisher => values['publisher'];
  List<String> get capabilities =>
      (values['capabilities'] ?? '').split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();

  /// Reads the top-level `msix_config:` mapping (flat `key: value` lines).
  factory MsixConfig.fromPubspec(String pubspecYaml) {
    final lines = pubspecYaml.split(RegExp(r'\r?\n'));
    final start = lines.indexWhere((l) => RegExp(r'^msix_config:\s*(#.*)?$').hasMatch(l));
    if (start == -1) {
      throw const PackagingException.usage('pubspec.yaml has no top-level "msix_config:" block.');
    }
    final values = <String, String>{};
    for (final line in lines.skip(start + 1)) {
      if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
      if (!line.startsWith(' ') && !line.startsWith('\t')) break;
      final m = RegExp(r'''^\s+([A-Za-z_]+):\s*(.*?)\s*$''').firstMatch(line);
      if (m == null) continue;
      var value = m.group(2)!;
      if (!value.startsWith('"') && !value.startsWith("'")) {
        final hash = value.indexOf(' #');
        if (hash != -1) value = value.substring(0, hash).trim();
      } else if (value.length >= 2 && value.endsWith(value[0])) {
        value = value.substring(1, value.length - 1);
      }
      values[m.group(1)!] = value;
    }
    if (values['identity_name'] == null) {
      throw const PackagingException.usage('msix_config in pubspec.yaml has no identity_name.');
    }
    return MsixConfig(values);
  }
}
