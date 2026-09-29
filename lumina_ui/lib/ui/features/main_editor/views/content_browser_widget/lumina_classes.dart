part of '../content_browser_widget.dart';

// The Lumina classes offered as Blueprint parents.

class _LuminaClassInfo {
  final String className;
  final String category;
  final String description;
  final IconData icon;

  const _LuminaClassInfo({
    required this.className,
    required this.category,
    required this.description,
    required this.icon,
  });
}

const List<_LuminaClassInfo> _allLuminaClasses = [
  // Actors & Framework
  _LuminaClassInfo(
    className: 'LuminaActor',
    category: 'Actors & Framework',
    description:
        'Base 3D world object capable of transforms, components & ticking.',
    icon: LucideIcons.box,
  ),
  _LuminaClassInfo(
    className: 'LuminaPawn',
    category: 'Actors & Framework',
    description: 'Possessable actor controllable by player or AI controllers.',
    icon: LucideIcons.user,
  ),
  _LuminaClassInfo(
    className: 'LuminaCharacter',
    category: 'Actors & Framework',
    description:
        'Bipedal pawn with capsule collision & character movement physics.',
    icon: LucideIcons.userCheck,
  ),
  _LuminaClassInfo(
    className: 'LuminaGameMode',
    category: 'Actors & Framework',
    description:
        'Defines game rules, match state & default pawn spawning logic.',
    icon: LucideIcons.gamepad2,
  ),
  _LuminaClassInfo(
    className: 'LuminaController',
    category: 'Actors & Framework',
    description: 'Base controller agent that directs a Pawn actor.',
    icon: LucideIcons.cpu,
  ),
  _LuminaClassInfo(
    className: 'LuminaPlayerController',
    category: 'Actors & Framework',
    description:
        'Player-facing controller handling camera, mouse & keyboard input.',
    icon: LucideIcons.gamepad,
  ),
  _LuminaClassInfo(
    className: 'LuminaPlayerState',
    category: 'Actors & Framework',
    description: 'Holds player scores, stats and player state properties.',
    icon: LucideIcons.userPlus,
  ),
  _LuminaClassInfo(
    className: 'LuminaLevelScriptActor',
    category: 'Actors & Framework',
    description:
        'Level-specific actor for world trigger events & level scripting.',
    icon: LucideIcons.scroll,
  ),

  // Components
  _LuminaClassInfo(
    className: 'LuminaActorComponent',
    category: 'Components',
    description: 'Reusable logic component attachable to any LuminaActor.',
    icon: LucideIcons.component,
  ),
  _LuminaClassInfo(
    className: 'LuminaSceneComponent',
    category: 'Components',
    description:
        'Component with 3D transform (location, rotation, scale) & attachment hierarchy.',
    icon: LucideIcons.move3d,
  ),
  _LuminaClassInfo(
    className: 'LuminaCameraComponent',
    category: 'Components',
    description: '3D viewport camera for rendering views and projections.',
    icon: LucideIcons.camera,
  ),
  _LuminaClassInfo(
    className: 'LuminaSpringArmComponent',
    category: 'Components',
    description:
        'Camera boom arm for smooth 3rd-person camera follow & collision test.',
    icon: LucideIcons.link2,
  ),
  _LuminaClassInfo(
    className: 'LuminaCollisionComponent',
    category: 'Components',
    description: 'Base 3D physical collision boundary component.',
    icon: LucideIcons.shield,
  ),
  _LuminaClassInfo(
    className: 'LuminaCapsuleComponent',
    category: 'Components',
    description: 'Capsule-shaped collision geometry container.',
    icon: LucideIcons.cylinder,
  ),
  _LuminaClassInfo(
    className: 'LuminaCharacterMovementComponent',
    category: 'Components',
    description: 'Handles walking, jumping, falling & physics movement logic.',
    icon: LucideIcons.footprints,
  ),
  _LuminaClassInfo(
    className: 'LuminaSkeletalMeshComponent',
    category: 'Components',
    description:
        'Renders rigged 3D skeletal meshes with skeletal animation support.',
    icon: LucideIcons.bone,
  ),
  _LuminaClassInfo(
    className: 'LuminaPlayerComponent',
    category: 'Components',
    description: 'Input mapping & local player possession component.',
    icon: LucideIcons.slidersHorizontal,
  ),
  _LuminaClassInfo(
    className: 'LuminaInputComponent',
    category: 'Components',
    description: 'Action & axis input bindings for player events.',
    icon: LucideIcons.keyboard,
  ),

  // World & Subsystems
  _LuminaClassInfo(
    className: 'LuminaWorld',
    category: 'World & Subsystems',
    description:
        'Top-level 3D scene container managing actors and physics ticks.',
    icon: LucideIcons.globe,
  ),
  _LuminaClassInfo(
    className: 'LuminaLevel',
    category: 'World & Subsystems',
    description: 'Contains level actors, environment lights & static geometry.',
    icon: LucideIcons.map,
  ),
  _LuminaClassInfo(
    className: 'LuminaLevelStreaming',
    category: 'World & Subsystems',
    description: 'Dynamic level streaming loader for open-world environments.',
    icon: LucideIcons.layers,
  ),
  _LuminaClassInfo(
    className: 'LuminaWorldSubsystem',
    category: 'World & Subsystems',
    description: 'Global world service lifecycle subsystem.',
    icon: LucideIcons.server,
  ),
  _LuminaClassInfo(
    className: 'LuminaWidget',
    category: 'UI & User Interface',
    description: 'User interface canvas widget for HUDs, menus and overlays.',
    icon: LucideIcons.layoutTemplate,
  ),
];
