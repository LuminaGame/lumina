import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as math;
import 'package:lumina/lumina.dart';
import 'package:lumina_widgets/lumina_widgets.dart';

class MyChar extends LuminaPlayerComponent {
  bool isJumping = false;

  @override
  void onRegister(LuminaActor ownerActor) {
    super.onRegister(ownerActor);
    bindAction('Jump', () {
      if (owner is LuminaCharacter) {
        (owner as LuminaCharacter).jump();
        isJumping = true;
      }
    });
    bindAxis('MoveForward', (value) {
      if (owner is LuminaPawn) {
        (owner as LuminaPawn).addMovementInput(math.Vector3(0, 0, -1), value);
      }
    });
  }

  @override
  LuminaObject build(LuminaBuildContext context) {
    return LuminaSkinnedMeshComponent(
      meshAssetPath: 'assets/models/suzanne.filamesh',
    );
  }
}

class MyLevel1 extends LuminaLevel {
  MyLevel1({super.key})
      : super(children: [
          LuminaCharacter(
            location: math.Vector3(0, 0.5, 0),
          ),
          LuminaActor(
            location: math.Vector3(-2, 1, -3),
            components: [
              LuminaCollisionComponent(
                shapeType: CollisionShapeType.sphere,
                radius: 1.0,
              ),
            ],
          ),
          LuminaActor(
            location: math.Vector3(2, 1, -3),
            components: [
              LuminaCollisionComponent(
                shapeType: CollisionShapeType.box,
              ),
            ],
          ),
        ]);
}

class MyLevel2 extends LuminaLevel {
  MyLevel2({super.key});
}

class MyWorld extends LuminaWorld {
  MyWorld({super.key, required List<LuminaObject> children})
      : super(initialLevel: LuminaLevel(children: children));
}

class MyGame extends LuminaGame {
  @override
  LuminaObject build(LuminaBuildContext context) {
    return MyWorld(
      children: [
        MyLevel1(),
        MyLevel2(),
      ],
    );
  }
}

void main() {
  runApp(const LuminaExampleApp());
}

class LuminaExampleApp extends StatefulWidget {
  const LuminaExampleApp({super.key});

  @override
  State<LuminaExampleApp> createState() => _LuminaExampleAppState();
}

class _LuminaExampleAppState extends State<LuminaExampleApp> {
  late final MyGame _game;
  final LuminaPlayerController _playerController = LuminaPlayerController();
  String _statusInfo = 'Initializing Lumina Engine...';

  @override
  void initState() {
    super.initState();
    _game = MyGame();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Lumina 3D Game Engine (Declarative Node Tree)'),
          actions: [
            IconButton(
              icon: const Icon(Icons.videogame_asset),
              onPressed: () {
                final world = _game.world;
                if (world != null && world.persistentLevel.actors.isNotEmpty) {
                  final char = world.persistentLevel.actors.firstWhere(
                    (a) => a is LuminaCharacter,
                    orElse: () => world.persistentLevel.actors.first,
                  );
                  if (char is LuminaPawn) {
                    _playerController.possess(char);
                    setState(() {
                      _statusInfo = 'LuminaPlayerController Possessed Character!\n'
                          'Pawn Eye Location: ${char.getPawnViewLocation()}\n'
                          'Player Controlled: ${char.isPlayerControlled()}';
                    });
                  }
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  LuminaGameWidget(game: _game),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.deepPurpleAccent),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Lumina Engine Active', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                          Text('Node Tree: MyGame -> MyWorld -> MyLevel1 -> LuminaCharacter', style: TextStyle(fontSize: 12)),
                          Text('Physics & Collision: Active (Kinematic Sweep & Layer Bitmask)', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_statusInfo, style: const TextStyle(fontFamily: 'monospace', color: Colors.cyanAccent, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.north),
                        label: const Text('Move Forward'),
                        onPressed: () {
                          final world = _game.world;
                          if (world != null && world.persistentLevel.actors.isNotEmpty) {
                            final char = world.persistentLevel.actors.cast<LuminaActor?>().firstWhere(
                              (a) => a is LuminaCharacter,
                              orElse: () => null,
                            );
                            if (char is LuminaCharacter) {
                              char.addMovementInput(math.Vector3(0, 0, -1), 1.0);
                              setState(() {
                                _statusInfo = 'Input Movement Vector Added: (0, 0, -1)\n'
                                    'Character Location: ${char.actorLocation}';
                              });
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_upward),
                        label: const Text('Jump'),
                        onPressed: () {
                          final world = _game.world;
                          if (world != null && world.persistentLevel.actors.isNotEmpty) {
                            final char = world.persistentLevel.actors.cast<LuminaActor?>().firstWhere(
                              (a) => a is LuminaCharacter,
                              orElse: () => null,
                            );
                            if (char is LuminaCharacter) {
                              char.jump();
                              setState(() {
                                _statusInfo = 'Jump Action Executed!\n'
                                    'Z Velocity: ${char.characterMovement.jumpZVelocity} m/s';
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
