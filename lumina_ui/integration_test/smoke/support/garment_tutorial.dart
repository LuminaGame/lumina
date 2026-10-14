import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:lumina_ui/testing.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/garment_editor_view_model.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/blueprint_sub_editor.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/blueprint/component_tree.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/garment/garment.dart';
import 'package:lumina_ui/ui/features/sub_editors/views/sub_editor_3d_viewport.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show EditableText, ValueKey;
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// What a garment tutorial works with: the source mesh and the body (file
/// names as the asset pickers list them, and a word to search them by), the
/// character Blueprint whose slot component receives the garment, and how
/// the captions name the garment.
class GarmentTutorialSetup {
  const GarmentTutorialSetup({
    required this.sourceFile,
    required this.sourceSearch,
    required this.bodyFile,
    required this.bodySearch,
    required this.blueprintPath,
    required this.slotComponentId,
    required this.garmentName,
  });

  final String sourceFile, sourceSearch, bodyFile, bodySearch;
  final String blueprintPath, slotComponentId;

  /// The garment in the captions (Turkish), e.g. "kırmızı elbise".
  final String garmentName;
}

/// The steps the tutorial shows (for the caption counter).
const int garmentTutorialSteps = 30;

/// Records the whole Garment workflow in the running editor [vm] with
/// [tutor]: Content Browser → New Asset → Character → Garment, open it,
/// pick the source mesh, the reference and preview body, the slot and the
/// thickness, move and resize with the gizmo, place Neck, Shoulder L/R and
/// Waist landmarks by clicking the garment and the body, Align, look from
/// two sides, save, and put the garment in the character Blueprint's slot.
/// Captions are Turkish, UI names stay English. [shot] saves a key PNG.
Future<void> runGarmentTutorial(
  WidgetTester tester,
  EditorViewModel vm,
  SmokeTutor tutor,
  GarmentTutorialSetup s, {
  required Future<void> Function(String label) shot,
}) async {
  Future<void> frames(int n) async {
    for (var i = 0; i < n; i++) {
      await tutor.hold(const Duration(milliseconds: 33));
    }
  }

  Future<void> until(bool Function() done, {int maxFrames = 900}) async {
    for (var i = 0; i < maxFrames && !done(); i++) {
      await tutor.hold(const Duration(milliseconds: 33));
    }
  }

  // An asset picker: open its popup, search, choose the item.
  Future<void> pick(String widgetKey, String prefix, String file, String search) async {
    final picker = find.byKey(ValueKey(widgetKey));
    final r = tester.getRect(picker);
    await tutor.clickAt(Offset(r.left + r.width * 0.4, r.center.dy));
    final field = find.descendant(of: find.byKey(ValueKey('${prefix}_search')), matching: find.byType(EditableText));
    if (field.evaluate().isNotEmpty) await tutor.type(field, search);
    await frames(10);
    await tutor.click(find.byKey(ValueKey('${prefix}_item_$file')));
  }

  // 1 — New Asset → Character → Garment.
  await tutor.step('Yeni bir giysi oluşturuyoruz: Content Browser → New Asset');
  final before = {for (final a in vm.realAssets) a.relativePath};
  await tutor.click(find.text('New Asset'));
  await shot('00 new asset dialog');
  await tutor.step('Character → Garment (.lmas): giysi, bir karaktere giydirilen mesh\'tir');
  await tutor.click(find.text('Character → Garment (.lmas)'));
  await until(() => vm.realAssets.any((a) => a.type == AssetType.garment && !before.contains(a.relativePath)));
  await shot('00 new asset');
  final created = vm.realAssets.firstWhere((a) => a.type == AssetType.garment && !before.contains(a.relativePath));

  // 2 — Open it.
  await tutor.step('characters klasöründeki yeni Garment asset\'ine çift tıklayıp açıyoruz');
  final folder = find.byKey(const ValueKey('folder_tile_contents/characters'));
  if (folder.evaluate().isNotEmpty) await tutor.click(folder, doubleClick: true);
  await frames(10);
  await tutor.click(find.byKey(ValueKey('asset_item_${created.relativePath}')), doubleClick: true, after: const Duration(milliseconds: 1500));
  await until(() => find.byType(GarmentSubEditor).evaluate().isNotEmpty);
  final editor = tester.state<GarmentSubEditorState>(find.byType(GarmentSubEditor));
  final g = editor.vm;
  await until(() => g.isLoaded && g.meshAssets.isNotEmpty);
  await tutor.step('Garment editörü: solda ayarlar, ortada viewport, sağda landmark\'lar');

  // 3–5 — Source mesh, reference body, preview body.
  await tutor.step('Source Mesh: giysinin yapıldığı mesh — ${s.sourceFile.split('.').first}');
  await pick('garment_source_mesh', 'garment_source', s.sourceFile, s.sourceSearch);
  await tutor.step('Reference Body: giysinin üzerinde tasarlandığı gövde — ${s.bodyFile.split('.').first}');
  await pick('garment_reference_body', 'garment_body', s.bodyFile, s.bodySearch);
  await tester.runAsync(() => g.meshesReady);
  await until(() => g.sourceMesh != null && g.bodyMesh != null);
  await frames(30);
  await tutor.step('Yeni giysi, slotunun bölgesine (Torso) otomatik yerleşti');
  await shot('01 placed on the body');
  await tutor.step('Preview On: önizleme gövdesi — aynı gövdeyi seçiyoruz');
  await pick('garment_preview_body', 'garment_preview', s.bodyFile, s.bodySearch);
  await frames(20);

  // 6–7 — Slot and thickness.
  await tutor.step('Slot: giysinin dolduracağı karakter slotu — Torso');
  await tutor.click(find.byKey(const ValueKey('garment_slot')));
  await tutor.click(find.text('Torso').last);
  await tutor.step('Thickness: kumaşın gövdeden en az uzaklığı (cm)');
  final thickness = find.descendant(of: find.byKey(const ValueKey('garment_thickness')), matching: find.byType(EditableText));
  await tutor.type(thickness, '0.4');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await frames(10);

  // 8–9 — The gizmo.
  final viewportFinder = find.byType(SubEditor3DViewport);
  dynamic viewport() => tester.state(viewportFinder);
  Rect rect() => tester.getRect(viewportFinder);
  await tutor.step('Move (W): gizmo okunu sürükleyerek giysiyi taşıyın');
  await tutor.click(find.byKey(const ValueKey('garment_move')));
  var handles = viewport().gizmoHandleScreenPositionsForTest(rect().size) as Map<String, Offset>;
  Offset along(String h, double px) {
    final c = handles['CENTER']!, t = handles[h]!;
    return (t - c) / (t - c).distance * px;
  }

  final grabZ = rect().topLeft + handles['CENTER']! + along('Z', (handles['Z']! - handles['CENTER']!).distance * 0.6);
  await tutor.drag(grabZ, grabZ + along('Z', 30));
  await tutor.step('Resize (R): ortadaki tutamaçla giysiyi büyütüp küçültün');
  await tutor.click(find.byKey(const ValueKey('garment_scale')));
  handles = viewport().gizmoHandleScreenPositionsForTest(rect().size) as Map<String, Offset>;
  final uniform = handles['UNIFORM'] ?? handles['CENTER']!;
  final grabU = rect().topLeft + uniform;
  await tutor.drag(grabU, grabU + const Offset(18, -18));
  await tutor.click(find.byKey(const ValueKey('garment_move')));

  // 10–17 — Landmarks: a point on the garment and the matching point on the body.
  final targets = _landmarkTargets(g);
  final names = {'Neck': 'Neck (boyun)', 'Shoulder L': 'Shoulder L (sol omuz)', 'Shoulder R': 'Shoulder R (sağ omuz)', 'Waist': 'Waist (bel)'};
  for (final e in names.entries) {
    final t = targets[e.key];
    if (t == null) continue;
    await tutor.step('Add a landmark… → ${e.value}');
    await tutor.click(find.byKey(const ValueKey('garment_add_preset')));
    await tutor.click(find.text(e.key).last);
    // Just under the vertex, on the fabric facing the camera.
    final placedGarment = _placedPoint(g, t.garmentVertex);
    placedGarment[2] += 0.2;
    await tutor.step('Garment satırı → ${s.garmentName} üzerinde ${e.key} noktasına tıklayın');
    await tutor.click(find.byKey(ValueKey('garment_point_${e.key}_Garment')));
    final gp = viewport().screenPositionOf(Vector3(placedGarment[0], placedGarment[1], placedGarment[2])) as Offset?;
    if (gp != null) await tutor.clickAt(rect().topLeft + gp);
    await tutor.step('Body satırı → gövdede aynı yere tıklayın');
    await tutor.click(find.byKey(ValueKey('garment_point_${e.key}_Body')));
    final bp = viewport().screenPositionOf(Vector3(t.body[0], t.body[1], t.body[2])) as Offset?;
    if (bp != null) await tutor.clickAt(rect().topLeft + bp);
    if (e.key == 'Neck') await shot('02 neck landmark');
  }

  // 18 — Align.
  await tutor.step('Align: giysi landmark\'lara göre gövdeye hizalanır (konum, dönüş, ölçek)');
  await tutor.click(find.byKey(const ValueKey('garment_align')), after: const Duration(milliseconds: 1800));
  await shot('03 aligned');

  // 19 — Look around (right button orbits).
  await tutor.step('Birkaç açıdan kontrol edin: sağ tuşla sürükleyerek etrafında dönün');
  final centre = rect().center;
  await tutor.drag(centre, centre + const Offset(220, 0), buttons: kSecondaryButton, steps: 60);
  await tutor.hold(const Duration(milliseconds: 1200));
  await shot('04 side view');
  await tutor.drag(centre, centre + const Offset(230, 0), buttons: kSecondaryButton, steps: 60);
  await tutor.hold(const Duration(milliseconds: 1200));
  await tutor.drag(centre, centre + const Offset(-450, 0), buttons: kSecondaryButton, steps: 80);

  // 20 — Save.
  await tutor.step('Save: giysi asset\'i kaydedilir');
  await tutor.click(find.byKey(const ValueKey('garment_save')), after: const Duration(milliseconds: 1200));
  await until(() => !g.isDirty);

  // 21–22 — Into the character Blueprint's slot.
  await tutor.step('Karakter Blueprint\'ini açın: blueprints klasöründe çift tıklayın');
  vm.selectTab(0);
  await frames(10);
  final up = find.byKey(const ValueKey('folder_tile_contents/blueprints'));
  if (up.evaluate().isEmpty) {
    // Back to the content root first.
    final root = find.text('contents').first;
    await tutor.click(root);
  }
  await tutor.click(find.byKey(const ValueKey('folder_tile_contents/blueprints')), doubleClick: true);
  await tutor.click(find.byKey(ValueKey('asset_item_${s.blueprintPath}')), doubleClick: true, after: const Duration(milliseconds: 1500));
  await until(() => find.byType(BlueprintSubEditor).evaluate().isNotEmpty);
  final bp = tester.state<BlueprintSubEditorState>(find.byType(BlueprintSubEditor)).viewModel;
  await until(() => bp.document.components.any((c) => c.id == s.slotComponentId));
  await tutor.step('Torso slot bileşenini seçin; Skeletal Mesh Asset alanına Garment asset\'ini verin');
  await tutor.click(find.descendant(of: find.byType(BlueprintComponentTree), matching: find.byKey(ValueKey('component_row_${s.slotComponentId}'))));
  await tutor.click(find.text('3D Viewport'));
  final garmentFile = created.relativePath.split('/').last;
  await pick('bp_asset_${s.slotComponentId}_skeletalMeshAsset', 'bp_asset_skeletalMeshAsset', garmentFile, garmentFile.split('.').first);
  await tutor.step('Giysi gövdeye uydurulur ve altındaki gövde maskelenir — Blueprint viewport\'ta görünür');
  await until(() => bp.preview.actor != null);
  var ready = false;
  LuminaCharacterSlots.of(bp.preview.actor!).ready.then((_) => ready = true);
  await until(() => ready, maxFrames: 2400);
  // F frames the character; then a look from both sides.
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tutor.hold(const Duration(seconds: 2));
  await shot('05 in the blueprint slot');
  final c2 = rect().center;
  await tutor.drag(c2, c2 + const Offset(140, 0), buttons: kSecondaryButton, steps: 60);
  await tutor.hold(const Duration(milliseconds: 1500));
  await tutor.drag(c2, c2 + const Offset(-280, 0), buttons: kSecondaryButton, steps: 90);
  await tutor.hold(const Duration(milliseconds: 1500));
  await tutor.drag(c2, c2 + const Offset(140, 0), buttons: kSecondaryButton, steps: 60);
  await tutor.hold(const Duration(seconds: 2));
  tutor.finish();
  await tutor.hold(const Duration(seconds: 1));
}

/// A landmark: the garment vertex standing for it (source mesh index) and
/// the body point (runtime frame, cm) it belongs at.
typedef _Target = ({int garmentVertex, List<double> body});

List<double> _placedPoint(GarmentEditorViewModel g, int v) {
  final p = g.placedSourcePositions();
  return [p[v * 3], p[v * 3 + 1], p[v * 3 + 2]];
}

/// Neck, Shoulder L/R and Waist on the placed garment (its front neckline,
/// its highest points left and right, the front of its narrowest slice
/// under the top) and on the body's skin (the front of the neck base, the
/// top of each shoulder, the front of the waist), the body facing +Z.
Map<String, _Target> _landmarkTargets(GarmentEditorViewModel g) {
  final body = g.bodyMesh!.skin;
  final p = g.placedSourcePositions();
  final n = p.length ~/ 3;
  double lo(Float64List a, int k) => [for (var i = k; i < a.length; i += 3) a[i]].reduce(math.min);
  double hi(Float64List a, int k) => [for (var i = k; i < a.length; i += 3) a[i]].reduce(math.max);
  final bMinY = lo(body.positions, 1), bH = hi(body.positions, 1) - bMinY;
  final bcx = (lo(body.positions, 0) + hi(body.positions, 0)) / 2, bcz = (lo(body.positions, 2) + hi(body.positions, 2)) / 2;
  final gcx = (lo(p, 0) + hi(p, 0)) / 2, gcz = (lo(p, 2) + hi(p, 2)) / 2;
  final gw = hi(p, 0) - lo(p, 0), gTop = hi(p, 1), gH = gTop - lo(p, 1);

  List<double>? front(double x, double y) {
    final hit = LuminaGarmentMath.raycast(body.positions, body.triangles, x, y, bcz + 300, 0, 0, -1);
    return hit == null ? null : [hit.x, hit.y, hit.z];
  }

  // The top of the shoulder: the highest skin vertex near x under the head.
  List<double>? shoulderTop(double x) {
    var top = -1;
    for (var v = 0; v < body.vertexCount; v++) {
      final y = body.positions[v * 3 + 1];
      if ((body.positions[v * 3] - x).abs() > 1.5 || y > bMinY + 0.88 * bH) continue;
      if (top < 0 || y > body.positions[top * 3 + 1]) top = v;
    }
    return top < 0 ? null : [body.positions[top * 3], body.positions[top * 3 + 1], body.positions[top * 3 + 2]];
  }


  int best(bool Function(int v) ok, double Function(int v) score) {
    var b = -1;
    var s = -double.infinity;
    for (var v = 0; v < n; v++) {
      if (!ok(v)) continue;
      final sv = score(v);
      if (sv > s) {
        s = sv;
        b = v;
      }
    }
    return b;
  }

  // The garment vertex facing the camera (largest z) nearest to (x, y).
  int frontAt(double x, double y, {double reach = 1.5}) => best(
        (v) => (p[v * 3] - x).abs() < reach && (p[v * 3 + 1] - y).abs() < reach,
        (v) => p[v * 3 + 2],
      );

  final out = <String, _Target>{};
  // The neckline's front centre, then 4 cm down on the fabric (a click on
  // the neckline itself would look through the opening).
  final neckTop = best((v) => (p[v * 3] - gcx).abs() < 0.06 * gw && p[v * 3 + 2] > gcz, (v) => p[v * 3 + 1]);
  final neck = neckTop < 0 ? -1 : frontAt(p[neckTop * 3], p[neckTop * 3 + 1] - 4, reach: 2);
  final bodyNeck = front(bcx, bMinY + 0.807 * bH);
  if (neck >= 0 && bodyNeck != null) out['Neck'] = (garmentVertex: neck, body: bodyNeck);
  for (final (name, sign) in const [('Shoulder L', 1.0), ('Shoulder R', -1.0)]) {
    final top = best((v) => sign * (p[v * 3] - gcx) > 0.15 * gw, (v) => p[v * 3 + 1] - 0.2 * (p[v * 3 + 2] - gcz).abs());
    // On the strap's front, 2 cm under its top.
    final v = top < 0 ? -1 : frontAt(p[top * 3], p[top * 3 + 1] - 2, reach: 2);
    final b = shoulderTop(bcx + sign * 0.09 * bH);
    if (v >= 0 && b != null) out[name] = (garmentVertex: v, body: b);
  }
  // The narrowest 2 cm slice between a quarter and a half of the way down.
  var bestWidth = double.infinity, waistY = gTop - 0.35 * gH;
  for (var y = gTop - 0.5 * gH; y < gTop - 0.25 * gH; y += 2) {
    var a = double.infinity, b = -double.infinity;
    for (var v = 0; v < n; v++) {
      if ((p[v * 3 + 1] - y).abs() > 1) continue;
      a = math.min(a, p[v * 3]);
      b = math.max(b, p[v * 3]);
    }
    if (b > a && b - a < bestWidth) {
      bestWidth = b - a;
      waistY = y;
    }
  }
  final waist = best((v) => (p[v * 3 + 1] - waistY).abs() < 1.5 && (p[v * 3] - gcx).abs() < 0.08 * gw, (v) => p[v * 3 + 2]);
  final bodyWaist = front(bcx, bMinY + 0.59 * bH);
  if (waist >= 0 && bodyWaist != null) out['Waist'] = (garmentVertex: waist, body: bodyWaist);
  return out;
}
