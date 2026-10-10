part of '../node_library.dart';

const _event = 0xFFB71C1C;
const _legacy = 0xFFC62828;
const _function = 0xFF1565C0;
const _pure = 0xFF2E7D32;
const _math = 0xFF283593;
const _flow = 0xFF4527A0;
const _variable = 0xFF6A1B9A;

const _execIn = LuminaBlueprintPinSpec('exec_in', 'Exec In', LuminaPinType.exec);
const _execOut = LuminaBlueprintPinSpec('exec_out', 'Exec Out', LuminaPinType.exec);
const _returnValue = 'return_value';

LuminaBlueprintPinSpec _f(String id, String name, [double d = 0.0]) =>
    LuminaBlueprintPinSpec(id, name, LuminaPinType.float, defaultValue: d);
LuminaBlueprintPinSpec _i(String id, String name, [int d = 0]) =>
    LuminaBlueprintPinSpec(id, name, LuminaPinType.integer, defaultValue: d);
LuminaBlueprintPinSpec _b(String id, String name, [bool d = false]) =>
    LuminaBlueprintPinSpec(id, name, LuminaPinType.boolean, defaultValue: d);
LuminaBlueprintPinSpec _s(String id, String name, [String d = '']) =>
    LuminaBlueprintPinSpec(id, name, LuminaPinType.string, defaultValue: d);
LuminaBlueprintPinSpec _v(String id, String name, [List<double> d = const [0.0, 0.0, 0.0]]) =>
    LuminaBlueprintPinSpec(id, name, LuminaPinType.vector, defaultValue: d);
LuminaBlueprintPinSpec _rot(String id, String name) =>
    LuminaBlueprintPinSpec(id, name, LuminaPinType.rotator, defaultValue: const [0.0, 0.0, 0.0]);
LuminaBlueprintPinSpec _obj(String id, String name, [String? cls]) =>
    LuminaBlueprintPinSpec(id, name, LuminaPinType.object, objectClass: cls);
LuminaBlueprintPinSpec _color(String id, String name, [List<double> d = const [1.0, 1.0, 1.0, 1.0]]) =>
    LuminaBlueprintPinSpec(id, name, LuminaPinType.color, defaultValue: d);
LuminaBlueprintPinSpec _ret(LuminaPinType t, {String? cls, String name = 'Return Value'}) =>
    LuminaBlueprintPinSpec(_returnValue, name, t, objectClass: cls);

LuminaBlueprintPinSpec _any(String id, String name) => LuminaBlueprintPinSpec(id, name, LuminaPinType.wildcard);
LuminaBlueprintPinSpec _delegate(String id, String name) => LuminaBlueprintPinSpec(id, name, LuminaPinType.delegate);
LuminaBlueprintPinSpec _handle(String id, String name) => LuminaBlueprintPinSpec(id, name, LuminaPinType.timerHandle);
LuminaBlueprintPinSpec _enum(String id, String name, [String? enumName]) =>
    LuminaBlueprintPinSpec(id, name, LuminaPinType.enumeration, enumName: enumName);
LuminaBlueprintPinSpec _exec(String id, String name) => LuminaBlueprintPinSpec(id, name, LuminaPinType.exec);

/// Load Level's data outputs, fresh on every result pin.
final List<LuminaBlueprintPinSpec> _levelLoadOutputs = [
  _f('percent', 'Percent'),
  _i('total_count', 'Total Count'),
  _i('loaded_count', 'Loaded Count'),
  _s('current_content', 'Current Content'),
  _s('error', 'Error'),
  _s('stack_trace', 'Stack Trace'),
];
LuminaBlueprintPinSpec _arr(String id, String name) => LuminaBlueprintPinSpec(id, name, LuminaPinType.array);
LuminaBlueprintPinSpec _xf(String id, String name) => LuminaBlueprintPinSpec(id, name, LuminaPinType.transform);

/// A pure math node: typed inputs, one typed output.
LuminaBlueprintNodeSpec _pureNode(String id, String title, String category, List<LuminaBlueprintPinSpec> inputs,
        LuminaBlueprintPinSpec out, List<String> keywords) =>
    LuminaBlueprintNodeSpec(
      id: id,
      title: title,
      category: category,
      kind: LuminaBlueprintNodeKind.pure,
      headerColor: category.startsWith('Math') ? _math : _pure,
      keywords: keywords,
      inputs: inputs,
      outputs: [out],
    );

/// The target pin of a widget element node: any element, or one type.
LuminaBlueprintPinSpec _element([String? type]) => _obj('target', 'Target',
    type == null ? LuminaBlueprintObjectClass.widgetElementKind : LuminaBlueprintObjectClass.widgetElement(type));

/// The target pin of a component node.
LuminaBlueprintPinSpec _comp(String componentClass, [String id = 'target', String name = 'Target']) =>
    _obj(id, name, LuminaBlueprintObjectClass.component(componentClass));

/// A widget element setter: exec in, the element, one value; exec out.
LuminaBlueprintNodeSpec _elementSet(String id, String title, String category, String? type, LuminaBlueprintPinSpec value,
        List<String> keywords) =>
    LuminaBlueprintNodeSpec(
      id: id,
      title: title,
      category: category,
      kind: LuminaBlueprintNodeKind.impure,
      headerColor: _function,
      keywords: ['widget', 'ui', 'element', ...keywords],
      inputs: [_execIn, _element(type), value],
      outputs: const [_execOut],
    );

/// A widget element getter: the element in, one value out.
LuminaBlueprintNodeSpec _elementGet(String id, String title, String category, String? type, LuminaPinType out,
        List<String> keywords) =>
    LuminaBlueprintNodeSpec(
      id: id,
      title: title,
      category: category,
      kind: LuminaBlueprintNodeKind.pure,
      headerColor: _pure,
      keywords: ['widget', 'ui', 'element', ...keywords],
      inputs: [_element(type)],
      outputs: [_ret(out)],
    );

/// A component setter: exec in, the component, values; exec out.
LuminaBlueprintNodeSpec _compSet(String id, String title, String category, String componentClass,
        List<LuminaBlueprintPinSpec> values, List<String> keywords) =>
    LuminaBlueprintNodeSpec(
      id: id,
      title: title,
      category: category,
      kind: LuminaBlueprintNodeKind.impure,
      headerColor: _function,
      keywords: ['component', ...keywords],
      inputs: [_execIn, _comp(componentClass), ...values],
      outputs: const [_execOut],
    );

/// A component getter: the component in, one value out.
LuminaBlueprintNodeSpec _compGet(String id, String title, String category, String componentClass,
        LuminaBlueprintPinSpec out, List<String> keywords,
        [List<LuminaBlueprintPinSpec> extraInputs = const []]) =>
    LuminaBlueprintNodeSpec(
      id: id,
      title: title,
      category: category,
      kind: LuminaBlueprintNodeKind.pure,
      headerColor: _pure,
      keywords: ['component', ...keywords],
      inputs: [_comp(componentClass), ...extraInputs],
      outputs: [out],
    );
