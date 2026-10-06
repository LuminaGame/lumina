/// Orders the meshes a viewport still has to bind: nearest to the camera
/// first, a bounded number per frame, so a level with thousands of actors
/// fills in over frames instead of freezing one.
abstract final class MeshBindScheduler {
  /// Up to [count] of [items], nearest first by [distance]; ties keep the
  /// order of [items]. Never more than [items] has.
  static List<T> nearestFirst<T>(Iterable<T> items, double Function(T item) distance, int count) {
    if (count <= 0) return const [];
    final indexed = <(int, double, T)>[];
    var i = 0;
    for (final item in items) {
      indexed.add((i++, distance(item), item));
    }
    indexed.sort((a, b) {
      final c = a.$2.compareTo(b.$2);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed.take(count)) e.$3];
  }

  /// Squared distance from the camera pivot to an actor location, the
  /// ordering key ([nearestFirst] only compares).
  static double squaredDistance(List<double> location, double px, double py, double pz) {
    final dx = location[0] - px, dy = location[1] - py, dz = location[2] - pz;
    return dx * dx + dy * dy + dz * dz;
  }
}
