import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lumina_editor_data/lumina_editor.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:lumina_ui/ui/core/property_editors/color_field.dart';
import 'package:lumina_ui/ui/core/property_editors/slider_field.dart';
import 'package:lumina_ui/ui/core/theme/editor_theme.dart';
import 'package:lumina_ui/ui/features/sub_editors/services/project_icon_rasterizer.dart';
import 'package:lumina_ui/ui/features/sub_editors/view_models/project_settings_view_model.dart';

/// Builds a titled settings section (the sub-editor's own look).
typedef SettingsSectionBuilder = Widget Function(String title, List<Widget> children);

/// Builds a labelled, search-aware settings row.
typedef SettingsRowBuilder = Widget Function(String label, Widget control, {String? help});

/// Project Settings → Packaging & Target → **Web Loading Style**:
/// the look of a web build's plain HTML loading
/// screen, shown while a web target is ticked. Every control edits the view
/// model's working copy; Apply & Save writes `packaging.web_loading_style`
/// and regenerates the project's `web/` loading screen. The preview draws the
/// generated page's layout with the same values, and "Open in Browser" serves
/// the generated page itself.
class WebLoadingStyleSection extends StatefulWidget {
  final ProjectSettingsViewModel viewModel;
  final SettingsSectionBuilder section;
  final SettingsRowBuilder row;

  const WebLoadingStyleSection({super.key, required this.viewModel, required this.section, required this.row});

  @override
  State<WebLoadingStyleSection> createState() => _WebLoadingStyleSectionState();
}

class _WebLoadingStyleSectionState extends State<WebLoadingStyleSection> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focus = {};
  double _previewFraction = 0.42;

  ProjectSettingsViewModel get _vm => widget.viewModel;

  static const Map<String, String> _progressLabels = {'bar': 'Bar', 'ring': 'Ring', 'percentage': 'Percentage'};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  /// A controller whose text follows [value] unless its field is focused.
  TextEditingController _controllerFor(String id, String value) {
    final c = _controllers.putIfAbsent(id, () => TextEditingController(text: value));
    final f = _focus.putIfAbsent(id, () => FocusNode());
    if (!f.hasFocus && c.text != value) c.text = value;
    return c;
  }

  FocusNode _focusFor(String id) => _focus.putIfAbsent(id, () => FocusNode());

  @override
  Widget build(BuildContext context) {
    final style = _vm.webLoadingStyle;
    final resolved = _vm.resolvedWebLoadingStyle;
    final brandingBackground = const ProjectWebLoadingStyle().resolve(_vm.project).background;
    final row = widget.row;
    return KeyedSubtree(
      key: const ValueKey('project_settings_web_loading'),
      child: widget.section('Web Loading Style', [
        row(
          'Background',
          KeyedSubtree(
            key: const ValueKey('project_settings_web_loading_background'),
            child: ColorField(
              value: resolved.background,
              defaultValue: brandingBackground,
              onChanged: _vm.setWebLoadingBackground,
              onCommit: _vm.setWebLoadingBackground,
              onReset: () => _vm.setWebLoadingBackground(''),
            ),
          ),
          help: style.background.isEmpty ? 'Follows the Icon Background' : 'Behind the whole page',
        ),
        row(
          'Gradient',
          Row(children: [
            Switch(
              key: const ValueKey('project_settings_web_loading_gradient_toggle'),
              value: style.gradient.isNotEmpty,
              onChanged: _vm.setWebLoadingGradientEnabled,
            ),
            const SizedBox(width: 10),
            if (style.gradient.isNotEmpty)
              Expanded(
                child: KeyedSubtree(
                  key: const ValueKey('project_settings_web_loading_gradient'),
                  child: ColorField(
                    value: resolved.gradient ?? resolved.background,
                    defaultValue: resolved.gradient ?? resolved.background,
                    onChanged: _vm.setWebLoadingGradient,
                    onCommit: _vm.setWebLoadingGradient,
                    onReset: () {},
                  ),
                ),
              ),
          ]),
          help: 'Fades the background to this colour, top to bottom',
        ),
        row(
          'Accent',
          KeyedSubtree(
            key: const ValueKey('project_settings_web_loading_accent'),
            child: ColorField(
              value: resolved.accent,
              defaultValue: ProjectWebLoadingStyle.defaultAccent,
              onChanged: _vm.setWebLoadingAccent,
              onCommit: _vm.setWebLoadingAccent,
              onReset: () => _vm.setWebLoadingAccent(ProjectWebLoadingStyle.defaultAccent),
            ),
          ),
          help: 'The progress bar, ring or percentage',
        ),
        row(
          'Text Colour',
          KeyedSubtree(
            key: const ValueKey('project_settings_web_loading_text'),
            child: ColorField(
              value: resolved.text,
              defaultValue: ProjectWebLoadingStyle.defaultText,
              onChanged: _vm.setWebLoadingText,
              onCommit: _vm.setWebLoadingText,
              onReset: () => _vm.setWebLoadingText(ProjectWebLoadingStyle.defaultText),
            ),
          ),
        ),
        row('Logo', _logoRow(style), help: 'Defaults to the project icon. PNG, JPG, WebP, SVG or GIF.'),
        row(
          'Title',
          TextField(
            key: const ValueKey('project_settings_web_loading_title'),
            controller: _controllerFor('title', style.title),
            focusNode: _focusFor('title'),
            placeholder: Text(_vm.project.projectName),
            onChanged: _vm.setWebLoadingTitle,
          ),
          help: 'Empty shows the project name; also the browser tab title',
        ),
        row(
          'Subtitle',
          TextField(
            key: const ValueKey('project_settings_web_loading_subtitle'),
            controller: _controllerFor('subtitle', style.subtitle),
            focusNode: _focusFor('subtitle'),
            onChanged: _vm.setWebLoadingSubtitle,
          ),
        ),
        row(
          'Progress Style',
          KeyedSubtree(
            key: const ValueKey('project_settings_web_loading_progress_style'),
            child: Select<String>(
              value: resolved.progressStyle,
              onChanged: (v) {
                if (v != null) _vm.setWebLoadingProgressStyle(v);
              },
              itemBuilder: (context, item) => Text(_progressLabels[item] ?? item, style: const TextStyle(fontSize: 10.5)),
              popup: SelectPopup(
                items: SelectItemList(
                  children: [
                    for (final s in ProjectWebLoadingStyle.progressStyles)
                      SelectItemButton(value: s, child: Text(_progressLabels[s] ?? s, style: const TextStyle(fontSize: 10.5))),
                  ],
                ),
              ).call,
            ),
          ),
        ),
        row(
          'Fade Duration',
          KeyedSubtree(
            key: const ValueKey('project_settings_web_loading_fade'),
            child: SliderField(
              value: resolved.fadeMs.toDouble(),
              defaultValue: ProjectWebLoadingStyle.defaultFadeMs.toDouble(),
              min: 0,
              max: ProjectWebLoadingStyle.maxFadeMs.toDouble(),
              unit: 'ms',
              fractionDigits: 0,
              onChanged: (v) => _vm.setWebLoadingFadeMs(v.round()),
              onCommit: (v) => _vm.setWebLoadingFadeMs(v.round()),
              onReset: () => _vm.setWebLoadingFadeMs(ProjectWebLoadingStyle.defaultFadeMs),
            ),
          ),
          help: 'How long the screen fades out once the game draws its first frame',
        ),
        row('Preview', _preview(resolved), help: 'The loading screen with these values; Apply & Save regenerates web/'),
      ]),
    );
  }

  Widget _logoRow(ProjectWebLoadingStyle style) {
    final logo = style.logo;
    final label = switch (logo) {
      ProjectWebLoadingStyle.logoFromIcon => _vm.project.branding.usesDefaultIcon ? 'Project icon (Lumina logo)' : 'Project icon (${_vm.project.branding.icon})',
      ProjectWebLoadingStyle.logoNone => 'No logo',
      _ => logo,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 36,
          height: 36,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Color(ResolvedWebLoadingStyle.argb(_vm.resolvedWebLoadingStyle.background)),
            border: Border.all(color: EditorColors.border),
            borderRadius: BorderRadius.circular(4),
          ),
          child: _logoImage(logo),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              key: const ValueKey('project_settings_web_loading_logo_label'),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, fontFamily: EditorTypography.monoFamily, color: EditorColors.foreground)),
        ),
        OutlineButton(
          key: const ValueKey('project_settings_web_loading_logo_choose'),
          onPressed: _chooseLogo,
          child: const Text('Choose…', style: TextStyle(fontSize: 10)),
        ),
        const SizedBox(width: 6),
        GhostButton(
          key: const ValueKey('project_settings_web_loading_logo_icon'),
          onPressed: logo == ProjectWebLoadingStyle.logoFromIcon ? null : _vm.useProjectIconAsWebLoadingLogo,
          child: const Text('Use Project Icon', style: TextStyle(fontSize: 10)),
        ),
        GhostButton(
          key: const ValueKey('project_settings_web_loading_logo_none'),
          onPressed: logo == ProjectWebLoadingStyle.logoNone ? null : _vm.useNoWebLoadingLogo,
          child: const Text('No Logo', style: TextStyle(fontSize: 10)),
        ),
      ]),
    ]);
  }

  /// The logo as the page will show it, or null for none.
  Widget? _logoImage(String logo) {
    if (logo == ProjectWebLoadingStyle.logoNone) return null;
    final File? file = logo == ProjectWebLoadingStyle.logoFromIcon ? _vm.iconFile : _vm.webLoadingLogoFile;
    if (file == null) return Image.asset(ProjectIconRasterizer.defaultIconAsset, fit: BoxFit.contain);
    if (!file.existsSync()) return const Icon(LucideIcons.imageOff, size: 16, color: EditorColors.logError);
    final key = ValueKey('web_loading_logo_${file.path}_${file.lastModifiedSync().microsecondsSinceEpoch}');
    return file.path.toLowerCase().endsWith('.svg') ? SvgPicture.file(file, key: key, fit: BoxFit.contain) : Image.file(file, key: key, fit: BoxFit.contain);
  }

  Future<void> _chooseLogo() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choose the web loading logo',
      type: FileType.custom,
      allowedExtensions: ProjectWebLoadingStyle.logoExtensions,
    );
    final path = result?.files.single.path;
    if (path != null) await _vm.chooseWebLoadingLogo(path);
  }

  Widget _preview(ResolvedWebLoadingStyle resolved) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WebLoadingPreview(
        key: const ValueKey('project_settings_web_loading_preview'),
        style: resolved,
        logo: _logoImage(resolved.logo),
        fraction: _previewFraction,
      ),
      const SizedBox(height: 6),
      Row(children: [
        const Text('Progress', style: TextStyle(fontSize: 9.5, color: EditorColors.mutedForeground)),
        const SizedBox(width: 8),
        Expanded(
          child: KeyedSubtree(
            key: const ValueKey('project_settings_web_loading_preview_progress'),
            child: SliderField(
              value: _previewFraction * 100,
              defaultValue: 42,
              min: 0,
              max: 100,
              unit: '%',
              fractionDigits: 0,
              onChanged: (v) => setState(() => _previewFraction = v / 100),
              onCommit: (v) => setState(() => _previewFraction = v / 100),
              onReset: () => setState(() => _previewFraction = 0.42),
            ),
          ),
        ),
        const SizedBox(width: 10),
        OutlineButton(
          key: const ValueKey('project_settings_web_loading_open_browser'),
          onPressed: _vm.previewWebLoadingInBrowser,
          child: const Text('Open in Browser', style: TextStyle(fontSize: 10)),
        ),
      ]),
      if (_vm.webLoadingStatus != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_vm.webLoadingStatus!,
              key: const ValueKey('project_settings_web_loading_status'), style: const TextStyle(fontSize: 9, color: EditorColors.mutedForeground)),
        ),
      if (_vm.webLoadingError != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_vm.webLoadingError!,
              key: const ValueKey('project_settings_web_loading_error'), style: const TextStyle(fontSize: 9, color: EditorColors.logError)),
        ),
    ]);
  }
}

/// The loading screen's layout, drawn in Flutter with the page's values
/// (`web/index.html` + `loading.css`): background or gradient, logo, title,
/// subtitle, the progress in its style and the phase label `loading.js`
/// shows at [fraction].
class WebLoadingPreview extends StatelessWidget {
  final ResolvedWebLoadingStyle style;
  final Widget? logo;
  final double fraction;

  const WebLoadingPreview({super.key, required this.style, required this.logo, required this.fraction});

  /// The label `loading.js` shows around [fraction] (its phases).
  static String labelFor(double fraction) {
    if (fraction >= 1) return 'Starting the game';
    if (fraction >= LuminaWebLoading.rendererEnd) return 'Loading game assets';
    if (fraction >= LuminaWebLoading.rendererStart) return 'Downloading the renderer';
    if (fraction >= LuminaWebLoading.engineEnd) return 'Starting the engine';
    return 'Downloading the engine';
  }

  @override
  Widget build(BuildContext context) {
    final background = Color(ResolvedWebLoadingStyle.argb(style.background));
    final accent = Color(ResolvedWebLoadingStyle.argb(style.accent));
    final text = Color(ResolvedWebLoadingStyle.argb(style.text));
    final gradient = style.gradient;
    final percent = '${(fraction * 100).round()}%';
    final Widget progress = switch (style.progressStyle) {
      'ring' => SizedBox(
          width: 44,
          height: 44,
          child: CustomPaint(
            painter: _RingPainter(fraction: fraction, accent: accent, track: text.withValues(alpha: 0.16)),
            child: Center(child: Text(percent, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: text))),
          ),
        ),
      'percentage' => Text(percent, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: accent)),
      _ => SizedBox(
          width: 190,
          height: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(children: [
              Positioned.fill(child: ColoredBox(color: text.withValues(alpha: 0.16))),
              FractionallySizedBox(widthFactor: fraction.clamp(0.0, 1.0), heightFactor: 1, child: ColoredBox(color: accent)),
            ]),
          ),
        ),
    };
    return Container(
      width: 360,
      height: 202,
      decoration: BoxDecoration(
        color: background,
        gradient: gradient == null
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [background, Color(ResolvedWebLoadingStyle.argb(gradient))],
              ),
        border: Border.all(color: EditorColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (logo != null) SizedBox(width: 48, height: 48, child: logo),
          const SizedBox(height: 6),
          Text(style.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: text)),
          if (style.subtitle.trim().isNotEmpty) Text(style.subtitle, style: TextStyle(fontSize: 8, color: text.withValues(alpha: 0.75))),
          const SizedBox(height: 8),
          progress,
          const SizedBox(height: 6),
          Text(labelFor(fraction), style: TextStyle(fontSize: 7, color: text.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color accent;
  final Color track;

  _RingPainter({required this.fraction, required this.accent, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.07;
    final inner = rect.deflate(stroke / 2);
    canvas.drawArc(inner, 0, math.pi * 2, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track);
    canvas.drawArc(inner, -math.pi / 2, math.pi * 2 * fraction.clamp(0.0, 1.0), false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = accent);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.accent != accent || old.track != track;
}
