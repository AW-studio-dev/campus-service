import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const interfaceFontFamily = 'Inter';
  static const logoFontFamily = 'Poppins';

  static const textTheme = TextTheme(
    headlineLarge: TextStyle(
      fontFamily: interfaceFontFamily,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontFamily: interfaceFontFamily,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    titleLarge: TextStyle(
      fontFamily: interfaceFontFamily,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: interfaceFontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontFamily: interfaceFontFamily,
      fontSize: 15,
      color: AppColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontFamily: interfaceFontFamily,
      fontSize: 14,
      color: AppColors.textPrimary,
    ),
    bodySmall: TextStyle(
      fontFamily: interfaceFontFamily,
      fontSize: 12,
      color: AppColors.textSecondary,
    ),
    labelLarge: TextStyle(
      fontFamily: interfaceFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );

  static const logo = TextStyle(
    fontFamily: logoFontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
}
