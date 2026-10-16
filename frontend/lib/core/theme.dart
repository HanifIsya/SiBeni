import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ---------------------------------------------------------------------------
/// SI BENI Design System
///
/// Visual language: "Industrial Calm".
///  - Deep graphite-navy structure, one cyan accent, disciplined risk colour.
///  - Generous whitespace, soft elevation, restrained borders.
///  - WCAG AAA contrast on every interactive surface (outdoor sunlight).
///  - Ergonomics for heavy-duty gloves: 52dp targets, 12dp minimum gaps.
/// ---------------------------------------------------------------------------
class AppTheme {
  const AppTheme._();

  // ------------------------------------------------------------------ brand
  static const Color brand = Color(0xFF0B3A5D); // Deep graphite navy
  static const Color brandDeep = Color(0xFF062235); // App bar / dark surfaces
  static const Color accent = Color(0xFF22B8E6); // Cyan telemetry accent
  static const Color accentDeep = Color(0xFF0E8FB8);

  // --------------------------------------------------------------- surfaces
  static const Color canvas = Color(0xFFF4F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEDF1F6);
  static const Color surfaceSunken = Color(0xFFE6ECF3);
  static const Color hairline = Color(0xFFDDE4ED);

  // ------------------------------------------------------------------- text
  static const Color ink = Color(0xFF0B1622);
  static const Color inkMuted = Color(0xFF5A6B7D);
  static const Color inkFaint = Color(0xFF8494A6);
  static const Color onDark = Color(0xFFFFFFFF);
  static const Color onDarkMuted = Color(0xFFA9C0D4);

  // ------------------------------------------------------- risk taxonomy
  static const Color riskLow = Color(0xFF12805C);
  static const Color riskLowBg = Color(0xFFE4F6EF);

  static const Color riskMedium = Color(0xFFB45309);
  static const Color riskMediumBg = Color(0xFFFDF3E3);

  static const Color riskHigh = Color(0xFFD9480F);
  static const Color riskHighBg = Color(0xFFFDEEE4);

  static const Color riskCritical = Color(0xFFC81E1E);
  static const Color riskCriticalBg = Color(0xFFFCEAEA);

  // ------------------------------------------------------------- telemetry
  static const Color online = Color(0xFF12805C);
  static const Color onlineBg = Color(0xFFE4F6EF);
  static const Color offline = Color(0xFFB45309);
  static const Color offlineBg = Color(0xFFFDF3E3);
  static const Color syncing = Color(0xFF0E8FB8);

  // ------------------------------------------------------------- gradients
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D4468), Color(0xFF062235)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF12496F), Color(0xFF07273C)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2CC6F2), Color(0xFF0E8FB8)],
  );

  // ------------------------------------------------------------- ergonomics
  static const double touchTarget = 52.0;
  static const double gap = 12.0;
  static const double sosHeight = 68.0;

  // ---------------------------------------------------------------- spacing
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  // ------------------------------------------------------------------ radii
  static const Radius rSm = Radius.circular(10);
  static const Radius rMd = Radius.circular(14);
  static const Radius rLg = Radius.circular(20);
  static const Radius rXl = Radius.circular(28);
  static const BorderRadius brSm = BorderRadius.all(rSm);
  static const BorderRadius brMd = BorderRadius.all(rMd);
  static const BorderRadius brLg = BorderRadius.all(rLg);
  static const BorderRadius brXl = BorderRadius.all(rXl);
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(999));

  // --------------------------------------------------------------- shadows
  static const List<BoxShadow> shadowSoft = [
    BoxShadow(color: Color(0x0A0B1622), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x0A0B1622), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> shadowLift = [
    BoxShadow(color: Color(0x140B1622), blurRadius: 28, offset: Offset(0, 12)),
  ];

  static List<BoxShadow> shadowGlow(Color color) => [
    BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 8)),
  ];

  // ------------------------------------------------------------- responsive
  static const double railBreakpoint = 720;
  static const double wideBreakpoint = 1040;

  /// Horizontal page gutter, widened on larger canvases.
  static double gutter(double width) {
    if (width >= wideBreakpoint) return 28;
    if (width >= railBreakpoint) return 24;
    return 18;
  }

  /// Caps line length so content never stretches across a tablet/desktop.
  static const double contentMaxWidth = 820;

  // --------------------------------------------------------------- risk map
  static Color riskColor(String? level) {
    switch ((level ?? '').toLowerCase()) {
      case 'critical':
        return riskCritical;
      case 'high':
        return riskHigh;
      case 'medium':
        return riskMedium;
      default:
        return riskLow;
    }
  }

  static Color riskBg(String? level) {
    switch ((level ?? '').toLowerCase()) {
      case 'critical':
        return riskCriticalBg;
      case 'high':
        return riskHighBg;
      case 'medium':
        return riskMediumBg;
      default:
        return riskLowBg;
    }
  }

  static String riskLabel(String? level) {
    switch ((level ?? '').toLowerCase()) {
      case 'critical':
        return 'KRITIS';
      case 'high':
        return 'TINGGI';
      case 'medium':
        return 'SEDANG';
      default:
        return 'RENDAH';
    }
  }

  static IconData riskIcon(String? level) {
    switch ((level ?? '').toLowerCase()) {
      case 'critical':
        return Icons.crisis_alert_rounded;
      case 'high':
        return Icons.warning_rounded;
      case 'medium':
        return Icons.error_outline_rounded;
      default:
        return Icons.verified_rounded;
    }
  }

  // ------------------------------------------------------------------ theme
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: canvas,
      colorScheme: const ColorScheme.light(
        primary: brand,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFE3EDF5),
        onPrimaryContainer: brandDeep,
        secondary: accentDeep,
        onSecondary: Colors.white,
        surface: surface,
        onSurface: ink,
        surfaceContainerHighest: surfaceMuted,
        error: riskCritical,
        onError: Colors.white,
        outline: hairline,
      ),
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: brLg),
      ),
      dividerTheme: const DividerThemeData(color: hairline, thickness: 1, space: 1),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceMuted,
        side: const BorderSide(color: hairline),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        shape: const RoundedRectangleBorder(borderRadius: brPill),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: inkFaint),
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: inkMuted),
        floatingLabelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: brand,
        ),
        border: _inputBorder(hairline),
        enabledBorder: _inputBorder(hairline),
        focusedBorder: _inputBorder(brand, width: 1.6),
        errorBorder: _inputBorder(riskCritical),
        focusedErrorBorder: _inputBorder(riskCritical, width: 1.6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(touchTarget),
          shape: const RoundedRectangleBorder(borderRadius: brMd),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand,
          minimumSize: const Size.fromHeight(touchTarget),
          side: const BorderSide(color: hairline, width: 1.4),
          shape: const RoundedRectangleBorder(borderRadius: brMd),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        shape: const RoundedRectangleBorder(borderRadius: brMd),
        insetPadding: const EdgeInsets.all(14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: brXl),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brand,
        linearMinHeight: 6,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: brand,
        thumbColor: brand,
        inactiveTrackColor: surfaceSunken,
        overlayColor: brand.withValues(alpha: 0.12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: brand.withValues(alpha: 0.10),
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 22,
            color: s.contains(WidgetState.selected) ? brand : inkFaint,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: s.contains(WidgetState.selected) ? brand : inkMuted,
          ),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: brMd,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base
        .copyWith(
          displaySmall: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: ink,
            height: 1.15,
          ),
          headlineMedium: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: ink,
            height: 1.2,
          ),
          headlineSmall: GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: ink,
            height: 1.25,
          ),
          titleLarge: GoogleFonts.plusJakartaSans(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: ink,
          ),
          titleMedium: GoogleFonts.plusJakartaSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          titleSmall: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          bodyLarge: GoogleFonts.plusJakartaSans(fontSize: 14.5, height: 1.5, color: ink),
          bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.5, color: inkMuted),
          bodySmall: GoogleFonts.plusJakartaSans(fontSize: 11.5, height: 1.45, color: inkMuted),
          labelLarge: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: ink,
          ),
          labelSmall: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: inkFaint,
          ),
        )
        .apply(fontFamily: 'Plus Jakarta Sans');
  }

  /// Monospace style for telemetry, coordinates and tabular figures.
  static TextStyle mono({
    double size = 12,
    FontWeight weight = FontWeight.w600,
    Color color = ink,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Eyebrow / section label.
  static TextStyle eyebrow({Color color = inkFaint}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
      color: color,
    );
  }
}