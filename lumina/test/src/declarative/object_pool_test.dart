import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

class PooledResource {
  bool isReset = false;
  int id;
  PooledResource(this.id);
}

void main() {
  group('LuminaObjectPool Tests (Task 04)', () {
    test('acquire on empty pool calls create; release then acquire returns same instance after reset', () {
      int nextId = 1;
      int resetCount = 0;
      final pool = LuminaObjectPool<PooledResource>(
        create: () => PooledResource(nextId++),
        reset: (obj) {
          resetCount++;
          obj.isReset = true;
        },
      );

      final res1 = pool.acquire();
      expect(res1.id, equals(1));
      expect(res1.isReset, isFalse);

      pool.release(res1);
      expect(resetCount, equals(1));
      expect(res1.isReset, isTrue);
      expect(pool.pooledCount, equals(1));

      final res2 = pool.acquire();
      expect(identical(res1, res2), isTrue);
      expect(pool.pooledCount, equals(0));
    });

    test('Pool cap: maxSize 2 drops extra releases without error', () {
      int nextId = 1;
      final pool = LuminaObjectPool<PooledResource>(
        create: () => PooledResource(nextId++),
        reset: (obj) => obj.isReset = true,
        maxSize: 2,
      );

      final obj1 = pool.acquire();
      final obj2 = pool.acquire();
      final obj3 = pool.acquire();

      pool.release(obj1);
      pool.release(obj2);
      pool.release(obj3); // Dropped

      expect(pool.pooledCount, equals(2));
    });

    test('1000 acquire/release cycles on warm pool allocate zero new objects', () {
      int createCount = 0;
      final pool = LuminaObjectPool<PooledResource>(
        create: () {
          createCount++;
          return PooledResource(createCount);
        },
        reset: (obj) => obj.isReset = true,
        maxSize: 10,
      );

      // Pre-warm pool with 5 objects
      final warmList = List.generate(5, (_) => pool.acquire());
      for (final obj in warmList) {
        pool.release(obj);
      }
      expect(createCount, equals(5));

      // 1000 cycles
      for (int i = 0; i < 1000; i++) {
        final a = pool.acquire();
        final b = pool.acquire();
        pool.release(a);
        pool.release(b);
      }

      expect(createCount, equals(5));
    });
  });
}
