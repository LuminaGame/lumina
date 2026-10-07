/// The identity of an engine object: an actor, a component, a level or a
/// level script.
///
/// Two keys are equal when their [value]s are. The declarative tree uses the
/// key to match a rebuilt node with its live element, the world finds placed
/// actors by it (a level row's `id` is its key), and [toString] is part of an
/// actor's `saveId`.
///
/// The engine's own key, with no Flutter dependency: widgets keep Flutter's
/// `Key`. (The input key of a keyboard, mouse or gamepad is `LuminaKey`.)
final class LuminaObjectKey {
  /// A key named [value] (a level row's actor id, `L_Main_script`, …).
  const LuminaObjectKey(this.value);

  /// The key's text.
  final String value;

  @override
  bool operator ==(Object other) => other is LuminaObjectKey && other.value == value;

  @override
  int get hashCode => Object.hash(LuminaObjectKey, value);

  /// `[<'value'>]`: the text actors' `saveId`s and level names embedded when
  /// objects carried a string value key, so saves written before keep
  /// matching the actors they belong to.
  @override
  String toString() => "[<'$value'>]";
}
