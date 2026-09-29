import 'dart:convert';
import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart';

/// Base save game object containing player state, level name, and serialized data.
class LuminaSaveGame {
  static const List<int> magicBytes = [0x4C, 0x4D, 0x53, 0x56]; // 'LMSV'
  static const int binaryFormatVersion = 1;

  static final Map<String, LuminaSaveGame Function(Map<String, dynamic>)> _registry = {};

  /// Registers a custom [LuminaSaveGame] subclass factory for polymorphic deserialization.
  static void registerSaveGameType<T extends LuminaSaveGame>(
    String className,
    T Function(Map<String, dynamic>) factory,
  ) {
    _registry[className] = factory;
  }

  /// Instantiates a registered [LuminaSaveGame] subclass from [json] or falls back to base class.
  static LuminaSaveGame instantiateFromJson(Map<String, dynamic> json) {
    final className = json['saveGameClassName'] as String?;
    if (className != null && _registry.containsKey(className)) {
      return _registry[className]!(json);
    }
    return LuminaSaveGame.fromJson(json);
  }

  String saveSlotName;
  int userIndex;
  DateTime saveTimestamp;
  String currentLevelName;
  Vector3 playerLocation;
  Quaternion playerRotation;
  Map<String, dynamic> customSaveData;
  int saveGameVersion;

  LuminaSaveGame({
    this.saveSlotName = 'SaveSlot_01',
    this.userIndex = 0,
    DateTime? saveTimestamp,
    this.currentLevelName = 'DefaultLevel',
    Vector3? playerLocation,
    Quaternion? playerRotation,
    Map<String, dynamic>? customSaveData,
    this.saveGameVersion = 1,
  })  : saveTimestamp = (saveTimestamp ?? DateTime.now()).toUtc(),
        playerLocation = playerLocation ?? Vector3.zero(),
        playerRotation = playerRotation ?? Quaternion.identity(),
        customSaveData = customSaveData != null ? Map<String, dynamic>.from(customSaveData) : {};

  String get saveGameClassName => runtimeType.toString();

  Map<String, dynamic> toJson() {
    _validateJsonSafe(customSaveData);
    return {
      'saveGameClassName': saveGameClassName,
      'saveGameVersion': saveGameVersion,
      'saveSlotName': saveSlotName,
      'userIndex': userIndex,
      'saveTimestamp': saveTimestamp.toIso8601String(),
      'currentLevelName': currentLevelName,
      'playerLocation': [playerLocation.x, playerLocation.y, playerLocation.z],
      'playerRotation': [playerRotation.x, playerRotation.y, playerRotation.z, playerRotation.w],
      'customSaveData': customSaveData,
    };
  }

  factory LuminaSaveGame.fromJson(Map<String, dynamic> json) {
    final locRaw = json['playerLocation'];
    final rotRaw = json['playerRotation'];

    Vector3 loc = Vector3.zero();
    if (locRaw is List && locRaw.length >= 3) {
      loc = Vector3(
        (locRaw[0] as num?)?.toDouble() ?? 0.0,
        (locRaw[1] as num?)?.toDouble() ?? 0.0,
        (locRaw[2] as num?)?.toDouble() ?? 0.0,
      );
    }

    Quaternion rot = Quaternion.identity();
    if (rotRaw is List && rotRaw.length >= 4) {
      rot = Quaternion(
        (rotRaw[0] as num?)?.toDouble() ?? 0.0,
        (rotRaw[1] as num?)?.toDouble() ?? 0.0,
        (rotRaw[2] as num?)?.toDouble() ?? 0.0,
        (rotRaw[3] as num?)?.toDouble() ?? 1.0,
      );
    }

    DateTime timestamp;
    final timeRaw = json['saveTimestamp'];
    if (timeRaw is String) {
      timestamp = DateTime.tryParse(timeRaw)?.toUtc() ?? DateTime.now().toUtc();
    } else {
      timestamp = DateTime.now().toUtc();
    }

    return LuminaSaveGame(
      saveSlotName: json['saveSlotName'] as String? ?? 'SaveSlot_01',
      userIndex: (json['userIndex'] as num?)?.toInt() ?? 0,
      saveTimestamp: timestamp,
      currentLevelName: json['currentLevelName'] as String? ?? 'DefaultLevel',
      playerLocation: loc,
      playerRotation: rot,
      customSaveData: json['customSaveData'] is Map
          ? Map<String, dynamic>.from(json['customSaveData'] as Map)
          : {},
      saveGameVersion: (json['saveGameVersion'] as num?)?.toInt() ?? 1,
    );
  }

  String serialize() => jsonEncode(toJson());

  static LuminaSaveGame deserialize(String rawJson) {
    dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } catch (e) {
      throw FormatException('Invalid JSON payload for LuminaSaveGame: $e');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON Object for LuminaSaveGame root');
    }

    return instantiateFromJson(decoded);
  }

  Uint8List serializeBinary() {
    final payloadUtf8 = utf8.encode(serialize());
    final byteData = ByteData(4 + 2 + 4 + payloadUtf8.length);

    // Magic: LMSV
    byteData.setUint8(0, magicBytes[0]);
    byteData.setUint8(1, magicBytes[1]);
    byteData.setUint8(2, magicBytes[2]);
    byteData.setUint8(3, magicBytes[3]);

    // Format Version: uint16
    byteData.setUint16(4, binaryFormatVersion, Endian.big);

    // Payload length: uint32
    byteData.setUint32(6, payloadUtf8.length, Endian.big);

    // Payload body
    final resultBytes = byteData.buffer.asUint8List();
    resultBytes.setRange(10, 10 + payloadUtf8.length, payloadUtf8);
    return resultBytes;
  }

  static LuminaSaveGame deserializeBinary(Uint8List bytes) {
    if (bytes.length < 10) {
      throw const FormatException('Corrupt or truncated Lumina binary save data');
    }

    if (bytes[0] != magicBytes[0] ||
        bytes[1] != magicBytes[1] ||
        bytes[2] != magicBytes[2] ||
        bytes[3] != magicBytes[3]) {
      throw const FormatException('Invalid magic header: not a Lumina save');
    }

    final byteData = ByteData.sublistView(bytes);
    final payloadLength = byteData.getUint32(6, Endian.big);

    if (bytes.length < 10 + payloadLength) {
      throw const FormatException('Truncated payload in Lumina binary save');
    }

    final payloadStr = utf8.decode(bytes.sublist(10, 10 + payloadLength));
    return deserialize(payloadStr);
  }

  static void _validateJsonSafe(Map<String, dynamic> map) {
    for (final entry in map.entries) {
      _checkValue(entry.key, entry.value);
    }
  }

  static void _checkValue(String keyPath, dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      return;
    }
    if (value is List) {
      for (int i = 0; i < value.length; i++) {
        _checkValue('$keyPath[$i]', value[i]);
      }
      return;
    }
    if (value is Map) {
      for (final entry in value.entries) {
        _checkValue('$keyPath.${entry.key}', entry.value);
      }
      return;
    }
    throw ArgumentError('Non-encodable value for key "$keyPath": ${value.runtimeType} ($value)');
  }
}
