import 'package:shadcn_flutter/shadcn_flutter.dart';

/// What a stretch of `.mat` source is, for colouring.
enum GlslTokenKind {
  plain,
  comment,
  string,
  number,
  keyword,
  type,
  function,

  /// Filament's material API: `material`, `materialParams_x`, `getUV0`, ...
  builtin,

  /// A key of the `material { }` header (`name`, `shadingModel`, ...) and the
  /// block names (`material`, `vertex`, `fragment`).
  headerKey,
  preprocessor,
  punctuation,
}

/// One coloured run of the source.
class GlslToken {
  final GlslTokenKind kind;
  final int start;
  final int end;
  const GlslToken(this.kind, this.start, this.end);
}

/// Splits Filament `.mat` source (the JSON-like header plus GLSL blocks) into
/// coloured runs. Purely lexical, so it is cheap enough to run on every
/// keystroke and never needs the compiler.
abstract final class GlslSyntaxHighlighter {
  static const Set<String> keywords = {
    'if', 'else', 'for', 'while', 'do', 'return', 'break', 'continue', 'discard', 'switch', 'case', 'default',
    'const', 'in', 'out', 'inout', 'uniform', 'struct', 'highp', 'mediump', 'lowp', 'precision', 'true', 'false',
  };

  static const Set<String> types = {
    'void', 'bool', 'int', 'uint', 'float', 'double',
    'vec2', 'vec3', 'vec4', 'ivec2', 'ivec3', 'ivec4', 'uvec2', 'uvec3', 'uvec4', 'bvec2', 'bvec3', 'bvec4',
    'mat2', 'mat3', 'mat4', 'mat3x3', 'mat4x4', 'sampler2D', 'sampler2DArray', 'samplerCube', 'sampler3D',
    'MaterialInputs', 'MaterialVertexInputs',
    // Header parameter types.
    'sampler2d', 'samplercube', 'float2', 'float3', 'float4', 'int2', 'int3', 'int4',
  };

  static const Set<String> builtins = {
    'material', 'materialParams', 'prepareMaterial', 'getUV0', 'getUV1', 'getColor', 'getCustom0',
    'getWorldPosition', 'getUserWorldPosition', 'getWorldNormalVector', 'getWorldGeometricNormalVector',
    'getWorldTangentFrame', 'getWorldReflectedVector', 'getWorldViewVector', 'getNdotV', 'getResolution',
    'getTime', 'getUserTime', 'getExposure', 'getEV100', 'getNormalizedViewportCoord', 'getPosition',
    'getMaterialGlobal0', 'getViewFromWorldMatrix', 'getWorldFromViewMatrix', 'getClipFromWorldMatrix',
    'getWorldFromModelMatrix', 'getVertexIndex', 'getInstanceIndex', 'inverseTonemapSRGB',
  };

  static const Set<String> headerKeys = {
    'fragment', 'vertex', 'name', 'shadingModel', 'blending', 'requires', 'parameters', 'variables',
    'doubleSided', 'transparency', 'culling', 'flipUV', 'domain', 'type', 'precision', 'default',
    'vertexDomain', 'interpolation', 'quality', 'featureLevel', 'specularAntiAliasing', 'clearCoatIorChange',
    'refractionMode', 'refractionType', 'reflections', 'colorWrite', 'depthWrite', 'depthCulling',
    'maskThreshold', 'postLightingBlending', 'customSurfaceShading', 'multiBounceAmbientOcclusion',
    'specularAmbientOcclusion', 'instanced', 'shadowMultiplier', 'transparentShadow', 'groupSize',
  };

  static final RegExp _lexer = RegExp(
    r'(?<comment>//[^\n]*|/\*[\s\S]*?(?:\*/|$))'
    r'|(?<pre>^[ \t]*#[^\n]*)'
    r'|(?<string>"(?:[^"\\\n]|\\.)*"?)'
    r'|(?<number>\b(?:\d+\.\d*|\.\d+|\d+)(?:[eE][+-]?\d+)?[fFuU]?\b)'
    r'|(?<ident>[A-Za-z_][A-Za-z0-9_]*)'
    r'|(?<punct>[{}()\[\];,.:+\-*/%=<>!&|^?~])',
    multiLine: true,
  );

  /// The coloured runs of [source], in order; uncovered gaps are plain.
  static List<GlslToken> tokenize(String source) {
    final out = <GlslToken>[];
    for (final m in _lexer.allMatches(source)) {
      final GlslTokenKind kind;
      if (m.namedGroup('comment') != null) {
        kind = GlslTokenKind.comment;
      } else if (m.namedGroup('pre') != null) {
        kind = GlslTokenKind.preprocessor;
      } else if (m.namedGroup('string') != null) {
        kind = GlslTokenKind.string;
      } else if (m.namedGroup('number') != null) {
        kind = GlslTokenKind.number;
      } else if (m.namedGroup('punct') != null) {
        kind = GlslTokenKind.punctuation;
      } else {
        kind = _identifier(source, m.start, m.end);
      }
      out.add(GlslToken(kind, m.start, m.end));
    }
    return out;
  }

  static GlslTokenKind _identifier(String source, int start, int end) {
    final word = source.substring(start, end);
    if (word.startsWith('materialParams_')) return GlslTokenKind.builtin;
    if (builtins.contains(word)) return GlslTokenKind.builtin;
    if (keywords.contains(word)) return GlslTokenKind.keyword;
    if (types.contains(word)) return GlslTokenKind.type;
    var i = end;
    while (i < source.length && (source[i] == ' ' || source[i] == '\t')) {
      i++;
    }
    final next = i < source.length ? source[i] : '';
    if (headerKeys.contains(word) && (next == ':' || next == '{')) return GlslTokenKind.headerKey;
    if (next == '(') return GlslTokenKind.function;
    return GlslTokenKind.plain;
  }

  /// The editor palette (dark theme): one colour per kind.
  static const Map<GlslTokenKind, Color> palette = {
    GlslTokenKind.plain: Color(0xFFD4D4D4),
    GlslTokenKind.comment: Color(0xFF6A9955),
    GlslTokenKind.string: Color(0xFFCE9178),
    GlslTokenKind.number: Color(0xFFB5CEA8),
    GlslTokenKind.keyword: Color(0xFFC586C0),
    GlslTokenKind.type: Color(0xFF4EC9B0),
    GlslTokenKind.function: Color(0xFFDCDCAA),
    GlslTokenKind.builtin: Color(0xFF4FC1FF),
    GlslTokenKind.headerKey: Color(0xFF9CDCFE),
    GlslTokenKind.preprocessor: Color(0xFFC586C0),
    GlslTokenKind.punctuation: Color(0xFFB0B0B0),
  };

  /// [source] as coloured spans over [base].
  static TextSpan highlight(String source, TextStyle base) {
    final spans = <TextSpan>[];
    var at = 0;
    for (final t in tokenize(source)) {
      if (t.start > at) spans.add(TextSpan(text: source.substring(at, t.start)));
      spans.add(TextSpan(
        text: source.substring(t.start, t.end),
        style: TextStyle(
          color: palette[t.kind],
          fontStyle: t.kind == GlslTokenKind.comment ? FontStyle.italic : null,
        ),
      ));
      at = t.end;
    }
    if (at < source.length) spans.add(TextSpan(text: source.substring(at)));
    return TextSpan(style: base.copyWith(color: palette[GlslTokenKind.plain]), children: spans);
  }
}

/// A text controller that draws `.mat` source with [GlslSyntaxHighlighter]
/// colours (while an IME composes, it falls back to the plain underline).
class GlslCodeController extends TextEditingController {
  GlslCodeController({super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (withComposing && value.isComposingRangeValid) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    return GlslSyntaxHighlighter.highlight(text, style ?? const TextStyle());
  }
}
