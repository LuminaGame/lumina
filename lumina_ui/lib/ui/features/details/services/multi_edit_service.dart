import 'package:lumina_ui/ui/features/details/models/editor_component_node.dart';
import 'package:lumina_ui/ui/features/details/models/component_property_registry.dart';
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';

class MultiEditComponentProperty {
  final String propertyId;
  final PropertyDescriptor descriptor;
  final bool isMixed;
  final dynamic commonValue;
  // For Vector3, we track mixed state per axis (X, Y, Z)
  final List<bool>? isMixedPerAxis;
  final List<double>? commonVector;

  MultiEditComponentProperty({
    required this.propertyId,
    required this.descriptor,
    required this.isMixed,
    this.commonValue,
    this.isMixedPerAxis,
    this.commonVector,
  });
}

class MultiEditComponentBlock {
  final String componentType;
  final String componentName;
  final bool isMixedEnabled;
  final bool? commonEnabled;
  final List<MultiEditComponentProperty> properties;

  MultiEditComponentBlock({
    required this.componentType,
    required this.componentName,
    required this.isMixedEnabled,
    this.commonEnabled,
    required this.properties,
  });
}

class MultiEditView {
  final bool isMixedVisible;
  final bool? commonVisible;
  final bool isMixedLocked;
  final bool? commonLocked;
  
  // Transform
  final List<bool> locationMixed;
  final List<double> locationCommon;
  final List<bool> rotationMixed;
  final List<double> rotationCommon;
  final List<bool> scaleMixed;
  final List<double> scaleCommon;
  
  // Common Components intersection
  final List<MultiEditComponentBlock> components;

  MultiEditView({
    required this.isMixedVisible,
    this.commonVisible,
    required this.isMixedLocked,
    this.commonLocked,
    required this.locationMixed,
    required this.locationCommon,
    required this.rotationMixed,
    required this.rotationCommon,
    required this.scaleMixed,
    required this.scaleCommon,
    required this.components,
  });
}

class MultiEditService {
  static MultiEditView computeMultiEditView(List<EditorActorNode> actors) {
    if (actors.isEmpty) {
      return MultiEditView(
        isMixedVisible: false, commonVisible: true,
        isMixedLocked: false, commonLocked: false,
        locationMixed: [false, false, false], locationCommon: [0,0,0],
        rotationMixed: [false, false, false], rotationCommon: [0,0,0],
        scaleMixed: [false, false, false], scaleCommon: [1,1,1],
        components: [],
      );
    }
    
    bool mixedVisible = false;
    bool? commonVisible = actors.first.isVisible;
    bool mixedLocked = false;
    bool? commonLocked = actors.first.isLocked;

    List<bool> locMixed = [false, false, false];
    List<double> locCommon = List.from(actors.first.location);
    
    List<bool> rotMixed = [false, false, false];
    List<double> rotCommon = List.from(actors.first.rotation);
    
    List<bool> scaleMixed = [false, false, false];
    List<double> scaleCommon = List.from(actors.first.scale);

    // Identify intersection of component types
    Map<String, int> typeCounts = {};
    for (final actor in actors) {
      final seenTypes = <String>{};
      for (final comp in actor.components) {
        seenTypes.add(comp.type);
      }
      for (final type in seenTypes) {
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }
      
      if (actor.isVisible != commonVisible) {
        mixedVisible = true;
        commonVisible = null;
      }
      if (actor.isLocked != commonLocked) {
        mixedLocked = true;
        commonLocked = null;
      }
      
      for (int i = 0; i < 3; i++) {
        if (!locMixed[i] && (actor.location[i] - locCommon[i]).abs() > 1e-6) locMixed[i] = true;
        if (!rotMixed[i] && (actor.rotation[i] - rotCommon[i]).abs() > 1e-6) rotMixed[i] = true;
        if (!scaleMixed[i] && (actor.scale[i] - scaleCommon[i]).abs() > 1e-6) scaleMixed[i] = true;
      }
    }
    
    List<MultiEditComponentBlock> commonBlocks = [];
    final commonTypes = typeCounts.entries.where((e) => e.value == actors.length).map((e) => e.key).toList();
    
    for (final type in commonTypes) {
      final desc = ComponentPropertyRegistry.descriptors[type];
      if (desc == null) continue;
      
      bool mixedEnabled = false;
      bool? commonEnabled;
      String? compName;
      
      List<EditorComponentNode> typeInstances = [];
      for (final actor in actors) {
        final c = actor.components.firstWhere((c) => c.type == type);
        typeInstances.add(c);
        if (compName == null) {
          compName = c.name;
          commonEnabled = c.enabled;
        } else {
          if (c.enabled != commonEnabled) {
            mixedEnabled = true;
            commonEnabled = null;
          }
        }
      }
      
      List<MultiEditComponentProperty> blockProps = [];
      for (final propDesc in desc.properties) {
        bool isMixed = false;
        dynamic commonVal = typeInstances.first.properties[propDesc.id] ?? propDesc.defaultValue;
        
        List<bool>? mixedPerAxis;
        List<double>? commonVec;
        
        if (propDesc.editor == PropertyEditorType.vector3) {
          mixedPerAxis = [false, false, false];
          final cv = (commonVal as List).map((e) => (e as num).toDouble()).toList();
          commonVec = cv;
          
          for (final inst in typeInstances) {
            final v = (inst.properties[propDesc.id] ?? propDesc.defaultValue) as List;
            for (int i=0; i<3; i++) {
              if (!mixedPerAxis[i] && ((v[i] as num).toDouble() - cv[i]).abs() > 1e-6) {
                mixedPerAxis[i] = true;
                isMixed = true;
              }
            }
          }
        } else if (propDesc.editor == PropertyEditorType.float) {
          double c = (commonVal as num).toDouble();
          for (final inst in typeInstances) {
            final val = inst.properties[propDesc.id] ?? propDesc.defaultValue;
            if (((val as num).toDouble() - c).abs() > 1e-6) {
              isMixed = true;
              commonVal = null;
              break;
            }
          }
        } else {
          for (final inst in typeInstances) {
            final val = inst.properties[propDesc.id] ?? propDesc.defaultValue;
            if (val != commonVal) {
              isMixed = true;
              commonVal = null;
              break;
            }
          }
        }
        
        blockProps.add(MultiEditComponentProperty(
          propertyId: propDesc.id,
          descriptor: propDesc,
          isMixed: isMixed,
          commonValue: commonVal,
          isMixedPerAxis: mixedPerAxis,
          commonVector: commonVec,
        ));
      }
      
      commonBlocks.add(MultiEditComponentBlock(
        componentType: type,
        componentName: compName!,
        isMixedEnabled: mixedEnabled,
        commonEnabled: commonEnabled,
        properties: blockProps,
      ));
    }
    
    return MultiEditView(
      isMixedVisible: mixedVisible, commonVisible: commonVisible,
      isMixedLocked: mixedLocked, commonLocked: commonLocked,
      locationMixed: locMixed, locationCommon: locCommon,
      rotationMixed: rotMixed, rotationCommon: rotCommon,
      scaleMixed: scaleMixed, scaleCommon: scaleCommon,
      components: commonBlocks,
    );
  }
}
