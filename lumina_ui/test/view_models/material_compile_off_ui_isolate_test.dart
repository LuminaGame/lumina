import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/material_editor_view_model.dart';

const _source = '''material {
    name : "M_Busy",
    shadingModel : lit,
    parameters : [ { type : sampler2d, name : mapColor } ],
    requires : [ uv0 ]
}
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = texture(materialParams_mapColor, getUV0());
    }
}''';

void main() {
  test('matc compiles off the calling isolate, which keeps running meanwhile', () async {
    var ticks = 0;
    final timer = Timer.periodic(const Duration(milliseconds: 10), (_) => ticks++);
    final stopwatch = Stopwatch()..start();
    final result = await DefaultFilamatCompilerRunner().compile(name: 'M_Busy', source: _source);
    stopwatch.stop();
    timer.cancel();

    expect(result.ok, isTrue, reason: result.issues.map((i) => i.message).join('\n'));
    // A compile on this isolate would hold every tick until it returned.
    expect(ticks, greaterThan(stopwatch.elapsedMilliseconds ~/ 10 ~/ 3),
        reason: '$ticks ticks in ${stopwatch.elapsedMilliseconds} ms');
  });
}
