part of '../material_graph_parser.dart';

class _Unsupported implements Exception {
  final String reason;
  _Unsupported(this.reason);
  @override
  String toString() => reason;
}

// ---------------------------------------------------------------------------
// Tokens and syntax
// ---------------------------------------------------------------------------

class _Tok {
  final String text;
  final bool isIdent;
  final bool isNumber;
  const _Tok(this.text, {this.isIdent = false, this.isNumber = false});
  @override
  String toString() => text;
}

List<_Tok> _lex(String s) {
  final out = <_Tok>[];
  var i = 0;
  const two = ['+=', '-=', '*=', '/=', '==', '!=', '<=', '>=', '&&', '||', '++', '--'];
  while (i < s.length) {
    final c = s[i];
    if (c.trim().isEmpty) {
      i++;
      continue;
    }
    if (c == '/' && i + 1 < s.length && s[i + 1] == '/') {
      final end = s.indexOf('\n', i);
      i = end < 0 ? s.length : end + 1;
      continue;
    }
    if (c == '/' && i + 1 < s.length && s[i + 1] == '*') {
      final end = s.indexOf('*/', i + 2);
      i = end < 0 ? s.length : end + 2;
      continue;
    }
    final ident = RegExp(r'[A-Za-z_][A-Za-z0-9_]*').matchAsPrefix(s, i);
    if (ident != null) {
      out.add(_Tok(ident.group(0)!, isIdent: true));
      i = ident.end;
      continue;
    }
    final number = RegExp(r'(\d+\.\d*|\.\d+|\d+)([eE][-+]?\d+)?[fF]?').matchAsPrefix(s, i);
    if (number != null) {
      out.add(_Tok(number.group(0)!.replaceAll(RegExp(r'[fF]$'), ''), isNumber: true));
      i = number.end;
      continue;
    }
    if (i + 1 < s.length && two.contains(s.substring(i, i + 2))) {
      out.add(_Tok(s.substring(i, i + 2)));
      i += 2;
      continue;
    }
    out.add(_Tok(c));
    i++;
  }
  return out;
}

sealed class _E {}

class _Num extends _E {
  final double value;
  _Num(this.value);
}

class _Id extends _E {
  final String name;
  _Id(this.name);
}

class _Call extends _E {
  final String callee;
  final List<_E> args;
  _Call(this.callee, this.args);
}

class _Mem extends _E {
  final _E target;
  final String name;
  _Mem(this.target, this.name);
}

class _Bin extends _E {
  final String op;
  final _E a;
  final _E b;
  _Bin(this.op, this.a, this.b);
}

class _Neg extends _E {
  final _E e;
  _Neg(this.e);
}

/// `!e`.
class _Not extends _E {
  final _E e;
  _Not(this.e);
}

/// `c ? t : f`.
class _Cond extends _E {
  final _E c;
  final _E t;
  final _E f;
  _Cond(this.c, this.t, this.f);
}

/// The comparison and logic operators a [_Bin] can carry besides arithmetic.
const _logicOps = {'>', '>=', '<', '<=', '==', '!=', '&&', '||'};

class _Parser {
  final List<_Tok> t;
  int i = 0;
  _Parser(this.t);

  bool get done => i >= t.length;
  String get peek => done ? '' : t[i].text;
  _Tok next() {
    if (done) throw _Unsupported('unexpected end of the fragment');
    return t[i++];
  }

  void expect(String s) {
    final tok = next();
    if (tok.text != s) throw _Unsupported("expected '$s', found '${tok.text}'");
  }

  /// An expression, GLSL precedence from the lowest: `?:` (right
  /// associative), `||`, `&&`, `==` `!=`, `<` `>` `<=` `>=`, `+` `-`, `*` `/`,
  /// unary `-` `+` `!`.
  _E expr() {
    final e = _conditional();
    _refuseUnsupportedOperator();
    return e;
  }

  _E _conditional() {
    final c = _binary(0);
    if (peek != '?') return c;
    next();
    final t = expr();
    expect(':');
    return _Cond(c, t, _conditional());
  }

  static const _levels = [
    {'||'},
    {'&&'},
    {'==', '!='},
    {'<', '>', '<=', '>='},
    {'+', '-'},
  ];

  _E _binary(int level) {
    if (level == _levels.length) return _term();
    var left = _binary(level + 1);
    while (_levels[level].contains(peek)) {
      final op = next().text;
      left = _Bin(op, left, _binary(level + 1));
    }
    return left;
  }

  void _refuseUnsupportedOperator() {
    const unsupported = ['%', '++', '--', '^', '^^', '&', '|', '<<', '>>'];
    if (unsupported.contains(peek)) throw _Unsupported("the '$peek' operator has no material node");
  }

  _E _term() {
    var left = _unary();
    while (peek == '*' || peek == '/') {
      final op = next().text;
      left = _Bin(op, left, _unary());
    }
    return left;
  }

  _E _unary() {
    if (peek == '-') {
      next();
      final e = _unary();
      return e is _Num ? _Num(-e.value) : _Neg(e);
    }
    if (peek == '+') {
      next();
      return _unary();
    }
    if (peek == '!') {
      next();
      return _Not(_unary());
    }
    return _postfix();
  }

  _E _postfix() {
    var e = _primary();
    while (peek == '.') {
      next();
      final name = next();
      if (!name.isIdent) throw _Unsupported("expected a member after '.'");
      e = _Mem(e, name.text);
    }
    if (peek == '[') throw _Unsupported('array indexing has no material node');
    return e;
  }

  _E _primary() {
    final tok = next();
    if (tok.isNumber) return _Num(double.parse(tok.text));
    if (tok.text == '(') {
      final e = expr();
      expect(')');
      return e;
    }
    if (tok.isIdent) {
      if (peek == '(') {
        next();
        final args = <_E>[];
        if (peek != ')') {
          args.add(expr());
          while (peek == ',') {
            next();
            args.add(expr());
          }
        }
        expect(')');
        return _Call(tok.text, args);
      }
      return _Id(tok.text);
    }
    throw _Unsupported("unexpected '${tok.text}'");
  }
}
