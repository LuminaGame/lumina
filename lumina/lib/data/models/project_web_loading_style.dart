import 'lumina_project.dart';

/// `packaging.web_loading_style` in the `.lmproject`: how a web build's plain HTML loading screen
/// looks while the engine, the renderer and the game's assets download.
///
/// Empty fields fall back to the project: the background to the Icon
/// Background, the title to the project name, the logo ([logoFromIcon]) to
/// the project icon. [resolve] applies those fallbacks and replaces invalid
/// values, so nothing unchecked reaches the generated CSS or HTML.
class ProjectWebLoadingStyle {
  /// `#RRGGBB`; empty: the project's Icon Background.
  final String background;

  /// `#RRGGBB` the background fades to (top to bottom); empty: a solid colour.
  final String gradient;

  /// `#RRGGBB` of the progress bar / ring.
  final String accent;

  /// `#RRGGBB` of the title, subtitle and labels.
  final String text;

  /// [logoFromIcon], a project-relative image (PNG, JPG, WebP, SVG, GIF), or
  /// [logoNone].
  final String logo;

  /// Empty: the project name.
  final String title;
  final String subtitle;

  /// One of [progressStyles].
  final String progressStyle;

  /// How long the screen takes to fade out once the first frame is drawn.
  final int fadeMs;

  static const String logoFromIcon = 'icon';
  static const String logoNone = 'none';
  static const String defaultAccent = '#FB7C01';
  static const String defaultText = '#FFFFFF';
  static const int defaultFadeMs = 400;
  static const int maxFadeMs = 3000;
  static const List<String> progressStyles = ['bar', 'ring', 'percentage'];

  /// Image extensions a browser shows as the logo.
  static const List<String> logoExtensions = ['png', 'jpg', 'jpeg', 'webp', 'svg', 'gif'];

  const ProjectWebLoadingStyle({
    this.background = '',
    this.gradient = '',
    this.accent = defaultAccent,
    this.text = defaultText,
    this.logo = logoFromIcon,
    this.title = '',
    this.subtitle = '',
    this.progressStyle = 'bar',
    this.fadeMs = defaultFadeMs,
  });

  static final RegExp _hex = RegExp(r'^#[0-9a-fA-F]{6}$');

  static bool isHexColor(String v) => _hex.hasMatch(v.trim());

  /// Why this style cannot be generated as it is (Project Settings shows
  /// these as validation errors; [resolve] falls back instead).
  List<String> problems() => [
        if (background.trim().isNotEmpty && !isHexColor(background)) 'Web loading background "$background" must be a #RRGGBB colour',
        if (gradient.trim().isNotEmpty && !isHexColor(gradient)) 'Web loading gradient "$gradient" must be a #RRGGBB colour',
        if (!isHexColor(accent)) 'Web loading accent "$accent" must be a #RRGGBB colour',
        if (!isHexColor(text)) 'Web loading text colour "$text" must be a #RRGGBB colour',
        if (!progressStyles.contains(progressStyle)) 'Web loading progress style "$progressStyle" is not one of ${progressStyles.join(', ')}',
        if (fadeMs < 0 || fadeMs > maxFadeMs) 'Web loading fade must be between 0 and $maxFadeMs ms',
      ];

  /// The values the generated page uses for [project].
  ResolvedWebLoadingStyle resolve(LuminaProject project) {
    String color(String v, String fallback) => isHexColor(v) ? v.trim().toUpperCase() : fallback;
    final iconBackground = project.branding.iconBackgroundArgb == null ? '#000000' : project.branding.iconBackground.trim().toUpperCase();
    return ResolvedWebLoadingStyle(
      background: background.trim().isEmpty ? iconBackground : color(background, iconBackground),
      gradient: isHexColor(gradient) ? gradient.trim().toUpperCase() : null,
      accent: color(accent, defaultAccent),
      text: color(text, defaultText),
      logo: logo.trim().isEmpty ? logoFromIcon : logo.trim(),
      title: title.trim().isEmpty ? project.projectName : title,
      subtitle: subtitle,
      progressStyle: progressStyles.contains(progressStyle) ? progressStyle : 'bar',
      fadeMs: fadeMs.clamp(0, maxFadeMs),
    );
  }

  Map<String, dynamic> toMap() => {
        'background': background,
        'gradient': gradient,
        'accent': accent,
        'text': text,
        'logo': logo,
        'title': title,
        'subtitle': subtitle,
        'progress_style': progressStyle,
        'fade_ms': fadeMs,
      };

  factory ProjectWebLoadingStyle.fromMap(Map<String, dynamic> map) => ProjectWebLoadingStyle(
        background: map['background'] as String? ?? '',
        gradient: map['gradient'] as String? ?? '',
        accent: map['accent'] as String? ?? defaultAccent,
        text: map['text'] as String? ?? defaultText,
        logo: map['logo'] as String? ?? logoFromIcon,
        title: map['title'] as String? ?? '',
        subtitle: map['subtitle'] as String? ?? '',
        progressStyle: map['progress_style'] as String? ?? 'bar',
        fadeMs: (map['fade_ms'] as num?)?.round() ?? defaultFadeMs,
      );

  ProjectWebLoadingStyle copyWith({
    String? background,
    String? gradient,
    String? accent,
    String? text,
    String? logo,
    String? title,
    String? subtitle,
    String? progressStyle,
    int? fadeMs,
  }) =>
      ProjectWebLoadingStyle(
        background: background ?? this.background,
        gradient: gradient ?? this.gradient,
        accent: accent ?? this.accent,
        text: text ?? this.text,
        logo: logo ?? this.logo,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        progressStyle: progressStyle ?? this.progressStyle,
        fadeMs: fadeMs ?? this.fadeMs,
      );
}

/// A [ProjectWebLoadingStyle] with the project fallbacks applied and every
/// colour a valid upper-case `#RRGGBB`.
class ResolvedWebLoadingStyle {
  final String background;

  /// Null: a solid [background].
  final String? gradient;
  final String accent;
  final String text;
  final String logo;
  final String title;
  final String subtitle;
  final String progressStyle;
  final int fadeMs;

  const ResolvedWebLoadingStyle({
    required this.background,
    required this.gradient,
    required this.accent,
    required this.text,
    required this.logo,
    required this.title,
    required this.subtitle,
    required this.progressStyle,
    required this.fadeMs,
  });

  /// `0xAARRGGBB` of a resolved `#RRGGBB` colour.
  static int argb(String hex) => 0xFF000000 | int.parse(hex.substring(1), radix: 16);
}
