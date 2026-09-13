import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'main_wrapper.dart';

class ModuleScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<ModuleMetric> metrics;
  final List<ModuleAction> actions;
  final List<ModuleRow> rows;

  const ModuleScreen({super.key, required this.title, required this.subtitle, required this.icon, this.metrics = const [], this.actions = const [], this.rows = const []});

  @override
  Widget build(BuildContext context) {
    return MainWrapper(
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              if (metrics.isNotEmpty) _buildMetricsGrid(c.maxWidth),
              const SizedBox(height: 32),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: _buildActivityCard()), const SizedBox(width: 24), Expanded(flex: 2, child: _buildActionsCard())])
              else ...[
                _buildActionsCard(),
                const SizedBox(height: 24),
                _buildActivityCard(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() => Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: Colors.white, size: 24)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5), maxLines: 1, overflow: TextOverflow.ellipsis), Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)])),
        ],
      );

  Widget _buildMetricsGrid(double width) {
    final cols = width > 1100 ? 4 : (width > 600 ? 2 : 1);
    return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: metrics.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 2.0), itemBuilder: (_, i) => _MetricCard(metric: metrics[i]));
  }

  Widget _buildActivityCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Module Activity', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            if (rows.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No recent activity.', style: TextStyle(color: AppColors.textSecondary))))
            else
              ...rows.map(_ActivityRow.new),
          ]),
        ),
      );

  Widget _buildActionsCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Quick Actions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            ...actions.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: a.onTap,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [Icon(a.icon, size: 18, color: AppColors.primary), const SizedBox(width: 12), Expanded(child: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis)), const Icon(Icons.chevron_right_rounded, size: 16)]),
                    ),
                  ),
                )),
          ]),
        ),
      );
}

class ModuleMetric {
  final String label, value, detail;
  final IconData icon;
  final Color color;
  const ModuleMetric(this.label, this.value, this.detail, this.icon, this.color);
}

class ModuleAction {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const ModuleAction(this.label, this.icon, {this.onTap});
}

class ModuleRow {
  final String title, subtitle, trailing;
  final IconData icon;
  final Color color;
  const ModuleRow(this.title, this.subtitle, this.trailing, this.icon, this.color);
}

class _MetricCard extends StatelessWidget {
  final ModuleMetric metric;
  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: metric.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(metric.icon, color: metric.color, size: 20)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(metric.label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), Text(metric.value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis), Text(metric.detail, style: TextStyle(color: metric.color, fontSize: 9, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)])),
          ]),
        ),
      );
}

class _ActivityRow extends StatelessWidget {
  final ModuleRow row;
  const _ActivityRow(this.row);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(children: [
          CircleAvatar(radius: 18, backgroundColor: row.color.withValues(alpha: 0.1), child: Icon(row.icon, color: row.color, size: 16)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(row.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis), Text(row.subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)])),
          const SizedBox(width: 8),
          Text(row.trailing, style: const TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );
}
