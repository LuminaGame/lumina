import 'package:flutter_filament/src/enums.dart';
import 'package:flutter_filament/src/texture.dart';
import 'package:flutter_filament/src/third_party/filament_c.g.dart' as c;
import 'package:test/test.dart';

void main() {
  group('Enum Fidelity Tests', () {
    test('PrimitiveType matches C enum', () {
      expect(PrimitiveType.points.value, c.filament_enum_primitive_type(0));
      expect(PrimitiveType.lines.value, c.filament_enum_primitive_type(1));
      expect(PrimitiveType.lineStrip.value, c.filament_enum_primitive_type(2));
      expect(PrimitiveType.triangles.value, c.filament_enum_primitive_type(3));
      expect(PrimitiveType.triangleStrip.value, c.filament_enum_primitive_type(4));
    });

    test('IndexType matches C enum', () {
      expect(IndexType.ushort.value, c.filament_enum_index_type(0));
      expect(IndexType.uint.value, c.filament_enum_index_type(1));
      expect(IndexType.ushort.value, isNot(equals(0)));
      expect(IndexType.uint.value, isNot(equals(1)));
    });

    test('AttributeType matches C enum', () {
      expect(AttributeType.byte.value, c.filament_enum_attribute_type(0));
      expect(AttributeType.ubyte4.value, c.filament_enum_attribute_type(7));
      expect(AttributeType.float3.value, c.filament_enum_attribute_type(20));
      expect(AttributeType.half4.value, c.filament_enum_attribute_type(25));
    });

    test('VertexAttribute matches C enum', () {
      expect(VertexAttribute.position.value, c.filament_enum_vertex_attribute(0));
      expect(VertexAttribute.color.value, c.filament_enum_vertex_attribute(2));
      expect(VertexAttribute.uv0.value, c.filament_enum_vertex_attribute(3));
      expect(VertexAttribute.custom7.value, c.filament_enum_vertex_attribute(15));
    });

    test('TextureUsage matches C values and bitmasks', () {
      expect(TextureUsage.none, c.filament_enum_texture_usage(0));
      expect(TextureUsage.colorAttachment, c.filament_enum_texture_usage(1));
      expect(TextureUsage.depthAttachment, c.filament_enum_texture_usage(2));
      expect(TextureUsage.stencilAttachment, c.filament_enum_texture_usage(3));
      expect(TextureUsage.uploadable, c.filament_enum_texture_usage(4));
      expect(TextureUsage.sampleable, c.filament_enum_texture_usage(5));
      expect(TextureUsage.subpassInput, c.filament_enum_texture_usage(6));
      expect(TextureUsage.blitSrc, c.filament_enum_texture_usage(7));
      expect(TextureUsage.blitDst, c.filament_enum_texture_usage(8));
      expect(TextureUsage.protectedUsage, c.filament_enum_texture_usage(9));
      expect(TextureUsage.genMipmappable, c.filament_enum_texture_usage(10));
      
      // Default usage is uploadable | sampleable
      expect(TextureUsage.defaultUsage, TextureUsage.uploadable | TextureUsage.sampleable);
      expect(TextureUsage.defaultUsage, c.filament_enum_texture_usage(11));
    });

    test('BuilderResult matches C enum', () {
      expect(BuilderResult.error.value, c.filament_enum_builder_result(0));
      expect(BuilderResult.success.value, c.filament_enum_builder_result(1));
    });

    test('MorphType matches C values and bitmasks', () {
      expect(MorphType.none, c.filament_enum_morph_type(0));
      expect(MorphType.positions, c.filament_enum_morph_type(1));
      expect(MorphType.tangents, c.filament_enum_morph_type(2));
      expect(MorphType.custom, c.filament_enum_morph_type(3));
      
      // Pairwise combinations don't collide
      expect(MorphType.positions & MorphType.tangents, 0);
      expect(MorphType.tangents & MorphType.custom, 0);
      expect(MorphType.positions | MorphType.tangents, equals(MorphType.positions + MorphType.tangents));
    });

    test('TextureFormat matches C enum', () {
      expect(TextureFormat.r8.value, c.filament_enum_internal_format(0));
      expect(TextureFormat.rgba8.value, c.filament_enum_internal_format(30));
      expect(TextureFormat.depth24.value, c.filament_enum_internal_format(22));
      expect(TextureFormat.depth32f.value, c.filament_enum_internal_format(37));
      expect(TextureFormat.rgbaAstc4x4.value, c.filament_enum_internal_format(73));
    });

    // We can also add tests for other enums if needed, but the primary task dictates the above.
  });
}
