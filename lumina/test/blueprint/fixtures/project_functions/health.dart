// Exposed-functions fixture: a project's lib/, scanned by BlueprintFunctionScanner.
import 'package:lumina/lumina_runtime.dart';

/// Hit points by actor: 100 until damaged.
final Expando<double> _health = Expando<double>('health');

/// An actor's hit points.
double healthOf(LuminaActor actor) => _health[actor] ?? 100.0;

/// Takes [amount] hit points from the actor running the node.
/// [lethal] kills it outright.
@BlueprintCallable(category: 'Game|Health', keywords: ['hurt', 'hit'])
void applyDamage(LuminaActor self, double amount, {bool lethal = false}) {
  final left = lethal ? 0.0 : healthOf(self) - amount;
  _health[self] = left < 0.0 ? 0.0 : left;
}

/// How healthy [target] is: its hit points as a fraction of 100, and whether
/// it is dead.
@BlueprintPure()
({double percent, bool dead}) healthState(LuminaActor target) {
  final hp = healthOf(target);
  return (percent: hp / 100.0, dead: hp <= 0.0);
}
