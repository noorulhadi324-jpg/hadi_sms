import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  static const plans = <_Plan>[
    _Plan('Starter', 'Rs. 1,000', 'starter', 'For growing schools', ['50 teachers', '100 students', 'Core school modules'], Icons.rocket_launch_rounded, false),
    _Plan('Pro', 'Rs. 2,500', 'pro', 'Most popular choice', ['250 students', 'All core modules', 'Priority support'], Icons.workspace_premium_rounded, true),
    _Plan('Premium Custom', 'Let’s talk', 'premium_custom', 'Built around your school', ['Custom user limits', 'Custom modules', 'Guided onboarding'], Icons.auto_awesome_rounded, false),
    _Plan('Custom Budget', 'Flexible', 'custom_budget', 'A plan within your budget', ['Flexible limits', 'Choose features', 'Scalable anytime'], Icons.tune_rounded, false),
  ];

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _client = SupabaseConfig.client;
  int? _schoolId;
  Map<String, dynamic>? _subscription;
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('Please log in again.');
      final profile = await _client.from('profiles').select('school_id').eq('id', userId).maybeSingle();
      final rawId = profile?['school_id'];
      final schoolId = rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '');
      if (schoolId == null) throw Exception('Your account is not linked to a school.');
      final rows = await _client.from('school_subscriptions').select('plan_key,status,trial_started_at,trial_ends_at').eq('school_id', schoolId).maybeSingle();
      if (!mounted) return;
      setState(() { _schoolId = schoolId; _subscription = rows; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _error = error.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _startDemo() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await _client.rpc('start_school_demo');
      await _load();
      _message('Your two-day demo has started.');
    } catch (error) {
      _message('Could not start demo: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _requestPlan(_Plan plan) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await _client.rpc('request_subscription_plan', params: {'p_plan_key': plan.key});
      _message('Your ${plan.name} request has been saved. Activation requires approval.');
    } catch (error) {
      _message('Could not send request: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _message(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
  }

  String _statusLabel() {
    final status = _subscription?['status']?.toString() ?? '';
    if (status == 'active') return 'ACTIVE PLAN';
    if (status == 'expired') return 'DEMO ENDED';
    final trialEnd = DateTime.tryParse(_subscription?['trial_ends_at']?.toString() ?? '');
    if (status == 'demo' && trialEnd != null && !trialEnd.isAfter(DateTime.now())) return 'DEMO ENDED';
    if (status == 'demo') return 'DEMO PLAN';
    if (status == 'cancelled') return 'PLAN CANCELLED';
    return 'NO ACTIVE PLAN';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Plans & Subscription')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
            children: [
              _StatusCard(
                loading: _loading,
                error: _error,
                statusLabel: _statusLabel(),
                subscription: _subscription,
                onStartDemo: _schoolId == null || _working ? null : _startDemo,
                working: _working,
              ),
              const SizedBox(height: 24),
              const Text('Choose your plan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -.5)),
              const SizedBox(height: 5),
              const Text('Request a plan. Payment and activation are arranged separately.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              ...SubscriptionScreen.plans.map((plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _PlanCard(plan: plan, working: _working, onChoose: () => _requestPlan(plan)),
                  )),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => context.go('/communication'),
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('Open support and messages'),
              ),
            ],
          ),
        ),
      );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.loading,
    required this.error,
    required this.statusLabel,
    required this.subscription,
    required this.onStartDemo,
    required this.working,
  });

  final bool loading;
  final String? error;
  final String statusLabel;
  final Map<String, dynamic>? subscription;
  final VoidCallback? onStartDemo;
  final bool working;

  @override
  Widget build(BuildContext context) {
    final end = DateTime.tryParse(subscription?['trial_ends_at']?.toString() ?? '')?.toLocal();
    final detail = subscription?['status'] == 'active'
        ? 'Your school subscription is active.'
        : subscription?['status'] == 'demo' && end != null && end.isAfter(DateTime.now())
            ? 'Demo ends ${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}/${end.year}.'
            : subscription?['status'] == null
                ? 'Start a two-day demo to explore the app.'
                : 'The demo period has ended. Choose a plan to request an upgrade.';
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF0D9488)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x260D9488), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(30)),
            child: Text(loading ? 'LOADING' : statusLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .6)),
          ),
          const Spacer(),
          const Icon(Icons.verified_rounded, color: Color(0xFF99F6E4)),
        ]),
        const SizedBox(height: 16),
        const Text('School plan status', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(error ?? detail, style: TextStyle(color: Colors.white.withValues(alpha: .88), fontSize: 12.5)),
        if (subscription == null && !loading) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onStartDemo,
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0F766E)),
            child: working ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Start 2-day free demo'),
          ),
        ],
      ]),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.working, required this.onChoose});
  final _Plan plan;
  final bool working;
  final VoidCallback onChoose;

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
            onPressed: working ? null : onChoose,
            style: FilledButton.styleFrom(backgroundColor: plan.featured ? AppColors.primary : const Color(0xFF0F172A)),
            child: Text(plan.name.contains('Custom') || plan.price == 'Flexible' ? 'Request custom plan' : 'Request upgrade'),
          )),
        ]),
      );
}

class _Plan {
  const _Plan(this.name, this.price, this.key, this.caption, this.features, this.icon, this.featured);
  final String name;
  final String price;
  final String key;
  final String caption;
  final List<String> features;
  final IconData icon;
  final bool featured;
}
