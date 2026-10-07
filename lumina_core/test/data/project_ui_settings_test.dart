import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/models/lumina_project.dart';

/// The project's UMG widget library lives in the manifest.
void main() {
  test('ui.widget_library round-trips; a manifest without a ui section reads shadcn', () {
    const project = LuminaProject(projectName: 'hud_game', ui: ProjectUiSettings(widgetLibrary: kUmgWidgetLibraryFlutter));
    final map = project.toMap();
    expect(map['ui'], {'widget_library': 'flutter'});
    expect(LuminaProject.fromMap(map).ui.widgetLibrary, kUmgWidgetLibraryFlutter);

    final legacy = Map<String, dynamic>.from(map)..remove('ui');
    expect(LuminaProject.fromMap(legacy).ui.widgetLibrary, kUmgWidgetLibraryShadcn,
        reason: 'what the UMG codegen emitted before the setting existed');
    expect(const LuminaProject(projectName: 'x').ui.widgetLibrary, kUmgWidgetLibraryShadcn, reason: 'the default');
    expect(project.copyWith(ui: const ProjectUiSettings(widgetLibrary: kUmgWidgetLibraryShadcn)).ui.widgetLibrary, kUmgWidgetLibraryShadcn);
    expect(ProjectUiSettings.fromMap(const {'widget_library': 'nonsense'}).widgetLibrary, kUmgWidgetLibraryShadcn);
  });
}
