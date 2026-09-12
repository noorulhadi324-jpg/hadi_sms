import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../widgets/hadi_design_system.dart';

class SchoolBrandingView extends StatelessWidget {
  final String schoolName;
  final String? logoUrl;
  final double logoSize;
  final bool showSchoolName;

  const SchoolBrandingView({
    super.key,
    required this.schoolName,
    required this.logoUrl,
    this.logoSize = 44,
    this.showSchoolName = true,
  });

  @override
  Widget build(BuildContext context) {
    return HadiBrandLogo(
      logoUrl: logoUrl,
      size: logoSize,
      showWordmark: showSchoolName,
      schoolName: schoolName,
    );
  }
}

class BrandSurface extends StatelessWidget {
  final Widget child;
  final Color color;

  const BrandSurface({
    super.key,
    required this.child,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}
