import 'package:lumina/src/declarative/lumina_object.dart';
import 'package:lumina/src/object/actor.dart';
import 'package:lumina/src/world/world.dart';

/// Base non-transform component that can be attached to a [LuminaActor].
abstract class LuminaActorComponent extends LuminaObject with LuminaSaveable {
  LuminaActor? _owner;
  bool _isRegistered = false;
  bool bSaveGame;
  final String? componentName;

  LuminaActorComponent({super.key, this.bSaveGame = false, this.componentName});

  /// The stable name of this component for serialization and identification.
  String get effectiveComponentName => componentName ?? runtimeType.toString();

  /// The actor that owns this component.
  LuminaActor? get owner => _owner;

  /// The world this component's owner actor belongs to.
  LuminaWorld? get world => _owner?.world;

  /// Whether this component is registered with an owner actor.
  bool get isRegistered => _isRegistered;

  /// Called when attached to an owner actor.
  void onRegister(LuminaActor ownerActor) {
    _owner = ownerActor;
    _isRegistered = true;
  }

  /// Called after registration for initialization logic.
  void onInitialize() {}

  /// Called when the game starts or actor enters world.
  void onBeginPlay() {}

  /// Called during the world tick update step.
  void onTick(double deltaTime) {}

  /// Called during the post-physics render prep phase to sync transforms and native handles.
  void onRenderPrep(LuminaWorld world) {}

  /// Called when detached or disposed.
  void onUnregister() {
    _isRegistered = false;
    _owner = null;
  }
}
