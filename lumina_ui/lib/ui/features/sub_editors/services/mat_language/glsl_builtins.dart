/// The common GLSL ES 3.0 built-in functions, types and keywords a `.mat`
/// `vertex` / `fragment` block can use (the language of the OpenGL ES
/// Shading Language 3.00 specification). Filament's own APIs are in the
/// generated `filament_material_api.g.dart`.
library;

import 'package:lumina_ui/ui/features/sub_editors/services/mat_language/mat_api_types.dart';

const String _g = 'GLSL';

/// The common built-in functions, `genType` standing for `float`, `vec2`,
/// `vec3` or `vec4`.
const List<MatFunctionInfo> glslBuiltinFunctions = [
  // Texture lookup.
  MatFunctionInfo(name: 'texture', signature: 'vec4 texture(sampler s, vec2|vec3 P [, float bias])', returnType: 'vec4', description: 'Samples the texture bound to s at coordinate P.', category: _g),
  MatFunctionInfo(name: 'textureLod', signature: 'vec4 textureLod(sampler s, vec2|vec3 P, float lod)', returnType: 'vec4', description: 'Samples the texture at coordinate P from an explicit level of detail.', category: _g),
  MatFunctionInfo(name: 'textureSize', signature: 'ivec2 textureSize(sampler s, int lod)', returnType: 'ivec2', description: 'The dimensions of level lod of the texture.', category: _g),
  MatFunctionInfo(name: 'texelFetch', signature: 'vec4 texelFetch(sampler s, ivec2 P, int lod)', returnType: 'vec4', description: 'Reads one texel at integer coordinate P of level lod, without filtering.', category: _g),
  // Interpolation and clamping.
  MatFunctionInfo(name: 'mix', signature: 'genType mix(genType x, genType y, genType|float a)', returnType: 'genType', description: 'Linear blend of x and y: x * (1 - a) + y * a.', category: _g),
  MatFunctionInfo(name: 'clamp', signature: 'genType clamp(genType x, genType|float minVal, genType|float maxVal)', returnType: 'genType', description: 'min(max(x, minVal), maxVal).', category: _g),
  MatFunctionInfo(name: 'step', signature: 'genType step(genType|float edge, genType x)', returnType: 'genType', description: '0.0 where x < edge, otherwise 1.0.', category: _g),
  MatFunctionInfo(name: 'smoothstep', signature: 'genType smoothstep(genType|float edge0, genType|float edge1, genType x)', returnType: 'genType', description: 'Smooth Hermite interpolation between 0 and 1 as x goes from edge0 to edge1.', category: _g),
  MatFunctionInfo(name: 'min', signature: 'genType min(genType x, genType|float y)', returnType: 'genType', description: 'The smaller of x and y.', category: _g),
  MatFunctionInfo(name: 'max', signature: 'genType max(genType x, genType|float y)', returnType: 'genType', description: 'The larger of x and y.', category: _g),
  MatFunctionInfo(name: 'abs', signature: 'genType abs(genType x)', returnType: 'genType', description: 'The absolute value of x.', category: _g),
  MatFunctionInfo(name: 'sign', signature: 'genType sign(genType x)', returnType: 'genType', description: '1.0 when x > 0, 0.0 when x = 0, -1.0 when x < 0.', category: _g),
  MatFunctionInfo(name: 'floor', signature: 'genType floor(genType x)', returnType: 'genType', description: 'The nearest integer less than or equal to x.', category: _g),
  MatFunctionInfo(name: 'ceil', signature: 'genType ceil(genType x)', returnType: 'genType', description: 'The nearest integer greater than or equal to x.', category: _g),
  MatFunctionInfo(name: 'fract', signature: 'genType fract(genType x)', returnType: 'genType', description: 'x - floor(x).', category: _g),
  MatFunctionInfo(name: 'mod', signature: 'genType mod(genType x, genType|float y)', returnType: 'genType', description: 'x modulo y: x - y * floor(x / y).', category: _g),
  // Exponential.
  MatFunctionInfo(name: 'pow', signature: 'genType pow(genType x, genType y)', returnType: 'genType', description: 'x raised to the power y.', category: _g),
  MatFunctionInfo(name: 'exp', signature: 'genType exp(genType x)', returnType: 'genType', description: 'The natural exponentiation of x, e^x.', category: _g),
  MatFunctionInfo(name: 'exp2', signature: 'genType exp2(genType x)', returnType: 'genType', description: '2 raised to the power x.', category: _g),
  MatFunctionInfo(name: 'log', signature: 'genType log(genType x)', returnType: 'genType', description: 'The natural logarithm of x.', category: _g),
  MatFunctionInfo(name: 'log2', signature: 'genType log2(genType x)', returnType: 'genType', description: 'The base 2 logarithm of x.', category: _g),
  MatFunctionInfo(name: 'sqrt', signature: 'genType sqrt(genType x)', returnType: 'genType', description: 'The square root of x.', category: _g),
  MatFunctionInfo(name: 'inversesqrt', signature: 'genType inversesqrt(genType x)', returnType: 'genType', description: '1 / sqrt(x).', category: _g),
  // Geometric.
  MatFunctionInfo(name: 'length', signature: 'float length(genType x)', returnType: 'float', description: 'The length of vector x.', category: _g),
  MatFunctionInfo(name: 'distance', signature: 'float distance(genType p0, genType p1)', returnType: 'float', description: 'The distance between p0 and p1: length(p0 - p1).', category: _g),
  MatFunctionInfo(name: 'dot', signature: 'float dot(genType x, genType y)', returnType: 'float', description: 'The dot product of x and y.', category: _g),
  MatFunctionInfo(name: 'cross', signature: 'vec3 cross(vec3 x, vec3 y)', returnType: 'vec3', description: 'The cross product of x and y.', category: _g),
  MatFunctionInfo(name: 'normalize', signature: 'genType normalize(genType x)', returnType: 'genType', description: 'A vector in the same direction as x with a length of 1.', category: _g),
  MatFunctionInfo(name: 'reflect', signature: 'genType reflect(genType I, genType N)', returnType: 'genType', description: 'The reflection direction of incident vector I about normal N.', category: _g),
  MatFunctionInfo(name: 'refract', signature: 'genType refract(genType I, genType N, float eta)', returnType: 'genType', description: 'The refraction vector of incident vector I through normal N with ratio of indices of refraction eta.', category: _g),
  // Trigonometry.
  MatFunctionInfo(name: 'radians', signature: 'genType radians(genType degrees)', returnType: 'genType', description: 'Converts degrees to radians.', category: _g),
  MatFunctionInfo(name: 'degrees', signature: 'genType degrees(genType radians)', returnType: 'genType', description: 'Converts radians to degrees.', category: _g),
  MatFunctionInfo(name: 'sin', signature: 'genType sin(genType angle)', returnType: 'genType', description: 'The sine of angle, in radians.', category: _g),
  MatFunctionInfo(name: 'cos', signature: 'genType cos(genType angle)', returnType: 'genType', description: 'The cosine of angle, in radians.', category: _g),
  MatFunctionInfo(name: 'tan', signature: 'genType tan(genType angle)', returnType: 'genType', description: 'The tangent of angle, in radians.', category: _g),
  MatFunctionInfo(name: 'asin', signature: 'genType asin(genType x)', returnType: 'genType', description: 'The arc sine of x, in radians.', category: _g),
  MatFunctionInfo(name: 'acos', signature: 'genType acos(genType x)', returnType: 'genType', description: 'The arc cosine of x, in radians.', category: _g),
  MatFunctionInfo(name: 'atan', signature: 'genType atan(genType y [, genType x])', returnType: 'genType', description: 'The arc tangent of y / x (or of y alone), in radians.', category: _g),
  // Derivatives (fragment only).
  MatFunctionInfo(name: 'dFdx', signature: 'genType dFdx(genType p)', returnType: 'genType', stage: MatStage.fragment, description: 'The derivative of p in x, in screen space.', category: _g),
  MatFunctionInfo(name: 'dFdy', signature: 'genType dFdy(genType p)', returnType: 'genType', stage: MatStage.fragment, description: 'The derivative of p in y, in screen space.', category: _g),
  MatFunctionInfo(name: 'fwidth', signature: 'genType fwidth(genType p)', returnType: 'genType', stage: MatStage.fragment, description: 'abs(dFdx(p)) + abs(dFdy(p)).', category: _g),
  // Vector relational.
  MatFunctionInfo(name: 'any', signature: 'bool any(bvec x)', returnType: 'bool', description: 'True when any component of x is true.', category: _g),
  MatFunctionInfo(name: 'all', signature: 'bool all(bvec x)', returnType: 'bool', description: 'True when every component of x is true.', category: _g),
  MatFunctionInfo(name: 'not', signature: 'bvec not(bvec x)', returnType: 'bvec', description: 'The component-wise logical complement of x.', category: _g),
  // Matrices.
  MatFunctionInfo(name: 'transpose', signature: 'mat transpose(mat m)', returnType: 'mat', description: 'The transpose of m.', category: _g),
  MatFunctionInfo(name: 'inverse', signature: 'mat inverse(mat m)', returnType: 'mat', description: 'The inverse of m.', category: _g),
  MatFunctionInfo(name: 'determinant', signature: 'float determinant(mat m)', returnType: 'float', description: 'The determinant of m.', category: _g),
  // Constructors.
  MatFunctionInfo(name: 'vec2', signature: 'vec2 vec2(float x [, float y])', returnType: 'vec2', description: 'Constructs a 2-component float vector.', category: _g),
  MatFunctionInfo(name: 'vec3', signature: 'vec3 vec3(float x [, float y, float z])', returnType: 'vec3', description: 'Constructs a 3-component float vector (also from a vec2 and a float).', category: _g),
  MatFunctionInfo(name: 'vec4', signature: 'vec4 vec4(float x [, float y, float z, float w])', returnType: 'vec4', description: 'Constructs a 4-component float vector (also from a vec3 and a float).', category: _g),
  MatFunctionInfo(name: 'ivec2', signature: 'ivec2 ivec2(int x [, int y])', returnType: 'ivec2', description: 'Constructs a 2-component integer vector.', category: _g),
  MatFunctionInfo(name: 'ivec3', signature: 'ivec3 ivec3(int x [, int y, int z])', returnType: 'ivec3', description: 'Constructs a 3-component integer vector.', category: _g),
  MatFunctionInfo(name: 'ivec4', signature: 'ivec4 ivec4(int x [, int y, int z, int w])', returnType: 'ivec4', description: 'Constructs a 4-component integer vector.', category: _g),
  MatFunctionInfo(name: 'mat3', signature: 'mat3 mat3(float diagonal | vec3 c0, vec3 c1, vec3 c2 | mat4 m)', returnType: 'mat3', description: 'Constructs a 3x3 float matrix from a diagonal value, three columns or the upper-left of a mat4.', category: _g),
  MatFunctionInfo(name: 'mat4', signature: 'mat4 mat4(float diagonal | vec4 c0, vec4 c1, vec4 c2, vec4 c3)', returnType: 'mat4', description: 'Constructs a 4x4 float matrix from a diagonal value or four columns.', category: _g),
  MatFunctionInfo(name: 'float', signature: 'float float(int|uint|bool x)', returnType: 'float', description: 'Converts x to a float.', category: _g),
  MatFunctionInfo(name: 'int', signature: 'int int(float|uint|bool x)', returnType: 'int', description: 'Converts x to an int (truncates a float).', category: _g),
];

/// The GLSL ES 3.0 types.
const List<MatTypeInfo> glslTypes = [
  MatTypeInfo('void', 'void', 'No value.'),
  MatTypeInfo('bool', 'bool', 'A boolean.'),
  MatTypeInfo('int', 'int', 'A signed 32-bit integer.'),
  MatTypeInfo('uint', 'uint', 'An unsigned 32-bit integer.'),
  MatTypeInfo('float', 'float', 'A single-precision float.'),
  MatTypeInfo('vec2', 'vec2', 'A vector of 2 floats.'),
  MatTypeInfo('vec3', 'vec3', 'A vector of 3 floats.'),
  MatTypeInfo('vec4', 'vec4', 'A vector of 4 floats.'),
  MatTypeInfo('ivec2', 'ivec2', 'A vector of 2 integers.'),
  MatTypeInfo('ivec3', 'ivec3', 'A vector of 3 integers.'),
  MatTypeInfo('ivec4', 'ivec4', 'A vector of 4 integers.'),
  MatTypeInfo('uvec2', 'uvec2', 'A vector of 2 unsigned integers.'),
  MatTypeInfo('uvec3', 'uvec3', 'A vector of 3 unsigned integers.'),
  MatTypeInfo('uvec4', 'uvec4', 'A vector of 4 unsigned integers.'),
  MatTypeInfo('bvec2', 'bvec2', 'A vector of 2 booleans.'),
  MatTypeInfo('bvec3', 'bvec3', 'A vector of 3 booleans.'),
  MatTypeInfo('bvec4', 'bvec4', 'A vector of 4 booleans.'),
  MatTypeInfo('mat2', 'mat2', 'A 2x2 float matrix.'),
  MatTypeInfo('mat3', 'mat3', 'A 3x3 float matrix.'),
  MatTypeInfo('mat4', 'mat4', 'A 4x4 float matrix.'),
  MatTypeInfo('sampler2D', 'sampler2D', 'A 2D texture sampler.'),
  MatTypeInfo('sampler2DArray', 'sampler2DArray', 'A 2D array texture sampler.'),
  MatTypeInfo('sampler3D', 'sampler3D', 'A 3D texture sampler.'),
  MatTypeInfo('samplerCube', 'samplerCube', 'A cubemap texture sampler.'),
  MatTypeInfo('MaterialInputs', 'struct', 'The fragment block\'s material properties (the material() argument).'),
  MatTypeInfo('MaterialVertexInputs', 'struct', 'The vertex block\'s material properties (the materialVertex() argument).'),
];

/// The GLSL ES 3.0 keywords and qualifiers.
const List<String> glslKeywords = [
  'if', 'else', 'for', 'while', 'do', 'switch', 'case', 'default', 'break', 'continue', 'return', //
  'const', 'in', 'out', 'inout', 'struct', 'true', 'false', 'highp', 'mediump', 'lowp', 'precision',
  'flat', 'smooth', 'invariant',
];

/// Keywords valid only in the fragment block.
const List<String> glslFragmentKeywords = ['discard'];
