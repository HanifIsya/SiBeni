import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand & Mascot Palette
  static const Color brandPrimary = Color(0xFF0F4C81);     // Deep Industrial Navy
  static const Color brandSecondary = Color(0xFF00B4D8);   // SI BENI Robot Cyan
  static const Color brandSafetyGreen = Color(0xFF15803D); // K3 Safety Emerald

  // Surfaces (High-Contrast Outdoor Legibility)
  static const Color surfaceBg = Color(0xFFF8FAFC);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF0B192C);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color borderSubtle = Color(0xFFCBD5E1);

  // Text Colors
  static const Color onSurfacePrimary = Color(0xFF0F172A);
  static const Color onSurfaceSecondary = Color(0xFF475569);
  static const Color onSurfaceInverse = Color(0xFFFFFFFF);

  // 4-Tier Risk Taxonomy
  static const Color riskLow = Color(0xFF16A34A);
  static const Color riskLowBg = Color(0xFFDCFCE7);

  static const Color riskMedium = Color(0xFFEAB308);
  static const Color riskMediumBg = Color(0xFFFEF9C3);

  static const Color riskHigh = Color(0xFFF97316);
  static const Color riskHighBg = Color(0xFFFFEDD5);

  static const Color riskCritical = Color(0xFFDC2626);
  static const Color riskCriticalBg = Color(0xFFFEE2E2);

  // Connectivity & Sync States
  static const Color statusOnline = Color(0xFF16A34A);
  static const Color statusOffline = Color(0xFFD97706);
  static const Color statusOfflineBg = Color(0xFFFEF3C7);
  static const Color statusOfflineText = Color(0xFF92400E);
  static const Color statusSyncing = Color(0xFF0284C7);

  // Ergonomic Dimensions (Gloved hands)
  static const double minTouchTarget = 52.0;
  static const double sosTargetHeight = 64.0;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: surfaceBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandPrimary,
        primary: brandPrimary,
        secondary: brandSecondary,
        surface: surfaceCard,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
        displaySmall: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: onSurfacePrimary,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: onSurfacePrimary,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: onSurfacePrimary,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: onSurfacePrimary,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: onSurfaceSecondary,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: brandPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
    );
  }
}
