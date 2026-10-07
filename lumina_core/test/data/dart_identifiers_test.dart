import 'package:test/test.dart';
import 'package:lumina_core/lumina_core.dart';

void main() {
  group('dartTypeName', () {
    test('asset-type prefixes become words', () {
      expect(dartTypeName('L_Main'), 'LMain');
      expect(dartTypeName('L_DefaultLevel'), 'LDefaultLevel');
      expect(dartTypeName('BP_Door'), 'BpDoor');
      expect(dartTypeName('BP_ThirdPersonCharacter'), 'BpThirdPersonCharacter');
      expect(dartTypeName('WBP_Hud'), 'WbpHud');
      expect(dartTypeName('ABP_Character'), 'AbpCharacter');
      expect(dartTypeName('E_DoorState'), 'EDoorState');
      expect(dartTypeName('BPI_Interactable'), 'BpiInteractable');
    });

    test('all-caps parts are words, camel parts keep their casing', () {
      expect(dartTypeName('BP_HUD'), 'BpHud');
      expect(dartTypeName('WBP_PlayerHUD'), 'WbpPlayerHUD');
      expect(dartTypeName('my_first_game'), 'MyFirstGame');
      expect(dartTypeName('MyGame'), 'MyGame');
      expect(dartTypeName('door'), 'Door');
      expect(dartTypeName('Level 2-Boss'), 'Level2Boss');
      expect(dartTypeName('L_3D'), 'L3d');
    });

    test('digits, keywords and empty names still give a valid type', () {
      expect(dartTypeName('3D_Level'), 'N3dLevel');
      expect(dartTypeName('Function'), 'FunctionAsset');
      expect(dartTypeName('String'), 'StringAsset');
      expect(dartTypeName('__'), 'Generated');
      expect(dartTypeName('', fallback: 'GeneratedWidget'), 'GeneratedWidget');
    });

    test('is idempotent on its own output', () {
      for (final n in ['L_Main', 'BP_ThirdPersonCharacter', 'WBP_PlayerHUD', '3D_Level']) {
        expect(dartTypeName(dartTypeName(n)), dartTypeName(n), reason: n);
      }
    });
  });

  group('dartFileStem / dartFileName', () {
    test('snake_case file names', () {
      expect(dartFileName('L_Main'), 'l_main.dart');
      expect(dartFileStem('L_Main'), 'l_main');
      expect(dartFileStem('L_DefaultLevel'), 'l_default_level');
      expect(dartFileStem('BP_Door'), 'bp_door');
      expect(dartFileStem('BP_ThirdPersonCharacter'), 'bp_third_person_character');
      expect(dartFileStem('WBP_Hud'), 'wbp_hud');
      expect(dartFileStem('WBP_PlayerHUD'), 'wbp_player_hud');
      expect(dartFileStem('E_HUDMode'), 'e_hud_mode');
      expect(dartFileStem('BPI_Interactable'), 'bpi_interactable');
      expect(dartFileStem('MyGameGameMode'), 'my_game_game_mode');
      expect(dartFileStem('Level2Main'), 'level2_main');
    });

    test('digits and empty names', () {
      expect(dartFileStem('3D_Level'), 'n3d_level');
      expect(dartFileStem('--'), 'generated');
    });

    test('snake_case input and the type name map to the same file', () {
      expect(dartFileStem('bp_door'), 'bp_door');
      expect(dartFileStem(dartTypeName('BP_ThirdPersonCharacter')), 'bp_third_person_character');
      expect(dartFileStem(dartTypeName('L_Main')), 'l_main');
    });
  });

  group('dartMemberName', () {
    test('lowerCamelCase', () {
      expect(dartMemberName('Health'), 'health');
      expect(dartMemberName('Max Health'), 'maxHealth');
      expect(dartMemberName('bIsOpen'), 'bIsOpen');
      expect(dartMemberName('HP'), 'hp');
      expect(dartMemberName('HPMax'), 'hpMax');
      expect(dartMemberName('Max_HP'), 'maxHp');
      expect(dartMemberName('MaxHP'), 'maxHP');
      expect(dartMemberName('Open_Door'), 'openDoor');
      expect(dartMemberName('HealthBar Progress'), 'healthBarProgress');
    });

    test('digits, keywords, reserved names and empty names', () {
      expect(dartMemberName('2nd Target'), 'n2ndTarget');
      expect(dartMemberName('Class'), 'class_');
      expect(dartMemberName('in'), 'in_');
      expect(dartMemberName('await'), 'await_');
      expect(dartMemberName('world', reserved: const {'world'}), 'world_');
      expect(dartMemberName('!!'), 'value');
      expect(dartMemberName('!!', fallback: 'variable'), 'variable');
    });
  });

  test('dartLowerCamelCase does not escape keywords', () {
    expect(dartLowerCamelCase('Class'), 'class');
    expect(dartLowerCamelCase('HealthBar Progress'), 'healthBarProgress');
    expect(dartLowerCamelCase(''), '');
  });

  test('isDartKeyword', () {
    expect(isDartKeyword('class'), isTrue);
    expect(isDartKeyword('late'), isTrue);
    expect(isDartKeyword('door'), isFalse);
  });

  test('legacyDartClassName reproduces the pre-rename class names', () {
    expect(legacyDartClassName('BP_Door'), 'BPDoor');
    expect(legacyDartClassName('WBP_PlayerHUD'), 'WBPPlayerHUD');
    expect(legacyDartClassName('my_first_game'), 'MyFirstGame');
  });
}
