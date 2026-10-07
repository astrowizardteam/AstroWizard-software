import 'package:flutter/material.dart';

/// AstroWizard brand colours (sampled from the astrowizard.co.in homepage).
/// This is the ONLY place colours are defined.
class Brand {
  static const Color gold = Color(0xFFF3B112); // "Consult Now" button
  static const Color goldLight = Color(0xFFF8CC38); // button gradient end
  static const Color brown = Color(0xFF5A4309); // heading text
  static const Color bronze = Color(0xFF8A6410); // lines / accents (readable on cream)
  static const Color cream = Color(0xFFF8F4E8); // header / page
  static const Color creamDeep = Color(0xFFF7F1CD); // hero edge tint
  static const Color whatsapp = Color(0xFF25D366);
}

ColorScheme brandScheme(Brightness b) {
  final base = ColorScheme.fromSeed(
    seedColor: Brand.gold,
    brightness: b,
    dynamicSchemeVariant: DynamicSchemeVariant.neutral,
  );
  if (b == Brightness.light) {
    return base.copyWith(
      primary: Brand.bronze,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFBE8A6),
      onPrimaryContainer: Brand.brown,
      secondary: Brand.gold,
      onSecondary: Brand.brown,
      secondaryContainer: const Color(0xFFFCEFC0),
      onSecondaryContainer: Brand.brown,
      tertiary: Brand.brown,
      surface: Brand.cream,
      onSurface: const Color(0xFF3A2D08),
      surfaceContainerLowest: const Color(0xFFFFFCF3),
      surfaceContainerHighest: const Color(0xFFEFE6C8),
      outline: const Color(0xFF8C7F5E),
      outlineVariant: const Color(0xFFE0D5AE),
    );
  }
  return base.copyWith(
    primary: Brand.goldLight,
    onPrimary: const Color(0xFF2B2004),
    primaryContainer: const Color(0xFF5A4309),
    onPrimaryContainer: const Color(0xFFFBE8A6),
    secondary: Brand.gold,
    onSecondary: const Color(0xFF2B2004),
    secondaryContainer: const Color(0xFF4A3807),
    onSecondaryContainer: const Color(0xFFFBE8A6),
    surface: const Color(0xFF1F1806),
    onSurface: Brand.cream,
    surfaceContainerLowest: const Color(0xFF2A210A),
    surfaceContainerHighest: const Color(0xFF3A2D0C),
    outlineVariant: const Color(0xFF5A4A20),
  );
}
