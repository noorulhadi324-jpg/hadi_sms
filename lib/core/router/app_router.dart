import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/splash/presentation/screens/session_router_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/school_registration_screen.dart';
import '../../features/attendance/presentation/screens/attendance_screen.dart';
import '../../features/finance/presentation/screens/finance_screen.dart';
import '../../features/communication/presentation/screens/communication_screen.dart';
import '../../features/class/presentation/screens/class_screen.dart';
import '../../features/teacher/presentation/screens/teacher_screen.dart';
import '../../features/teacher/presentation/screens/teacher_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/academic/presentation/screens/academic_screen.dart';
import '../../features/accounting/presentation/screens/accounting_screen.dart';
import '../../features/assignment/presentation/screens/assignment_screen.dart';
import '../../features/classroom/presentation/screens/classroom_screen.dart';
import '../../features/event/presentation/screens/event_screen.dart';
import '../../features/examination/presentation/screens/examination_screen.dart';
import '../../features/fee/presentation/screens/fee_screen.dart';
import '../../features/homework/presentation/screens/homework_screen.dart';
import '../../features/hostel/presentation/screens/hostel_screen.dart';
import '../../features/inventory/presentation/screens/inventory_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/notification/presentation/screens/notification_screen.dart';
import '../../features/parent/presentation/screens/parent_screen.dart';
import '../../features/parent/presentation/screens/parent_dashboard_screen.dart';
import '../../features/payroll/presentation/screens/payroll_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/result/presentation/screens/result_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/staff/presentation/screens/staff_screen.dart';
import '../../features/transport/presentation/screens/transport_screen.dart';
import 'guards/auth_guard.dart';
import '../auth/auth_state_notifier.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/session-router',
    refreshListenable: AuthStateNotifier.instance,
    redirect: (BuildContext context, GoRouterState state) {
      return AuthGuard.redirect(state);
    },
    routes: [
      GoRoute(path: '/session-router', builder: (_, __) => const SessionRouterScreen()),
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/teacher-login', builder: (_, __) => const LoginScreen(expectedRole: 'teacher')),
      GoRoute(path: '/parent-login', builder: (_, __) => const LoginScreen(expectedRole: 'parent')),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/reset-password', builder: (_, __) => const ResetPasswordScreen()),
      GoRoute(path: '/register-school', builder: (_, __) => const SchoolRegistrationScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/teacher-dashboard', builder: (_, __) => const TeacherDashboardScreen()),
      GoRoute(path: '/parent-dashboard', builder: (_, __) => const ParentDashboardScreen()),
      GoRoute(path: '/academic', builder: (_, __) => const AcademicScreen()),
      GoRoute(path: '/student', builder: (_, __) => const ClassesScreen()),
      GoRoute(path: '/teacher', builder: (_, __) => const TeacherScreen()),
      GoRoute(path: '/attendance', builder: (_, __) => const AttendanceScreen()),
      GoRoute(path: '/finance', builder: (_, __) => const FinanceScreen()),
      GoRoute(path: '/communication', builder: (_, __) => const CommunicationScreen()),
      GoRoute(path: '/academics', builder: (_, __) => const AcademicScreen()),
      GoRoute(path: '/accounting', builder: (_, __) => const AccountingScreen()),
      GoRoute(path: '/assignment', builder: (_, __) => const AssignmentsScreen()),
      GoRoute(path: '/classroom', builder: (_, __) => const ClassroomsScreen()),
      GoRoute(path: '/event', builder: (_, __) => const EventsScreen()),
      GoRoute(path: '/examination', builder: (_, __) => const ExaminationsScreen()),
      GoRoute(path: '/fee', builder: (_, __) => const FeesScreen()),
      GoRoute(path: '/homework', builder: (_, __) => const HomeworkScreen()),
      GoRoute(path: '/hostel', builder: (_, __) => const HostelScreen()),
      GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
      GoRoute(path: '/library', builder: (_, __) => const LibraryScreen()),
      GoRoute(path: '/notification', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/parent', builder: (_, __) => const ParentsScreen()),
      GoRoute(path: '/payroll', builder: (_, __) => const PayrollScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/result', builder: (_, __) => const ResultsScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/staff', builder: (_, __) => const StaffScreen()),
      GoRoute(path: '/transport', builder: (_, __) => const TransportScreen()),
    ],
  );
}