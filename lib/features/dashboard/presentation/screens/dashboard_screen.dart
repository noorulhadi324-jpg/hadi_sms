import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/main_wrapper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String role = 'Admin';

  static const modules = <_Module>[
    _Module('Exam Module', 'Schedules, marks & results', Icons.fact_check_rounded, Color(0xFF4F46E5), '/examination'),
    _Module('Smart Attendance', 'Fast daily attendance', Icons.fingerprint_rounded, Color(0xFF0D9488), '/attendance'),
    _Module('Teachers Payroll', 'Salary & payment records', Icons.account_balance_wallet_rounded, Color(0xFFF59E0B), '/payroll'),
    _Module('Income & Expense', 'Track school cash flow', Icons.query_stats_rounded, Color(0xFF2563EB), '/finance'),
    _Module('Stationery & Inventory', 'Stock and issue register', Icons.inventory_2_rounded, Color(0xFF9333EA), '/inventory'),
    _Module('Secure Database', 'Live • All systems normal', Icons.cloud_done_rounded, Color(0xFF10B981), '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return MainWrapper(
      child: RefreshIndicator(
        onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 500)),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              sliver: SliverList.list(children: [
                _Greeting(onPlans: () => context.push('/subscription')),
                const SizedBox(height: 18),
                _PlanBanner(onTap: () => context.push('/subscription')),
                const SizedBox(height: 26),
                const _SectionTitle('App Modules', 'Everything your school needs, in one place'),
                const SizedBox(height: 14),
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900 ? 3 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: modules.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: constraints.maxWidth < 380 ? 1.02 : 1.12,
                    ),
                    itemBuilder: (_, index) => _ModuleCard(
                      module: modules[index],
                      onTap: () => context.push(modules[index].route),
                    ),
                  );
                }),
                const SizedBox(height: 26),
                const _SectionTitle('Dedicated role experience', 'Switch preview to see each workspace'),
                const SizedBox(height: 14),
                _RoleSwitcher(value: role, onChanged: (value) => setState(() => role = value)),
                const SizedBox(height: 14),
                _RoleBanner(role: role),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.onPlans});
  final VoidCallback onPlans;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Welcome back', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Good ${DateTime.now().hour < 12 ? 'morning' : DateTime.now().hour < 17 ? 'afternoon' : 'evening'}, Admin 👋',
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.6)),
          const SizedBox(height: 5),
          const Text('Here is your school at a glance.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ])),
        IconButton.filledTonal(onPressed: onPlans, tooltip: 'Plans', icon: const Icon(Icons.workspace_premium_rounded)),
      ]);
}

class _PlanBanner extends StatelessWidget {
  const _PlanBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF3730A3)]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: .22), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFF5EEAD4).withValues(alpha: .2), borderRadius: BorderRadius.circular(30)),
              child: const Text('2-DAY FREE DEMO', style: TextStyle(color: Color(0xFFCCFBF1), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .7)),
            ),
            const SizedBox(height: 12),
            const Text('Run your school smarter', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Simple tools. Secure data. Better decisions.', style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 12)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11)),
              child: const Text('View packages'),
            ),
          ])),
          Container(width: 66, height: 66, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), shape: BoxShape.circle), child: const Icon(Icons.school_rounded, color: Colors.white, size: 32)),
        ]),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ]);
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.onTap});
  final _Module module;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border), boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 6))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: module.color.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)), child: Icon(module.icon, color: module.color, size: 24)),
              const Spacer(),
              Text(module.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, height: 1.15)),
              const SizedBox(height: 5),
              Text(module.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, height: 1.25)),
            ]),
          ),
        ),
      );
}

class _RoleSwitcher extends StatelessWidget {
  const _RoleSwitcher({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(16)),
        child: Row(children: ['Admin', 'Teacher', 'Student'].map((item) {
          final selected = item == value;
          return Expanded(child: InkWell(
            onTap: () => onChanged(item),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(12), boxShadow: selected ? const [BoxShadow(color: Color(0x120F172A), blurRadius: 10)] : null),
              alignment: Alignment.center,
              child: Text(item, style: TextStyle(color: selected ? AppColors.primary : AppColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ));
        }).toList()),
      );
}

class _RoleBanner extends StatelessWidget {
  const _RoleBanner({required this.role});
  final String role;
  @override
  Widget build(BuildContext context) {
    final details = switch (role) {
      'Teacher' => ('Teach with focus', 'Attendance, classes, homework and results in one focused workspace.', Icons.co_present_rounded),
      'Student' => ('Learn with clarity', 'Timetable, assignments, attendance and results—always within reach.', Icons.menu_book_rounded),
      _ => ('Lead with confidence', 'Monitor operations, people and finances from one secure command center.', Icons.admin_panel_settings_rounded),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFFE6FFFB), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF99F6E4))),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFF0D9488), borderRadius: BorderRadius.circular(15)), child: Icon(details.$3, color: Colors.white)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(details.$1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(details.$2, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35)),
        ])),
      ]),
    );
  }
}

class _Module {
  const _Module(this.title, this.subtitle, this.icon, this.color, this.route);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
}
