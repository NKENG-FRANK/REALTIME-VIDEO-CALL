import 'package:flutter/material.dart';

class Palette {
  Palette._();

  static const LinearGradient callGradient = LinearGradient(
    begin: Alignment(-0.342, -0.94),
    end: Alignment(0.342, 0.94),
    colors: [Color(0xFF8FC1A8), Color(0xFF4E8F72)],
  );
}

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF1E9E64);
  static const Color primaryLight = Color(0xFF27B576);
  static const Color primaryDark = Color(0xFF117A4D);

  // Accent colors
  static const Color accent = Color(0xFFF2B231);
  static const Color error = Color(0xFFE5484D);

  // Background colors
  static const Color background = Color(0xFFEDF4EA);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color inputBackground = Color(0xFFFFFFFF);

  // Text colors
  static const Color textPrimary = Color(0xFF10231A);
  static const Color textMuted = Color(0xFF587064);
  static const Color textLight = Color(0xFFEAF4EE);

  // Status colors
  static const Color onlineGreen = Color(0xFF1E9E64);
  static const Color awayYellow = Color(0xFFF2B231);

  // Signal indicator
  static const Color signalStrong = Color(0xFF1E9E64);
  static const Color signalMedium = Color(0xFF27B576);
  static const Color signalWeak = Color(0xFFF2B231);
  static const Color signalExcellent = Color(0xFF3DDC97);
  static const Color signalGood = Color(0xFF1E9E64);
  static const Color signalFair = Color(0xFFF2B231);
  static const Color signalPoor = Color(0xFFE5484D);

  // Call action colors
  static const Color callDecline = Color(0xFFE5484D);
  static const Color callAccept = Color(0xFF117A4D);

  // Stat card tints
  static const Color statGreenTint = Color(0xFFBFE8CF);
  static const Color statYellowTint = Color(0xFFFBE7A8);
  static const Color statNeutralTint = Color(0xFFEAF4EE);

  // Star rating
  static const Color starDefault = Color(0xFF8DA69A);
  static const Color starActive = Color(0xFFF2B231);

  // Page background (sage/warm white used on call screens)
  static const Color callBackground = Color(0xFFEDF4EA);

  // Transparency
  static const Color shadowColor = Color.fromRGBO(16, 35, 26, 0.13);
  static const Color borderColor = Color.fromRGBO(16, 35, 26, 0.09);
}
