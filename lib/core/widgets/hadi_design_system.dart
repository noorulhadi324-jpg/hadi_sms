import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../theme/app_theme.dart';

class HadiBrandLogo extends StatelessWidget {
  final String? logoUrl;
  final double size;
  final bool showWordmark;
  final String schoolName;

  const HadiBrandLogo({
    super.key,
    this.logoUrl,
    this.size = 44,
    this.showWordmark = false,
    this.schoolName = 'HADI SMS',
  });

  bool get _hasLogo => logoUrl != null && logoUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final mark = DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(size * .28),
        boxShadow: AppTheme.softShadow(opacity: .14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .28),
        child: SizedBox(
          width: size,
          height: size,
          child: _hasLogo
              ? Image.network(
                  logoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _DefaultLogoMark(),
                )
              : const _DefaultLogoMark(),
        ),
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'HADI SMS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              if (schoolName.trim().isNotEmpty && schoolName.trim() != 'HADI SMS')
                Text(
                  schoolName.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DefaultLogoMark extends StatelessWidget {
  const _DefaultLogoMark();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: .16),
            border: Border.all(color: Colors.white.withValues(alpha: .3)),
          ),
        ),
        const Icon(Icons.school_rounded, color: Colors.white, size: 23),
      ],
    );
  }
}

class HadiGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? tint;
  final bool elevated;

  const HadiGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.tint,
    this.elevated = true,
  });

  @override
  State<HadiGlassCard> createState() => _HadiGlassCardState();
}

class _HadiGlassCardState extends State<HadiGlassCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()..translate(0.0, _pressed ? 2.0 : 0.0),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.tint ?? Colors.white.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: Colors.white.withValues(alpha: .7)),
        boxShadow: widget.elevated ? AppTheme.softShadow(opacity: .075) : const [],
      ),
      child: widget.child,
    );

    if (widget.onTap == null) return content;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _pressed = true),
      onExit: (_) => setState(() => _pressed = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap!();
        },
        child: content,
      ),
    );
  }
}

class HadiStatusBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const HadiStatusBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  Color _resolveColor() {
    if (color != null) return color!;
    switch (label.trim().toLowerCase()) {
      case 'active':
      case 'paid':
      case 'present':
      case 'success':
        return AppColors.success;
      case 'pending':
      case 'late':
      case 'warning':
        return AppColors.warning;
      case 'inactive':
      case 'overdue':
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _resolveColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: .20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class HadiRoleBadge extends StatelessWidget {
  final String role;

  const HadiRoleBadge({super.key, required this.role});

  Color _color() {
    switch (role.trim().toLowerCase()) {
      case 'admin':
      case 'principal':
        return AppColors.roleAdmin;
      case 'teacher':
        return AppColors.roleTeacher;
      case 'student':
        return AppColors.roleStudent;
      case 'parent':
        return AppColors.roleParent;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) => HadiStatusBadge(label: role, color: _color());
}

class HadiModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? value;

  const HadiModuleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return HadiGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: color.withValues(alpha: .18)),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 8),
            Text(value!, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w900)),
          ],
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.textMuted),
          ],
        ],
      ),
    );
  }
}
