import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/main_wrapper.dart';

class FeesScreen extends StatelessWidget {
  const FeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainWrapper(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 800;

          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView(
              physics:
              const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                wide ? 24 : 16,
                20,
                wide ? 24 : 16,
                32,
              ),
              children: [
                _buildHeader(context, wide),

                const SizedBox(height: 24),

                _buildOverview(),

                const SizedBox(height: 24),

                _buildActions(context, wide),

                const SizedBox(height: 24),

                _buildFeeManagement(context),

                const SizedBox(height: 24),

                _buildRecentActivity(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context,
      bool wide,
      ) {
    return Row(
      children: [
       const Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'Fees & Finance',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage fee structures, payments and collections.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        if (wide)
          FilledButton.icon(
            onPressed: () {
              _showComingSoon(
                context,
                'Fee payment',
              );
            },
            icon: const Icon(
              Icons.add_rounded,
            ),
            label: const Text(
              'Collect Fee',
            ),
          ),
      ],
    );
  }

  Widget _buildOverview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count =
        constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 550
            ? 2
            : 1;

        final cards = [
          const _FeeStat(
            title: 'Total Collection',
            value: '--',
            subtitle: 'No finance data connected',
            icon: Icons
                .account_balance_wallet_rounded,
            color: AppColors.primary,
          ),
         const _FeeStat(
            title: 'Pending Fees',
            value: '--',
            subtitle: 'No finance data connected',
            icon: Icons.schedule_rounded,
            color: AppColors.warning,
          ),
          const _FeeStat(
            title: 'Paid Students',
            value: '--',
            subtitle: 'Waiting for fee data',
            icon: Icons
                .check_circle_outline_rounded,
            color: AppColors.success,
          ),
          const _FeeStat(
            title: 'Fee Records',
            value: '--',
            subtitle: 'Waiting for fee data',
            icon: Icons.receipt_long_rounded,
            color: AppColors.info,
          ),
        ];

        if (count == 1) {
          return Column(
            children: cards
                .map(
                  (card) => Padding(
                padding:
                const EdgeInsets.only(
                  bottom: 12,
                ),
                child: _buildStatCard(
                  card,
                ),
              ),
            )
                .toList(),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics:
          const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio:
            constraints.maxWidth >= 900
                ? 1.55
                : 2.1,
          ),
          itemBuilder: (_, index) {
            return _buildStatCard(
              cards[index],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(
      _FeeStat stat,
      ) {
    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
              BoxDecoration(
                color:
                stat.color.withValues(
                  alpha: .10,
                ),
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
              ),
              child: Icon(
                stat.icon,
                color: stat.color,
                size: 24,
              ),
            ),
            const SizedBox(
              width: 14,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    stat.title,
                    style:
                    const TextStyle(
                      color:
                      AppColors
                          .textSecondary,
                      fontSize: 12,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    stat.value,
                    style:
                    const TextStyle(
                      fontSize: 22,
                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Text(
                    stat.subtitle,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    const TextStyle(
                      color:
                      AppColors
                          .textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(
      BuildContext context,
      bool wide,
      ) {
    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text(
              'Fee Management',
              style:
              TextStyle(
                fontSize: 17,
                fontWeight:
                FontWeight.w800,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            const Text(
              'Choose an action to manage school fees.',
              style:
              TextStyle(
                color:
                AppColors
                    .textSecondary,
                fontSize: 12,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            LayoutBuilder(
              builder:
                  (context, constraints) {
                final columns =
                constraints.maxWidth >
                    700
                    ? 4
                    : constraints
                    .maxWidth >
                    400
                    ? 2
                    : 1;

                final actions = [
                  _FeeAction(
                    title:
                    'Fee Categories',
                    subtitle:
                    'Create fee types',
                    icon:
                    Icons.category_outlined,
                    color:
                    AppColors.primary,
                    onTap: () {
                      _showComingSoon(
                        context,
                        'Fee Categories',
                      );
                    },
                  ),
                  _FeeAction(
                    title:
                    'Fee Structure',
                    subtitle:
                    'Set student fees',
                    icon:
                    Icons
                        .account_tree_outlined,
                    color:
                    AppColors.info,
                    onTap: () {
                      _showComingSoon(
                        context,
                        'Fee Structure',
                      );
                    },
                  ),
                  _FeeAction(
                    title:
                    'Collect Payment',
                    subtitle:
                    'Record a payment',
                    icon:
                    Icons
                        .payments_outlined,
                    color:
                    AppColors.success,
                    onTap: () {
                      _showComingSoon(
                        context,
                        'Collect Payment',
                      );
                    },
                  ),
                  _FeeAction(
                    title:
                    'Receipts',
                    subtitle:
                    'View fee receipts',
                    icon:
                    Icons
                        .receipt_long_outlined,
                    color:
                    AppColors.warning,
                    onTap: () {
                      _showComingSoon(
                        context,
                        'Fee Receipts',
                      );
                    },
                  ),
                ];

                if (columns == 1) {
                  return Column(
                    children: actions
                        .map(
                          (action) =>
                          Padding(
                            padding:
                            const EdgeInsets
                                .only(
                              bottom: 10,
                            ),
                            child:
                            _buildActionTile(
                              action,
                            ),
                          ),
                    )
                        .toList(),
                  );
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics:
                  const NeverScrollableScrollPhysics(),
                  itemCount:
                  actions.length,
                  gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                    columns,
                    crossAxisSpacing:
                    10,
                    mainAxisSpacing:
                    10,
                    childAspectRatio:
                    columns == 4
                        ? 1.7
                        : 1.8,
                  ),
                  itemBuilder:
                      (_, index) {
                    return _buildActionTile(
                      actions[index],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
      _FeeAction action,
      ) {
    return InkWell(
      onTap: action.onTap,
      borderRadius:
      BorderRadius.circular(
        14,
      ),
      child: Container(
        padding:
        const EdgeInsets.all(
          16,
        ),
        decoration:
        BoxDecoration(
          color:
          action.color.withValues(
            alpha: .06,
          ),
          borderRadius:
          BorderRadius.circular(
            14,
          ),
          border:
          Border.all(
            color:
            action.color.withValues(
              alpha: .15,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration:
              BoxDecoration(
                color:
                action.color
                    .withValues(
                  alpha: .12,
                ),
                borderRadius:
                BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                action.icon,
                color:
                action.color,
                size: 21,
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    action.title,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    action.subtitle,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    const TextStyle(
                      color:
                      AppColors
                          .textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeManagement(
      BuildContext context,
      ) {
    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Text(
                        'Student Fee Records',
                        style:
                        TextStyle(
                          fontSize: 17,
                          fontWeight:
                          FontWeight
                              .w800,
                        ),
                      ),
                      SizedBox(
                        height: 4,
                      ),
                      Text(
                        'Search and manage student fee records.',
                        style:
                        TextStyle(
                          color:
                          AppColors
                              .textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                OutlinedButton.icon(
                  onPressed: () {
                    _showComingSoon(
                      context,
                      'Student Fee Records',
                    );
                  },
                  icon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                  ),
                  label:
                  const Text(
                    'Search',
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 20,
            ),

            Container(
              width:
              double.infinity,
              padding:
              const EdgeInsets.symmetric(
                vertical: 36,
                horizontal: 20,
              ),
              decoration:
              BoxDecoration(
                color:
                AppColors.background,
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
                border:
                Border.all(
                  color:
                  AppColors.border,
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons
                        .receipt_long_outlined,
                    size: 42,
                    color:
                    AppColors.textMuted,
                  ),
                  SizedBox(
                    height: 12,
                  ),
                  Text(
                    'No fee records loaded',
                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Text(
                    'Connect the fee tables to display real student payments here.',
                    textAlign:
                    TextAlign.center,
                    style:
                    TextStyle(
                      color:
                      AppColors
                          .textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recent Fee Activity',
                    style:
                    TextStyle(
                      fontSize: 17,
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child:
                  const Text(
                    'View All',
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            Container(
              width:
              double.infinity,
              padding:
              const EdgeInsets.symmetric(
                vertical: 30,
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons
                        .history_rounded,
                    size: 38,
                    color:
                    AppColors.border,
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Text(
                    'No recent fee activity',
                    style:
                    TextStyle(
                      color:
                      AppColors
                          .textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(
      BuildContext context,
      String title,
      ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          '$title will be connected to Supabase next.',
        ),
      ),
    );
  }
}

class _FeeStat {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _FeeStat({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _FeeAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeeAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}