[English](../../en/lumina_ui/windows-packaging.md)

# Windows paketleme

`tool/package-windows.sh` script'inin arkasındaki mantık: komut satırı seçenekleri, geliştirme sertifikası, self-signed ve publish modları için paketleme planı ve build edilmiş bir MSIX paketini geri okuyan doğrulama. Dosya yolları `lumina_ui/` paket dizinine görelidir.

**Bu sayfada:**

- [`lib/tooling/windows_packaging/certificates.dart`](#libtoolingwindows_packagingcertificatesdart)
- [`lib/tooling/windows_packaging/options.dart`](#libtoolingwindows_packagingoptionsdart)
- [`lib/tooling/windows_packaging/package_windows.dart`](#libtoolingwindows_packagingpackage_windowsdart)
- [`lib/tooling/windows_packaging/plan.dart`](#libtoolingwindows_packagingplandart)
- [`lib/tooling/windows_packaging/verify.dart`](#libtoolingwindows_packagingverifydart)

## `lib/tooling/windows_packaging/certificates.dart`

### `class CertificateInfo`

What a certificate file holds.

**Yapıcı Metotlar (Constructors):**

- `const CertificateInfo({required this.subject, required this.thumbprint, required this.notAfter, required this.hasPrivateKey, required this.enhancedKeyUsages,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `subject` | `final String subject` |  |
| `thumbprint` | `final String thumbprint` |  |
| `notAfter` | `final DateTime notAfter` |  |
| `hasPrivateKey` | `final bool hasPrivateKey` |  |
| `enhancedKeyUsages` | `final List<String> enhancedKeyUsages` |  |

### `class DevCertificateInfo`

The dev certificate as used for a build.

**Yapıcı Metotlar (Constructors):**

- `const DevCertificateInfo({required this.subject, required this.thumbprint, required this.password, required this.pfxPath, required this.cerPath,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `subject` | `final String subject` |  |
| `thumbprint` | `final String thumbprint` |  |
| `password` | `final String password` |  |
| `pfxPath` | `final String pfxPath` |  |
| `cerPath` | `final String cerPath` |  |

### `class DevCertificate`

The stable Lumina development code-signing certificate (`windows/packaging/dev/`, git-ignored): created once, then reused, so every self-signed build carries the same publisher and a newer package upgrades an installed one in place.

**Yapıcı Metotlar (Constructors):**

- `DevCertificate(this.dir)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `subject` | `static const String subject` |  |
| `passwordVariable` | `static const String passwordVariable` | Overrides the generated password file. |
| `dir` | `final Directory dir` |  |
| `pfx` | `File get pfx` |  |
| `cer` | `File get cer` |  |
| `passwordFile` | `File get passwordFile` |  |
| `trustCommand` | `String get trustCommand` | The one-time, admin command that trusts [cer] for sideloading. |
| `existingPassword` | `String? existingPassword(Map<String, String> environment)` | The password: [passwordVariable], else the password file (generated once). Null in a dry run when neither exists yet. |
| `ensure` | `Future<DevCertificateInfo> ensure({required Map<String, String> environment}) async` | Creates the certificate on first use, or reuses the existing one. |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `codeSigningEku` | `const String codeSigningEku` | The code-signing extended key usage (1.3.6.1.5.5.7.3.3). |
| `runPowerShell` | `Future<ProcessResult> runPowerShell(String script, {Map<String, String> environment = const {}})` | Runs a Windows PowerShell [script]; secrets travel in [environment], never on the command line. |
| `readCertificate` | `Future<CertificateInfo> readCertificate(String path, {String? password}) async` | Reads the certificate in [path] (a `.pfx` with [password], or a `.cer`). Throws a [PackagingException] (64) "cannot open certificate …" when the file does not open (a wrong password, not a certificate). The password is never part of the message. |
| `createSelfSignedPfx` | `Future<File> createSelfSignedPfx({required String subject, required File pfx, required String password, File?...` | Creates a self-signed code-signing certificate for [subject] with `New-SelfSignedCertificate` (in `Cert:\CurrentUser\My`, five years), exports it to [pfx] (protected by [password]) and, when given, its public part to [cer], then deletes it and its key from the user store. Returns [pfx]. |

## `lib/tooling/windows_packaging/options.dart`

### `enum PackagingMode`

How the package is signed.

**Değerler:**

- `selfSigned`: The stable Lumina development certificate (local and team testing).
- `publish`: A certificate from the environment, timestamped (distribution).

### `class PackagingException`

A refusal or failure with the exit code the script returns: 64 for usage / signing-input problems, 2 off Windows, 1 for a failed build or verification.

**Yapıcı Metotlar (Constructors):**

- `const PackagingException(this.exitCode, this.message)`
- `const PackagingException.usage(this.message)`: A usage or configuration problem (EX_USAGE).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `exitCode` | `final int exitCode` |  |
| `message` | `final String message` |  |

### `class PackageWindowsOptions`

The parsed command line of `tool/package-windows.sh`.

**Yapıcı Metotlar (Constructors):**

- `const PackageWindowsOptions({this.mode = PackagingMode.selfSigned, this.version, this.output = defaultOutput, this.skipBuild = false, this.appInstaller, this.dr...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `mode` | `final PackagingMode mode` |  |
| `version` | `final String? version` | `a.b.c.d` from `--version`; null → from `pubspec.yaml` ([resolveVersion]). |
| `output` | `final String output` | The output folder (`--output`, default `build/msix`), relative to `lumina_ui/` unless absolute. |
| `skipBuild` | `final bool skipBuild` |  |
| `appInstaller` | `final String? appInstaller` | Publish mode only: the App Installer feed folder (`msix:publish`). |
| `dryRun` | `final bool dryRun` |  |
| `help` | `final bool help` |  |
| `defaultOutput` | `static const String defaultOutput` |  |
| `usage` | `static const String usage` |  |
| `parse` | `static PackageWindowsOptions parse(List<String> args)` | Parses [args]; throws a [PackagingException] (exit 64) on bad usage. |
| `resolveVersion` | `String resolveVersion(String pubspecYaml)` | [version], or the one derived from [pubspecYaml]. |

### `class MsixConfig`

The `msix_config:` block of `pubspec.yaml` (the identity both modes share; signing values come only from the command line).

**Yapıcı Metotlar (Constructors):**

- `const MsixConfig(this.values)`
- `factory MsixConfig.fromPubspec(String pubspecYaml)`: Reads the top-level `msix_config:` mapping (flat `key: value` lines).

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `values` | `final Map<String, String> values` |  |
| `identityName` | `String? get identityName` |  |
| `displayName` | `String? get displayName` |  |
| `publisherDisplayName` | `String? get publisherDisplayName` |  |
| `outputName` | `String? get outputName` |  |
| `executionAlias` | `String? get executionAlias` |  |
| `architecture` | `String get architecture` |  |
| `logoPath` | `String? get logoPath` |  |
| `storePublisher` | `String? get storePublisher` | The Store / Partner Center publisher, when the config records one. |
| `capabilities` | `List<String> get capabilities` |  |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `msixVersionFromPubspec` | `String msixVersionFromPubspec(String pubspecYaml)` | `version: x.y.z+n` → `x.y.z.n` (`x.y.z` → `x.y.z.0`). |

## `lib/tooling/windows_packaging/package_windows.dart`

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `findDartExecutable` | `String findDartExecutable(Map<String, String> environment)` | The Dart SDK executable to run `msix` with: this process when it is dart, else the Flutter SDK's (FLUTTER_ROOT, the ancestors of this executable, then PATH). |
| `runPackageWindows` | `Future<int> runPackageWindows(List<String> args, PackagingContext context) async` | Runs the packaging for [args]; returns the process exit code. |

## `lib/tooling/windows_packaging/plan.dart`

### `class PackagingContext`

Where the packaging runs and reports.

**Yapıcı Metotlar (Constructors):**

- `const PackagingContext({required this.packageRoot, required this.environment, this.devCertificateDir, required this.out, required this.err,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `packageRoot` | `final String packageRoot` | The `lumina_ui/` package folder. |
| `environment` | `final Map<String, String> environment` |  |
| `devCertificateDir` | `final String? devCertificateDir` | The dev certificate folder; default `<packageRoot>/windows/packaging/dev`. |
| `out` | `final StringSink out` |  |
| `err` | `final StringSink err` |  |
| `devDir` | `String get devDir` |  |
| `releaseDir` | `String get releaseDir` | The Release folder `flutter build windows` writes and msix packs. |

### `abstract final class PublishEnv`

The environment variables of publish mode.

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `publisher` | `static const String publisher` |  |
| `certPath` | `static const String certPath` |  |
| `certPassword` | `static const String certPassword` |  |
| `signtoolOptions` | `static const String signtoolOptions` |  |
| `timestampUrl` | `static const String timestampUrl` |  |
| `defaultTimestampUrl` | `static const String defaultTimestampUrl` |  |

### `class PackagingPlan`

A resolved packaging run.

**Yapıcı Metotlar (Constructors):**

- `const PackagingPlan({required this.mode, required this.version, required this.config, required this.outputDir, required this.outputName, required this.publisher...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `mode` | `final PackagingMode mode` |  |
| `version` | `final String version` |  |
| `config` | `final MsixConfig config` |  |
| `outputDir` | `final String outputDir` |  |
| `outputName` | `final String outputName` |  |
| `publisher` | `final String publisher` |  |
| `msixCommand` | `final String msixCommand` | `create`, or `publish` with `--appinstaller`. |
| `msixArguments` | `final List<String> msixArguments` | The arguments after `dart run msix:<command>`. |
| `secrets` | `final List<String> secrets` | Values masked when the command is printed (passwords). |
| `skipBuild` | `final bool skipBuild` |  |
| `certificateThumbprint` | `final String? certificateThumbprint` |  |
| `signingSource` | `final String signingSource` | Where the signing key comes from, for the summary. |
| `devCertificate` | `final DevCertificate? devCertificate` | Self-signed: the dev certificate (created by the build when missing). |
| `msixPath` | `String get msixPath` |  |
| `describeCommand` | `String describeCommand()` | `dart run msix:<command> …` with secrets masked and spaced values quoted. |

### `class PackagingPlanner`

Builds a [PackagingPlan]; publish-mode input is validated here, before any build.

**Yapıcı Metotlar (Constructors):**

- `const PackagingPlanner(this.context)`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `context` | `final PackagingContext context` |  |
| `plan` | `Future<PackagingPlan> plan(PackageWindowsOptions options) async` |  |
| `sameSubject` | `static bool sameSubject(String a, String b)` | Distinguished names compared field by field, ignoring spacing after commas. |

## `lib/tooling/windows_packaging/verify.dart`

### `class MsixExpectation`

What a package must be.

**Yapıcı Metotlar (Constructors):**

- `const MsixExpectation({required this.identityName, required this.publisher, required this.version, required this.mode, this.thumbprint,})`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `identityName` | `final String identityName` |  |
| `publisher` | `final String publisher` |  |
| `version` | `final String version` |  |
| `mode` | `final PackagingMode mode` |  |
| `thumbprint` | `final String? thumbprint` | The signing certificate's thumbprint, when known. |
| `requiredFiles` | `static const List<String> requiredFiles` | Files every Lumina Studio package holds (plus `data/flutter_assets/…`). |

### `class MsixVerification`

The read-back of a package; [problems] is empty when it passed.

**Yapıcı Metotlar (Constructors):**

- `const MsixVerification({required this.entries, required this.identityName, required this.publisher, required this.version, required this.executionAlias, require...`

**Üyeler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `entries` | `final Set<String> entries` |  |
| `identityName` | `final String? identityName` |  |
| `publisher` | `final String? publisher` |  |
| `version` | `final String? version` |  |
| `executionAlias` | `final String? executionAlias` |  |
| `capabilities` | `final List<String> capabilities` |  |
| `signatureStatus` | `final String signatureStatus` |  |
| `signatureMessage` | `final String signatureMessage` |  |
| `signerSubject` | `final String? signerSubject` |  |
| `signerThumbprint` | `final String? signerThumbprint` |  |
| `timestamped` | `final bool timestamped` |  |
| `size` | `final int size` |  |
| `problems` | `final List<String> problems` |  |
| `ok` | `bool get ok` |  |

**Üst düzey fonksiyonlar ve değişkenler:**

| Üye | İmza | Açıklama |
| :--- | :--- | :--- |
| `verifyMsix` | `Future<MsixVerification> verifyMsix(File msix, MsixExpectation expected) async` | Verifies [msix] against [expected]: every problem is collected, each naming what was found and what was expected. |

---

[Önceki: MCP araç kataloğu](mcp-tools.md) | [Üst: lumina_ui (Lumina Studio)](index.md) | [Sonraki: Alt editörler](sub-editors/index.md)
