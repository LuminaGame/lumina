import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:lumina_core/lumina_core.dart';

/// A signed-in Marketplace session as the editor keeps it between runs.
class StoredMarketplaceSession {
  const StoredMarketplaceSession({required this.server, required this.refreshToken, this.username});

  /// The server root the token belongs to (`http://127.0.0.1:8787/`).
  final String server;
  final String refreshToken;
  final String? username;
}

/// Keeps the Marketplace refresh token between editor runs in an encrypted
/// file under the editor's config directory ([LuminaConfigDir], a temp
/// directory in tests): `marketplace/session.json`, AES-256-GCM with a key
/// derived (HKDF-SHA256) from this machine's id, the user name and a random
/// per-file salt, so a copied file does not open on another machine or
/// account. The file is readable by its owner only. Access tokens are never
/// stored; they live in memory for 15 minutes.
class MarketplaceSessionStore {
  MarketplaceSessionStore({Directory? configDir, this.machineSecret})
      : file = File('${LuminaConfigDir.resolve(explicit: configDir).path}/marketplace/session.json');

  final File file;

  /// Key material instead of [defaultMachineSecret] (tests use it to prove a
  /// file from another machine does not open).
  final List<int>? machineSecret;

  static const int _formatVersion = 1;
  static final List<int> _info = utf8.encode('lumina-marketplace-session-v1');

  /// This machine and account, as key material: `/etc/machine-id` (or the
  /// host name where there is none) and the user name.
  static List<int> defaultMachineSecret() {
    var machine = '';
    for (final path in const ['/etc/machine-id', '/var/lib/dbus/machine-id']) {
      try {
        final f = File(path);
        if (f.existsSync()) {
          machine = f.readAsStringSync().trim();
          if (machine.isNotEmpty) break;
        }
      } catch (_) {}
    }
    if (machine.isEmpty) machine = Platform.localHostname;
    final user = Platform.environment['USER'] ?? Platform.environment['USERNAME'] ?? '';
    return utf8.encode('$machine\u0000$user');
  }

  Future<SecretKey> _key(List<int> salt) => Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
        secretKey: SecretKey(machineSecret ?? defaultMachineSecret()),
        nonce: salt,
        info: _info,
      );

  static List<int> _random(int n) {
    final r = Random.secure();
    return List<int>.generate(n, (_) => r.nextInt(256));
  }

  Future<void> save(StoredMarketplaceSession session) async {
    final salt = _random(16);
    final algorithm = AesGcm.with256bits();
    final box = await algorithm.encrypt(
      utf8.encode(jsonEncode({'refreshToken': session.refreshToken})),
      secretKey: await _key(salt),
      nonce: algorithm.newNonce(),
    );
    file.parent.createSync(recursive: true);
    final tmp = File('${file.path}.tmp');
    tmp.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'formatVersion': _formatVersion,
      'server': session.server,
      'username': session.username,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    }));
    _ownerOnly(tmp);
    tmp.renameSync(file.path);
  }

  /// The stored session for [server], or null when there is none, it is for
  /// another server, or it does not decrypt here.
  Future<StoredMarketplaceSession?> load(String server) async {
    if (!file.existsSync()) return null;
    try {
      final j = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      if (j['formatVersion'] != _formatVersion || j['server'] != server) return null;
      final salt = base64Decode(j['salt'] as String);
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(
          base64Decode(j['cipherText'] as String),
          nonce: base64Decode(j['nonce'] as String),
          mac: Mac(base64Decode(j['mac'] as String)),
        ),
        secretKey: await _key(salt),
      );
      final token = (jsonDecode(utf8.decode(clear)) as Map)['refreshToken'] as String;
      return StoredMarketplaceSession(server: server, refreshToken: token, username: j['username'] as String?);
    } catch (e) {
      debugPrint('[MarketplaceSessionStore] ${file.path} cannot be read here ($e); signing in again.');
      return null;
    }
  }

  void clear() {
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  static void _ownerOnly(File f) {
    if (Platform.isWindows) return;
    try {
      Process.runSync('chmod', ['600', f.path]);
    } catch (_) {}
  }
}
