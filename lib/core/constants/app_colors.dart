import 'package:flutter/material.dart';

/// HADI SMS design tokens.
/// A fresh, non-template visual language: deep graphite, teal, mint and warm amber.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF0F766E); // Deep Teal
  static const Color primaryDark = Color(0xFF134E4A);
  static const Color primaryLight = Color(0xFFCCFBF1);
  static const Color secondary = Color(0xFF172033); // Graphite Navy
  static const Color accent = Color(0xFFF59E0B); // Warm Amber

  // Surfaces
  static const Color background = Color(0xFFF3F6F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF8FAFA);
  static const Color surfaceElevated = Color(0xFFECF4F2);
  static const Color border = Color(0xFFD9E5E2);
  static const Color divider = Color(0xFFE7EFED);

  // Text
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Semantic status
  static const Color success = Color(0xFF15803D);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFB91C1C);
  static const Color info = Color(0xFF0369A1);

  // Role identity
  static const Color roleAdmin = Color(0xFF172033);
  static const Color roleTeacher = Color(0xFF0369A1);
  static const Color roleStudent = Color(0xFF0F766E);
  static const Color roleParent = Color(0xFFB45309);
  static const Color roleStaff = Color(0xFF6D28D9);

  // Module identity
  static const Color moduleAttendance = Color(0xFF0F766E);
  static const Color moduleFees = Color(0xFFB45309);
  static const Color moduleExams = Color(0xFF6D28D9);
  static const Color moduleClasses = Color(0xFF0369A1);
  static const Color moduleStudents = Color(0xFF047857);
  static const Color moduleTeachers = Color(0xFF0891B2);
  static const Color moduleParents = Color(0xFFBE185D);
  static const Color moduleHomework = Color(0xFF7C3AED);
  static const Color moduleCommunication = Color(0xFF0E7490);
  static const Color moduleReports = Color(0xFF475569);
  static const Color moduleLibrary = Color(0xFF166534);
  static const Color moduleTransport = Color(0xFF075985);
  static const Color moduleHostel = Color(0xFF9A3412);
  static const Color moduleInventory = Color(0xFF4D7C0F);
  static const Color moduleEvents = Color(0xFFBE123C);

  static const List<Color> chartPalette = [
    primary,
    info,
    success,
    accent,
    moduleExams,
    moduleParents,
  ];

  static const Color white = Colors.white;
  static const Color black = Colors.black;
}
