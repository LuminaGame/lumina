import 'package:flutter/widgets.dart' show IconData;
import 'package:lumina_plugin_protocol/lumina_plugin_protocol.dart';

/// [icon] as protocol data, for a [PluginProcessCommand], a slot button
/// state or a declarative button.
PluginIconSpec pluginIconOf(IconData icon) => PluginIconSpec(
      icon.codePoint,
      fontFamily: icon.fontFamily,
      fontPackage: icon.fontPackage,
      matchTextDirection: icon.matchTextDirection,
    );

/// The [IconData] [spec] describes, for the editor to draw an icon a plugin
/// process sent.
///
/// The glyph is found in the editor's bundled icon fonts: a plugin process
/// runs from the editor's own executable, so the const icons its code names
/// keep their glyphs when release builds tree-shake the icon fonts. The
/// constructor is reached through a tear-off so the build's icon
/// tree-shaker, which refuses non-constant `IconData(...)` expressions,
/// accepts this one.
IconData iconDataOf(PluginIconSpec spec) => _makeIcon(
      spec.codePoint,
      fontFamily: spec.fontFamily,
      fontPackage: spec.fontPackage,
      matchTextDirection: spec.matchTextDirection,
    );

// The code point comes from the wire, so it cannot be a constant; the
// glyph is kept by the plugin's own const icon (see [iconDataOf]).
const IconData Function(int codePoint, {String? fontFamily, String? fontPackage, bool matchTextDirection}) _makeIcon =
    // ignore: tearoff_with_must_be_const_parameter
    IconData.new;
