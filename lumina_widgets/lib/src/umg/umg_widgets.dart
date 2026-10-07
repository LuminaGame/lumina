import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

part 'umg_widgets/controls.dart';
part 'umg_widgets/display.dart';
part 'umg_widgets/text_and_style.dart';

/// The UMG widgets a game uses when its project picks plain Flutter widgets:
/// built from `package:flutter/widgets.dart` alone, so a game needs
/// no Material and no shadcn_flutter, and they compile for the web. The UMG
/// codegen and the designer preview both use them.
///
/// The look follows a dark neutral palette close to shadcn's, so a menu reads
/// the same whichever library the project picked.
abstract final class LuminaUmgColors {
  static const Color foreground = Color(0xFFFAFAFA);
  static const Color muted = Color(0xFFA1A1AA);
  static const Color surface = Color(0xFF18181B);
  static const Color raised = Color(0xFF27272A);
  static const Color border = Color(0xFF3F3F46);
  static const Color destructive = Color(0xFFDC2626);

  /// Primary buttons: saturated enough for the designer's default white label.
  static const Color primary = Color(0xFF2563EB);
}
