import 'package:flutter/foundation.dart';
import 'package:lumina/lumina.dart';
import '../../../core/services/content_folders.dart';
import '../services/installed_template_repository.dart';
import '../services/template_project_creator.dart';
import 'launcher_view_model.dart';

class CreateProjectViewModel extends ChangeNotifier {
  final LauncherViewModel launcherVM;
  final ProjectRepository projectRepo;

  String _name = 'my_lumina_game';
  String _location;
  String _template = 'blank_3d';
  String _widgetLibrary = kUmgWidgetLibraryShadcn;
  String? _validationError;

  bool _isCreating = false;
  ProjectCreationStep? _currentStep;
  double _progress = 0.0;
  String _progressLabel = '';
  final List<String> _processOutput = [];
  String? _creationError;
  LuminaProject? _activeProject;

  CreateProjectViewModel({
    required this.launcherVM,
    required this.projectRepo,
  }) : _location = launcherVM.defaultProjectsDirectory {
    _validate();
  }

  String get name => _name;
  String get location => _location;
  String get template => _template;

  /// The UMG widget library the new project's widgets use.
  String get widgetLibrary => _widgetLibrary;
  String? get validationError => _validationError;
  LuminaProject? get activeProject => _activeProject;

  bool get isCreating => _isCreating;
  ProjectCreationStep? get currentStep => _currentStep;
  double get progress => _progress;
  String get progressLabel => _progressLabel;
  List<String> get processOutput => _processOutput;
  String? get creationError => _creationError;

  void updateName(String val) {
    _name = val;
    _validate();
    notifyListeners();
  }

  void updateLocation(String val) {
    _location = val;
    _validate();
    notifyListeners();
  }

  void updateWidgetLibrary(String library) {
    if (!kUmgWidgetLibraries.contains(library)) return;
    _widgetLibrary = library;
    notifyListeners();
  }

  void updateTemplate(String val) {
    _template = val;
    notifyListeners();
  }

  /// The installed folder templates, after the built-in ones.
  List<InstalledGameTemplate> get installedTemplates => launcherVM.installedTemplates;

  /// The selected installed template, or null for a built-in one.
  InstalledGameTemplate? get selectedInstalledTemplate {
    if (!_template.startsWith(kInstalledTemplateIdPrefix)) return null;
    for (final t in installedTemplates) {
      if (t.id == _template) return t;
    }
    return null;
  }

  /// Uninstalls a Marketplace template from the dialog; a selected one falls
  /// back to Blank 3D.
  bool uninstallTemplate(InstalledGameTemplate template) {
    final ok = launcherVM.uninstallTemplate(template);
    if (_template == template.id) _template = 'blank_3d';
    notifyListeners();
    return ok;
  }

  static String? validateProjectName(String name) {
    if (name.isEmpty) return 'Project name cannot be empty.';
    if (RegExp(r'^[0-9]').hasMatch(name)) return 'Project name cannot start with a number.';
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(name)) return 'Project name must be lowercase with underscores (e.g. my_game)';
    if (name.toLowerCase() == 'class') return 'Project name cannot be a reserved Dart keyword.';
    return null;
  }
  static String? validateLocation(String location) {
    if (location.isEmpty) return 'Location cannot be empty.';
    return null;
  }

  void _validate() {
    _validationError = validateProjectName(_name) ?? validateLocation(_location);
    notifyListeners();
  }

  Future<void> createProject() async {
    if (_validationError != null) return;

    _isCreating = true;
    _creationError = null;
    _processOutput.clear();
    _progress = 0.0;
    _progressLabel = 'Starting creation...';
    notifyListeners();

    try {
      final installed = selectedInstalledTemplate;
      if (_template.startsWith(kInstalledTemplateIdPrefix) && installed == null) {
        throw StateError('The template ${_template.substring(kInstalledTemplateIdPrefix.length)} is no longer installed.');
      }
      // An installed template brings its own widget library (its code is
      // built on it); a built-in one takes the dialog's choice.
      final stream = installed != null
          ? TemplateProjectCreator(projectRepo).create(
              template: installed,
              projectName: _name,
              projectLocation: _location,
            )
          : projectRepo.createProjectStream(
              projectName: _name,
              projectLocation: _location,
              template: _template,
              widgetLibrary: _widgetLibrary,
            );
      await for (final p in stream) {
        _currentStep = p.step;
        _progress = p.progress;
        _progressLabel = p.message;
        _processOutput.add(p.message);
        notifyListeners();
      }

      // Standard folders the template's own assets do not create:
      // widgets/ and input/, kept by a marker file.
      final created = ContentFolders.ensureProjectFolders('$_location/$_name');
      if (created.isNotEmpty) {
        _processOutput.add('Created content folders: ${created.join(', ')}');
        notifyListeners();
      }

      // Every project gets its own editor; its host is written now
      // so the first Open builds it. A failure here never fails the creation —
      // Open generates a missing host again.
      final resolver = launcherVM.editorResolver;
      if (resolver.everyProject) {
        try {
          await resolver.generator.generate('$_location/$_name', const [], projectName: _name);
          _processOutput.add("Wrote the project's editor host (.lumina/editor)");
        } catch (e) {
          _processOutput.add("Could not write the project's editor host: $e");
        }
        notifyListeners();
      }

      await launcherVM.loadRecentProjects();
      final path = '$_location/$_name/$_name.lmproject';
      _activeProject = await projectRepo.loadProject(path);
    } catch (e) {
      _creationError = e.toString();
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }
}
