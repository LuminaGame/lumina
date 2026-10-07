import 'package:lumina/src/world/subsystem/world_subsystem.dart';

/// Reference physics world subsystem providing simulation stepping and collision integration.
class LuminaPhysicsWorldSubsystem extends LuminaWorldSubsystem {
  double totalSimulatedTime = 0.0;
  int stepCount = 0;

  @override
  void onWorldTick(double deltaTime) {
    super.onWorldTick(deltaTime);
    totalSimulatedTime += deltaTime;
    stepCount++;
  }

  @override
  void onWorldShutdown() {
    totalSimulatedTime = 0.0;
    stepCount = 0;
    super.onWorldShutdown();
  }
}
