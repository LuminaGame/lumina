import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/lumina_runtime.dart';

/// The standalone widget layer over a real world: registered
/// builders, zOrder, visibility, per-element rebuilds and the common element
/// properties. Widgets are built by hand here in the exact shape
/// `umg_widget_codegen` emits (a class taking `instance`, elements wrapped in
/// [LuminaUmgElement]).
const _hud = LuminaBlueprintWidgetClass(name: 'WBP_HUD', elements: [
  LuminaBlueprintWidgetElement(name: 'FPSCounter', fieldName: 'fpsCounter', typeName: 'text', props: {'text': 'FPS: 0', 'fontSize': 16.0, 'color': '#FFFFFF'}),
  LuminaBlueprintWidgetElement(name: 'Title', fieldName: 'title', typeName: 'text', props: {'text': 'Designer title'}),
  LuminaBlueprintWidgetElement(name: 'Health', fieldName: 'health', typeName: 'progressBar', props: {'percent': 0.75, 'color': '#4ADE80'}),
  LuminaBlueprintWidgetElement(name: 'Resume', fieldName: 'resume', typeName: 'button', props: {'label': 'Resume'}),
]);
const _menu = LuminaBlueprintWidgetClass(name: 'WBP_Menu');

/// The shape of a generated widget class.
class _WbpHud extends StatelessWidget {
  const _WbpHud({this.instance, this.onResume, this.builds});

  final Map<String, Object?>? instance;
  final VoidCallback? onResume;
  final Map<String, int>? builds;

  Widget _count(String name, Widget child) {
    builds?.update(name, (n) => n + 1, ifAbsent: () => 1);
    return child;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('canvasPanel'),
      mainAxisSize: MainAxisSize.min,
      children: [
        LuminaUmgElement(
          instance: instance,
          name: 'FPSCounter',
          builder: (context, e) => _count(
            'FPSCounter',
            Text(
              key: const ValueKey('fpsCounter'),
              LuminaUmgElementBinding.value<String>(e, 'text', 'FPS: 0'),
              style: TextStyle(fontSize: LuminaUmgElementBinding.value<double>(e, 'fontSize', 16.0), color: LuminaUmgElementBinding.color(e, 'color', const Color(0xFFFFFFFF))),
            ),
          ),
        ),
        LuminaUmgElement(
          instance: instance,
          name: 'Title',
          builder: (context, e) => _count('Title', Text(key: const ValueKey('title'), LuminaUmgElementBinding.value<String>(e, 'text', 'Designer title'))),
        ),
        LuminaUmgElement(
          instance: instance,
          name: 'Health',
          builder: (context, e) => _count(
            'Health',
            SizedBox(
              key: const ValueKey('health'),
              height: 8,
              width: 100,
              child: LuminaUmgProgressBar(progress: LuminaUmgElementBinding.value<double>(e, 'percent', 0.75), color: LuminaUmgElementBinding.color(e, 'fillColor', const Color(0xFF4ADE80))),
            ),
          ),
        ),
        LuminaUmgElement(
          instance: instance,
          name: 'Resume',
          builder: (context, e) => _count(
            'Resume',
            LuminaUmgButton(
              key: const ValueKey('resume'),
              onPressed: LuminaUmgElementBinding.isEnabled(e) ? onResume : null,
              child: Text(LuminaUmgElementBinding.value<String>(e, 'label', 'Resume')),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: DefaultTextStyle(style: const TextStyle(fontSize: 14, color: Color(0xFFFFFFFF)), child: Overlay(initialEntries: [OverlayEntry(builder: (_) => child)])),
    );

void main() {
  late LuminaWorld world;
  late LuminaCharacter character;
  late Map<String, int> builds;
  var resumed = 0;

  setUp(() {
    LuminaWidgetBuilderRegistry.clear();
    builds = {};
    resumed = 0;
    LuminaWidgetBuilderRegistry.register('WBP_HUD', _hud, (context, instance) => _WbpHud(instance: instance, builds: builds, onResume: () => resumed++));
    world = LuminaWorld(worldType: LuminaWorldType.game);
    character = LuminaCharacter();
    world.persistentLevel.registerActor(character);
  });

  tearDown(() {
    LuminaWidgetBuilderRegistry.clear();
  });

  Map<String, Object?> create(String cls) => LuminaBlueprintFunctionLibrary.createWidget(character, cls) as Map<String, Object?>;

  group('LuminaWidgetLayer over a world', () {
    testWidgets('createWidget + addToViewport builds the registered builder once; removeFromParent removes it', (tester) async {
      var builderCalls = 0;
      LuminaWidgetBuilderRegistry.register('WBP_HUD', _hud, (context, instance) {
        builderCalls++;
        return _WbpHud(instance: instance, builds: builds);
      });
      await tester.pumpWidget(_host(LuminaWidgetLayer(world: world)));
      expect(find.byKey(const ValueKey('fpsCounter')), findsNothing);

      final hud = create('WBP_HUD');
      LuminaBlueprintFunctionLibrary.addToViewport(character, hud, 0);
      await tester.pump();
      expect(find.text('FPS: 0'), findsOneWidget);
      expect(find.text('Designer title'), findsOneWidget);
      expect(builderCalls, 1);
      expect(builds['FPSCounter'], 1);

      LuminaBlueprintFunctionLibrary.removeFromParent(character, hud);
      await tester.pump();
      expect(find.text('FPS: 0'), findsNothing);
      expect(builderCalls, 1, reason: 'removing does not rebuild the other instances');
    });

    testWidgets('two widgets render in zOrder order and an unknown class shows a fallback card', (tester) async {
      LuminaWidgetBuilderRegistry.register('WBP_Menu', _menu, (context, instance) => const Text('MENU', key: ValueKey('menu')));
      await tester.pumpWidget(_host(LuminaWidgetLayer(world: world)));
      final menu = create('WBP_Menu');
      final hud = create('WBP_HUD');
      LuminaBlueprintFunctionLibrary.addToViewport(character, menu, 10);
      LuminaBlueprintFunctionLibrary.addToViewport(character, hud, 0);
      await tester.pump();
      final stack = tester.widget<Stack>(find.byType(Stack).first);
      expect(stack.children.map((c) => (c.key as ObjectKey).value), [hud, menu], reason: 'lower zOrder first (drawn underneath)');

      final other = create('WBP_Unknown');
      LuminaBlueprintFunctionLibrary.addToViewport(character, other, 5);
      await tester.pump();
      expect(find.text('WBP_Unknown'), findsOneWidget, reason: 'unknown class → fallback card naming it');
      final ordered = tester.widget<Stack>(find.byType(Stack).first);
      expect(ordered.children.map((c) => (c.key as ObjectKey).value), [hud, other, menu]);
    });

    testWidgets('visibility Hidden skips one widget; Set Visibility back shows it', (tester) async {
      LuminaWidgetBuilderRegistry.register('WBP_Menu', _menu, (context, instance) => const Text('MENU'));
      await tester.pumpWidget(_host(LuminaWidgetLayer(world: world)));
      final menu = create('WBP_Menu');
      final hud = create('WBP_HUD');
      LuminaBlueprintFunctionLibrary.addToViewport(character, menu, 1);
      LuminaBlueprintFunctionLibrary.addToViewport(character, hud, 0);
      await tester.pump();
      expect(find.text('MENU'), findsOneWidget);
      LuminaBlueprintFunctionLibrary.setWidgetVisibility(character, menu, 'Hidden');
      await tester.pump();
      expect(find.text('MENU'), findsNothing);
      expect(find.text('FPS: 0'), findsOneWidget);
      LuminaBlueprintFunctionLibrary.setWidgetVisibility(character, menu, 'Visible');
      await tester.pump();
      expect(find.text('MENU'), findsOneWidget);
    });

    testWidgets('a null world renders nothing; the layer follows a world handed to it later', (tester) async {
      final current = ValueNotifier<LuminaWorld?>(null);
      addTearDown(current.dispose);
      await tester.pumpWidget(_host(ValueListenableBuilder<LuminaWorld?>(
        valueListenable: current,
        builder: (context, w, _) => LuminaWidgetLayer(world: w),
      )));
      expect(find.byType(Stack), findsNothing);
      LuminaBlueprintFunctionLibrary.addToViewport(character, create('WBP_HUD'));
      await tester.pump();
      expect(find.text('FPS: 0'), findsNothing, reason: 'no world, nothing to render');
      current.value = world;
      await tester.pump();
      expect(find.text('FPS: 0'), findsOneWidget, reason: 'the widget added before the world arrived is shown');
      current.value = null;
      await tester.pump();
      expect(find.text('FPS: 0'), findsNothing);
    });
  });

  group('per-element state', () {
    testWidgets('set_element_text FPSCounter rebuilds only that Text; Title keeps its designer text', (tester) async {
      await tester.pumpWidget(_host(LuminaWidgetLayer(world: world)));
      final hud = create('WBP_HUD');
      LuminaBlueprintFunctionLibrary.addToViewport(character, hud);
      await tester.pump();
      expect(builds, {'FPSCounter': 1, 'Title': 1, 'Health': 1, 'Resume': 1});

      final fps = LuminaBlueprintFunctionLibrary.getWidgetElement(hud, 'FPSCounter');
      LuminaBlueprintFunctionLibrary.setElementText(character, fps, 'FPS: 60');
      await tester.pump();
      expect(find.text('FPS: 60'), findsOneWidget);
      expect(find.text('Designer title'), findsOneWidget);
      expect(builds, {'FPSCounter': 2, 'Title': 1, 'Health': 1, 'Resume': 1}, reason: 'only the bound Text rebuilt');

      LuminaBlueprintFunctionLibrary.setElementColor(character, fps, [1.0, 0.0, 0.0, 1.0]);
      LuminaBlueprintFunctionLibrary.setElementFontSize(character, fps, 32.0);
      await tester.pump();
      final text = tester.widget<Text>(find.byKey(const ValueKey('fpsCounter')));
      expect(text.style!.color, const Color(0xFFFF0000));
      expect(text.style!.fontSize, 32.0);
      expect(builds['Title'], 1);

      // A progress bar reads Set Percent / Set Fill Color the same way.
      final health = LuminaBlueprintFunctionLibrary.getWidgetElement(hud, 'Health');
      LuminaBlueprintFunctionLibrary.setElementPercent(character, health, 0.25);
      LuminaBlueprintFunctionLibrary.setElementFillColor(character, health, [0.0, 0.0, 1.0, 1.0]);
      await tester.pump();
      final bar = tester.widget<LuminaUmgProgressBar>(find.byType(LuminaUmgProgressBar));
      expect(bar.progress, 0.25);
      expect(bar.color, const Color(0xFF0000FF));
      expect(builds, {'FPSCounter': 3, 'Title': 1, 'Health': 2, 'Resume': 1});
    });

    testWidgets('Collapsed removes the element from layout; renderOpacity 0.5 wraps it in Opacity; isEnabled false disables a Button', (tester) async {
      await tester.pumpWidget(_host(LuminaWidgetLayer(world: world)));
      final hud = create('WBP_HUD');
      LuminaBlueprintFunctionLibrary.addToViewport(character, hud);
      await tester.pump();

      final title = LuminaBlueprintFunctionLibrary.getWidgetElement(hud, 'Title');
      LuminaBlueprintFunctionLibrary.setElementVisibility(character, title, 'Collapsed');
      await tester.pump();
      expect(find.byKey(const ValueKey('title')), findsNothing);
      expect(find.text('FPS: 0'), findsOneWidget);

      LuminaBlueprintFunctionLibrary.setElementVisibility(character, title, 'Hidden');
      await tester.pump();
      final hidden = tester.widget<Visibility>(find.ancestor(of: find.byKey(const ValueKey('title')), matching: find.byType(Visibility)));
      expect(hidden.visible, isFalse);
      expect(hidden.maintainSize, isTrue, reason: 'Hidden keeps the space, Collapsed does not');

      LuminaBlueprintFunctionLibrary.setElementVisibility(character, title, 'Visible');
      await tester.pump();
      expect(find.text('Designer title'), findsOneWidget);

      final fps = LuminaBlueprintFunctionLibrary.getWidgetElement(hud, 'FPSCounter');
      expect(find.ancestor(of: find.byKey(const ValueKey('fpsCounter')), matching: find.byType(Opacity)), findsNothing);
      LuminaBlueprintFunctionLibrary.setElementRenderOpacity(character, fps, 0.5);
      await tester.pump();
      final opacity = tester.widget<Opacity>(find.ancestor(of: find.byKey(const ValueKey('fpsCounter')), matching: find.byType(Opacity)));
      expect(opacity.opacity, 0.5);

      await tester.tap(find.byKey(const ValueKey('resume')));
      expect(resumed, 1);
      final resume = LuminaBlueprintFunctionLibrary.getWidgetElement(hud, 'Resume');
      LuminaBlueprintFunctionLibrary.setElementIsEnabled(character, resume, false);
      await tester.pump();
      expect(tester.widget<LuminaUmgButton>(find.byKey(const ValueKey('resume'))).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('resume')), warnIfMissed: false);
      expect(resumed, 1, reason: 'a disabled element ignores pointers');
      LuminaBlueprintFunctionLibrary.setElementLabel(character, resume, 'Continue');
      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Set Shadow Color and Opacity / Set Outline on FPSCounter change the rendered text in the headless game host', (tester) async {
      // The shape umg_widget_codegen emits for a Text with a designer shadow.
      LuminaWidgetBuilderRegistry.register('WBP_HUD', _hud, (context, instance) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LuminaUmgElement(
                instance: instance,
                name: 'FPSCounter',
                builder: (context, e) => LuminaUmgText(
                  key: const ValueKey('fpsCounter'),
                  LuminaUmgElementBinding.value<String>(e, 'text', 'FPS: 0'),
                  style: TextStyle(
                    fontSize: LuminaUmgElementBinding.value<double>(e, 'fontSize', 16.0),
                    color: LuminaUmgElementBinding.color(e, 'color', const Color(0xFFFFFFFF)),
                    shadows: LuminaUmgElementBinding.shadow(e, const LuminaUmgTextShadow(enabled: true, color: Color(0xB3000000), offsetX: 1.0, offsetY: 1.0, blur: 0.0)).shadows,
                  ),
                  outline: LuminaUmgElementBinding.outline(e, const LuminaUmgTextOutline(size: 0.0, color: Color(0xFF000000))),
                ),
              ),
            ],
          ));
      await tester.pumpWidget(_host(LuminaWidgetLayer(world: world)));
      final hud = create('WBP_HUD');
      LuminaBlueprintFunctionLibrary.addToViewport(character, hud);
      await tester.pump();
      List<Text> texts() => tester.widgetList<Text>(find.descendant(of: find.byKey(const ValueKey('fpsCounter')), matching: find.byType(Text), matchRoot: true)).toList();
      expect(texts().single.style!.shadows, [const Shadow(color: Color(0xB3000000), offset: Offset(1, 1))], reason: 'the designer shadow');

      final fps = LuminaBlueprintFunctionLibrary.getWidgetElement(hud, 'FPSCounter');
      LuminaBlueprintFunctionLibrary.setElementShadowColor(character, fps, [1.0, 0.0, 0.0, 0.5]);
      await tester.pump();
      expect(texts().single.style!.shadows, [const Shadow(color: Color(0x80FF0000), offset: Offset(1, 1))]);

      LuminaBlueprintFunctionLibrary.setElementOutline(character, fps, 2.0, [0.0, 0.0, 0.0, 1.0]);
      await tester.pump();
      final layers = texts();
      expect(layers, hasLength(2), reason: 'a stroked copy under the fill');
      expect(layers.first.style!.foreground!.strokeWidth, 4.0);
      expect(layers.first.style!.shadows!.single.color, const Color(0x80FF0000));

      LuminaBlueprintFunctionLibrary.setElementShadowEnabled(character, fps, false);
      await tester.pump();
      expect(texts().first.style!.shadows, isEmpty);
    });

    testWidgets('Set Background Color on a Container element repaints it in the headless game host', (tester) async {
      const panelClass = LuminaBlueprintWidgetClass(name: 'WBP_Panel', elements: [
        LuminaBlueprintWidgetElement(name: 'Panel', fieldName: 'panel', typeName: 'container', props: {'backgroundColor': '#1E1E2A', 'cornerRadius': 12.0}),
      ]);
      // The shape umg_widget_codegen emits for a Container.
      LuminaWidgetBuilderRegistry.register('WBP_Panel', panelClass, (context, instance) => Center(
            child: LuminaUmgElement(
              instance: instance,
              name: 'Panel',
              builder: (context, e) => LuminaUmgContainer(
                key: const ValueKey('panel'),
                style: LuminaUmgElementBinding.containerStyle(e, const LuminaUmgContainerStyle(
                  backgroundColor: Color(0xFF1E1E2A),
                  cornerRadius: BorderRadius.all(Radius.circular(12.0)),
                  width: 200.0,
                  height: 80.0,
                )),
              ),
            ),
          ));
      await tester.pumpWidget(_host(LuminaWidgetLayer(world: world)));
      final panel = create('WBP_Panel');
      LuminaBlueprintFunctionLibrary.addToViewport(character, panel);
      await tester.pump();
      BoxDecoration decoration() => tester.widget<Container>(find.descendant(of: find.byKey(const ValueKey('panel')), matching: find.byType(Container))).decoration! as BoxDecoration;
      expect(decoration().color, const Color(0xFF1E1E2A));
      expect(decoration().borderRadius, BorderRadius.circular(12));

      final element = LuminaBlueprintFunctionLibrary.getWidgetElement(panel, 'Panel');
      LuminaBlueprintFunctionLibrary.setElementBackgroundColor(character, element, [0.0, 0.5, 1.0, 1.0]);
      LuminaBlueprintFunctionLibrary.setElementCornerRadius(character, element, 4);
      await tester.pump();
      expect(decoration().color, const Color(0xFF0080FF));
      expect(decoration().borderRadius, BorderRadius.circular(4));
    });

    testWidgets('a deprecated Set Text (Widget) still reaches every Text element through the layer', (tester) async {
      await tester.pumpWidget(_host(LuminaWidgetLayer(world: world)));
      final hud = create('WBP_HUD');
      LuminaBlueprintFunctionLibrary.addToViewport(character, hud);
      await tester.pump();
      LuminaBlueprintFunctionLibrary.setWidgetText(character, hud, 'Both');
      await tester.pump();
      expect(find.text('Both'), findsNWidgets(2));
    });
  });
}
