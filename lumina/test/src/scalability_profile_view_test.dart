import 'package:flutter_filament/flutter_filament.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// The editor's quality popover changed nothing because
/// there was no way to push a named preset into a live Filament view. These
/// tests pin the lookup, the resolution-scale override and the view writes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('forPreset resolves every editor preset, case-insensitively, and falls back to epic', () {
    expect(LuminaScalabilityProfile.forPreset('low'), same(LuminaScalabilityProfile.low));
    expect(LuminaScalabilityProfile.forPreset('Medium'), same(LuminaScalabilityProfile.medium));
    expect(LuminaScalabilityProfile.forPreset('HIGH'), same(LuminaScalabilityProfile.high));
    expect(LuminaScalabilityProfile.forPreset('epic'), same(LuminaScalabilityProfile.epic));
    expect(LuminaScalabilityProfile.forPreset('cinematic'), same(LuminaScalabilityProfile.cinematic));
    expect(LuminaScalabilityProfile.forPreset('nonsense'), same(LuminaScalabilityProfile.epic));
  });

  test('the five presets really differ in cost, from low to cinematic', () {
    final low = LuminaScalabilityProfile.low;
    final cine = LuminaScalabilityProfile.cinematic;
    expect(low.shadows.mapSize, lessThan(cine.shadows.mapSize));
    expect(low.shadows.cascades, lessThan(cine.shadows.cascades));
    expect(low.dynamicResolution.enabled, isTrue, reason: 'low trades resolution for frame rate');
    expect(cine.dynamicResolution.enabled, isFalse);
    expect(cine.taa.enabled, isTrue);
    expect(cine.msaa.enabled, isTrue, reason: 'cinematic is the only preset paying for MSAA');
  });

  test('withResolutionScale: 100 % leaves the profile alone, anything lower drives dynamic resolution', () {
    final epic = LuminaScalabilityProfile.epic;
    expect(epic.withResolutionScale(100), same(epic));

    final half = epic.withResolutionScale(50);
    expect(half.dynamicResolution.enabled, isTrue);
    expect(half.dynamicResolution.minScaleX, closeTo(0.5, 1e-9));
    expect(half.dynamicResolution.maxScaleX, closeTo(0.5, 1e-9), reason: 'pinned, not a range');
    expect(half.dynamicResolution.minScaleY, closeTo(0.5, 1e-9));
    expect(half.shadows, epic.shadows, reason: 'only the resolution changes');

    // Out-of-range input is clamped rather than producing a broken view.
    expect(epic.withResolutionScale(500).dynamicResolution.maxScaleX, closeTo(2.0, 1e-9));
    expect(epic.withResolutionScale(1).dynamicResolution.minScaleX, closeTo(0.25, 1e-9));
  });

  test('applyToView writes the profile into a real Filament view and is readable back', () {
    final engine = FilamentEngine.create()!;
    final view = engine.createView();
    try {
      LuminaScalabilityProfile.low.applyToView(view);
      expect(view.dynamicResolutionOptions.enabled, isTrue);
      expect(view.renderQuality.hdrColorBuffer, QualityLevel.low);

      LuminaScalabilityProfile.cinematic.applyToView(view);
      expect(view.dynamicResolutionOptions.enabled, isFalse);
      expect(view.renderQuality.hdrColorBuffer, QualityLevel.ultra);

      // The resolution override reaches the view too.
      LuminaScalabilityProfile.epic.withResolutionScale(50).applyToView(view);
      expect(view.dynamicResolutionOptions.enabled, isTrue);
      expect(view.dynamicResolutionOptions.minScaleX, closeTo(0.5, 1e-6));
    } finally {
      engine.destroyView(view);
      engine.dispose();
    }
  });
}
