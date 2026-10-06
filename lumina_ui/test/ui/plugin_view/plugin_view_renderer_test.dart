import 'package:flutter/material.dart' as m show Material, InkWell, Checkbox, TextField, LinearProgressIndicator, ElevatedButton;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart';
import 'package:lumina_ui/ui/core/property_editors/color_field.dart';
import 'package:lumina_ui/ui/core/property_editors/enum_field.dart';
import 'package:lumina_ui/ui/core/property_editors/scrub_numeric_field.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/widgets/plugin_view/plugin_log_control.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'plugin_view_harness.dart';

const _view = 'gen';

/// A generator panel with every input kind, as a plugin process sends it.
PluginViewSpec _panel({bool enabled = true}) => PluginViewSpec(id: _view, children: [
      PluginControl.section('settings', 'Settings', [
        PluginControl.text('intro', 'Scatter rocks over the selected landscape.', style: 'muted'),
        PluginControl(kind: PluginControlKind.textField, id: 'name', props: {
          'label': 'Name',
          'value': 'Rocks',
          'placeholder': 'Layer name',
          'enabled': enabled,
        }),
        PluginControl(kind: PluginControlKind.numberField, id: 'count', props: {
          'label': 'Count',
          'value': 120,
          'step': 1,
          'enabled': enabled,
        }),
        PluginControl(kind: PluginControlKind.numberField, id: 'density', props: {
          'label': 'Density',
          'value': 0.5,
          'min': 0,
          'max': 1,
          'step': 0.05,
          'enabled': enabled,
        }),
        PluginControl(kind: PluginControlKind.boolField, id: 'align', props: {'label': 'Align to normal', 'value': false, 'enabled': enabled}),
        PluginControl(kind: PluginControlKind.enumField, id: 'mode', props: {
          'label': 'Mode',
          'value': 'poisson',
          'options': [
            {'value': 'poisson', 'label': 'Poisson disk'},
            {'value': 'grid', 'label': 'Jittered grid'},
          ],
          'enabled': enabled,
        }),
        PluginControl(kind: PluginControlKind.colorField, id: 'tint', props: {'label': 'Tint', 'value': '#808080', 'enabled': enabled}),
      ]),
      PluginControl.row('actions', [
        PluginControl(kind: PluginControlKind.button, id: 'run', props: {'text': 'Generate', 'tone': 'primary', 'enabled': enabled}),
        PluginControl(kind: PluginControlKind.button, id: 'clear', props: {'text': 'Clear', 'tone': 'destructive', 'enabled': enabled}),
      ]),
      PluginControl.divider('sep'),
      PluginControl.progress('job', value: 0.25, text: 'Sampling points'),
      PluginControl(kind: PluginControlKind.log, id: 'log', props: {
        'lines': ['started', 'sampled 30 points'],
      }),
    ]);

void main() {
  testWidgets('every control renders with the editor shadcn widgets, no Material', (tester) async {
    final h = PluginViewHarness(_panel());
    await h.pump(tester);

    for (final id in ['settings', 'intro', 'name', 'count', 'density', 'align', 'mode', 'tint', 'actions', 'run', 'clear', 'sep', 'job', 'log']) {
      expect(byControl(_view, id), findsOneWidget, reason: id);
    }
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('Scatter rocks over the selected landscape.'), findsOneWidget);
    expect(find.descendant(of: byControl(_view, 'name'), matching: find.byType(TextField)), findsOneWidget);
    expect(find.descendant(of: byControl(_view, 'count'), matching: find.byType(ScrubNumericField)), findsOneWidget);
    expect(find.descendant(of: byControl(_view, 'density'), matching: find.byType(SliderField)), findsOneWidget);
    expect(find.descendant(of: byControl(_view, 'align'), matching: find.byType(Checkbox)), findsOneWidget);
    expect(find.descendant(of: byControl(_view, 'mode'), matching: find.byType(EnumField)), findsOneWidget);
    expect(find.text('Poisson disk'), findsOneWidget);
    expect(find.descendant(of: byControl(_view, 'tint'), matching: find.byType(ColorField)), findsOneWidget);
    expect(find.descendant(of: byControl(_view, 'run'), matching: find.byType(Button)), findsOneWidget);
    expect(find.descendant(of: byControl(_view, 'job'), matching: find.byType(LinearProgressIndicator)), findsOneWidget);
    expect(find.text('Sampling points'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);

    expect(find.byType(m.Material), findsNothing);
    expect(find.byType(m.InkWell), findsNothing);
    expect(find.byType(m.Checkbox), findsNothing);
    expect(find.byType(m.TextField), findsNothing);
    expect(find.byType(m.LinearProgressIndicator), findsNothing);
    expect(find.byType(m.ElevatedButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing and submitting, toggling, picking and pressing send their events', (tester) async {
    final h = PluginViewHarness(_panel());
    await h.pump(tester);

    final name = find.descendant(of: byControl(_view, 'name'), matching: find.byType(EditableText));
    await tester.tap(name);
    await tester.pump();
    await tester.enterText(name, 'Boulders');
    await tester.pump();
    expect(h.sent, isEmpty, reason: 'typing alone sends nothing');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    await tester.tap(find.descendant(of: byControl(_view, 'align'), matching: find.byType(Checkbox)));
    await tester.pump();

    await tester.tap(find.text('Poisson disk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jittered grid'));
    await tester.pumpAndSettle();

    final count = find.descendant(of: byControl(_view, 'count'), matching: find.byType(EditableText));
    await tester.tap(count);
    await tester.pump();
    await tester.enterText(count, '250');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final tint = find.descendant(of: byControl(_view, 'tint'), matching: find.byType(EditableText));
    await tester.tap(tint);
    await tester.pump();
    await tester.enterText(tint, '#33aa55');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    await tester.tap(find.text('Generate'));
    await tester.pump();

    expect(h.sent, [
      ('name', 'changed', 'Boulders'),
      ('align', 'changed', true),
      ('mode', 'changed', 'grid'),
      ('count', 'changed', 250),
      ('tint', 'changed', '#33AA55'),
      ('run', 'pressed', null),
    ]);
    expect(h.events.every((e) => e.viewId == _view), isTrue);
    // The editor shows what the user chose before the plugin answers.
    expect(find.text('Jittered grid'), findsOneWidget);
  });

  testWidgets('disabled controls send nothing', (tester) async {
    final h = PluginViewHarness(_panel(enabled: false));
    await h.pump(tester);

    await tester.tap(find.text('Generate'), warnIfMissed: false);
    await tester.tap(find.descendant(of: byControl(_view, 'align'), matching: find.byType(Checkbox)), warnIfMissed: false);
    await tester.tap(find.text('Poisson disk'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Jittered grid'), findsNothing, reason: 'the option list never opened');

    final name = find.descendant(of: byControl(_view, 'name'), matching: find.byType(EditableText));
    await tester.tap(name, warnIfMissed: false);
    await tester.pump();
    expect(tester.widget<EditableText>(name).focusNode.hasFocus, isFalse);

    expect(h.sent, isEmpty);
  });

  testWidgets('a patch rebuilds only its control; a focused field keeps its caret and typing', (tester) async {
    final h = PluginViewHarness(_panel());
    await h.pump(tester);

    final name = find.descendant(of: byControl(_view, 'name'), matching: find.byType(EditableText));
    await tester.tap(name);
    await tester.pump();
    await tester.enterText(name, 'Pebbles');
    final editable = tester.widget<EditableText>(name);
    editable.controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();

    final nameWidget = tester.widget(byControl(_view, 'name'));
    final logWidget = tester.widget(byControl(_view, 'log'));
    final jobWidget = tester.widget(byControl(_view, 'job'));

    await h.patch(tester, const PluginViewPatch([
      PluginViewPatchOp.set('job', {'value': 0.75, 'text': 'Placing instances'}),
    ]));

    expect(find.text('Placing instances'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(identical(tester.widget(byControl(_view, 'job')), jobWidget), isFalse, reason: 'the patched control rebuilt');
    expect(identical(tester.widget(byControl(_view, 'name')), nameWidget), isTrue, reason: 'the text field was not rebuilt');
    expect(identical(tester.widget(byControl(_view, 'log')), logWidget), isTrue);

    final after = tester.widget<EditableText>(name);
    expect(after.focusNode.hasFocus, isTrue);
    expect(after.controller.text, 'Pebbles');
    expect(after.controller.selection, const TextSelection.collapsed(offset: 3));

    // An identical spec rebuilt from JSON (a full resend) clobbers nothing.
    h.spec.value = PluginViewSpec.fromJson(h.spec.value.toJson());
    await tester.pump();
    expect(identical(tester.widget(byControl(_view, 'name')), nameWidget), isTrue);
    expect(tester.widget<EditableText>(name).controller.text, 'Pebbles');

    // A new value from the plugin waits while the user is typing...
    await h.patch(tester, const PluginViewPatch([PluginViewPatchOp.set('name', {'value': 'Gravel'})]));
    expect(tester.widget<EditableText>(name).controller.text, 'Pebbles');
    // ...leaving the field commits the typing...
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(h.sent, [('name', 'changed', 'Pebbles')]);
    // ...and the plugin's next value shows.
    await h.patch(tester, const PluginViewPatch([PluginViewPatchOp.set('name', {'value': 'Sand'})]));
    expect(tester.widget<EditableText>(name).controller.text, 'Sand');
  });

  testWidgets('the window going to the background does not send a half-typed field', (tester) async {
    // Desktop: focus is parked while the window is in the background.
    tester.binding.focusManager.listenToApplicationLifecycleChangesIfSupported();
    final h = PluginViewHarness(_panel());
    await h.pump(tester);
    addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));

    final name = find.descendant(of: byControl(_view, 'name'), matching: find.byType(EditableText));
    await tester.tap(name);
    await tester.pump();
    await tester.enterText(name, 'Gr');
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(tester.widget<EditableText>(name).focusNode.hasFocus, isFalse);
    expect(h.sent, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.widget<EditableText>(name).focusNode.hasFocus, isTrue);
    await tester.enterText(name, 'Granite');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(h.sent, [('name', 'changed', 'Granite')]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('sections collapse locally and the indeterminate bar has no percentage', (tester) async {
    final h = PluginViewHarness(PluginViewSpec(id: _view, children: [
      PluginControl.section('advanced', 'Advanced', [PluginControl.text('hint', 'Seed and spacing')], collapsed: true),
      PluginControl.progress('wait', text: 'Waiting for the worker'),
    ]));
    await h.pump(tester);

    expect(find.text('Seed and spacing'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('$_view/advanced/header')));
    await tester.pump();
    expect(find.text('Seed and spacing'), findsOneWidget);
    expect(h.sent, isEmpty, reason: 'collapsing is local UI state');

    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, isNull);
    expect(find.text('Waiting for the worker'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('an unknown kind renders a muted fallback line, never throws', (tester) async {
    final h = PluginViewHarness(const PluginViewSpec(id: _view, children: [
      PluginControl(kind: 'sparkline', id: 'fps', props: {'values': [1, 2, 3]}),
      PluginControl(kind: PluginControlKind.text, id: 'after', props: {'value': 'still here'}),
    ]));
    await h.pump(tester);

    expect(find.text('unsupported control sparkline'), findsOneWidget);
    expect(find.text('still here'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the log keeps the newest maxLines and follows new lines', (tester) async {
    final h = PluginViewHarness(PluginViewSpec(id: _view, children: [
      PluginControl(kind: PluginControlKind.log, id: 'log', props: {
        'lines': [for (var i = 0; i < 300; i++) 'line $i'],
        'maxLines': 50,
      }),
    ]));
    await h.pump(tester);
    await tester.pump();

    String shown() => tester.widget<Text>(find.byKey(const ValueKey('$_view/log/text'))).data!;
    expect(shown().split('\n'), [for (var i = 250; i < 300; i++) 'line $i']);
    expect(PluginLogControl.keptLines(h.spec.value.find('log')!).length, 50);
    expect(tester.widget<Text>(find.byKey(const ValueKey('$_view/log/text'))).style?.fontFamily, 'JetBrains Mono');

    await h.patch(tester, PluginViewPatch([
      PluginViewPatchOp.set('log', {
        'lines': [for (var i = 0; i < 301; i++) 'line $i'],
      }),
    ]));
    await tester.pump();
    expect(shown().split('\n').first, 'line 251');
    expect(shown().split('\n').last, 'line 300');
    final scrollable = tester.state<ScrollableState>(
        find.descendant(of: byControl(_view, 'log'), matching: find.byType(Scrollable)));
    expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);
  });
}
