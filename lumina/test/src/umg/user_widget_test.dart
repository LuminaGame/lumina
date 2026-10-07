import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina.dart';

/// A widget's script: attached by Create Widget, Pre Construct and
/// Construct on Add to Viewport, Destruct on Remove from Parent, Tick while
/// on screen, element events through `LuminaUserWidgets.fire`.
class _Recorder extends LuminaUserWidget {
  final List<String> calls = [];

  @override
  void onWidgetPreConstruct(bool isDesignTime) => calls.add('pre:$isDesignTime');

  @override
  void onWidgetConstruct() => calls.add('construct');

  @override
  void onWidgetDestruct() => calls.add('destruct');

  @override
  void onWidgetTick(double inDeltaTime) => calls.add('tick');

  @override
  void onWidgetEvent(String element, String event, Map<String, Object?> args) => calls.add('$element.$event$args');
}

void main() {
  setUp(() {
    LuminaWidgetClassRegistry.register(const LuminaBlueprintWidgetClass(name: 'WBP_Clicker', elements: [
      LuminaBlueprintWidgetElement(name: 'StartButton', typeName: 'button'),
      LuminaBlueprintWidgetElement(name: 'Title', typeName: 'text', props: {'text': 'Hi'}),
    ]));
  });
  tearDown(() {
    LuminaUserWidgets.clear();
    LuminaWidgetClassRegistry.clear();
  });

  test('Create Widget attaches the registered script; Add / Remove run the lifecycle; Tick only on screen', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    final owner = LuminaActor();
    world.persistentLevel.registerActor(owner);
    world.beginPlay();
    LuminaUserWidgets.register('WBP_Clicker', _Recorder.new);

    final widget = LuminaBlueprintFunctionLibrary.createWidget(owner, 'WBP_Clicker') as Map<String, Object?>;
    final script = LuminaUserWidgets.of(widget)! as _Recorder;
    expect(identical(script.widgetInstance, widget), isTrue);
    expect(script.widgetClassName, 'WBP_Clicker');
    expect(script.world, same(world), reason: 'spawned into the creating actor\'s world');
    expect(script.hiddenInGame, isTrue);
    expect(widget.containsValue(script), isFalse, reason: 'the instance map stays JSON-plain');
    expect(script.widgetElement('Title')!['text'], 'Hi');

    world.tick(1 / 60);
    expect(script.calls, isEmpty, reason: 'no Tick before it is on screen');

    LuminaBlueprintFunctionLibrary.addToViewport(owner, widget, 0);
    LuminaBlueprintFunctionLibrary.addToViewport(owner, widget, 0);
    expect(script.calls, ['pre:false', 'construct'], reason: 'Pre Construct then Construct, once per stay');
    world.tick(1 / 60);
    expect(script.calls.last, 'tick');

    LuminaUserWidgets.fire(widget, 'StartButton', 'OnClicked');
    expect(script.calls.last, 'StartButton.OnClicked{}');
    LuminaUserWidgets.fire(widget, 'Volume', 'OnValueChanged', {'value': 0.25});
    expect(script.calls.last, 'Volume.OnValueChanged{value: 0.25}');

    LuminaBlueprintFunctionLibrary.removeFromParent(owner, widget);
    expect(script.calls.last, 'destruct');
    final before = script.calls.length;
    world.tick(1 / 60);
    expect(script.calls.length, before, reason: 'no Tick once removed');
    LuminaBlueprintFunctionLibrary.addToViewport(owner, widget, 0);
    expect(script.calls.sublist(before), ['pre:false', 'construct'], reason: 'Construct again when re-added');
  });

  test('a class without a graph gets no script; fire on it does nothing', () {
    final owner = LuminaActor();
    final widget = LuminaBlueprintFunctionLibrary.createWidget(owner, 'WBP_Clicker') as Map<String, Object?>;
    expect(LuminaUserWidgets.of(widget), isNull);
    LuminaUserWidgets.fire(widget, 'StartButton', 'OnClicked');
    LuminaUserWidgets.fire(null, 'StartButton', 'OnClicked');
  });

  test('widget nodes with no Target act on the calling widget, and on nothing from an actor', () {
    final world = LuminaWorld(worldType: LuminaWorldType.game);
    world.beginPlay();
    final subsystem = world.getSubsystem<LuminaWidgetSubsystem>()!;
    LuminaUserWidgets.register('WBP_Clicker', _Recorder.new);
    final owner = world.spawnActorImmediately(LuminaActor());
    final widget = LuminaBlueprintFunctionLibrary.createWidget(owner, 'WBP_Clicker') as Map<String, Object?>;
    final script = LuminaUserWidgets.of(widget)!;

    LuminaBlueprintFunctionLibrary.addToViewport(script, null, 3);
    expect(subsystem.widgets, [widget]);
    expect(widget['zOrder'], 3);
    LuminaBlueprintFunctionLibrary.setWidgetVisibility(script, null, 'Hidden');
    expect(widget['visibility'], 'Hidden');
    LuminaBlueprintFunctionLibrary.removeFromParent(script, null);
    expect(subsystem.widgets, isEmpty);
    expect(LuminaBlueprintFunctionLibrary.getWidgetSelf(script), same(widget));
    expect(LuminaBlueprintFunctionLibrary.getWidgetVariable(script, 'Title'), same((widget['elements']! as Map)['Title']));

    // From an actor, an unwired Target is still nothing.
    LuminaBlueprintFunctionLibrary.addToViewport(owner, null, 0);
    expect(subsystem.widgets, isEmpty);
    expect(LuminaBlueprintFunctionLibrary.getWidgetSelf(owner), isNull);
    expect(LuminaBlueprintFunctionLibrary.getWidgetVariable(owner, 'Title'), isNull);
  });
}
