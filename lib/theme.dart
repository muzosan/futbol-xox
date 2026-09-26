import 'package:flutter/material.dart';

import 'game/engine/common.dart';

/// Uygulamanın renk paleti: gece maçı temalı koyu arayüz.
class AppColors {
  static const background = Color(0xFF0B0F14);
  static const surface = Color(0xFF131A22);
  static const surfaceHigh = Color(0xFF1B2430);
  static const border = Color(0xFF263241);
  static const primary = Color(0xFF2EE59D); // neon saha yeşili
  static const x = Color(0xFF4DA3FF);
  static const o = Color(0xFFFF5C7A);
  static const amber = Color(0xFFFFC857);
  static const text = Color(0xFFE8EEF5);
  static const textMuted = Color(0xFF8B98A9);
  static const success = Color(0xFF1E9E6A);
  static const danger = Color(0xFFD64560);
}

Color markColor(Mark mark) => mark == Mark.x ? AppColors.x : AppColors.o;

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: const Color(0xFF04140D),
    surface: AppColors.surface,
    onSurface: AppColors.text,
    surfaceContainerHighest: AppColors.surfaceHigh,
    onSurfaceVariant: AppColors.textMuted,
    outline: AppColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}
