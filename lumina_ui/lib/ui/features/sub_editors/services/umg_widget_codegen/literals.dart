part of '../umg_widget_codegen.dart';

// Element-state reads: the runtime value under [key], with the
// designer's value as the fallback the generated code carries.
String _string_(UmgNode n, String key, String fallback) =>
    "LuminaUmgElementBinding.value<String>(e, ${_str(key)}, ${_str(n.props[key]?.toString() ?? fallback)})";

String _double_(UmgNode n, String key, double fallback) =>
    "LuminaUmgElementBinding.value<double>(e, ${_str(key)}, ${_f(_num(n.props[key], fallback))})";

String _int_(UmgNode n, String key, int fallback) => "LuminaUmgElementBinding.value<int>(e, ${_str(key)}, $fallback)";

String _color_(UmgNode n, String key, String fallback) =>
    "LuminaUmgElementBinding.color(e, ${_str(key)}, ${_color(n.props[key] ?? fallback, fallback)})";

String _padded(UmgNode c, String child) {
  final s = c.slot;
  if (s.paddingLeft == 0 && s.paddingTop == 0 && s.paddingRight == 0 && s.paddingBottom == 0) return child;
  return 'Padding(padding: EdgeInsets.fromLTRB(${_f(s.paddingLeft)}, ${_f(s.paddingTop)}, ${_f(s.paddingRight)}, ${_f(s.paddingBottom)}), child: $child)';
}

double _alignValue(UmgAlign a) {
  switch (a) {
    case UmgAlign.start:
      return -1;
    case UmgAlign.center:
    case UmgAlign.fill:
      return 0;
    case UmgAlign.end:
      return 1;
  }
}

String _alignment(UmgSlot s) => 'Alignment(${_f(_alignValue(s.hAlign))}, ${_f(_alignValue(s.vAlign))})';

/// The element's text style: font size, colour and the
/// drop shadow, each a runtime read over the designer value. With
/// [outlineRing] the outline joins as a ring of sharp shadows (an editable
/// field has no second layer to stroke).
String _textStyle(UmgNode n, {bool outlineRing = false}) {
  final shadows = outlineRing ? '[...${_shadow_(n)}.shadows, ...${_outline_(n)}.ringShadows]' : '${_shadow_(n)}.shadows';
  return 'TextStyle(fontSize: ${_double_(n, 'fontSize', 14)}, color: ${_color_(n, 'color', '#FFFFFF')}, shadows: $shadows)';
}

/// A label of [n]: its text style plus the outline stroked under the fill.
String _text(UmgNode n, String text) => 'LuminaUmgText($text, style: ${_textStyle(n)}, outline: ${_outline_(n)})';

/// The runtime shadow of [n] over its designer shadow.
String _shadow_(UmgNode n) {
  final p = n.props;
  final d = UmgWidgetType.textEffectDefaults;
  return 'LuminaUmgElementBinding.shadow(e, const LuminaUmgTextShadow('
      'enabled: ${p['shadowEnabled'] == true}, '
      'color: ${_color(p['shadowColor'] ?? d['shadowColor'], d['shadowColor'] as String)}, '
      'offsetX: ${_f(_num(p['shadowOffsetX'], 1))}, '
      'offsetY: ${_f(_num(p['shadowOffsetY'], 1))}, '
      'blur: ${_f(_num(p['shadowBlur'], 0))}))';
}

/// The runtime outline of [n] over its designer outline.
String _outline_(UmgNode n) {
  final p = n.props;
  final d = UmgWidgetType.textEffectDefaults;
  return 'LuminaUmgElementBinding.outline(e, const LuminaUmgTextOutline('
      'size: ${_f(_num(p['outlineSize'], 0))}, '
      'color: ${_color(p['outlineColor'] ?? d['outlineColor'], d['outlineColor'] as String)}))';
}

String _buttonStyle(dynamic v) {
  const allowed = {'primary', 'secondary', 'outline', 'ghost', 'destructive'};
  final s = v?.toString() ?? 'primary';
  return allowed.contains(s) ? s : 'primary';
}

String _drawAsFit(dynamic v) {
  switch (v?.toString()) {
    case 'box':
      return 'BoxFit.fill';
    case 'border':
      return 'BoxFit.cover';
    default:
      return 'BoxFit.contain';
  }
}

List<String> _options(dynamic v) =>
    (v?.toString() ?? '').split(',').map((o) => o.trim()).where((o) => o.isNotEmpty).toList();

double _num(dynamic v, double fallback) => v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? fallback);

int _int(dynamic v, int fallback) => v is num ? v.toInt() : (int.tryParse(v?.toString() ?? '') ?? fallback);

String _f(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e15) return '${v.toInt()}.0';
  return v.toString();
}

String _str(String s) {
  final escaped = s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$').replaceAll('\n', r'\n').replaceAll('\r', '');
  return "'$escaped'";
}

/// `#RRGGBB` / `#RRGGBBAA` → `Color(0xAARRGGBB)`.
String _color(dynamic v, String fallback) {
  // the fallback for an unparseable colour in *generated game code*, not an editor colour
  final c = UmgWidgetCodegen.parseHexColor(v?.toString() ?? '') ?? UmgWidgetCodegen.parseHexColor(fallback) ?? const Color(0xFFFFFFFF);
  return 'Color(0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()})';
}
