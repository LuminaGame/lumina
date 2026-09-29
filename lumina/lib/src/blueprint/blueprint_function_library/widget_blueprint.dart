part of '../blueprint_function_library.dart';

// --- Widget Blueprint graphs ----------------------------------------

/// `Get <Element>` in a widget's own graph: the state of its `Is Variable`
/// element [element] (designer name); null outside a widget script.
Object? _getWidgetVariable(LuminaActor self, String element) => self is LuminaUserWidget ? self.widgetElement(element) : null;

/// Self in a widget's own graph: the widget instance map.
Object? _getWidgetSelf(LuminaActor self) => self is LuminaUserWidget ? self.widgetInstance : null;

/// A widget node's Target when it is left unwired: the calling widget, in a
/// widget's own graph (`Target: self`); null elsewhere.
Object? _widgetTarget(LuminaActor self, Object? target) => target ?? (self is LuminaUserWidget ? self.widgetInstance : null);

final Map<String, LuminaBlueprintFunction> _widgetBlueprintFunctions = <String, LuminaBlueprintFunction>{
  LuminaBlueprintNodeLibrary.getWidgetVariable: (c, i) =>
      LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getWidgetVariable(c.self, i['element'] as String? ?? '')),
  LuminaBlueprintNodeLibrary.getWidgetSelf: (c, i) => LuminaBlueprintFunctionLibrary._ret(LuminaBlueprintFunctionLibrary.getWidgetSelf(c.self)),
};

final Map<String, LuminaBlueprintCallShape> _widgetBlueprintCallShapes = <String, LuminaBlueprintCallShape>{
  LuminaBlueprintNodeLibrary.getWidgetVariable:
      const LuminaBlueprintCallShape('getWidgetVariable', ['element'], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
  LuminaBlueprintNodeLibrary.getWidgetSelf: const LuminaBlueprintCallShape('getWidgetSelf', [], self: true, outputs: LuminaBlueprintFunctionLibrary._r),
};
