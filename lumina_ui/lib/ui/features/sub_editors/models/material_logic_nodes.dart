import 'package:lumina_editor_data/lumina_editor.dart' show LuminaBlueprintNode;
import 'package:lumina_ui/ui/features/sub_editors/models/material_graph.dart';

// design-token-exempt: node header colours follow material node conventions,
// not the editor chrome palette.
const int _logicColor = 0xFF8E2430;

/// The material graph's logic expressions: Compare, And, Or, Not and If.
///
/// A comparison yields a `bool` ([MaterialValueType.boolean]); bools feed only
/// And / Or / Not and an If's Condition, never float math. If picks its Then
/// or Else value by the condition and is written as the GLSL conditional
/// `(c ? t : f)`, so both values are evaluated (fine for pure expressions and
/// texture samples).
abstract final class MaterialLogicNodes {
  static const String compare = 'mat_compare';
  static const String and = 'mat_and';
  static const String or = 'mat_or';
  static const String not = 'mat_not';
  static const String ifNode = 'mat_if';

  static const String category = 'Logic';

  /// Compare's operators, in the order the editor lists them.
  static const List<String> operators = ['>', '>=', '<', '<=', '==', '!='];
  static const String defaultOperator = '>=';

  /// Height of the operator select a Compare node draws under its header.
  static const double compareBodyHeight = 30;

  static const List<String> _keywords = ['if', 'branch', 'select', 'condition', 'compare', 'and', 'or', 'not'];

  static const List<MaterialNodeSpec> specs = [
    MaterialNodeSpec(
      id: compare,
      title: 'Compare',
      category: category,
      headerColor: _logicColor,
      keywords: [..._keywords, '>', '>=', '<', '<=', '==', '!=', 'greater', 'less', 'equal'],
      inputs: [
        MaterialPinDef('a', 'A', type: MaterialValueType.float1, defaultValue: 0.0),
        MaterialPinDef('b', 'B', type: MaterialValueType.float1, defaultValue: 0.0),
      ],
      outputs: [MaterialPinDef('out', '', type: MaterialValueType.boolean)],
      defaults: {'op': defaultOperator},
      tooltip: 'Compares two floats (A > B, A >= B, A < B, A <= B, A == B, A != B) into a bool for an If, '
          'And, Or or Not.',
    ),
    MaterialNodeSpec(
      id: and,
      title: 'And',
      category: category,
      headerColor: _logicColor,
      keywords: [..._keywords, '&&'],
      inputs: [
        MaterialPinDef('a', 'A', type: MaterialValueType.boolean),
        MaterialPinDef('b', 'B', type: MaterialValueType.boolean),
      ],
      outputs: [MaterialPinDef('out', '', type: MaterialValueType.boolean)],
      tooltip: 'True when both A and B are true (A && B).',
    ),
    MaterialNodeSpec(
      id: or,
      title: 'Or',
      category: category,
      headerColor: _logicColor,
      keywords: [..._keywords, '||'],
      inputs: [
        MaterialPinDef('a', 'A', type: MaterialValueType.boolean),
        MaterialPinDef('b', 'B', type: MaterialValueType.boolean),
      ],
      outputs: [MaterialPinDef('out', '', type: MaterialValueType.boolean)],
      tooltip: 'True when A or B is true (A || B).',
    ),
    MaterialNodeSpec(
      id: not,
      title: 'Not',
      category: category,
      headerColor: _logicColor,
      keywords: [..._keywords, '!', 'invert', 'negate'],
      inputs: [MaterialPinDef('a', 'A', type: MaterialValueType.boolean)],
      outputs: [MaterialPinDef('out', '', type: MaterialValueType.boolean)],
      tooltip: 'True when A is false (!A).',
    ),
    MaterialNodeSpec(
      id: ifNode,
      title: 'If',
      category: category,
      headerColor: _logicColor,
      keywords: [..._keywords, 'else', 'ternary', 'switch', 'choose', '?:'],
      inputs: [
        MaterialPinDef('condition', 'Condition', type: MaterialValueType.boolean),
        MaterialPinDef('then', 'Then', defaultValue: 1.0),
        MaterialPinDef('else', 'Else', defaultValue: 0.0),
      ],
      outputs: [MaterialPinDef('out', 'Result')],
      tooltip: 'Picks Then where Condition holds, else Else; both are evaluated (`c ? t : f`). Then and Else '
          'are the same type (a float broadcasts); Result is that type.',
    ),
  ];

  static bool isLogic(String registryId) =>
      registryId == compare || registryId == and || registryId == or || registryId == not || registryId == ifNode;

  /// A Compare node's operator (`>=` when unset or unknown).
  static String operatorOf(LuminaBlueprintNode node) {
    final op = node.literals['op'];
    return op is String && operators.contains(op) ? op : defaultOperator;
  }

  /// The canvas title of a logic node: a Compare shows its operator.
  static String? titleOf(LuminaBlueprintNode node) =>
      node.registryId == compare ? 'Compare (A ${operatorOf(node)} B)' : null;
}
