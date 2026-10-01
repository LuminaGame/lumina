/// Resolves a [PackageWindowsOptions] into the exact
/// `dart run msix:create|publish …` invocation of each signing mode, refusing
/// missing or inconsistent publish-mode input before anything is built.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'certificates.dart';
import 'options.dart';

/// Where the packaging runs and reports.
class PackagingContext {
  /// The `lumina_ui/` package folder.
  final String packageRoot;
  final Map<String, String> environment;

  /// The dev certificate folder; default `<packageRoot>/windows/packaging/dev`.
  final String? devCertificateDir;
  final StringSink out;
  final StringSink err;

  const PackagingContext({
    required this.packageRoot,
    required this.environment,
    this.devCertificateDir,
    required this.out,
    required this.err,
  });

  String get devDir => devCertificateDir ?? p.join(packageRoot, 'windows', 'packaging', 'dev');

  /// The Release folder `flutter build windows` writes and msix packs.
  String get releaseDir => p.join(packageRoot, 'build', 'windows', 'x64', 'runner', 'Release');
}

/// The environment variables of publish mode.
abstract final class PublishEnv {
  static const String publisher = 'LUMINA_MSIX_PUBLISHER';
  static const String certPath = 'LUMINA_MSIX_CERT_PATH';
  static const String certPassword = 'LUMINA_MSIX_CERT_PASSWORD';
  static const String signtoolOptions = 'LUMINA_MSIX_SIGNTOOL_OPTIONS';
  static const String timestampUrl = 'LUMINA_MSIX_TIMESTAMP_URL';
  static const String defaultTimestampUrl = 'http://timestamp.digicert.com';
}

/// A resolved packaging run.
class PackagingPlan {
  final PackagingMode mode;
  final String version;
  final MsixConfig config;
  final String outputDir;
  final String outputName;
  final String publisher;

  /// `create`, or `publish` with `--appinstaller`.
  final String msixCommand;

  /// The arguments after `dart run msix:<command>`.
  final List<String> msixArguments;

  /// Values masked when the command is printed (passwords).
  final List<String> secrets;
  final bool skipBuild;
  final String? certificateThumbprint;

  /// Where the signing key comes from, for the summary.
  final String signingSource;

  /// Self-signed: the dev certificate (created by the build when missing).
  final DevCertificate? devCertificate;

  const PackagingPlan({
    required this.mode,
    required this.version,
    required this.config,
    required this.outputDir,
    required this.outputName,
    required this.publisher,
    required this.msixCommand,
    required this.msixArguments,
    required this.secrets,
    required this.skipBuild,
    required this.certificateThumbprint,
    required this.signingSource,
    required this.devCertificate,
  });

  String get msixPath => p.join(outputDir, '$outputName.msix');

  /// `dart run msix:<command> …` with secrets masked and spaced values quoted.
  String describeCommand() {
    String quote(String a) => a.isEmpty || a.contains(RegExp(r'[\s"]')) ? '"${a.replaceAll('"', r'\"')}"' : a;
    String mask(String a) {
      var masked = a;
      for (final s in secrets) {
        if (s.isNotEmpty) masked = masked.replaceAll(s, '****');
      }
      return masked;
    }

    return ['dart', 'run', 'msix:$msixCommand', ...msixArguments.map((a) => quote(mask(a)))].join(' ');
  }
}

/// Builds a [PackagingPlan]; publish-mode input is validated here, before
/// any build.
class PackagingPlanner {
  final PackagingContext context;

  const PackagingPlanner(this.context);

  Future<PackagingPlan> plan(PackageWindowsOptions options) async {
    final pubspec = File(p.join(context.packageRoot, 'pubspec.yaml')).readAsStringSync();
    final config = MsixConfig.fromPubspec(pubspec);
    final version = options.resolveVersion(pubspec);
    final outputDir = p.normalize(p.isAbsolute(options.output) ? options.output : p.join(context.packageRoot, options.output));
    final outputName = '${config.outputName ?? 'LuminaEngine'}_${version}_${config.architecture}';

    final common = <String>[
      '--version', version,
      '--output-path', outputDir,
      '--output-name', outputName,
      '--identity-name', config.identityName!,
      '--architecture', config.architecture,
      '--install-certificate', 'false',
      if (options.skipBuild) ...['--build-windows', 'false'],
    ];

    return switch (options.mode) {
      PackagingMode.selfSigned => _selfSigned(options, config, version, outputDir, outputName, common),
      PackagingMode.publish => _publish(options, config, version, outputDir, outputName, common),
      PackagingMode.store => _store(options, config, version, outputDir, outputName, common),
    };
  }

  /// Unsigned (`msix --store` skips signing), published as the Partner
  /// Center publisher recorded in `msix_config`.
  Future<PackagingPlan> _store(PackageWindowsOptions options, MsixConfig config, String version, String outputDir,
      String outputName, List<String> common) async {
    final publisher = config.storePublisher;
    if (publisher == null || publisher.isEmpty) {
      throw const PackagingException.usage('--store needs msix_config: publisher in pubspec.yaml: the Partner Center publisher '
          '(Product management → Product identity → Package/Identity/Publisher).');
    }
    checkStoreVersion(version);
    return PackagingPlan(
      mode: PackagingMode.store,
      version: version,
      config: config,
      outputDir: outputDir,
      outputName: outputName,
      publisher: publisher,
      msixCommand: 'create',
      msixArguments: [...common, '--store', '--publisher', publisher],
      secrets: const [],
      skipBuild: options.skipBuild,
      certificateThumbprint: null,
      signingSource: 'none (Microsoft Store package; the Store signs it)',
      devCertificate: null,
    );
  }

  Future<PackagingPlan> _selfSigned(PackageWindowsOptions options, MsixConfig config, String version, String outputDir,
      String outputName, List<String> common) async {
    final dev = DevCertificate(Directory(context.devDir));
    String password;
    String? thumbprint;
    if (options.dryRun) {
      password = dev.existingPassword(context.environment) ?? '<generated on first build>';
    } else {
      final info = await dev.ensure(environment: context.environment);
      password = info.password;
      thumbprint = info.thumbprint;
    }
    return PackagingPlan(
      mode: PackagingMode.selfSigned,
      version: version,
      config: config,
      outputDir: outputDir,
      outputName: outputName,
      publisher: DevCertificate.subject,
      msixCommand: 'create',
      msixArguments: [
        ...common,
        '--certificate-path', dev.pfx.absolute.path,
        '--certificate-password', password,
        '--publisher', DevCertificate.subject,
      ],
      secrets: [password],
      skipBuild: options.skipBuild,
      certificateThumbprint: thumbprint,
      signingSource: 'self-signed dev certificate ${dev.pfx.absolute.path}',
      devCertificate: dev,
    );
  }

  Future<PackagingPlan> _publish(PackageWindowsOptions options, MsixConfig config, String version, String outputDir,
      String outputName, List<String> common) async {
    final env = context.environment;
    String? read(String name) {
      final v = env[name]?.trim();
      return v == null || v.isEmpty ? null : v;
    }

    final publisher = read(PublishEnv.publisher);
    if (publisher == null) {
      throw const PackagingException.usage('--publish needs ${PublishEnv.publisher}: the certificate subject, '
          'e.g. "CN=Arbwick Ltd, O=Arbwick Ltd, C=GB" (Store builds: the Partner Center publisher). '
          'No self-signed fallback.');
    }
    final certPath = read(PublishEnv.certPath);
    final signtool = read(PublishEnv.signtoolOptions);
    if (certPath == null && signtool == null) {
      throw const PackagingException.usage('--publish needs a signing key: set ${PublishEnv.certPath} + ${PublishEnv.certPassword} '
          '(a .pfx) or ${PublishEnv.signtoolOptions} (e.g. "/sha1 <thumbprint>" for a key in the store or on a token). '
          'No self-signed fallback.');
    }
    if (certPath != null && signtool != null) {
      throw const PackagingException.usage('--publish: set either ${PublishEnv.certPath} or ${PublishEnv.signtoolOptions}, not both.');
    }
    final timestamp = read(PublishEnv.timestampUrl) ?? PublishEnv.defaultTimestampUrl;
    final secrets = <String>[];
    String? thumbprint;
    late String signingSource;
    final List<String> tokens;

    if (certPath != null) {
      final password = env[PublishEnv.certPassword];
      if (password == null || password.isEmpty) {
        throw const PackagingException.usage('${PublishEnv.certPath} is set but ${PublishEnv.certPassword} is not: the .pfx password is required.');
      }
      if (!File(certPath).existsSync()) {
        throw PackagingException.usage('${PublishEnv.certPath}: $certPath does not exist.');
      }
      final info = await readCertificate(certPath, password: password);
      if (!sameSubject(info.subject, publisher)) {
        throw PackagingException.usage('The certificate subject does not match the publisher:\n'
            '  certificate ($certPath): ${info.subject}\n'
            '  ${PublishEnv.publisher}: $publisher\n'
            'The package publisher must equal the signing certificate subject.');
      }
      if (!info.hasPrivateKey) {
        throw PackagingException.usage('cannot open certificate $certPath for signing: it holds no private key.');
      }
      thumbprint = info.thumbprint;
      secrets.add(password);
      signingSource = certPath;
      tokens = ['/fd', 'SHA256', '/tr', timestamp, '/td', 'SHA256', '/f', '"${p.absolute(certPath)}"', '/p', '"$password"'];
    } else {
      final given = signtool!;
      final lower = given.toLowerCase().split(RegExp(r'\s+'));
      const selectors = ['/sha1', '/n', '/r', '/i', '/f'];
      if (!lower.any(selectors.contains)) {
        throw const PackagingException.usage('${PublishEnv.signtoolOptions} must select the certificate with /sha1, /n, /r, /i or /f '
            '(otherwise msix would sign with its own test certificate).');
      }
      signingSource = '${PublishEnv.signtoolOptions} ($given)';
      tokens = [
        given,
        if (!lower.contains('/fd')) ...['/fd', 'SHA256'],
        if (!lower.contains('/tr')) ...['/tr', timestamp],
        if (!lower.contains('/td')) ...['/td', 'SHA256'],
      ];
    }

    final appInstaller = options.appInstaller;
    return PackagingPlan(
      mode: PackagingMode.publish,
      version: version,
      config: config,
      outputDir: outputDir,
      outputName: outputName,
      publisher: publisher,
      msixCommand: appInstaller == null ? 'create' : 'publish',
      msixArguments: [
        ...common,
        '--publisher', publisher,
        '--signtool-options', tokens.join(' '),
        if (appInstaller != null) ...['--publish-folder-path', p.normalize(p.absolute(appInstaller))],
      ],
      secrets: secrets,
      skipBuild: options.skipBuild,
      certificateThumbprint: thumbprint,
      signingSource: signingSource,
      devCertificate: null,
    );
  }

  /// Distinguished names compared field by field, ignoring spacing after commas.
  static bool sameSubject(String a, String b) {
    List<String> parts(String s) => s.split(RegExp(r',\s*')).map((x) => x.trim()).toList();
    final pa = parts(a), pb = parts(b);
    if (pa.length != pb.length) return false;
    for (var i = 0; i < pa.length; i++) {
      if (pa[i] != pb[i]) return false;
    }
    return true;
  }
}
