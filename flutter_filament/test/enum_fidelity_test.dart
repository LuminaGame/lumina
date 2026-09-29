import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:test/test.dart';

void main() {
  group('Enum Fidelity & Backend Ground Truth Parity', () {
    test('PrimitiveType explicit values match Filament backend C++ values exactly', () {
      expect(PrimitiveType.points.value, equals(c.filament_enum_primitive_type(0)));
      expect(PrimitiveType.lines.value, equals(c.filament_enum_primitive_type(1)));
      expect(PrimitiveType.lineStrip.value, equals(c.filament_enum_primitive_type(2)));
      expect(PrimitiveType.triangles.value, equals(c.filament_enum_primitive_type(3)));
      expect(PrimitiveType.triangleStrip.value, equals(c.filament_enum_primitive_type(4)));

      // Assert non-contiguous values (lineStrip is 3, triangles is 4, triangleStrip is 5)
      expect(PrimitiveType.points.value, equals(0));
      expect(PrimitiveType.lines.value, equals(1));
      expect(PrimitiveType.lineStrip.value, equals(3));
      expect(PrimitiveType.triangles.value, equals(4));
      expect(PrimitiveType.triangleStrip.value, equals(5));
    });

    test('IndexType values match backend ElementType::USHORT and UINT', () {
      expect(IndexType.ushort.value, equals(c.filament_enum_index_type(0)));
      expect(IndexType.uint.value, equals(c.filament_enum_index_type(1)));

      expect(IndexType.ushort.value, equals(12));
      expect(IndexType.uint.value, equals(17));
    });

    test('TextureUsage bitmask constants match C values and defaultUsage is uploadable|sampleable', () {
      expect(TextureUsage.none, equals(c.filament_enum_texture_usage(0)));
      expect(TextureUsage.colorAttachment, equals(c.filament_enum_texture_usage(1)));
      expect(TextureUsage.depthAttachment, equals(c.filament_enum_texture_usage(2)));
      expect(TextureUsage.stencilAttachment, equals(c.filament_enum_texture_usage(3)));
      expect(TextureUsage.uploadable, equals(c.filament_enum_texture_usage(4)));
      expect(TextureUsage.sampleable, equals(c.filament_enum_texture_usage(5)));
      expect(TextureUsage.subpassInput, equals(c.filament_enum_texture_usage(6)));
      expect(TextureUsage.blitSrc, equals(c.filament_enum_texture_usage(7)));
      expect(TextureUsage.blitDst, equals(c.filament_enum_texture_usage(8)));
      expect(TextureUsage.protectedUsage, equals(c.filament_enum_texture_usage(9)));
      expect(TextureUsage.genMipmappable, equals(c.filament_enum_texture_usage(10)));
      expect(TextureUsage.defaultUsage, equals(c.filament_enum_texture_usage(11)));

      expect(TextureUsage.defaultUsage, equals(TextureUsage.uploadable | TextureUsage.sampleable));
    });

    test('BuilderResult values match C error(-1) and success(0)', () {
      expect(BuilderResult.error.value, equals(c.filament_enum_builder_result(0)));
      expect(BuilderResult.success.value, equals(c.filament_enum_builder_result(1)));
      expect(BuilderResult.error.value, equals(-1));
      expect(BuilderResult.success.value, equals(0));
    });

    test('MorphType bitmask constants match C and do not collide', () {
      expect(MorphType.none, equals(c.filament_enum_morph_type(0)));
      expect(MorphType.positions, equals(c.filament_enum_morph_type(1)));
      expect(MorphType.tangents, equals(c.filament_enum_morph_type(2)));
      expect(MorphType.custom, equals(c.filament_enum_morph_type(3)));

      final combined = MorphType.positions | MorphType.tangents;
      expect(combined & MorphType.positions, equals(MorphType.positions));
      expect(combined & MorphType.tangents, equals(MorphType.tangents));
      expect(combined & MorphType.custom, equals(0));
    });

    test('Existing enums audit (Backend, LightType, ManipulatorMode, FilamatShading)', () {
      for (int i = 0; i < FilamentBackend.values.length; i++) {
        expect(FilamentBackend.values[i].index, equals(c.filament_enum_backend(i)));
      }

      for (int i = 0; i < LightType.values.length; i++) {
        expect(LightType.values[i].value, equals(c.filament_enum_light_type(i)));
      }

      for (int i = 0; i < ManipulatorMode.values.length; i++) {
        expect(ManipulatorMode.values[i].value, equals(c.filament_enum_manipulator_mode(i)));
      }

      for (int i = 0; i < FilamatShading.values.length; i++) {
        expect(FilamatShading.values[i].value, equals(c.filament_enum_filamat_shading(i)));
      }
    });

    test('PixelFormat and PixelType values match Filament DriverEnums.h', () {
      for (final format in PixelFormat.values) {
        expect(format.value, equals(c.filament_enum_pixel_format(format.value)),
            reason: 'Mismatch for PixelFormat.${format.name}');
      }

      for (final type in PixelType.values) {
        expect(type.value, equals(c.filament_enum_pixel_type(type.value)),
            reason: 'Mismatch for PixelType.${type.name}');
      }
    });

    test('CullingMode, DepthFunc, TransparencyMode match Filament DriverEnums.h', () {
      for (final mode in CullingMode.values) {
        expect(mode.value, equals(c.filament_enum_culling_mode(mode.value)),
            reason: 'Mismatch for CullingMode.${mode.name}');
      }

      for (final func in DepthFunc.values) {
        expect(func.value, equals(c.filament_enum_depth_func(func.value)),
            reason: 'Mismatch for DepthFunc.${func.name}');
      }

      for (final mode in TransparencyMode.values) {
        expect(mode.value, equals(c.filament_enum_transparency_mode(mode.value)),
            reason: 'Mismatch for TransparencyMode.${mode.name}');
      }
    });
  });
}

