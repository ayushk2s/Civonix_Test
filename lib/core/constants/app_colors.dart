import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Background ─────────────────────────────────────────────────────────────
  static const Color background   = Color(0xFF0A0E1A);
  static const Color surface      = Color(0xFF111827);
  static const Color surfaceHigh  = Color(0xFF1C2333);
  static const Color card         = Color(0xFF151D2E);
  static const Color cardBorder   = Color(0xFF1E2A3D);
  static const Color overlay      = Color(0xFF0D1220);

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF6C63FF);
  static const Color primaryDark  = Color(0xFF4B44CC);
  static const Color primaryLight = Color(0xFF8F89FF);
  static const Color accent       = Color(0xFF00D2A8);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color gain         = Color(0xFF00D2A8);
  static const Color gainMuted    = Color(0xFF0D3830);
  static const Color loss         = Color(0xFFFF4D67);
  static const Color lossMuted    = Color(0xFF3D1020);
  static const Color warning      = Color(0xFFFFB800);
  static const Color warningMuted = Color(0xFF3D2D00);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFE8EAF0);
  static const Color textSecondary = Color(0xFF9BA3AF);
  static const Color textMuted     = Color(0xFF4B5563);
  static const Color textDisabled  = Color(0xFF374151);

  // ── Chart ──────────────────────────────────────────────────────────────────
  static const List<Color> chartGradient = [
    Color(0xFF6C63FF),
    Color(0xFF00D2A8),
  ];

  static const List<Color> allocationColors = [
    Color(0xFF6C63FF),
    Color(0xFF00D2A8),
    Color(0xFFFFB800),
    Color(0xFFFF4D67),
    Color(0xFF38BDF8),
    Color(0xFFA78BFA),
    Color(0xFFFB923C),
    Color(0xFF34D399),
  ];

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gainGradient = LinearGradient(
    colors: [Color(0xFF00D2A8), Color(0xFF0AB98C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient lossGradient = LinearGradient(
    colors: [Color(0xFFFF4D67), Color(0xFFCC2B45)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF151D2E), Color(0xFF0F1623)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
