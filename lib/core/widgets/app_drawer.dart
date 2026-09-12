import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_colors.dart';
import '../network/supabase_client.dart';
import 'main_wrapper.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final branding = ref.watch(schoolBrandingProvider);

    final user = SupabaseConfig.client.auth.currentUser;

    final fullName =
        (user?.userMetadata?['full_name'] as String?)?.trim() ?? '';

    final role =
        (user?.userMetadata?['role'] as String?)?.trim() ?? '';

    return Drawer(
      width: 292,
      backgroundColor: const Color(0xFF111827),
      child: SafeArea(
        child: Column(
          children: [
            // =====================================================
            // HEADER
            // =====================================================

            _Header(
              branding: branding,
              onClose: () => Navigator.of(context).pop(),
            ),

            // =====================================================
            // USER
            // =====================================================

            _UserCard(
              fullName: fullName,
              role: role,
            ),

            const SizedBox(height: 10),

            // =====================================================
            // MAIN MENU
            // =====================================================

            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  12,
                  4,
                  12,
                  8,
                ),
                children: [
                  _menuItem(
                    context,
                    currentRoute,
                    'Dashboard',
                    Icons.dashboard_rounded,
                    '/dashboard',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Students',
                    Icons.people_alt_rounded,
                    '/student',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Teachers',
                    Icons.school_rounded,
                    '/teacher',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Parents',
                    Icons.family_restroom_rounded,
                    '/parent',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Staff',
                    Icons.badge_rounded,
                    '/staff',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Academics',
                    Icons.auto_stories_rounded,
                    '/academic',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Attendance',
                    Icons.fact_check_rounded,
                    '/attendance',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Homework',
                    Icons.menu_book_rounded,
                    '/homework',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Assignments',
                    Icons.assignment_rounded,
                    '/assignment',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Examinations',
                    Icons.quiz_rounded,
                    '/examination',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Results',
                    Icons.grade_rounded,
                    '/result',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Fees & Finance',
                    Icons.payments_rounded,
                    '/finance',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Communication',
                    Icons.chat_bubble_rounded,
                    '/communication',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Events',
                    Icons.event_rounded,
                    '/event',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Library',
                    Icons.local_library_rounded,
                    '/library',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Inventory',
                    Icons.inventory_2_rounded,
                    '/inventory',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Transport',
                    Icons.directions_bus_rounded,
                    '/transport',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Hostel',
                    Icons.hotel_rounded,
                    '/hostel',
                  ),

                  _menuItem(
                    context,
                    currentRoute,
                    'Reports',
                    Icons.analytics_rounded,
                    '/reports',
                  ),

                  const SizedBox(height: 8),

                  Divider(
                    color: Colors.white.withValues(alpha: .08),
                    height: 1,
                  ),

                  const SizedBox(height: 8),

                  _menuItem(
                    context,
                    currentRoute,
                    'Settings',
                    Icons.settings_rounded,
                    '/settings',
                  ),
                ],
              ),
            ),

            // =====================================================
            // BOTTOM
            // =====================================================

            _BottomActions(
              onFees: () => _go(context, '/finance'),
              onProfile: () => _go(context, '/profile'),
              onSchool: () => _go(context, '/settings'),
              onSettings: () => _go(context, '/settings'),
              onLogout: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // MENU ITEM
  // =============================================================

  Widget _menuItem(
      BuildContext context,
      String currentRoute,
      String title,
      IconData icon,
      String route,
      ) {
    final active = currentRoute == route;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _go(context, route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 46,
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: active
                      ? Colors.white
                      : Colors.white60,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : Colors.white70,
                      fontSize: 12.5,
                      fontWeight: active
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),

                if (active)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =============================================================
  // NAVIGATION
  // =============================================================

  void _go(BuildContext context, String route) {
    // Drawer پہلے close
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // Route بعد میں change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      final current =
          GoRouterState.of(context).uri.path;

      if (current != route) {
        context.go(route);
      }
    });
  }

  // =============================================================
  // LOGOUT
  // =============================================================

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Logout',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await SupabaseConfig.client.auth.signOut();

      if (!context.mounted) return;

      context.go('/login');
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
        ),
      );
    }
  }
}

// =================================================================
// HEADER
// =================================================================

class _Header extends StatelessWidget {
  final AsyncValue<SchoolBranding> branding;
  final VoidCallback onClose;

  const _Header({
    required this.branding,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        18,
        12,
        14,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: branding.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              error: (_, __) => const Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 25,
              ),
              data: (data) {
                final logo = data.logoUrl;

                if (logo == null || logo.isEmpty) {
                  return const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 25,
                  );
                }

                return Image.network(
                  logo,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 25,
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: branding.when(
              loading: () => _schoolText('Loading...'),
              error: (_, __) => _schoolText('HADI SMS'),
              data: (data) => _schoolText(data.name),
            ),
          ),

          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _schoolText(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'School Management',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// =================================================================
// USER CARD
// =================================================================

class _UserCard extends StatelessWidget {
  final String fullName;
  final String role;

  const _UserCard({
    required this.fullName,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: .06),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFF312E81),
            child: Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty
                      ? 'School Admin'
                      : fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  role.isEmpty
                      ? 'ADMINISTRATOR'
                      : role.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.verified_rounded,
            color: Color(0xFF34D399),
            size: 16,
          ),
        ],
      ),
    );
  }
}

// =================================================================
// BOTTOM ACTIONS
// =================================================================

class _BottomActions extends StatelessWidget {
  final VoidCallback onFees;
  final VoidCallback onProfile;
  final VoidCallback onSchool;
  final VoidCallback onSettings;
  final VoidCallback onLogout;

  const _BottomActions({
    required this.onFees,
    required this.onProfile,
    required this.onSchool,
    required this.onSettings,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        6,
        16,
        16,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Action(
                  title: 'Fees',
                  icon: Icons.payments_outlined,
                  onTap: onFees,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Action(
                  title: 'Profile',
                  icon: Icons.person_outline_rounded,
                  onTap: onProfile,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: _Action(
                  title: 'Settings',
                  icon: Icons.settings_outlined,
                  onTap: onSettings,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onLogout,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withValues(alpha: .15),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// ACTION
// =================================================================

class _Action extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _Action({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: .04),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white60,
              size: 18,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}