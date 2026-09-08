import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF2D5016);      // Dark green
  static const Color primaryLight = Color(0xFF3A6B1F); // Light green
  static const Color primaryDark = Color(0xFF203B10);  // Darker green

  // Accent colors
  static const Color accent = Color(0xFFFFD700);       // Yellow
  static const Color error = Color(0xFFDC143C);        // Red

  // Background colors
  static const Color background = Color(0xFFF1F6F4);   // Page background
  static const Color cardBackground = Color(0xFFFFFFFF); // White
  static const Color inputBackground = Color(0xFFF3F6F4); // Light input

  // Text colors
  static const Color textPrimary = Color(0xFF253229);  // Dark text
  static const Color textMuted = Color(0xFF929A95);    // Muted text
  static const Color textLight = Color(0xFFF4F7E9);    // Light text (for white bg)

  // Transparency
  static const Color shadowColor = Color.fromRGBO(35, 53, 42, 0.16);
  static const Color borderColor = Color.fromRGBO(244, 247, 233, 0.11);
}
