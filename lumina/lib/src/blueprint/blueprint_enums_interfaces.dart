import 'blueprint_model.dart';

/// The project's enum assets a running game or the editor knows:
/// `Switch on Enum`, `Int → Enum` and `Get Enum Value Count`
/// read their values here. The editor's asset repository and the generated
/// `main()` fill it.
abstract final class LuminaBlueprintEnums {
  static final Map<String, LuminaBlueprintEnumDocument> _enums = {};

  static void register(LuminaBlueprintEnumDocument e) => _enums[e.name] = e;

  static void registerAll(Iterable<LuminaBlueprintEnumDocument> enums) => enums.forEach(register);

  static LuminaBlueprintEnumDocument? lookup(String? name) => name == null ? null : _enums[name];

  static void unregister(String name) => _enums.remove(name);

  static void clear() => _enums.clear();

  static bool get isEmpty => _enums.isEmpty;

  /// Every registered enum, in registration order.
  static List<LuminaBlueprintEnumDocument> get all => List.unmodifiable(_enums.values);

  /// The values of [name], or none for an unknown enum.
  static List<String> valuesOf(String? name) => lookup(name)?.values ?? const [];
}

/// The project's interface assets: what `Interface Message`
/// and `Event <Function>` type their pins from.
abstract final class LuminaBlueprintInterfaces {
  static final Map<String, LuminaBlueprintInterfaceDocument> _interfaces = {};

  static void register(LuminaBlueprintInterfaceDocument i) => _interfaces[i.name] = i;

  static void registerAll(Iterable<LuminaBlueprintInterfaceDocument> interfaces) => interfaces.forEach(register);

  static LuminaBlueprintInterfaceDocument? lookup(String? name) => name == null ? null : _interfaces[name];

  static void unregister(String name) => _interfaces.remove(name);

  static void clear() => _interfaces.clear();

  static bool get isEmpty => _interfaces.isEmpty;

  static List<LuminaBlueprintInterfaceDocument> get all => List.unmodifiable(_interfaces.values);
}

/// A custom event as the type context sees it: its name and
/// parameters, collected from the event graph's `custom_event` nodes so
/// `Call Custom Event` and delegate pins can be typed.
class LuminaBlueprintCustomEvent {
  final String name;
  final List<LuminaBlueprintVariable> parameters;

  /// The node that declares it.
  final String nodeId;

  const LuminaBlueprintCustomEvent({required this.name, this.parameters = const [], required this.nodeId});
}
