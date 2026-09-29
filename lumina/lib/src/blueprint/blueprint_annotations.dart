/// Annotations that expose Dart functions to Blueprints,
/// Lumina's `UFUNCTION(BlueprintCallable)` and `UFUNCTION(BlueprintPure)`.
///
/// Put one on a public top-level or static function. Lumina's scanner (the
/// editor's "header tool", `BlueprintFunctionScanner`) reads it from source,
/// derives the node's pins from the parameters and the return type, and
/// generates the registration the Blueprint VM calls, since Flutter has no
/// run-time reflection. Generated Blueprint classes call the function
/// directly.
///
/// Pin types: `double` float, `int` integer, `bool` boolean, `String` string,
/// `Vector3` vector (authoring space: cm, Z up, like every Blueprint vector),
/// `Vector2` vector2D, `LuminaRotator` rotator, `LuminaActor` or a subclass
/// object. A first parameter named `self` of type `LuminaActor` is the
/// Blueprint running the node ("Target is self"); a record return
/// gives one output pin per named field; named parameters with defaults give
/// pin defaults.
///
/// ```dart
/// /// Takes [amount] hit points from the actor.
/// @BlueprintCallable(category: 'Game|Health')
/// void applyDamage(LuminaActor self, double amount, {bool lethal = false}) { … }
/// ```
library;

/// Marks a function as an impure Blueprint node, with exec pins: it runs when
/// its exec input fires, like `UFUNCTION(BlueprintCallable)`.
class BlueprintCallable {
  /// The palette category, `|` separating levels (`Game|Health`). Defaults
  /// to `Project`.
  final String? category;

  /// The node title. Defaults to the function name split into words
  /// (`applyDamage` → "Apply Damage").
  final String? displayName;

  /// Extra words the palette search matches.
  final List<String> keywords;

  /// The node tooltip. Defaults to the function's doc comment.
  final String? tooltip;

  const BlueprintCallable({this.category, this.displayName, this.keywords = const [], this.tooltip});
}

/// Marks a function as a pure Blueprint node, without exec pins: it is
/// evaluated when a node pulls one of its outputs, like
/// `UFUNCTION(BlueprintPure)`. It must return a value.
class BlueprintPure {
  /// The palette category, `|` separating levels. Defaults to `Project`.
  final String? category;

  /// The node title. Defaults to the function name split into words.
  final String? displayName;

  /// Extra words the palette search matches.
  final List<String> keywords;

  /// The node tooltip. Defaults to the function's doc comment.
  final String? tooltip;

  const BlueprintPure({this.category, this.displayName, this.keywords = const [], this.tooltip});
}
