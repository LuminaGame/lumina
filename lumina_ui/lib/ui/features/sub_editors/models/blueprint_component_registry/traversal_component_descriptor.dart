import 'package:shadcn_flutter/shadcn_flutter.dart' show LucideIcons;

import 'package:lumina_ui/ui/features/sub_editors/models/blueprint_component_registry.dart';

/// The traversal component (hurdle, vault, mantle) as the Blueprint editor
/// adds it: its check tunables. The chooser rows (`animations`) are written
/// by whoever builds the clip set, such as the Game Animation Sample builder.
const ComponentTypeDescriptor traversalComponentDescriptor = ComponentTypeDescriptor(
  typeName: 'LuminaTraversalComponent',
  displayName: 'Traversal',
  category: 'Movement',
  isSceneComponent: false,
  icon: LucideIcons.footprints,
  properties: [
    ComponentPropertySchema(group: 'TRAVERSAL', name: 'Enabled', dartField: 'enabled', type: ComponentPropertyType.boolean, defaultValue: true),
    ComponentPropertySchema(
        group: 'TRAVERSAL', name: 'Min Ledge Height', dartField: 'minLedgeHeight', type: ComponentPropertyType.number, defaultValue: 50.0, min: 10.0, max: 200.0),
    ComponentPropertySchema(
        group: 'TRAVERSAL', name: 'Max Ledge Height', dartField: 'maxLedgeHeight', type: ComponentPropertyType.number, defaultValue: 275.0, min: 50.0, max: 500.0),
    ComponentPropertySchema(
        group: 'TRAVERSAL', name: 'Min Trace Distance', dartField: 'minTraceDistance', type: ComponentPropertyType.number, defaultValue: 75.0, min: 10.0, max: 500.0),
    ComponentPropertySchema(
        group: 'TRAVERSAL', name: 'Max Trace Distance', dartField: 'maxTraceDistance', type: ComponentPropertyType.number, defaultValue: 350.0, min: 10.0, max: 1000.0),
    ComponentPropertySchema(group: 'TRAVERSAL', name: 'Root Bone', dartField: 'rootBone', type: ComponentPropertyType.string, defaultValue: ''),
    ComponentPropertySchema(group: 'TRAVERSAL', name: 'Debug Draw', dartField: 'debugDraw', type: ComponentPropertyType.boolean, defaultValue: false),
  ],
);
