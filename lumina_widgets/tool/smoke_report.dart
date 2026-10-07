// Runs lumina_widgets' smoke tests (or any tests named) on GPU 1 and writes
// the report: `build/smoke_report.html` plus one page per area under
// `build/smoke_report/`, linking (never embedding) the artifacts in
// `build/smoke_artifacts/`.
//
//   dart run tool/smoke_report.dart test/smoke/game_widget_smoke_test.dart --no-dashboard
//                                                    # targeted run: merges
//   dart run tool/smoke_report.dart <target> --fresh # targeted, starts clean
//   dart run tool/smoke_report.dart --report-only    # re-render from events
//
// The runner, the report and every flag are lumina_smoke's
// (`package:lumina_smoke/report.dart`); this file is the package's
// configuration.
import 'package:lumina_smoke/report.dart';

/// lumina_widgets' report configuration.
const SmokeReportConfig luminaWidgetsSmokeConfig = SmokeReportConfig(
  title: 'Lumina Widgets Smoke & Test Report',
  tag: 'Game UI',
  dashboardTitle: 'Lumina Widgets Smoke Tests',
  categories: luminaWidgetsTestCategories,
  categoryNote: 'One page per area; every PNG and video is linked from build/smoke_artifacts/, not embedded.',
  scenarioKeywords: ['game_widget', 'umg'],
);

/// The package's areas, in report order, with the words that place a test
/// file in them.
const TestCategories luminaWidgetsTestCategories = TestCategories(
  [
    ('Game Widget & Host', ['game_widget', 'game_host', 'lumina_widget', 'game']),
    ('UMG', ['umg', 'element', 'widget_layer', 'widget_element']),
    ('Media', ['media', 'video', 'audio']),
    ('Foundation', ['engine_observables', 'observable']),
    ('Web', ['web', 'game_import_graph']),
  ],
  longestMatch: true,
  folders: {'umg': 'UMG', 'media': 'Media', 'web': 'Web', 'foundation': 'Foundation', 'game': 'Game Widget & Host'},
);

Future<void> main(List<String> args) => smokeReportMain(args, luminaWidgetsSmokeConfig);
