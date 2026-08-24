import 'package:flutter/material.dart';

/// Single shared color palette for the whole app. Previously each screen
/// (home, login, register, forgot_password) defined its own local copy —
/// home's palette won since it's the more actively developed one; the
/// auth screens' extra semantic tokens (background/card/divider/etc.)
/// were folded in here rather than left duplicated per-file.
class AppColors {
  // Hospital-ish, government-clean
  static const deepNavy = Color(0xFF0F2D5C);
  static const softBlue = Color(0xFF2D5BFF);
  static const mint = Color(0xFF14B8A6);
  static const cardBorder = Color(0xFFE7ECF4);
  static const textMuted = Color(0xFF6B7280);

  // Auth-screen tokens, folded into the shared palette.
  static const bgSoft = Color(0xFFF3F6FF);
  static const card = Colors.white;
  static const textMain = Color(0xFF0B1220);
  static const fieldFill = Colors.white;

  /// Alias for cardBorder — auth screens called this `divider`, same role.
  static const divider = cardBorder;
}
