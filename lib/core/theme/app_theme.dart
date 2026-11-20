import 'dart:ui' show FontFeature;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Spacing scale.
class Sp {
  const Sp._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii: small controls, panels, sheets.
class Rad {
  const Rad._();
  static const double control = 12;
  static const double panel = 16;
  static const double sheet = 24;
}

class Breakpoints {
  const Breakpoints._();

  /// Below this width the app uses the phone layout (bottom navigation).
  static const double compact = 720;

  /// From this width the navigation rail shows labels.
  static const double wide = 1100;
}

/// Semantic colours that the Material [ColorScheme] has no slot for.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.paper,
    required this.line,
    required this.lineStrong,
    required this.muted,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.accent,
    required this.accentSoft,
  });

  final Color paper;
  final Color line;
  final Color lineStrong;
  final Color muted;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color accent;
  final Color accentSoft;

  static const AppPalette light = AppPalette(
    paper: AppColors.paper,
    line: AppColors.line,
    lineStrong: AppColors.lineStrong,
    muted: AppColors.muted,
    success: AppColors.leaf,
    successSoft: AppColors.leafSoft,
    warning: AppColors.haldiDeep,
    warningSoft: AppColors.haldiSoft,
    danger: AppColors.chili,
    dangerSoft: AppColors.chiliSoft,
    accent: AppColors.haldi,
    accentSoft: AppColors.haldiSoft,
  );

  static const AppPalette dark = AppPalette(
    paper: AppColors.darkPaper,
    line: AppColors.darkLine,
    lineStrong: AppColors.darkLineStrong,
    muted: AppColors.darkMuted,
    success: Color(0xFF5FC79A),
    successSoft: Color(0xFF173A2C),
    warning: Color(0xFFF5C25A),
    warningSoft: Color(0xFF3A2D0C),
    danger: Color(0xFFFF8A80),
    dangerSoft: Color(0xFF3B1714),
    accent: AppColors.haldi,
    accentSoft: Color(0xFF3A2D0C),
  );

  @override
  AppPalette copyWith({
    Color? paper,
    Color? line,
    Color? lineStrong,
    Color? muted,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? accent,
    Color? accentSoft,
  }) {
    return AppPalette(
      paper: paper ?? this.paper,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      muted: muted ?? this.muted,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      paper: Color.lerp(paper, other.paper, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
    );
  }
}

/// Shortcuts for reading the theme.
extension ThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textStyles => Theme.of(this).textTheme;
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isCompact => screenWidth < Breakpoints.compact;
  bool get isWide => screenWidth >= Breakpoints.wide;
}

/// Tabular figures keep prices and counters aligned.
TextStyle withTabularFigures(TextStyle style) =>
    style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.leaf,
    onPrimary: Colors.white,
    primaryContainer: AppColors.leafSoft,
    onPrimaryContainer: AppColors.leafDeep,
    secondary: AppColors.haldi,
    onSecondary: AppColors.ink,
    secondaryContainer: AppColors.haldiSoft,
    onSecondaryContainer: AppColors.haldiDeep,
    error: AppColors.chili,
    onError: Colors.white,
    errorContainer: AppColors.chiliSoft,
    onErrorContainer: AppColors.chiliDeep,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    outline: AppColors.lineStrong,
    outlineVariant: AppColors.line,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.paper,
    surfaceContainer: AppColors.paper,
    surfaceContainerHigh: Color(0xFFEBEFE9),
    surfaceContainerHighest: Color(0xFFE5EAE3),
    inverseSurface: AppColors.ink,
    onInverseSurface: Colors.white,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF4FBF8E),
    onPrimary: Color(0xFF062A1D),
    primaryContainer: Color(0xFF173A2C),
    onPrimaryContainer: Color(0xFFBFE8D3),
    secondary: AppColors.haldi,
    onSecondary: Color(0xFF2B1D00),
    secondaryContainer: Color(0xFF3A2D0C),
    onSecondaryContainer: Color(0xFFF5C25A),
    error: Color(0xFFFF8A80),
    onError: Color(0xFF410002),
    errorContainer: Color(0xFF3B1714),
    onErrorContainer: Color(0xFFFFB4AB),
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkInk,
    onSurfaceVariant: AppColors.darkMuted,
    outline: AppColors.darkLineStrong,
    outlineVariant: AppColors.darkLine,
    surfaceContainerLowest: AppColors.darkPaper,
    surfaceContainerLow: AppColors.darkSurface,
    surfaceContainer: AppColors.darkSurface,
    surfaceContainerHigh: Color(0xFF1A3025),
    surfaceContainerHighest: Color(0xFF213A2E),
    inverseSurface: AppColors.darkInk,
    onInverseSurface: AppColors.darkPaper,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  /// One family for Bangla and English: Anek Bangla carries both scripts in
  /// matching weights, so mixed content looks like a single voice. Falls back
  /// to the platform font if the family cannot be resolved.
  static TextTheme _textTheme(Brightness brightness, Color ink) {
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
    ).textTheme;
    TextTheme themed;
    try {
      themed = GoogleFonts.getTextTheme('Anek Bangla', base);
    } catch (_) {
      themed = base;
    }
    return themed
        .copyWith(
          displaySmall: themed.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
          headlineMedium: themed.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
          headlineSmall: themed.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          titleLarge: themed.titleLarge?.copyWith(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: themed.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          titleSmall: themed.titleSmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: themed.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
          bodyMedium: themed.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
          bodySmall: themed.bodySmall?.copyWith(fontSize: 12.5, height: 1.4),
          labelLarge: themed.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          labelMedium: themed.labelMedium?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          labelSmall: themed.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        )
        .apply(bodyColor: ink, displayColor: ink);
  }

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark ? _darkScheme : _lightScheme;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final text = _textTheme(brightness, scheme.onSurface);

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(Rad.control),
          borderSide: BorderSide(color: color, width: width),
        );

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Rad.control),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: palette.paper,
      extensions: <ThemeExtension<dynamic>>[palette],
      dividerColor: palette.line,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.paper,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Rad.panel),
          side: BorderSide(color: palette.line),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.line,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: text.bodyMedium?.copyWith(
          color: palette.muted.withValues(alpha: 0.75),
        ),
        helperStyle: text.bodySmall?.copyWith(color: palette.muted),
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
        border: border(palette.line),
        enabledBorder: border(palette.line),
        disabledBorder: border(palette.line.withValues(alpha: 0.6)),
        focusedBorder: border(scheme.primary, 1.6),
        errorBorder: border(scheme.error),
        focusedErrorBorder: border(scheme.error, 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: palette.line,
          disabledForegroundColor: palette.muted,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: BorderSide(color: palette.lineStrong),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 44),
          shape: controlShape,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelSmall?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.onSurface : palette.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.onPrimaryContainer : palette.muted,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: palette.muted),
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(
          color: palette.muted,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        disabledColor: palette.line,
        side: BorderSide(color: palette.line),
        shape: const StadiumBorder(),
        labelStyle: text.labelMedium,
        secondaryLabelStyle: text.labelMedium,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : palette.lineStrong,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : palette.line,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: palette.lineStrong, width: 1.5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? scheme.surfaceContainerHighest
            : AppColors.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: controlShape,
        insetPadding: const EdgeInsets.all(16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: palette.lineStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Rad.sheet)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        iconColor: palette.muted,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall?.copyWith(color: palette.muted),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: palette.line,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.25),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? scheme.surfaceContainerHighest : AppColors.ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: text.bodySmall?.copyWith(color: Colors.white),
      ),
    );
  }
}
