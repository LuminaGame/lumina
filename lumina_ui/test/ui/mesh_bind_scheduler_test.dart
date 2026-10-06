import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/main_editor/views/viewport_widget/mesh_bind_scheduler.dart';

void main() {
  test('nearest first, a bounded number at a time, ties in insertion order', () {
    final items = {'far': 900.0, 'near': 10.0, 'mid': 100.0, 'near2': 10.0, 'nearest': 1.0};
    final picked = MeshBindScheduler.nearestFirst(items.keys, (k) => items[k]!, 3);
    expect(picked, ['nearest', 'near', 'near2']);
    expect(MeshBindScheduler.nearestFirst(items.keys, (k) => items[k]!, 10), hasLength(5), reason: 'never more than there are');
    expect(MeshBindScheduler.nearestFirst(items.keys, (k) => items[k]!, 0), isEmpty);
    expect(MeshBindScheduler.nearestFirst(<String>[], (k) => 0.0, 2), isEmpty);
  });

  test('the squared distance keys the camera pivot order', () {
    expect(MeshBindScheduler.squaredDistance([3, 4, 0], 0, 0, 0), 25.0);
    expect(MeshBindScheduler.squaredDistance([1, 1, 1], 1, 1, 1), 0.0);
  });
}
