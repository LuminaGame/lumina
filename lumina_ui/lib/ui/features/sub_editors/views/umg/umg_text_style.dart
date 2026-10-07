import 'package:lumina_editor_data/lumina_editor.dart'
    show LuminaUmgElementBinding, LuminaUmgText, LuminaUmgTextOutline, LuminaUmgTextShadow;
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/features/sub_editors/services/umg_widget_codegen.dart';

/// The text look of a designer element, shared by the
/// designer canvas and [UmgRuntimeView] so both draw what the generated
/// widget draws: font size, colour and drop shadow from the designer
/// [props], each overridden by the runtime element state [element] (what
/// the Blueprint element nodes wrote; null in the designer).
///
/// With [outlineRing] the outline joins the shadows as a ring of sharp
/// shadows, for an editable field a stroked second layer cannot sit under.
TextStyle umgTextStyle(Map<String, dynamic> props, Map<String, Object?>? element, {bool outlineRing = false}) {
  // A game's default white text (what the generated code falls back to), not an editor colour.
  final designerColor = UmgWidgetCodegen.parseHexColor(props['color']?.toString() ?? '') ?? const Color(0xFFFFFFFF);
  final fontSize = props['fontSize'];
  return TextStyle(
    fontSize: LuminaUmgElementBinding.value<double>(element, 'fontSize', fontSize is num ? fontSize.toDouble() : 14.0),
    color: LuminaUmgElementBinding.color(element, 'color', designerColor),
    shadows: [
      ...umgTextShadow(props, element).shadows,
      if (outlineRing) ...umgTextOutline(props, element).ringShadows,
    ],
  );
}

/// The drop shadow of [props] under the runtime [element]'s overrides.
LuminaUmgTextShadow umgTextShadow(Map<String, dynamic> props, Map<String, Object?>? element) {
  // The designer props use the element-state keys, so the binding reads both.
  final designer = LuminaUmgElementBinding.shadow(Map<String, Object?>.from(props), LuminaUmgTextShadow.defaults);
  return LuminaUmgElementBinding.shadow(element, designer);
}

/// The outline of [props] under the runtime [element]'s overrides.
LuminaUmgTextOutline umgTextOutline(Map<String, dynamic> props, Map<String, Object?>? element) {
  final designer = LuminaUmgElementBinding.outline(Map<String, Object?>.from(props), LuminaUmgTextOutline.defaults);
  return LuminaUmgElementBinding.outline(element, designer);
}

/// A text of a designer element: [umgTextStyle] plus its outline drawn as a
/// stroked layer under the fill ([LuminaUmgText], the widget the generated
/// code uses too).
Widget umgText(String text, Map<String, dynamic> props, Map<String, Object?>? element) =>
    LuminaUmgText(text, style: umgTextStyle(props, element), outline: umgTextOutline(props, element));
