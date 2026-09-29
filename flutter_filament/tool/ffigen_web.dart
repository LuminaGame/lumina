// Generates the web variants of flutter_filament's FFI surface:
//
//   lib/src/third_party/filament_c.g.dart  →  lib/src/third_party/filament_c.web.g.dart
//   lib/src/math_types.dart                →  lib/src/math_types.web.g.dart
//
// The input is the ffigen output itself (and the hand-written math structs),
// so the web bindings cannot drift from the native ones:
//   * every `@ffi.Native` external becomes a Dart function calling the same
//     `_filament_*` export of the WebAssembly module (tool/web/build_module.sh);
//   * every `ffi.Struct` / `ffi.Union` external field becomes an accessor over
//     the module's memory, at the offset the wasm32 C ABI puts it;
//   * `NativeCallable<T>` types and `Native.addressOf` targets used anywhere in
//     lib/ are registered, so callbacks and finalizers work on the web.
//
// Run after `dart run tool/ffigen.dart`:   dart run tool/ffigen_web.dart
import 'dart:io';

const _bindings = 'lib/src/third_party/filament_c.g.dart';
const _bindingsWeb = 'lib/src/third_party/filament_c.web.g.dart';
const _math = 'lib/src/math_types.dart';
const _mathWeb = 'lib/src/math_types.web.g.dart';

void main() {
  final bindings = File(_bindings).readAsStringSync();
  final math = File(_math).readAsStringSync();
  final typedefs = _typedefs(bindings);
  _aliases = typedefs;

  final layouts = _LayoutTable();
  final bindingsOut = _Transformer(
    source: bindings,
    layouts: layouts,
    ffiImport: "import '../web_ffi/ffi.dart' as ffi;",
    moduleImport: "import '../web_ffi/module.dart';",
    registerName: r'$registerFilamentBindings',
  );
  final mathOut = _Transformer(
    source: math,
    layouts: layouts,
    ffiImport: "import 'web_ffi/ffi.dart' as ffi;",
    moduleImport: "import 'web_ffi/module.dart';",
    registerName: r'$registerMathTypes',
  );
  // Struct layouts first: fields may name structs declared later.
  bindingsOut.collectStructs();
  mathOut.collectStructs();

  final callbacks = _callbackTypes(typedefs);
  final addresses = _nativeAddressTargets();

  File(_bindingsWeb).writeAsStringSync(bindingsOut.render(
    functions: true,
    callbacks: callbacks,
    nativeAddresses: addresses,
  ));
  File(_mathWeb).writeAsStringSync(mathOut.render(functions: false, callbacks: const [], nativeAddresses: const {}));
  stdout.writeln('${bindingsOut.functionCount} functions, ${bindingsOut.structCount + mathOut.structCount} structs, '
      '${callbacks.length} callback types, ${addresses.length} native addresses -> $_bindingsWeb, $_mathWeb');
}

// --- small parsing helpers ------------------------------------------------------

/// Splits [s] at top-level commas (ignoring <>, (), [] nesting).
List<String> _splitTopLevel(String s) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c == '<' || c == '(' || c == '[') depth++;
    if (c == '>' || c == ')' || c == ']') depth--;
    if (c == ',' && depth == 0) {
      parts.add(s.substring(start, i).trim());
      start = i + 1;
    }
  }
  final last = s.substring(start).trim();
  if (last.isNotEmpty) parts.add(last);
  return parts.where((p) => p.isNotEmpty).toList();
}

/// Index of the bracket closing the one at [open].
int _matching(String s, int open) {
  final o = s[open];
  final c = switch (o) { '(' => ')', '<' => '>', '{' => '}', '[' => ']', _ => throw ArgumentError(o) };
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == o) depth++;
    if (s[i] == c) {
      depth--;
      if (depth == 0) return i;
    }
  }
  throw StateError('unbalanced $o at $open');
}

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// `(RETURN, [PARAMS])` of a native function type `R Function(P1 a, P2 b)`.
(String, List<String>) _nativeFunctionType(String type) {
  final t = _squash(type);
  final fn = t.indexOf(' Function(');
  if (fn < 0) throw StateError('not a function type: $t');
  final ret = t.substring(0, fn).trim();
  final open = t.indexOf('(', fn);
  final params = _splitTopLevel(t.substring(open + 1, _matching(t, open)))
      // Typedefs may name parameters: `ffi.Uint32 renderable`.
      .map((p) => p.contains('>') ? p.substring(0, p.lastIndexOf('>') + 1) : p.split(' ').first)
      .toList();
  return (ret, params);
}

/// Typedefs of the bindings file, so aliases like `FilamentPickCallback`
/// (a function pointer) classify as what they stand for.
Map<String, String> _aliases = const {};

/// Boundary kind of a native type (see `$CallbackSignature` in web_ffi/ffi.dart).
String _kind(String nativeType) {
  var t = nativeType.replaceAll(' ', '');
  for (var i = 0; i < 4 && _aliases.containsKey(t); i++) {
    t = _aliases[t]!.replaceAll(' ', '');
  }
  if (t.startsWith('ffi.Pointer')) return 'p';
  return switch (t) {
    'ffi.Void' => 'v',
    'ffi.Bool' => 'b',
    'ffi.Float' => 'f',
    'ffi.Double' => 'd',
    'ffi.Int64' || 'ffi.Uint64' || 'ffi.LongLong' || 'ffi.UnsignedLongLong' => 'j',
    'ffi.Uint32' || 'ffi.UnsignedInt' || 'ffi.Size' || 'ffi.UintPtr' => 'u',
    'ffi.Uint8' => 'u8',
    'ffi.Uint16' => 'u16',
    _ => 'i',
  };
}

Map<String, String> _typedefs(String bindings) {
  final out = <String, String>{};
  for (final m in RegExp(r'typedef (\w+) =([\s\S]*?);').allMatches(bindings)) {
    out[m.group(1)!] = _squash(m.group(2)!);
  }
  return out;
}

// --- struct layouts (wasm32) ------------------------------------------------------

class _Field {
  final String annotation; // e.g. '@ffi.Uint32()' or '@ffi.Array.multi([2])' or ''
  final String type; // Dart type as written
  final String name;
  int offset = 0;
  _Field(this.annotation, this.type, this.name);
}

class _Struct {
  final String name;
  final bool isUnion;
  final List<_Field> fields;
  int size = -1;
  int alignment = 1;
  _Struct(this.name, this.isUnion, this.fields);
}

class _LayoutTable {
  final Map<String, _Struct> structs = {};

  (int, int) sizeAlign(_Field f) {
    final ann = f.annotation.replaceAll(' ', '');
    if (f.type.startsWith('ffi.Pointer')) return (4, 4);
    if (f.type.startsWith('ffi.Array')) {
      final elem = f.type.substring(f.type.indexOf('<') + 1, f.type.lastIndexOf('>')).trim();
      final (es, ea) = _primitive(elem) ?? (elem.startsWith('ffi.Pointer') ? (4, 4) : structLayout(elem.replaceAll('ffi.', '')));
      final dims = RegExp(r'\d+').allMatches(ann.replaceFirst('@ffi.Array', '')).map((m) => int.parse(m.group(0)!));
      final count = dims.fold<int>(1, (a, b) => a * b);
      return (es * count, ea);
    }
    if (ann.isNotEmpty) {
      final native = ann.substring(1, ann.indexOf('('));
      final p = _primitive(native);
      if (p != null) return p;
    }
    return structLayout(f.type);
  }

  (int, int)? _primitive(String native) => switch (native.replaceAll(' ', '')) {
        'ffi.Bool' || 'ffi.Int8' || 'ffi.Uint8' || 'ffi.Char' => (1, 1),
        'ffi.Int16' || 'ffi.Uint16' => (2, 2),
        'ffi.Int32' || 'ffi.Uint32' || 'ffi.Int' || 'ffi.UnsignedInt' || 'ffi.Size' || 'ffi.IntPtr' ||
        'ffi.UintPtr' || 'ffi.Float' || 'ffi.Long' || 'ffi.UnsignedLong' =>
          (4, 4),
        'ffi.Int64' || 'ffi.Uint64' || 'ffi.Double' || 'ffi.LongLong' || 'ffi.UnsignedLongLong' => (8, 8),
        _ => null,
      };

  (int, int) structLayout(String name) {
    final s = structs[name] ?? (throw StateError('unknown struct type $name'));
    if (s.size < 0) {
      var offset = 0;
      var maxAlign = 1;
      var maxSize = 0;
      for (final f in s.fields) {
        final (size, align) = sizeAlign(f);
        if (align > maxAlign) maxAlign = align;
        if (s.isUnion) {
          f.offset = 0;
          if (size > maxSize) maxSize = size;
        } else {
          offset = (offset + align - 1) ~/ align * align;
          f.offset = offset;
          offset += size;
        }
      }
      final end = s.isUnion ? maxSize : offset;
      s.alignment = maxAlign;
      s.size = end == 0 ? 0 : (end + maxAlign - 1) ~/ maxAlign * maxAlign;
    }
    return (s.size, s.alignment);
  }
}

// --- the transformer ----------------------------------------------------------------

class _Transformer {
  final String source;
  final _LayoutTable layouts;
  final String ffiImport;
  final String moduleImport;
  final String registerName;
  final List<_Struct> _own = [];
  int functionCount = 0;
  int get structCount => _own.length;

  _Transformer({
    required this.source,
    required this.layouts,
    required this.ffiImport,
    required this.moduleImport,
    required this.registerName,
  });

  static final _classHead = RegExp(r'final class (\w+) extends ffi\.(Struct|Union) \{');
  static final _field = RegExp(r'((?:@ffi\.[\w.]+\([^)]*\)\s*)?)external\s+([\w.<>, ]+?)\s+(\w+);');

  void collectStructs() {
    for (final m in _classHead.allMatches(source)) {
      final open = source.indexOf('{', m.start);
      final body = source.substring(open + 1, _matching(source, open));
      final fields = [
        for (final f in _field.allMatches(body)) _Field(_squash(f.group(1)!), _squash(f.group(2)!), f.group(3)!),
      ];
      final s = _Struct(m.group(1)!, m.group(2) == 'Union', fields);
      layouts.structs[s.name] = s;
      _own.add(s);
    }
  }

  String render({
    required bool functions,
    required List<(String, String)> callbacks,
    required Map<String, String> nativeAddresses,
  }) {
    for (final s in _own) {
      layouts.structLayout(s.name);
    }
    var out = source;

    // Structs / unions: accessors instead of external fields, plus a view ctor.
    for (final s in _own.reversed) {
      final head = RegExp('final class ${s.name} extends ffi\\.(Struct|Union) \\{').firstMatch(out)!;
      final open = out.indexOf('{', head.start);
      final close = _matching(out, open);
      var body = out.substring(open + 1, close);
      body = body.replaceAllMapped(_field, (m) {
        final f = s.fields.firstWhere((f) => f.name == m.group(3));
        return _accessor(f);
      });
      body = '\n  ${s.name}.\$at(super.\$address) : super.\$at();\n$body';
      out = out.substring(0, open + 1) + body + out.substring(close);
    }

    final externs = StringBuffer();
    if (functions) {
      final native = RegExp(r'@ffi\.Native<([\s\S]*?)>\(([^)]*)\)\s*external\s+([\s\S]*?)\s+(\w+)\s*\(([\s\S]*?)\);');
      out = out.replaceAllMapped(native, (m) {
        functionCount++;
        final (nativeRet, nativeParams) = _nativeFunctionType(m.group(1)!);
        final dartRet = _squash(m.group(3)!);
        final name = m.group(4)!;
        final dartParams = _splitTopLevel(m.group(5)!);
        if (dartParams.length != nativeParams.length) throw StateError('$name: parameter mismatch');
        final names = [for (final p in dartParams) p.split(' ').last];
        final kinds = [for (final p in nativeParams) _kind(p)];
        final retKind = _kind(nativeRet);

        final jsParams = [for (var i = 0; i < kinds.length; i++) '${kinds[i] == 'j' ? 'JSBigInt' : 'JSNumber'} ${names[i]}'];
        final jsRet = switch (retKind) { 'v' => 'void', 'j' => 'JSBigInt', _ => 'JSNumber' };
        externs.writeln("  @JS('_$name')");
        externs.writeln('  external $jsRet $name(${jsParams.join(', ')});');

        final args = [
          for (var i = 0; i < kinds.length; i++)
            switch (kinds[i]) {
              'p' => '${names[i]}.address.toJS',
              'b' => '(${names[i]} ? 1 : 0).toJS',
              'j' => 'FlutterFilamentModule.toBigInt(${names[i]})',
              _ => '${names[i]}.toJS',
            },
        ].join(', ');
        final call = '_m.$name($args)';
        final body = switch (retKind) {
          'v' => '{\n  $call;\n}',
          'p' => '=>\n    $dartRet.fromAddress($call.toDartInt);',
          'b' => '=>\n    $call.toDartInt != 0;',
          'f' || 'd' => '=>\n    $call.toDartDouble;',
          'j' => '=>\n    FlutterFilamentModule.fromBigInt($call);',
          'u' => '=>\n    $call.toDartInt.toUnsigned(32);',
          'u8' => '=>\n    $call.toDartInt.toUnsigned(8);',
          'u16' => '=>\n    $call.toDartInt.toUnsigned(16);',
          _ => '=>\n    $call.toDartInt;',
        };
        return '$dartRet $name(${dartParams.join(', ')}) $body';
      });
    }

    // Imports: the web ffi layer instead of dart:ffi.
    out = out.replaceFirst(RegExp(r"import '(?:dart:ffi|(?:\.\./)*ffi_platform\.dart)' as ffi;"), [
      "import 'dart:js_interop';",
      if (!out.contains("import 'dart:typed_data';")) "import 'dart:typed_data';",
      '',
      ffiImport,
      moduleImport,
    ].join('\n'));
    out = out.replaceFirst(RegExp(r'^', multiLine: false),
        '// GENERATED by tool/ffigen_web.dart from ${functions ? _bindings : _math} — do not edit.\n'
        '// ignore_for_file: type=lint, unused_import, unused_element\n');

    final buf = StringBuffer(out);
    if (functions) {
      buf
        ..writeln()
        ..writeln('// --- the module\'s exports (web) ---------------------------------------------')
        ..writeln('extension type _Module._(JSObject _) implements JSObject {')
        ..write(externs)
        ..writeln('}')
        ..writeln()
        ..writeln('_Module get _m => _Module._(FlutterFilamentModule.instance);');
    }
    buf
      ..writeln()
      ..writeln('/// Registers this file\'s struct layouts${functions ? ', callback types and native addresses' : ''} with the web ffi layer.')
      ..writeln('void $registerName() {');
    for (final s in _own) {
      buf.writeln('  ffi.\$registerStruct<${s.name}>(${s.size}, ${s.alignment}, ${s.name}.\$at);');
    }
    for (final (type, sig) in callbacks) {
      buf.writeln('  ffi.\$registerCallbackType<$type>($sig);');
    }
    for (final e in nativeAddresses.entries) {
      buf.writeln("  ffi.\$registerNativeAddress(${e.key}, '_${e.key}', '${e.value}');");
    }
    buf.writeln('}');
    return buf.toString();
  }

  String _accessor(_Field f) {
    final off = f.offset;
    final at = off == 0 ? r'$address' : '\$address + $off';
    final ann = f.annotation.replaceAll(' ', '');
    const le = 'Endian.little';
    String getSet(String type, String getter, String setter) =>
        '$type get ${f.name} => $getter;\n  set ${f.name}($type value) => $setter;';
    if (f.type.startsWith('ffi.Pointer')) {
      return getSet(f.type, '${f.type}.fromAddress(FlutterFilamentModule.heap.getUint32($at, $le))',
          'FlutterFilamentModule.heap.setUint32($at, value.address, $le)');
    }
    if (f.type.startsWith('ffi.Array')) {
      final dims = RegExp(r'\d+').allMatches(ann.replaceFirst('@ffi.Array', '')).map((m) => int.parse(m.group(0)!));
      final count = dims.fold<int>(1, (a, b) => a * b);
      return '${f.type} get ${f.name} => ${f.type}.\$view($at, $count);';
    }
    if (ann.isEmpty) {
      final (size, _) = layouts.structLayout(f.type);
      return '${f.type} get ${f.name} => ${f.type}.\$at($at);\n'
          '  set ${f.name}(${f.type} value) => ffi.\$copyStruct(value.\$address, $at, $size);';
    }
    final native = ann.substring(1, ann.indexOf('('));
    final h = 'FlutterFilamentModule.heap';
    return switch (native) {
      'ffi.Bool' => getSet('bool', '$h.getUint8($at) != 0', '$h.setUint8($at, value ? 1 : 0)'),
      'ffi.Int8' || 'ffi.Char' => getSet('int', '$h.getInt8($at)', '$h.setInt8($at, value)'),
      'ffi.Uint8' => getSet('int', '$h.getUint8($at)', '$h.setUint8($at, value)'),
      'ffi.Int16' => getSet('int', '$h.getInt16($at, $le)', '$h.setInt16($at, value, $le)'),
      'ffi.Uint16' => getSet('int', '$h.getUint16($at, $le)', '$h.setUint16($at, value, $le)'),
      'ffi.Int32' || 'ffi.Int' || 'ffi.IntPtr' || 'ffi.Long' =>
        getSet('int', '$h.getInt32($at, $le)', '$h.setInt32($at, value, $le)'),
      'ffi.Uint32' || 'ffi.UnsignedInt' || 'ffi.Size' || 'ffi.UintPtr' || 'ffi.UnsignedLong' =>
        getSet('int', '$h.getUint32($at, $le)', '$h.setUint32($at, value, $le)'),
      'ffi.Int64' || 'ffi.Uint64' || 'ffi.LongLong' || 'ffi.UnsignedLongLong' =>
        getSet('int', 'ffi.\$readInt64($at)', 'ffi.\$writeInt64($at, value)'),
      'ffi.Float' => getSet('double', '$h.getFloat32($at, $le)', '$h.setFloat32($at, value, $le)'),
      'ffi.Double' => getSet('double', '$h.getFloat64($at, $le)', '$h.setFloat64($at, value, $le)'),
      _ => throw StateError('unhandled field annotation $ann on ${f.name}'),
    };
  }
}

// --- callbacks and native addresses used by the hand-written wrappers ------------------

Iterable<File> _handWritten() => Directory('lib/src')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart') && !f.path.contains('third_party') && !f.path.contains('web_ffi') && !f.path.endsWith('.g.dart'));

String _stripPrefixes(String type) => type.replaceAll(RegExp(r'\b(c|ffi_gen|ffi_bind)\.'), '');

/// `(Dart type text, $CallbackSignature constructor)` for every callback type.
List<(String, String)> _callbackTypes(Map<String, String> typedefs) {
  final types = <String>{};
  for (final name in typedefs.keys) {
    final def = typedefs[name]!;
    if (def.contains(' Function(') && def.startsWith('ffi.')) types.add(name);
  }
  for (final f in _handWritten()) {
    final src = f.readAsStringSync();
    for (final m in RegExp(r'NativeCallable<').allMatches(src)) {
      final open = m.end - 1;
      final type = _squash(src.substring(open + 1, _matching(src, open)));
      if (type == 'T') continue;
      types.add(_stripPrefixes(type));
    }
  }
  final out = <(String, String)>[];
  for (final type in types) {
    final resolved = typedefs[type] ?? type;
    if (!resolved.contains(' Function(')) continue;
    final (ret, params) = _nativeFunctionType(resolved);
    String k(String t) => switch (_kind(t)) { 'u8' || 'u16' => 'u', final x => x };
    final sig = "const ffi.\$CallbackSignature('${k(ret)}', [${params.map((p) => "'${k(p)}'").join(', ')}])";
    out.add((type, sig));
  }
  return out;
}

/// `binding → wasm signature` for every `ffi.Native.addressOf<…>(c.binding)`.
Map<String, String> _nativeAddressTargets() {
  final bindings = File(_bindings).readAsStringSync();
  final out = <String, String>{};
  for (final f in _handWritten()) {
    final src = f.readAsStringSync();
    for (final m in RegExp(r'Native\.addressOf<[\s\S]*?>\(\s*(?:\w+\.)?(\w+)\s*,?\s*\)').allMatches(src)) {
      final name = m.group(1)!;
      final decl = RegExp('@ffi\\.Native<([\\s\\S]*?)>\\([^)]*\\)\\s*external\\s+[\\s\\S]*?\\s+$name\\s*\\(').firstMatch(bindings);
      if (decl == null) throw StateError('Native.addressOf target $name is not a binding');
      final (ret, params) = _nativeFunctionType(decl.group(1)!);
      String w(String t) => switch (_kind(t)) { 'v' => 'v', 'f' => 'f', 'd' => 'd', 'j' => 'j', _ => 'i' };
      out[name] = w(ret) + params.map(w).join();
    }
  }
  return out;
}
