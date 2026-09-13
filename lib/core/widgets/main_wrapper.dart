import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_drawer.dart';
import '../constants/app_colors.dart';
import '../network/supabase_client.dart';

class SchoolBranding {
  final String name;
  final String? logoUrl;

  const SchoolBranding({
    required this.name,
    required this.logoUrl,
  });
}

/// Gets the school ID of the currently logged-in user.
final schoolIdProvider = FutureProvider<int?>((ref) async {
  final client = SupabaseConfig.client;
  final userId = client.auth.currentUser?.id;

  if (userId == null) {
    return null;
  }

  try {
    final profile = await client
        .from('profiles')
        .select('school_id')
        .eq('id', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));

    final value = profile?['school_id'];

    final schoolId = value is int
        ? value
        : int.tryParse(value?.toString() ?? '');

    if (schoolId != null) {
      return schoolId;
    }
  } catch (_) {
    // Continue to fallback.
  }

  try {
    final school = await client
        .from('schools')
        .select('id')
        .eq('created_by', userId)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));

    final value = school?['id'];

    return value is int
        ? value
        : int.tryParse(value?.toString() ?? '');
  } catch (_) {
    return null;
  }
});

/// Gets school name and logo.
final schoolBrandingProvider =
FutureProvider<SchoolBranding>((ref) async {
  final client = SupabaseConfig.client;

  final schoolId = await ref.watch(schoolIdProvider.future);

  if (schoolId == null) {
    return const SchoolBranding(
      name: 'HADI SMS',
      logoUrl: null,
    );
  }

  try {
    final school = await client
        .from('schools')
        .select('school_name, logo_url')
        .eq('id', schoolId)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));

    final name =
        school?['school_name']?.toString().trim() ?? '';

    final logo =
        school?['logo_url']?.toString().trim() ?? '';

    return SchoolBranding(
      name: name.isEmpty ? 'HADI SMS' : name,
      logoUrl: logo.isEmpty ? null : logo,
    );
  } catch (_) {
    return const SchoolBranding(
      name: 'HADI SMS',
      logoUrl: null,
    );
  }
});

/// Number of unread active notifications.
final unreadNotificationsProvider =
StreamProvider<int>((ref) async* {
  final client = SupabaseConfig.client;

  while (true) {
    int count = 0;

    try {
      final schoolId =
      await ref.read(schoolIdProvider.future);

      if (schoolId != null) {
        final now =
        DateTime.now().toUtc().toIso8601String();

        final response = await client
            .from('notifications')
            .select('id')
            .eq('school_id', schoolId)
            .eq('is_read', false)
            .eq('is_active', true)
            .lte('starts_at', now)
            .or(
          'expires_at.is.null,expires_at.gt.$now',
        )
            .timeout(const Duration(seconds: 10));

        count = (response as List).length;
      }
    } catch (_) {
      count = 0;
    }

    yield count;

    await Future<void>.delayed(
      const Duration(seconds: 15),
    );
  }
});

/// Current academic session.
final currentSessionProvider = Provider<String>((ref) {
  final now = DateTime.now();

  final startYear =
  now.month >= 4 ? now.year : now.year - 1;

  return '$startYear-${startYear + 1}';
});

class MainWrapper extends ConsumerWidget {
  final Widget child;

  const MainWrapper({
    super.key,
    required this.child,
  });

  Future<void> _openNotifications(
      BuildContext context,
      WidgetRef ref,
      ) async {
    await context.push('/notification');

    ref.invalidate(unreadNotificationsProvider);
  }

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final scaffoldKey = GlobalKey<ScaffoldState>();

    final width =
        MediaQuery.sizeOf(context).width;

    final brandingAsync =
    ref.watch(schoolBrandingProvider);

    final unreadAsync =
    ref.watch(unreadNotificationsProvider);

    final session =
    ref.watch(currentSessionProvider);

    final unreadCount =
        unreadAsync.valueOrNull ?? 0;

    return Scaffold(
      key: scaffoldKey,

      backgroundColor:
      AppColors.background,

      // ============================================================
      // DRAWER
      // ============================================================

      drawer: const AppDrawer(),

      // ============================================================
      // APP BAR
      // ============================================================

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,

        backgroundColor:
        Colors.white,

        surfaceTintColor:
        Colors.transparent,

        toolbarHeight: 68,

        leadingWidth: 58,

        leading: Padding(
          padding:
          const EdgeInsets.only(left: 10),

          child: _HeaderButton(
            icon: Icons.menu_rounded,
            tooltip: 'Menu',

            onTap: () {
              scaffoldKey.currentState
                  ?.openDrawer();
            },
          ),
        ),

        centerTitle: true,

        titleSpacing: 0,

        title: brandingAsync.when(
          loading: () {
            return _SchoolBrandingLoading(
              session: session,
            );
          },

          error: (_, __) {
            return _SchoolBranding(
              name: 'HADI SMS',
              logoUrl: null,
              session: session,
            );
          },

          data: (branding) {
            return _SchoolBranding(
              name: branding.name,
              logoUrl: branding.logoUrl,
              session: session,
            );
          },
        ),

        actions: [
          if (width >= 700)
            _HeaderButton(
              icon: Icons.search_rounded,
              tooltip: 'Search',
              onTap: () {},
            ),

          const SizedBox(width: 4),

          _HeaderButton(
            icon:
            Icons.notifications_none_rounded,

            tooltip:
            'Notifications',

            badge:
            unreadCount,

            onTap: () {
              _openNotifications(
                context,
                ref,
              );
            },
          ),

          const SizedBox(width: 5),

          Padding(
            padding:
            const EdgeInsets.only(right: 12),

            child: _ProfileButton(
              onTap: () {
                context.push('/profile');
              },
            ),
          ),
        ],
      ),

      // ============================================================
      // PAGE CONTENT
      // ============================================================

      body: SafeArea(
        top: false,
        bottom: false,

        child: ColoredBox(
          color:
          AppColors.background,

          child: child,
        ),
      ),
    );
  }
}

// ==================================================================
// HEADER BUTTON
// ==================================================================

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badge;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final hasBadge = badge > 0;

    return Tooltip(
      message: tooltip,

      child: Stack(
        clipBehavior: Clip.none,

        children: [
          Material(
            color:
            const Color(0xFFF8F8FC),

            borderRadius:
            BorderRadius.circular(13),

            child: InkWell(
              onTap: onTap,

              borderRadius:
              BorderRadius.circular(13),

              child: SizedBox(
                width: 42,
                height: 42,

                child: Icon(
                  icon,
                  color:
                  AppColors.textPrimary,
                  size: 21,
                ),
              ),
            ),
          ),

          if (hasBadge)
            Positioned(
              right: -2,
              top: -3,

              child: Container(
                constraints:
                const BoxConstraints(
                  minWidth: 17,
                ),

                height: 17,

                padding:
                const EdgeInsets.symmetric(
                  horizontal: 4,
                ),

                decoration:
                BoxDecoration(
                  color:
                  AppColors.error,

                  borderRadius:
                  BorderRadius.circular(20),

                  border:
                  Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),

                alignment:
                Alignment.center,

                child: Text(
                  badge > 99
                      ? '99+'
                      : '$badge',

                  style:
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================================================================
// PROFILE BUTTON
// ==================================================================

class _ProfileButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ProfileButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
      AppColors.primary.withValues(alpha: .08),

      shape:
      const CircleBorder(),

      child: InkWell(
        onTap: onTap,

        customBorder:
        const CircleBorder(),

        child: const SizedBox(
          width: 42,
          height: 42,

          child: Icon(
            Icons.person_rounded,
            color:
            AppColors.primary,
            size: 21,
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// SCHOOL BRANDING
// ==================================================================

class _SchoolBranding extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final String session;

  const _SchoolBranding({
    required this.name,
    required this.logoUrl,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final hasLogo =
        logoUrl != null &&
            logoUrl!.isNotEmpty;

    return ConstrainedBox(
      constraints:
      const BoxConstraints(
        maxWidth: 250,
      ),

      child: Row(
        mainAxisSize:
        MainAxisSize.min,

        children: [
          Container(
            width: 40,
            height: 40,

            clipBehavior:
            Clip.antiAlias,

            decoration:
            BoxDecoration(
              color:
              AppColors.primary
                  .withValues(alpha: .08),

              borderRadius:
              BorderRadius.circular(12),

              border:
              Border.all(
                color:
                AppColors.border,
              ),
            ),

            child: hasLogo
                ? Image.network(
              logoUrl!,
              fit: BoxFit.cover,

              errorBuilder:
                  (_, __, ___) {
                return const
                _DefaultSchoolIcon();
              },
            )
                : const
            _DefaultSchoolIcon(),
          ),

          const SizedBox(width: 9),

          Flexible(
            child: Column(
              mainAxisSize:
              MainAxisSize.min,

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Text(
                  name,

                  maxLines: 1,

                  overflow:
                  TextOverflow.ellipsis,

                  style:
                  const TextStyle(
                    fontSize: 14,
                    fontWeight:
                    FontWeight.w900,
                    letterSpacing: -.2,
                  ),
                ),

                Text(
                  session,

                  style:
                  const TextStyle(
                    color:
                    AppColors.primary,
                    fontSize: 9,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// DEFAULT SCHOOL ICON
// ==================================================================

class _DefaultSchoolIcon
    extends StatelessWidget {
  const _DefaultSchoolIcon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.school_rounded,
        color:
        AppColors.primary,
        size: 22,
      ),
    );
  }
}

// ==================================================================
// SCHOOL BRANDING LOADING
// ==================================================================

class _SchoolBrandingLoading
    extends StatelessWidget {
  final String session;

  const _SchoolBrandingLoading({
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize:
      MainAxisSize.min,

      children: [
        Container(
          width: 40,
          height: 40,

          decoration:
          BoxDecoration(
            color:
            AppColors.primary
                .withValues(alpha: .08),

            borderRadius:
            BorderRadius.circular(12),
          ),

          alignment:
          Alignment.center,

          child: const SizedBox(
            width: 17,
            height: 17,

            child:
            CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        ),

        const SizedBox(width: 9),

        Column(
          mainAxisSize:
          MainAxisSize.min,

          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            const Text(
              'HADI SMS',

              style:
              TextStyle(
                fontSize: 14,
                fontWeight:
                FontWeight.w900,
              ),
            ),

            Text(
              session,

              style:
              const TextStyle(
                color:
                AppColors.primary,
                fontSize: 9,
                fontWeight:
                FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}