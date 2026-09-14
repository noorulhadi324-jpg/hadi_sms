import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  static const plans = <_Plan>[
    _Plan('Starter', 'Rs. 1,000', 'For growing schools', ['50 teachers', '100 students', 'Core school modules'], Icons.rocket_launch_rounded, false),
    _Plan('Pro', 'Rs. 2,500', 'Most popular choice', ['250 students', 'All core modules', 'Priority support'], Icons.workspace_premium_rounded, true),
    _Plan('Premium Custom', 'Let’s talk', 'Built around your school', ['Custom user limits', 'Custom modules', 'Guided onboarding'], Icons.auto_awesome_rounded, false),
    _Plan('Custom Budget', 'Flexible', 'A plan within your budget', ['Flexible limits', 'Choose features', 'Scalable anytime'], Icons.tune_rounded, false),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Plans & Subscription')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            const _StatusCard(),
            const SizedBox(height: 24),
            const Text('Choose your plan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.5)),
            const SizedBox(height: 5),
            const Text('Transparent monthly plans that grow with your school.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            ...plans.map((plan) => Padding(padding: const EdgeInsets.only(bottom: 14), child: _PlanCard(plan: plan))),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => _message(context, 'Support will contact you shortly.'),
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text('Contact support'),
            ),
          ],
        ),
      );

  static void _message(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
}

class _StatusCard extends StatelessWidget {
  const _StatusCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF0D9488)]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Color(0x260D9488), blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(30)), child: const Text('ACTIVE DEMO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .6))),
            const Spacer(),
            const Icon(Icons.verified_rounded, color: Color(0xFF99F6E4)),
          ]),
          const SizedBox(height: 16),
          const Text('2-Day Free Demo', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('Explore every essential feature before choosing a plan.', style: TextStyle(color: Colors.white.withValues(alpha: .82), fontSize: 12.5)),
          const SizedBox(height: 18),
          ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: .5, minHeight: 7, backgroundColor: Colors.white.withValues(alpha: .18), color: const Color(0xFF5EEAD4))),
          const SizedBox(height: 8),
          Text('1 day remaining', style: TextStyle(color: Colors.white.withValues(alpha: .82), fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});
  final _Plan plan;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: plan.featured ? AppColors.primary : AppColors.border, width: plan.featured ? 1.6 : 1),
          boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 18, offset: Offset(0, 7))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: (plan.featured ? AppColors.primary : const Color(0xFF0D9488)).withValues(alpha: .1), borderRadius: BorderRadius.circular(14)), child: Icon(plan.icon, color: plan.featured ? AppColors.primary : const Color(0xFF0D9488))),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(plan.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))), if (plan.featured) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(20)), child: const Text('POPULAR', style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w900)))]),
              const SizedBox(height: 3),
              Text(plan.caption, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
            ])),
          ]),
          const SizedBox(height: 18),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(plan.price, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -.7)), if (plan.price.startsWith('Rs.')) const Padding(padding: EdgeInsets.only(bottom: 4, left: 5), child: Text('/ month', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)))]),
          const SizedBox(height: 15),
          ...plan.features.map((feature) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(children: [const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 19), const SizedBox(width: 9), Text(feature, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))]))),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () => SubscriptionScreen._message(context, '${plan.name} selected. We will help you complete the upgrade.'),
            style: FilledButton.styleFrom(backgroundColor: plan.featured ? AppColors.primary : const Color(0xFF0F172A)),
            child: Text(plan.name.contains('Custom') || plan.price == 'Flexible' ? 'Contact for plan' : 'Upgrade plan'),
          )),
        ]),
      );
}

class _Plan {
  const _Plan(this.name, this.price, this.caption, this.features, this.icon, this.featured);
  final String name;
  final String price;
  final String caption;
  final List<String> features;
  final IconData icon;
  final bool featured;
}
