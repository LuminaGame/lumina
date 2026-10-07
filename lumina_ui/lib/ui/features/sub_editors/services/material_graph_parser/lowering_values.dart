part of '../material_graph_parser.dart';

/// A value during lowering: a node output, or a literal not yet given a node.
class _Val {
  final String? nodeId;
  final String? pinId;
  final List<double>? literal;
  final MaterialValueType type;

  /// `vec3(x)` of a float: the float, which every consumer broadcasts.
  final int? broadcastTo;

  const _Val.node(this.nodeId, this.pinId, this.type, {this.broadcastTo}) : literal = null;
  _Val.lit(List<double> values, {this.broadcastTo})
      : literal = values,
        nodeId = null,
        pinId = null,
        type = MaterialValueType.ofWidth(values.length);

  bool get isLiteral => literal != null;
  bool get isScalarLiteral => literal != null && literal!.length == 1;

  /// Width as a `vecN(...)` argument sees it.
  int get argWidth => broadcastTo ?? type.width;

  _Val withBroadcast(int n) =>
      isLiteral ? _Val.lit(literal!, broadcastTo: n) : _Val.node(nodeId, pinId, type, broadcastTo: n);

  /// Whether [a] and [b] are the same value (the same node output or equal
  /// literals, broadcast alike); null is a local not assigned on that path.
  static bool same(_Val? a, _Val? b) {
    if (a == null || b == null) return a == null && b == null;
    if (a.broadcastTo != b.broadcastTo || a.type != b.type) return false;
    if (a.isLiteral || b.isLiteral) {
      final x = a.literal, y = b.literal;
      if (x == null || y == null || x.length != y.length) return false;
      for (var k = 0; k < x.length; k++) {
        if (x[k] != y[k]) return false;
      }
      return true;
    }
    return a.nodeId == b.nodeId && a.pinId == b.pinId;
  }
}

/// A lowered value handed back to [_Lowering._member] as if it were syntax.
class _ValExpr extends _E {
  final _Val value;
  _ValExpr(this.value);
}
