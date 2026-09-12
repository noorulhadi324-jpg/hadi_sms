import 'package:flutter/material.dart';

/// Central design tokens for HADI SMS.
///
/// Module colors are deliberately distinct so users can identify areas of
/// the system immediately. Role/status colors are shared across badges,
/// cards, dialogs and reports.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF5B5CF0);
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color primaryLight = Color(0xFFEEF2FF);
  static const Color secondary = Color(0xFF151A3B);

  // Surfaces / neutrals
  static const Color background = Color(0xFFF4F7FB);
  static const Color surface = Colors.white;
  static const Color surfaceSoft = Color(0xFFF8FAFD);
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFEDF1F7);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Status
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // Roles
  static const Color roleAdmin = Color(0xFF5B21B6);
  static const Color roleTeacher = Color(0xFF1D4ED8);
  static const Color roleStudent = Color(0xFF0F766E);
  static const Color roleParent = Color(0xFFBE185D);

  // Modules
  static const Color moduleAttendance = Color(0xFF0F766E);
  static const Color moduleFees = Color(0xFF047857);
  static const Color moduleExams = Color(0xFF7C3AED);
  static const Color moduleClasses = Color(0xFF2563EB);
  static const Color moduleStudents = Color(0xFFEA580C);
  static const Color moduleTeachers = Color(0xFF0891B2);
  static const Color moduleParents = Color(0xFFDB2777);
  static const Color moduleHomework = Color(0xFFCA8A04);
  static const Color moduleCommunication = Color(0xFF9333EA);
  static const Color moduleReports = Color(0xFF334155);
  static const Color moduleLibrary = Color(0xFF166534);
  static const Color moduleTransport = Color(0xFF0369A1);
  static const Color moduleHostel = Color(0xFF9A3412);
  static const Color moduleInventory = Color(0xFF4D7C0F);
  static const Color moduleEvents = Color(0xFFBE123C);

  static const List<Color> chartPalette = [
    moduleAttendance,
    moduleFees,
    moduleExams,
    moduleClasses,
    moduleStudents,
    moduleCommunication,
  ];

  static const Color white = Colors.white;
  static const Color black = Colors.black;
}
