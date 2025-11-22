import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class BillingColors extends ThemeExtension<BillingColors> {
  const BillingColors({
    required this.background,
    required this.surface,
    required this.surfaceElevation,
    required this.surfaceTint,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.success,
    required this.warning,
    required this.danger,
    required this.pillBackground,
    required this.pillForeground,
    required this.shadowColor,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevation;
  final Color surfaceTint;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color success;
  final Color warning;
  final Color danger;
  final Color pillBackground;
  final Color pillForeground;
  final Color shadowColor;

  @override
  BillingColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevation,
    Color? surfaceTint,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? success,
    Color? warning,
    Color? danger,
    Color? pillBackground,
    Color? pillForeground,
    Color? shadowColor,
  }) {
    return BillingColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevation: surfaceElevation ?? this.surfaceElevation,
      surfaceTint: surfaceTint ?? this.surfaceTint,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      pillBackground: pillBackground ?? this.pillBackground,
      pillForeground: pillForeground ?? this.pillForeground,
      shadowColor: shadowColor ?? this.shadowColor,
    );
  }

  @override
  ThemeExtension<BillingColors> lerp(
    ThemeExtension<BillingColors>? other,
    double t,
  ) {
    if (other is! BillingColors) return this;
    return BillingColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevation: Color.lerp(
        surfaceElevation,
        other.surfaceElevation,
        t,
      )!,
      surfaceTint: Color.lerp(surfaceTint, other.surfaceTint, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      pillBackground: Color.lerp(pillBackground, other.pillBackground, t)!,
      pillForeground: Color.lerp(pillForeground, other.pillForeground, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
    );
  }
}

@immutable
class BillingSpacing extends ThemeExtension<BillingSpacing> {
  const BillingSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.gutter,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double gutter;

  @override
  BillingSpacing copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? gutter,
  }) {
    return BillingSpacing(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      gutter: gutter ?? this.gutter,
    );
  }

  @override
  ThemeExtension<BillingSpacing> lerp(
    ThemeExtension<BillingSpacing>? other,
    double t,
  ) {
    if (other is! BillingSpacing) return this;
    return BillingSpacing(
      xs: lerpDouble(xs, other.xs, t),
      sm: lerpDouble(sm, other.sm, t),
      md: lerpDouble(md, other.md, t),
      lg: lerpDouble(lg, other.lg, t),
      xl: lerpDouble(xl, other.xl, t),
      gutter: lerpDouble(gutter, other.gutter, t),
    );
  }

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

class _Palette {
  // Modern Blue Theme
  static const Color background = Color(0xFFF8FAFC); // Cool light gray
  static const Color surface = Colors.white;
  static const Color surfaceElevation = Color(0xFFFFFFFF);
  static const Color surfaceTint = Color(0xFFF1F5F9);
  static const Color primary = Color(0xFF2563EB); // Modern blue
  static const Color secondary = Color(0xFF1E40AF); // Darker blue
  static const Color secondaryContainer = Color(0xFFDBEAFE); // Light blue background
  static const Color border = Color(0xFFE5E7EB); // Light gray border
  static const Color subtleBorder = Color(0xFFF1F5F9);
  static const Color textPrimary = Color(0xFF0F172A); // Almost black
  static const Color textSecondary = Color(0xFF334155); // Dark gray
  static const Color textMuted = Color(0xFF64748B); // Medium gray
  static const Color success = Color(0xFF0FA47F); // Keep green
  static const Color warning = Color(0xFFF59E0B); // Keep orange
  static const Color danger = Color(0xFFEF4444); // Keep red
  static const Color pillBackground = Color(0xFFDBEAFE); // Light blue
  static const Color pillForeground = Color(0xFF1E40AF); // Dark blue
  static const Color shadow = Color(0x0A000000); // Softer shadow
}

TextTheme _buildTextTheme([TextTheme? base]) {
  final fallback = base ?? ThemeData.light().textTheme;
  final poppins = GoogleFonts.poppinsTextTheme(fallback);

  return poppins.copyWith(
    displayLarge: poppins.displayLarge?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 48,
      letterSpacing: -0.8,
      height: 1.05,
    ),
    displayMedium: poppins.displayMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 40,
      letterSpacing: -0.6,
      height: 1.08,
    ),
    headlineLarge: poppins.headlineLarge?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 32,
      letterSpacing: -0.4,
      height: 1.1,
    ),
    headlineMedium: poppins.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 28,
      letterSpacing: -0.2,
      height: 1.2,
    ),
    headlineSmall: poppins.headlineSmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 24,
      letterSpacing: -0.1,
      height: 1.25,
    ),
    titleLarge: poppins.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 20,
      height: 1.3,
    ),
    titleMedium: poppins.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 18,
      height: 1.35,
    ),
    titleSmall: poppins.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 16,
      letterSpacing: 0.1,
      height: 1.4,
    ),
    bodyLarge: poppins.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
      fontSize: 16,
      height: 1.55,
      letterSpacing: 0.1,
    ),
    bodyMedium: poppins.bodyMedium?.copyWith(
      fontSize: 14.5,
      fontWeight: FontWeight.w500,
      height: 1.6,
      letterSpacing: 0.15,
    ),
    bodySmall: poppins.bodySmall?.copyWith(
      fontSize: 13,
      height: 1.6,
      letterSpacing: 0.2,
    ),
    labelLarge: poppins.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 13.5,
      letterSpacing: 0.6,
    ),
    labelMedium: poppins.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 12.5,
      letterSpacing: 0.5,
    ),
    labelSmall: poppins.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 11.5,
      letterSpacing: 0.4,
    ),
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData.light();

    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: _Palette.primary,
      onPrimary: Colors.white,
      secondary: _Palette.secondary,
      onSecondary: Colors.white,
      error: _Palette.danger,
      onError: Colors.white,
      surface: _Palette.surface,
      onSurface: _Palette.textPrimary,
      background: _Palette.background,
      onBackground: _Palette.textPrimary,
      primaryContainer: Color(0xFF1E40AF),
      onPrimaryContainer: Colors.white,
      secondaryContainer: Color(0xFFDBEAFE),
      onSecondaryContainer: _Palette.secondary,
      surfaceVariant: Color(0xFFF1F5F9),
      onSurfaceVariant: _Palette.textSecondary,
      outline: _Palette.border,
      shadow: _Palette.shadow,
      scrim: Colors.black45,
      inverseSurface: _Palette.secondary,
      onInverseSurface: Colors.white,
      tertiary: _Palette.warning,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFFFEDD5),
      onTertiaryContainer: _Palette.warning,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme)
        .apply(
          bodyColor: colorScheme.onSurface.withOpacity(0.92),
          displayColor: colorScheme.onSurface,
        )
        .copyWith(
          bodyMedium: (base.textTheme.bodyMedium ?? const TextStyle()).copyWith(
            color: colorScheme.onSurface.withOpacity(0.92),
          ),
          bodySmall: (base.textTheme.bodySmall ?? const TextStyle()).copyWith(
            color: colorScheme.onSurface.withOpacity(0.86),
          ),
          labelMedium: (base.textTheme.labelMedium ?? const TextStyle())
              .copyWith(
                color: colorScheme.onSurface.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _Palette.background,
      textTheme: textTheme,
      typography: Typography.material2021(),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      extensions: const <ThemeExtension<dynamic>>[
        BillingColors(
          background: _Palette.background,
          surface: _Palette.surface,
          surfaceElevation: _Palette.surfaceElevation,
          surfaceTint: _Palette.surfaceTint,
          textPrimary: _Palette.textPrimary,
          textSecondary: _Palette.textSecondary,
          textMuted: _Palette.textMuted,
          border: _Palette.border,
          success: _Palette.success,
          warning: _Palette.warning,
          danger: _Palette.danger,
          pillBackground: _Palette.pillBackground,
          pillForeground: _Palette.pillForeground,
          shadowColor: _Palette.shadow,
        ),
        BillingSpacing(xs: 4, sm: 8, md: 16, lg: 24, xl: 32, gutter: 40),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: _Palette.textPrimary,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: _Palette.textPrimary,
        ),
        iconTheme: const IconThemeData(color: _Palette.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: _Palette.surface,
        elevation: 1.5,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: _Palette.subtleBorder, width: 1),
        ),
        shadowColor: _Palette.shadow,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _Palette.primary,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 2,
          shadowColor: _Palette.shadow,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _Palette.textPrimary,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          side: const BorderSide(color: _Palette.border, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _Palette.primary,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 2,
          shadowColor: _Palette.shadow,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _Palette.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: CircleBorder(),
        sizeConstraints: BoxConstraints.tightFor(width: 64, height: 64),
      ),
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        backgroundColor: _Palette.surface,
        selectedColor: _Palette.secondaryContainer,
        labelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: _Palette.textSecondary,
          letterSpacing: 0.3,
        ),
        side: const BorderSide(color: _Palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerTheme: const DividerThemeData(
        color: _Palette.border,
        thickness: 1,
        space: 24,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _Palette.surface,
        hintStyle: textTheme.bodyMedium?.copyWith(color: _Palette.textMuted),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: _Palette.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 20,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: _Palette.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: _Palette.primary, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: _Palette.border, width: 1.5),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          textStyle: MaterialStateProperty.all(
            textTheme.labelLarge?.copyWith(
              color: _Palette.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          side: MaterialStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(MaterialState.selected)
                  ? _Palette.primary
                  : _Palette.border,
              width: 1.5,
            ),
          ),
          foregroundColor: MaterialStateProperty.resolveWith(
            (states) => states.contains(MaterialState.selected)
                ? _Palette.primary
                : _Palette.textSecondary,
          ),
          backgroundColor: MaterialStateProperty.resolveWith(
            (states) => states.contains(MaterialState.selected)
                ? _Palette.surface
                : Colors.transparent,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        tileColor: _Palette.surface,
        textColor: _Palette.textPrimary,
        iconColor: _Palette.textSecondary,
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    final textTheme = GoogleFonts.interTextTheme(base.textTheme)
        .apply(
          bodyColor: base.colorScheme.onSurface.withOpacity(0.92),
          displayColor: base.colorScheme.onSurface,
        )
        .copyWith(
          bodyMedium: (base.textTheme.bodyMedium ?? const TextStyle()).copyWith(
            color: base.colorScheme.onSurface.withOpacity(0.92),
          ),
          bodySmall: (base.textTheme.bodySmall ?? const TextStyle()).copyWith(
            color: base.colorScheme.onSurface.withOpacity(0.86),
          ),
          labelMedium: (base.textTheme.labelMedium ?? const TextStyle())
              .copyWith(
                color: base.colorScheme.onSurface.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
        );

    return base.copyWith(useMaterial3: true, textTheme: textTheme);
  }

  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing24 = 24.0;
}
