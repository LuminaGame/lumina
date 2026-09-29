import 'dart:typed_data';

class TextureMipLevel {
  final int level;
  final int width;
  final int height;
  final Uint8List pixels; // raw RGBA8 (width * height * 4)

  const TextureMipLevel({
    required this.level,
    required this.width,
    required this.height,
    required this.pixels,
  });

  (int, int, int, int) pixelAt(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return (0, 0, 0, 0);
    final idx = (y * width + x) * 4;
    if (idx + 3 >= pixels.length) return (0, 0, 0, 0);
    return (pixels[idx], pixels[idx + 1], pixels[idx + 2], pixels[idx + 3]);
  }
}

class TextureSettings {
  bool srgb;
  String group; // 'World', 'UI', 'Effects', 'Skybox', 'Normalmap'
  String format; // 'KTX2 / Basis Universal', 'ASTC', 'ETC2', 'Uncompressed RGBA8'
  String quality; // 'Default', 'High Quality / Lossless', 'Fast Compression'
  String mipGen; // 'FromTextureGroup', 'Sharpen1'..'Sharpen10', 'Blur1'..'Blur10', 'NoMipmaps'
  String filter; // 'Bilinear', 'Trilinear', 'Anisotropic 16x'
  String addressX; // 'Wrap', 'Clamp', 'Mirror'
  String addressY; // 'Wrap', 'Clamp', 'Mirror'

  TextureSettings({
    this.srgb = true,
    this.group = 'World',
    this.format = 'KTX2 / Basis Universal',
    this.quality = 'Default',
    this.mipGen = 'FromTextureGroup',
    this.filter = 'Bilinear',
    this.addressX = 'Wrap',
    this.addressY = 'Wrap',
  });

  Map<String, dynamic> toJson() => {
        'srgb': srgb,
        'group': group,
        'format': format,
        'quality': quality,
        'mip_gen': mipGen,
        'filter': filter,
        'address_x': addressX,
        'address_y': addressY,
      };

  factory TextureSettings.fromJson(Map<String, dynamic> json) => TextureSettings(
        srgb: json['srgb'] as bool? ?? true,
        group: json['group'] as String? ?? 'World',
        format: json['format'] as String? ?? 'KTX2 / Basis Universal',
        quality: json['quality'] as String? ?? 'Default',
        mipGen: json['mip_gen'] as String? ?? 'FromTextureGroup',
        filter: json['filter'] as String? ?? 'Bilinear',
        addressX: json['address_x'] as String? ?? 'Wrap',
        addressY: json['address_y'] as String? ?? 'Wrap',
      );
}
