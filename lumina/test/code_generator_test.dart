import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_project.dart';
import 'package:lumina/data/models/lumina_asset.dart';
import 'package:lumina/data/services/code_generator_service.dart';
import 'package:lumina/data/services/level_template_service.dart';
import 'package:lumina/src/game/template_character.dart';
import 'package:lumina/src/world/world_partition.dart';

import 'helpers/analyze_generated_project.dart';

void main() {
  group('DartCodeGeneratorService Tests', () {
    final generator = DartCodeGeneratorService();

    test('Should generate valid main.dart declarative code', () {
      final code = generator.generateMainDart(projectName: 'my_lumina_game');
      expect(code, contains('import \'package:flutter/material.dart\';'));
      // Games import the runtime only: no editor data layer, no FFI packages.
      expect(code, contains('import \'package:lumina/lumina_runtime.dart\';'));
      expect(code, isNot(contains('package:lumina/lumina.dart')));
      expect(code, contains('Future<void> main() async {'));
      expect(code, contains('class MyLuminaGameGame extends LuminaGame'));
      // The level comes from the Open Level table.
      expect(code, contains("'L_DefaultLevel': () => LDefaultLevel(),"));
      expect(code, contains("final level = (_projectLevels[levelName] ?? _projectLevels['L_DefaultLevel']!)();"));
      expect(code, contains('LuminaGameWidget(game: _game)'));
      expect(generator.generateMainDart(projectName: 'p', levelName: 'L_Env'), contains("import 'levels/l_env.dart';"));
    });

    test('honours the manifest game mode, and falls back to the engine default', () {
      final plain = generator.generateMainDart(projectName: 'my_game');
      expect(plain, contains('world.gameMode ??= LuminaGameMode();'));
      expect(plain, isNot(contains("import 'game/")));

      final templated = generator.generateMainDart(
        projectName: 'my_game',
        gameModeClass: 'MyGameGameMode',
        gameModeImport: 'game/my_game_game_mode.dart',
      );
      expect(templated, contains("import 'game/my_game_game_mode.dart';"));
      expect(templated, contains('world.gameMode ??= MyGameGameMode();'));
      expect(templated, isNot(contains('world.gameMode ??= LuminaGameMode();')));
    });

    test('every generated game file imports the runtime, not the editor barrel', () {
      final files = <String>[
        generator.generateMainDart(projectName: 'my_game'),
        generator.generateLevelDart(levelName: 'L_Test', actors: const []),
        generator.generateCharacterDart(projectName: 'my_game', thirdPerson: true),
        generator.generateCharacterDart(projectName: 'my_game', thirdPerson: false),
        generator.generateGameModeDart(projectName: 'my_game'),
        generator.generateActorRegistryDart(const ['BP_Door']),
      ];
      for (final code in files) {
        expect(code, contains("import 'package:lumina/lumina_runtime.dart';"));
        expect(code, isNot(contains('package:lumina/lumina.dart')));
      }
    });

    test('emits the Flutter keyboard/mouse bridge into the input subsystem', () {
      final code = generator.generateMainDart(projectName: 'my_game');
      expect(code, contains('LuminaInputSubsystem'));
      expect(code, contains('input.injectKeyDown(key)'));
      expect(code, contains('input.injectKeyUp(key)'));
      expect(code, contains('input.injectAnalog(LuminaKey.mouseX'));
      // Every keyboard key, through the engine's one key table.
      expect(code, contains('LuminaKey.fromKeyId(event.logicalKey.keyId)'));
      expect(code, isNot(contains('_keyMap')));
    });

    test('the game hides the mouse cursor over its window and still reads mouse look', () {
      final code = generator.generateMainDart(projectName: 'my_game');
      expect(code, contains('cursor: _freeCursor ? SystemMouseCursors.basic : SystemMouseCursors.none'));
      expect(code, contains('onHover: _onPointerDelta'));
    });

    test('the built game follows the player controller: Show Mouse Cursor / a UI input mode frees the pointer', () {
      final code = generator.generateMainDart(projectName: 'my_game');
      // It follows player 0's controller, whichever game (level) is running…
      expect(code, contains('LuminaGameplayStatics.getPlayerController(world, playerIndex: 0)'));
      expect(code, contains('.cursorState.addListener(_onCursorState)'));
      // …releases the pointer and shows the cursor while the game wants it free…
      expect(code, contains('final free = _followedController?.wantsFreeCursor ?? false;'));
      expect(code, contains('cursor: _freeCursor ? SystemMouseCursors.basic : SystemMouseCursors.none'));
      // …and neither a click nor the pointer arriving takes it while free.
      expect(code, contains('if (!_isCaptured && !_freeCursor) _capture(_centre());'));
      expect(code, contains('if (_hadLock || _captureInFlight || _freeCursor) return;'));
    });

    test('the built game captures the mouse on start, listens to motion events, and recaptures on click', () {
      final code = generator.generateMainDart(projectName: 'my_game');
      expect(code, contains('LuminaMouseCapture.backend.capture'));
      expect(code, contains('backend.events.listen'));
      expect(code, contains('MouseCaptureMotion'));
      expect(code, contains('onPointerDown:'));
      expect(code, contains('LuminaMouseCapture.backend.release()'));
    });

    test('the capture result counts, the first capture is retried when the pointer arrives, hover turns while uncaptured', () {
      final code = generator.generateMainDart(projectName: 'my_game');
      // A failed capture (no Wayland pointer yet) is not recorded as captured…
      expect(code, contains('final ok = await LuminaMouseCapture.backend.capture(centre: centre);'));
      expect(code, contains('_isCaptured = ok;'));
      // …the first capture is tried again when the pointer enters or moves
      // over the game, until one succeeds; after a loss a click takes it back.
      expect(code, contains('onEnter: (_) => _captureUntilFirstLock()'));
      expect(code, contains('_captureUntilFirstLock();'));
      expect(code, contains('if (_hadLock || _captureInFlight || _freeCursor) return;'));
      // …and hover deltas turn the camera whenever nothing is captured.
      expect(code, contains('if (_isCaptured && _captureSupport?.relativeMotion == true) return;'));
      expect(code, isNot(contains('    if (_captureSupport?.relativeMotion == true) return;')));
    });

    test('Should generate valid level declarative code for actors', () {
      final actors = [
        LuminaAsset(
          assetId: 'actor-1',
          name: 'DirectionalLight',
          type: AssetType.actor,
          metadata: {'type': 'light', 'intensity': '8.0'},
        ),
        LuminaAsset(
          assetId: 'actor-2',
          name: 'Terrain_Main',
          type: AssetType.actor,
          metadata: {'type': 'mesh', 'mesh': 'contents/meshes/SM_Terrain.lmas'},
        ),
      ];

      final code = generator.generateLevelDart(
        levelName: 'L_DefaultLevel',
        actors: actors,
      );

      expect(code, contains('class LDefaultLevel extends LuminaLevel'));
      expect(code, contains('scriptActor: _LDefaultLevelScript()'));
      expect(code, contains('LuminaActor('));
      expect(code, contains("LuminaObjectKey('actor-1')"));
      expect(code, contains("LuminaObjectKey('actor-2')"));
      expect(code, contains("key: const LuminaObjectKey('L_DefaultLevel_script')"));
      expect(code, isNot(contains('ValueKey')), reason: 'engine objects carry the engine key');
      expect(code, isNot(contains('package:flutter/foundation.dart')));
      expect(code, isNot(contains('StatelessWidget')), reason: 'levels are runtime LuminaLevel subclasses, not widgets');
    });
  });

  group('generateLevelDart with editor actor maps + environment', () {
    final generator = DartCodeGeneratorService();
    final actorMaps = <Map<String, dynamic>>[
      {'id': 'act_1', 'name': 'PlayerPawn_Default', 'type': 'Pawn', 'location': [-60.0, 40.0, 0.0], 'rotation': [0.0, 90.0, 0.0]},
      {
        'id': 'act_2', 'name': 'Sun', 'type': 'Light', 'location': [0.0, 150.0, 180.0], 'rotation': [-45.0, 30.0, 0.0],
        'lightIntensity': 80000.0, 'lightColorHex': '#FF8000', 'castShadows': true,
        'components': [
          {'id': 'act_2_sun', 'type': 'LuminaDirectionalLightComponent', 'properties': {'intensity': 90000.0, 'effectiveColorHex': '#FFCC66', 'castShadows': false}},
        ],
      },
      {
        'id': 'act_3', 'name': 'SkyAmbience', 'type': 'Environment', 'location': [0.0, 0.0, 0.0],
        'components': [
          {'id': 'act_3_sky', 'type': 'LuminaSkyComponent', 'properties': {'mode': 'color', 'colorHex': '#4080FF', 'skyIntensity': 25000.0, 'iblIntensity': 20000.0}},
        ],
      },
      {'id': 'act_4', 'name': 'Rock', 'type': 'Mesh', 'location': [80.0, -40.0, 0.0], 'scale': [2.0, 2.0, 2.0], 'meshAssetPath': '/tmp/rock.glb', 'castShadows': false},
      {'id': 'act_5', 'name': 'Lighting', 'type': 'Folder', 'location': [0.0, 0.0, 0.0]},
      {'id': 'act_6', 'name': 'Lamp', 'type': 'PointLight', 'location': [1.0, 2.0, 3.0], 'lightIntensity': 5000.0, 'lightColorHex': '#FFFFFF'},
      {
        'id': 'act_8', 'name': 'Torch', 'type': 'SpotLight', 'location': [0.0, 0.0, 200.0], 'lightIntensity': 6000.0,
        'components': [
          {'id': 'act_8_light', 'type': 'LuminaSpotLightComponent', 'properties': {'intensity': 7500.0, 'colorHex': '#FF4000', 'castShadows': true, 'attenuationRadius': 850.0, 'innerConeAngle': 20.0, 'outerConeAngle': 35.0}},
        ],
      },
      {
        'id': 'act_9', 'name': 'Bulb', 'type': 'PointLight', 'location': [0.0, 0.0, 100.0],
        'components': [
          {'id': 'act_9_light', 'type': 'LuminaPointLightComponent', 'properties': {'intensity': 1200.0, 'attenuationRadius': 300.0}},
        ],
      },
      {
        'id': 'act_7', 'name': 'Terrain', 'type': 'Landscape', 'location': [0.0, -10.0, 0.0],
        'scale': [1.0, 1.0, 1.0], 'meshAssetPath': 'contents/landscapes/NewLandscape.lmas',
      },
    ];
    final environment = <String, dynamic>{
      'version': 1,
      'postProcess': {
        'fogEnabled': true, 'fogDensity': 0.03, 'fogHeightFalloff': 1.0, 'fogColorHex': '#99AABB',
        'exposure': 0.5, 'bloomIntensity': 4.0, 'bloomThreshold': 1200.0, 'vignette': 0.5,
        'saturation': 1.1, 'contrast': 1.05, 'gamma': 0.9,
      },
    };

    test('emits typed runtime objects for every actor type and skips folders', () {
      final code = generator.generateLevelDart(levelName: 'L_Env', actors: const [], actorMaps: actorMaps, environment: environment);
      expect(code, contains('class LEnv extends LuminaLevel'));
      // Stored Z-up [-60, 40, 0] lands at runtime (x, z, −y).
      expect(code, contains("LuminaPawn(key: const LuminaObjectKey('act_1'), location: Vector3(-60.0000, 0.0000, -40.0000), rotation: luminaAuthoringRotation(0.0000, 90.0000, 0.0000))"));
      // component properties win over the actor-level fallbacks
      expect(code, contains('LuminaDirectionalLightComponent('));
      expect(code, contains('intensity: 90000.0000'));
      // #FFCC66 is sRGB; the light gets linear RGB.
      expect(code, contains('color: Vector3(1.0000, 0.6038, 0.1329)'));
      expect(code, contains('sunAngularRadius: 0.5450, castShadows: false, visible: true))'));
      expect(code, contains('LuminaSkyComponent.color(color: Vector4(0.2510, 0.5020, 1.0000, 1.0)'));
      expect(code, contains('skyIntensity: 25000.0000, iblIntensity: 20000.0000'));
      expect(code, contains("LuminaStaticMeshComponent(meshAssetPath: '/tmp/rock.glb'"));
      expect(code, contains('scale: Vector3(2.0000, 2.0000, 2.0000), castShadows: false'));
      expect(code, contains('LuminaPointLightComponent('));
      // A light's own component carries its attenuation radius
      // and cone angles into the generated level; a light without one keeps
      // the runtime defaults.
      expect(code, contains("LuminaPointLightComponent(location: Vector3(1.0000, 3.0000, -2.0000), rotation: luminaAuthoringRotation(0.0000, 0.0000, 0.0000), color: Vector3(1.0000, 1.0000, 1.0000), intensity: 5000.0000, falloffRadius: 1000.0000, castShadows"));
      expect(code, contains("LuminaSpotLightComponent(location: Vector3(0.0000, 200.0000, 0.0000), rotation: luminaAuthoringRotation(0.0000, 0.0000, 0.0000), color: Vector3(1.0000, 0.0513, 0.0000), intensity: 7500.0000, falloffRadius: 850.0000, innerConeAngleDegrees: 20.0000, outerConeAngleDegrees: 35.0000, castShadows: true"));
      expect(code, contains('intensity: 1200.0000, falloffRadius: 300.0000, castShadows'));
      expect(code, contains('sunAngularRadius: 0.5450, castShadows: false, visible: true))'));
      expect(
        code,
        contains("LuminaLandscapeComponent(assetPath: 'contents/landscapes/NewLandscape.lmas'"),
        reason: 'a placed Landscape actor must emit the runtime terrain component, not a bare scene component',
      );
      expect(code, isNot(contains('Lighting')), reason: 'folders are organisational only');
      // environment post-process applied on begin play with the editor's unit mapping
      expect(code, contains('w.postProcess.apply('));
      expect(code, contains('fog.copyWith(enabled: true, density: 0.0003, heightFalloff: 0.0100'));
      expect(code, contains('bloom.copyWith(enabled: true, strength: 0.5000, highlight: 1200.0000)'));
      expect(code, contains('vignette.copyWith(enabled: true, midPoint: 0.5500)'));
      expect(code, contains('exposure: 0.5000, saturation: 1.1000, contrast: 1.0500'));
      expect(code, contains('Vector3.all(0.9000)'));
    });

    test('HDRI sky maps to LuminaSkyComponent.environment', () {
      final code = generator.generateLevelDart(levelName: 'L_Hdri', actors: const [], actorMaps: [
        {
          'id': 'sky', 'name': 'Sky', 'type': 'Environment', 'location': [0.0, 0.0, 0.0],
          'components': [
            {'id': 'c', 'type': 'LuminaSkyComponent', 'properties': {'mode': 'environment', 'showSun': true, 'sky_environment': {'slot_name': 'sky_environment', 'asset_id': '', 'asset_path': 'contents/textures/lightroom_ibl.ktx'}}},
          ],
        },
      ]);
      expect(code, contains("LuminaSkyComponent.environment(environmentAssetPath: 'contents/textures/lightroom_ibl.ktx'"));
      expect(code, contains('showSun: true'));
      expect(code, contains('// No environment section authored for this level.'));
    });

    test('asset paths in a level are bundle paths: absolute project paths become contents/…', () {
      final code = generator.generateLevelDart(levelName: 'L_Assets', actors: const [], actorMaps: [
        {'id': 'rock', 'name': 'Rock', 'type': 'StaticMesh', 'location': [0.0, 0.0, 0.0],
         'meshAssetPath': '/home/dev/Lumina Projects/my_game/contents/meshes/static/rock.entity.glb'},
        {
          'id': 'sky', 'name': 'Sky', 'type': 'Environment', 'location': [0.0, 0.0, 0.0],
          'components': [
            {'id': 'c', 'type': 'LuminaSkyComponent', 'properties': {'mode': 'environment', 'sky_environment': {'asset_path': '/home/dev/Lumina Projects/my_game/contents/textures/sky_ibl.ktx'}}},
          ],
        },
      ]);
      expect(code, contains("meshAssetPath: 'contents/meshes/static/rock.entity.glb'"));
      expect(code, contains("environmentAssetPath: 'contents/textures/sky_ibl.ktx'"));
      expect(code, isNot(contains('/home/dev/')), reason: 'a shipped game never names the developer\'s disk');
    });

    test('a shadcn project wraps the game in ShadcnLayer; a plain-Flutter one does not', () {
      final shadcn = generator.generateMainDart(projectName: 'my_game', widgetLibrary: kUmgWidgetLibraryShadcn);
      expect(shadcn, contains("import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;"));
      expect(shadcn, contains('shadcn.ShadcnLayer('));
      expect(shadcn, contains('theme: shadcn.ThemeData.dark()'));
      final plain = generator.generateMainDart(projectName: 'my_game', widgetLibrary: kUmgWidgetLibraryFlutter);
      expect(plain, isNot(contains('shadcn')));
      expect(generator.generateMainDart(projectName: 'my_game'), isNot(contains('shadcn')),
          reason: 'callers pass the library; unwrapped is the only output that compiles without the dependency');
    });

    test('the launcher sets world gravity from the project (cm/s²)', () {
      expect(generator.generateMainDart(projectName: 'g'), contains('world.gravityZ = -980.0000;'));
      expect(generator.generateMainDart(projectName: 'g', gravityZ: -490), contains('world.gravityZ = -490.0000;'));
    });

    test('the launcher routes every runtime asset load through the Flutter asset bundle', () {
      final code = generator.generateMainDart(projectName: 'my_game');
      expect(code, contains('LuminaAssets.defaultProvider = '));
      expect(code, contains('rootBundle.load(path)'));
    });

    test('generated level compiles against the real lumina package (dart analyze)', () async {
      final code = generator.generateLevelDart(levelName: 'L_Env', actors: const [], actorMaps: actorMaps, environment: environment);
      final tempDir = Directory.systemTemp.createTempSync('lumina_levelgen_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final luminaDir = Directory.current.path;
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync("""
name: levelgen_probe
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
  lumina:
    path: $luminaDir
  vector_math: ^2.1.4
""");
      Directory('${tempDir.path}/lib/levels').createSync(recursive: true);
      File('${tempDir.path}/lib/levels/l_env.dart').writeAsStringSync(code);
      File('${tempDir.path}/lib/main.dart').writeAsStringSync(generator.generateMainDart(projectName: 'levelgen_probe', levelName: 'L_Env'));
      final pubGet = await Process.run('flutter', ['pub', 'get', '--offline'], workingDirectory: tempDir.path, runInShell: Platform.isWindows);
      expect(pubGet.exitCode, 0, reason: 'pub get: ${pubGet.stdout}${pubGet.stderr}');
      final analyze = await analyzeGeneratedProject(tempDir.path);
      expect(analyze.exitCode, 0, reason: 'generated level must analyze clean:\n${analyze.stdout}\n${analyze.stderr}\n$code');
    });
  });

  group('PlayerStart, Primitive and the generated game source', () {
    final generator = DartCodeGeneratorService();

    Map<String, dynamic> primitive(String id, String shape, List<double> size, String hex) => {
          'id': id,
          'name': id,
          'type': 'Primitive',
          'location': [1.0, 2.0, 3.0],
          'scale': [1.0, 1.0, 1.0],
          'components': [
            {
              'id': '${id}_mesh',
              'type': 'LuminaProceduralMeshComponent',
              'properties': {
                'shape': shape,
                'sizeX': size[0],
                'sizeY': size[1],
                'sizeZ': size[2],
                'colorHex': hex,
              },
            },
          ],
        };

    test('PlayerStart emits LuminaPlayerStart and Primitive emits a procedural mesh actor', () {
      final code = generator.generateLevelDart(
        levelName: 'L_Tpl',
        actors: const [],
        actorMaps: [
          {
            'id': 'ps',
            'name': 'PlayerStart',
            'type': 'PlayerStart',
            'location': [0.0, -600.0, 100.0], // cm, Z up
            'components': [
              {
                'id': 'ps_gm',
                'type': 'LuminaGameModeBinding',
                'properties': {
                  'gameModeClass': 'TplGameMode',
                  'gameModeImport': '../game/tpl_game_mode.dart',
                },
              },
            ],
          },
          primitive('floor', 'plane', [20.0, 20.0, 0.0], '#6E7681'),
          primitive('crate', 'box', [1.0, 2.0, 3.0], '#FF8000'),
        ],
      );

      expect(code, contains("LuminaPlayerStart(key: const LuminaObjectKey('ps'), location: Vector3(0.0000, 100.0000, 600.0000)"));
      expect(code, contains("luminaPrimitiveShapeFrom('plane')"));
      expect(code, contains("luminaPrimitiveShapeFrom('box')"));
      // Stored Z up (sizeZ = 3 is the height), emitted as the runtime's Y-up extent.
      expect(code, contains('size: Vector3(1.0000, 3.0000, 2.0000)'));
      expect(code, contains('color: Vector3(1.0000, 0.5020, 0.0000)'));
      // The primitive is an engine class, not source pasted into the level.
      // Play-In-Editor builds the same actor from the same component
      // properties, so the editor and the shipped game cannot draw different
      // geometry for the same box.
      expect(code, contains('LuminaPrimitiveActor(key:'));
      expect(code, isNot(contains('class _PrimitiveActor')),
          reason: 'the geometry builder must not be duplicated into every level');

      // The game mode binding rides on metadata.actors, so a save cannot
      // unwire it: the regenerated level installs and logs in by itself.
      expect(code, contains("import '../game/tpl_game_mode.dart';"));
      expect(code, contains('mode = TplGameMode();'));
      expect(code, contains('playerController = mode.login();'));
      expect(code, contains('playerController?.onTick(deltaTime);'));
    });

    test('a level without primitives or a player start is unchanged', () {
      final code = generator.generateLevelDart(
        levelName: 'L_Plain',
        actors: const [],
        actorMaps: [
          {'id': 'a', 'name': 'Rock', 'type': 'Mesh', 'location': [0.0, 0.0, 0.0]},
        ],
      );
      expect(code, isNot(contains('LuminaPrimitiveActor')));
      expect(code, isNot(contains('login()')));
      expect(code, isNot(contains("import 'dart:typed_data';")));
      expect(code, contains('// No environment section authored for this level.'));
    });

    test('first person character: eye-height camera, bound actions, no spring arm', () {
      final code = generator.generateCharacterDart(projectName: 'my_game', thirdPerson: false);
      expect(code, contains('class MyGameCharacter extends LuminaCharacter'));
      expect(code, contains('LuminaCameraComponent('));
      expect(code, contains('location: Vector3(0.0, baseEyeHeight, 0.0)'));
      expect(code, isNot(contains('LuminaSpringArmComponent')));
      expect(code, contains('inputComponent.bindAction(iaMove, TriggerState.triggered, onMove);'));
      expect(code, contains('inputComponent.bindAction(iaLook, TriggerState.triggered, onLook);'));
      // Jump on Started, Stop Jumping on Completed; the
      // Space mapping has no trigger (implicit Down).
      expect(code, contains('inputComponent.bindAction(iaJump, TriggerState.started, onJump);'));
      expect(code, contains('inputComponent.bindAction(iaJump, TriggerState.completed, onStopJumping);'));
      expect(code, contains('context.mapKey(LuminaKey.keySpace, iaJump);'));
      expect(code, contains('characterMovement.jumpCutMultiplier = ${LuminaTemplateCharacterTuning.jumpCutMultiplier};'));
      expect(code, contains('context.mapKey(LuminaKey.keyW, iaMove'));
      expect(code, contains('// BEGIN USER CODE: class_body'));
    });

    test('third person character: spring arm with pawn control rotation and collision probe', () {
      final code = generator.generateCharacterDart(projectName: 'my_game', thirdPerson: true);
      expect(code, contains('LuminaSpringArmComponent('));
      expect(code, contains('targetArmLength: ${LuminaTemplateCharacterTuning.boomLength}'));
      expect(code, contains('springArmComponent.bUsePawnControlRotation = true;'));
      expect(code, contains('springArmComponent.bDoCollisionTest = true;'));
      expect(code, contains('springArmComponent.bEnableCameraLag = true;'));
      expect(code, contains('cameraComponent.attachToComponent(springArmComponent);'));
    });

    test('game mode spawns the generated character', () {
      final code = generator.generateGameModeDart(projectName: 'my_game');
      expect(code, contains('class MyGameGameMode extends LuminaGameMode'));
      expect(code, contains('defaultPawnFactory: () => MyGameCharacter()'));
      expect(code, contains("import '../pawns/my_game_character.dart';"));
    });
  });

  group('Environment actors: height fog, post process volume, local fog volume', () {
    final generator = DartCodeGeneratorService();

    test('an ExponentialHeightFog actor emits the component with the authored values and Z-up → Y-up location', () {
      final code = generator.generateLevelDart(levelName: 'L_Fog', actors: const [], actorMaps: [
        {
          'id': 'act_1', 'name': 'HeightFog', 'type': 'ExponentialHeightFog', 'location': [0.0, 0.0, 250.0],
          'components': [
            {'id': 'act_1_fog', 'type': 'LuminaExponentialHeightFogComponent', 'properties': {'fogDensity': 0.05, 'useSkyColor': true}},
          ],
        },
      ]);
      expect(code, contains("LuminaActor(key: const LuminaObjectKey('act_1'), root: LuminaExponentialHeightFogComponent(location: Vector3(0.0000, 250.0000, 0.0000)"));
      expect(code, contains('fogDensity: 0.0500'));
      expect(code, contains('fogHeightFalloff: 0.2000, startDistance: 0.0000, fogCutoffDistance: 0.0000, fogMaxOpacity: 1.0000'));
      expect(code, contains('inscatteringColor: Vector3(0.4470, 0.6380, 1.0000), useSkyColor: true, visible: true))'));
    });

    test('a PostProcessVolume actor emits its properties map verbatim with the transform and scale', () {
      final code = generator.generateLevelDart(levelName: 'L_Ppv', actors: const [], actorMaps: [
        {
          'id': 'act_2', 'name': 'Volume', 'type': 'PostProcessVolume', 'location': [10.0, 20.0, 30.0], 'scale': [2.0, 1.0, 1.0],
          'components': [
            {'id': 'act_2_ppv', 'type': 'LuminaPostProcessVolumeComponent', 'properties': {'extentX': 400.0, 'unbound': false, 'overrideBloomIntensity': true, 'bloomIntensity': 5.0}},
          ],
        },
      ]);
      expect(code, contains("root: LuminaPostProcessVolumeComponent.fromProperties(const <String, dynamic>{'bloomIntensity': 5.0000, 'extentX': 400.0000, 'overrideBloomIntensity': true, 'unbound': false}, location: Vector3(10.0000, 30.0000, -20.0000)"));
      expect(code, contains('scale: Vector3(2.0000, 1.0000, 1.0000), visible: true))'));
    });

    test('a LocalFogVolume actor emits its properties map verbatim', () {
      final code = generator.generateLevelDart(levelName: 'L_Lfv', actors: const [], actorMaps: [
        {
          'id': 'act_3', 'name': 'Fog', 'type': 'LocalFogVolume', 'location': [0.0, 0.0, 0.0],
          'components': [
            {'id': 'act_3_lfv', 'type': 'LuminaLocalFogVolumeComponent', 'properties': {'shape': 'sphere', 'radius': 400.0, 'fogAlbedoHex': '#CCD9E6'}},
          ],
        },
      ]);
      expect(code, contains("root: LuminaLocalFogVolumeComponent.fromProperties(const <String, dynamic>{'fogAlbedoHex': '#CCD9E6', 'radius': 400.0000, 'shape': 'sphere'}"));
    });

    test('an actor without the component emits the runtime defaults', () {
      final code = generator.generateLevelDart(levelName: 'L_Bare', actors: const [], actorMaps: [
        {'id': 'a', 'name': 'F', 'type': 'ExponentialHeightFog', 'location': [0.0, 0.0, 0.0]},
        {'id': 'b', 'name': 'V', 'type': 'PostProcessVolume', 'location': [0.0, 0.0, 0.0]},
        {'id': 'c', 'name': 'Env', 'type': 'Environment', 'location': [0.0, 0.0, 0.0]},
        {'id': 'd', 'name': 'SkyAtm', 'type': 'SkyAtmosphere', 'location': [0.0, 0.0, 0.0]},
      ]);
      expect(code, contains('fogDensity: 0.0200'));
      expect(code, contains('LuminaPostProcessVolumeComponent.fromProperties(const <String, dynamic>{}, '));
      expect(code, contains("LuminaActor(key: const LuminaObjectKey('c'), root: LuminaSkyComponent.color(color: Vector4(0.3608, 0.4980, 0.7216, 1.0)"));
      expect(code, contains("LuminaActor(key: const LuminaObjectKey('d'), root: LuminaSkyComponent.color(color: Vector4(0.3608, 0.4980, 0.7216, 1.0)"));
    });
  });

  group('World Partition level section', () {
    final generator = DartCodeGeneratorService();

    /// The Open World level template as the editor writes it: sun, sky, a
    /// 256 m ground plane and a PlayerStart carrying a streaming source.
    List<Map<String, dynamic>> openWorldActors() =>
        LevelTemplateCatalog.byId(kOpenWorldLevelTemplateId).levelActors;

    test('the Open World template ships the runtime\'s own defaults', () {
      final section = LevelTemplateCatalog.byId(kOpenWorldLevelTemplateId).worldPartition!;
      expect(section['enabled'], isTrue);
      // 1:1 with LuminaWorldPartitionSubsystem's constructor defaults.
      expect(section['cellSize'], LuminaWorldPartitionSubsystem().cellSize);
      expect(section['maxCellTransitionsPerTick'],
          LuminaWorldPartitionSubsystem().maxCellTransitionsPerTick);
      // 1:1 with LuminaStreamingSourceComponent's own default radius.
      expect(section['loadingRange'], LuminaStreamingSourceComponent().loadingRadius);
      expect(section['dataLayers'], isEmpty, reason: 'no fabricated layers');

      final start = openWorldActors().firstWhere((a) => a['type'] == 'PlayerStart');
      final comps = start['components'] as List;
      expect(comps.any((c) => c['type'] == kStreamingSourceComponentType), isTrue);

      expect(LevelTemplateCatalog.byId(kEmptyLevelTemplateId).levelActors, isEmpty);
      expect(LevelTemplateCatalog.byId(kEmptyLevelTemplateId).worldPartition, isNull);
      expect(LevelTemplateCatalog.byId(kDefaultLevelTemplateId).worldPartition, isNull);
      expect(LevelTemplateCatalog.byId(kDefaultLevelTemplateId).levelActors.length, 4);
    });

    test('emits the subsystem registration, the authored knobs and the streaming source', () {
      final code = generator.generateLevelDart(
        levelName: 'L_OpenWorld',
        actors: const [],
        actorMaps: openWorldActors(),
        worldPartition: {
          'enabled': true,
          'cellSize': 256.0,
          'loadingRange': 400.0,
          'maxCellTransitionsPerTick': 4,
          'dataLayers': [
            {'name': 'Gameplay', 'initialState': 'activated', 'isRuntime': true},
            {'name': 'Editor Only', 'initialState': 'unloaded', 'isRuntime': false},
          ],
        },
      );
      expect(code, contains('LuminaWorldPartitionSubsystem(cellSize: 256.0000, maxCellTransitionsPerTick: 4)'));
      expect(code, contains("registerLayer('Gameplay', initialState: DataLayerState.activated, bIsRuntime: true)"));
      expect(code, contains("registerLayer('Editor Only', initialState: DataLayerState.unloaded, bIsRuntime: false)"));
      expect(code, contains('partition.addActor(actor, actor.actorLocation)'));
      expect(code, contains('partition.registerSource(component)'));
      // The streaming source is a real component on a real PlayerStart, and it
      // inherits the section's loadingRange because the template authored none.
      expect(code, contains('class _LOpenWorldStreamingPlayerStart extends LuminaPlayerStart'));
      expect(code, contains('loadingRadius: 400.0000'));
      expect(code, contains('_LOpenWorldStreamingPlayerStart(key: const LuminaObjectKey(\'act_player_start\')'));
    });

    test('a level row naming data layers is assigned to them by its key', () {
      final actors = openWorldActors();
      final start = actors.firstWhere((a) => a['type'] == 'PlayerStart');
      start['dataLayers'] = ['Gameplay', 'Vodina 2'];
      final code = generator.generateLevelDart(
        levelName: 'L_OpenWorld',
        actors: const [],
        actorMaps: actors,
        worldPartition: {
          'enabled': true,
          'dataLayers': [
            {'name': 'Gameplay', 'initialState': 'activated', 'isRuntime': true},
          ],
        },
      );
      expect(code, contains("'${start['id']}': ['Gameplay', 'Vodina 2'],"));
      expect(code, contains('partition.assignActorToLayer(actor, layer)'));
      expect(code, contains('if (key != null)'));
      expect(code, contains('dataLayersByActor[key.value]'));

      // Without any row naming a layer nothing is emitted for it.
      final plain = generator.generateLevelDart(
        levelName: 'L_OpenWorld',
        actors: const [],
        actorMaps: openWorldActors(),
        worldPartition: {'enabled': true, 'dataLayers': const []},
      );
      expect(plain, isNot(contains('assignActorToLayer')));
    });

    test('a component-authored loadingRadius wins over the section default', () {
      final actors = openWorldActors();
      final start = actors.firstWhere((a) => a['type'] == 'PlayerStart');
      (start['components'] as List).first['properties']['loadingRadius'] = 999.0;
      final code = generator.generateLevelDart(
        levelName: 'L_Wp', actors: const [], actorMaps: actors,
        worldPartition: {'enabled': true, 'cellSize': 128.0, 'loadingRange': 250.0, 'maxCellTransitionsPerTick': 10},
      );
      expect(code, contains('loadingRadius: 999.0000'));
    });

    test('regression: no section (or a disabled one) emits none of it', () {
      final without = generator.generateLevelDart(
        levelName: 'L_Plain', actors: const [], actorMaps: openWorldActors());
      expect(without, isNot(contains('LuminaWorldPartitionSubsystem')));
      expect(without, isNot(contains('LuminaStreamingSourceComponent')));
      expect(without, contains("LuminaPlayerStart(key: const LuminaObjectKey('act_player_start')"));

      final disabled = generator.generateLevelDart(
        levelName: 'L_Plain', actors: const [], actorMaps: openWorldActors(),
        worldPartition: {'enabled': false, 'cellSize': 128.0, 'loadingRange': 250.0, 'maxCellTransitionsPerTick': 10},
      );
      expect(disabled, without, reason: 'a disabled section must generate byte-identical code');
    });

    test('a generated Open World level analyzes clean against the real package', () async {
      final code = generator.generateLevelDart(
        levelName: 'L_OpenWorld',
        actors: const [],
        actorMaps: openWorldActors(),
        worldPartition: LevelTemplateCatalog.byId(kOpenWorldLevelTemplateId).worldPartition,
      );
      final tempDir = Directory.systemTemp.createTempSync('lumina_wpgen_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final luminaDir = Directory.current.path;
      File('${tempDir.path}/pubspec.yaml').writeAsStringSync("""
name: wpgen_probe
environment:
  sdk: ^3.12.0
dependencies:
  flutter:
    sdk: flutter
  lumina:
    path: $luminaDir
  vector_math: ^2.1.4
""");
      Directory('${tempDir.path}/lib/levels').createSync(recursive: true);
      File('${tempDir.path}/lib/levels/l_open_world.dart').writeAsStringSync(code);
      File('${tempDir.path}/lib/main.dart').writeAsStringSync(
          generator.generateMainDart(projectName: 'wpgen_probe', levelName: 'L_OpenWorld'));
      final pubGet = await Process.run('flutter', ['pub', 'get', '--offline'], workingDirectory: tempDir.path, runInShell: Platform.isWindows);
      expect(pubGet.exitCode, 0, reason: 'pub get: ${pubGet.stdout}${pubGet.stderr}');
      final analyze = await analyzeGeneratedProject(tempDir.path);
      expect(analyze.exitCode, 0, reason: 'generated Open World level must analyze clean:\n${analyze.stdout}\n${analyze.stderr}\n$code');
    }, timeout: const Timeout(Duration(minutes: 4)));
  });
}
