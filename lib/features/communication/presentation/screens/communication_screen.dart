import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

/// ===============================================================
/// NOTICES PROVIDER
/// ===============================================================

final communicationNoticesProvider =
FutureProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) async {
    final client = SupabaseConfig.client;

    final schoolId = await ref.watch(
      schoolIdProvider.future,
    );

    if (schoolId == null) {
      throw Exception(
        'No school linked to your account.',
      );
    }

    final response = await client
        .from('notifications')
        .select()
        .eq('school_id', schoolId)
        .order(
      'created_at',
      ascending: false,
    );

    return List<Map<String, dynamic>>.from(
      response,
    );
  },
);

/// ===============================================================
/// COMMUNICATION SCREEN
/// ===============================================================

class CommunicationScreen extends ConsumerWidget {
  const CommunicationScreen({
    super.key,
  });

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final noticesAsync = ref.watch(
      communicationNoticesProvider,
    );

    return MainWrapper(
      child: noticesAsync.when(
        loading: () => const _MessengerLoading(),
        error: (error, stack) => _MessengerError(
          error: error,
          onRetry: () {
            ref.invalidate(
              communicationNoticesProvider,
            );
          },
        ),
        data: (notices) => _MessengerContent(
          notices: notices,
          onRefresh: () async {
            ref.invalidate(
              communicationNoticesProvider,
            );

            try {
              await ref.read(
                communicationNoticesProvider.future,
              );
            } catch (_) {}
          },
        ),
      ),
    );
  }
}

/// ===============================================================
/// MAIN CONTENT
/// ===============================================================

class _MessengerContent extends StatelessWidget {
  final List<Map<String, dynamic>> notices;
  final Future<void> Function() onRefresh;

  const _MessengerContent({
    required this.notices,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile =
            constraints.maxWidth < 700;

        return Column(
          children: [
            _buildHeader(
              context,
              isMobile,
            ),

            Expanded(
              child: notices.isEmpty
                  ? _buildEmpty()
                  : _buildConversationList(
                context,
                isMobile,
              ),
            ),
          ],
        );
      },
    );
  }

  /// =============================================================
  /// HEADER
  /// =============================================================

  Widget _buildHeader(
      BuildContext context,
      bool isMobile,
      ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 28,
        isMobile ? 16 : 24,
        isMobile ? 16 : 28,
        12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .scaffoldBackgroundColor,
        border: const Border(
          bottom: BorderSide(
            color: AppColors.border,
          ),
        ),
      ),
      child: Row(
        children: [
          /// MESSAGE ICON
          Container(
            width: isMobile ? 44 : 50,
            height: isMobile ? 44 : 50,
            decoration: BoxDecoration(
              color: AppColors.primary
                  .withValues(alpha: .10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: AppColors.primary,
              size: 25,
            ),
          ),

          const SizedBox(width: 12),

          /// TITLE
          const Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight:
                    FontWeight.w900,
                    letterSpacing: -.5,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'School communication',
                  style: TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          /// SEARCH
          IconButton(
            tooltip: 'Search',
            onPressed: () {
              _showSearchMessage(context);
            },
            icon: const Icon(
              Icons.search_rounded,
            ),
          ),

          /// REFRESH
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),

          if (!isMobile) ...[
            const SizedBox(width: 8),

            FilledButton.icon(
              onPressed: () {
                _showPostNoticeMessage(
                  context,
                );
              },
              icon: const Icon(
                Icons.edit_rounded,
                size: 17,
              ),
              label: const Text(
                'New Message',
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// =============================================================
  /// CONVERSATION LIST
  /// =============================================================

  Widget _buildConversationList(
      BuildContext context,
      bool isMobile,
      ) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile
              ? double.infinity
              : 900,
        ),
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.separated(
            physics:
            const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal:
              isMobile ? 8 : 20,
              vertical: 8,
            ),
            itemCount: notices.length,
            separatorBuilder:
                (_, __) => const Divider(
              height: 1,
              indent: 78,
            ),
            itemBuilder:
                (context, index) {
              return _messageTile(
                context,
                notices[index],
                isMobile,
              );
            },
          ),
        ),
      ),
    );
  }

  /// =============================================================
  /// MESSAGE TILE
  /// =============================================================

  Widget _messageTile(
      BuildContext context,
      Map<String, dynamic> notice,
      bool isMobile,
      ) {
    final title =
    notice['title']
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? notice['title'].toString()
        : 'School Announcement';

    final body =
        notice['body']
            ?.toString()
            .trim() ??
            '';

    final createdAt =
    notice['created_at']?.toString();

    final time =
    _formatTime(createdAt);

    final initials =
    _getInitials(title);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius:
        BorderRadius.circular(14),
        onTap: () {
          _openMessage(
            context,
            notice,
          );
        },
        child: Padding(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 13,
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              /// AVATAR
              Stack(
                children: [
                  CircleAvatar(
                    radius:
                    isMobile ? 27 : 29,
                    backgroundColor:
                    AppColors.primary
                        .withValues(alpha: .10),
                    child: Text(
                      initials,
                      style:
                      const TextStyle(
                        color:
                        AppColors.primary,
                        fontWeight:
                        FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  Positioned(
                    right: 0,
                    bottom: 1,
                    child:
                    Container(
                      width: 13,
                      height: 13,
                      decoration:
                      BoxDecoration(
                        color:
                        AppColors.success,
                        shape:
                        BoxShape.circle,
                        border:
                        Border.all(
                          color:
                          Theme.of(
                            context,
                          ).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                width: 13,
              ),

              /// MESSAGE INFO
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style:
                            const TextStyle(
                              fontSize: 15,
                              fontWeight:
                              FontWeight
                                  .w800,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        Text(
                          time,
                          style:
                          const TextStyle(
                            color: AppColors
                                .textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      body.isEmpty
                          ? 'No message content'
                          : body,
                      maxLines:
                      isMobile ? 2 : 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      const TextStyle(
                        color: AppColors
                            .textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 5,
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,
                color:
                AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// =============================================================
  /// FULL MESSAGE
  /// =============================================================

  void _openMessage(
      BuildContext context,
      Map<String, dynamic> notice,
      ) {
    final title =
    notice['title']
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? notice['title'].toString()
        : 'School Announcement';

    final body =
        notice['body']
            ?.toString()
            .trim() ??
            '';

    final date =
    _formatFullDate(
      notice['created_at']?.toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
      Colors.transparent,
      builder: (context) {
        return Container(
          constraints:
          const BoxConstraints(
            maxHeight: 650,
          ),
          decoration:
          const BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.vertical(
              top: Radius.circular(26),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding:
              const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration:
                      BoxDecoration(
                        color: AppColors
                            .border,
                        borderRadius:
                        BorderRadius
                            .circular(
                          20,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 22,
                  ),

                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor:
                        AppColors.primary
                            .withValues(
                          alpha: .10,
                        ),
                        child: const Icon(
                          Icons
                              .campaign_rounded,
                          color:
                          AppColors.primary,
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
                              title,
                              style:
                              const TextStyle(
                                fontSize: 17,
                                fontWeight:
                                FontWeight
                                    .w900,
                              ),
                            ),
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              date,
                              style:
                              const TextStyle(
                                color: AppColors
                                    .textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        onPressed: () {
                          Navigator.pop(
                            context,
                          );
                        },
                        icon:
                        const Icon(
                          Icons
                              .close_rounded,
                        ),
                      ),
                    ],
                  ),

                  const Divider(
                    height: 28,
                  ),

                  Expanded(
                    child:
                    SingleChildScrollView(
                      child: Text(
                        body.isEmpty
                            ? 'No message content.'
                            : body,
                        style:
                        const TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: AppColors
                              .textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// =============================================================
  /// EMPTY
  /// =============================================================

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Container(
              width: 85,
              height: 85,
              decoration:
              BoxDecoration(
                color: AppColors
                    .primary
                    .withValues(alpha: .08),
                shape:
                BoxShape.circle,
              ),
              child:
              const Icon(
                Icons
                    .chat_bubble_outline_rounded,
                size: 42,
                color:
                AppColors.primary,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 19,
                fontWeight:
                FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: 7,
            ),

            const Text(
              'School announcements will appear here.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// =============================================================
  /// INITIALS
  /// =============================================================

  String _getInitials(
      String text,
      ) {
    final words =
    text.trim().split(
      RegExp(r'\s+'),
    );

    if (words.isEmpty) {
      return 'N';
    }

    if (words.length == 1) {
      return words.first
          .substring(
        0,
        words.first.length > 2
            ? 2
            : words.first.length,
      )
          .toUpperCase();
    }

    return '${words[0][0]}${words[1][0]}'
        .toUpperCase();
  }

  /// =============================================================
  /// TIME
  /// =============================================================

  String _formatTime(
      String? value,
      ) {
    if (value == null ||
        value.isEmpty) {
      return '';
    }

    final date =
    DateTime.tryParse(value);

    if (date == null) {
      return '';
    }

    final local =
    date.toLocal();

    final now =
    DateTime.now();

    final difference =
    now.difference(local);

    if (difference.inMinutes < 1) {
      return 'Now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }

    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }

    return '${local.day}/${local.month}/${local.year}';
  }

  String _formatFullDate(
      String? value,
      ) {
    if (value == null ||
        value.isEmpty) {
      return 'Recently';
    }

    final date =
    DateTime.tryParse(value);

    if (date == null) {
      return 'Recently';
    }

    final local =
    date.toLocal();

    final hour =
    local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;

    final minute =
    local.minute
        .toString()
        .padLeft(
      2,
      '0',
    );

    final period =
    local.hour >= 12
        ? 'PM'
        : 'AM';

    return '${local.day}/${local.month}/${local.year} • '
        '$hour:$minute $period';
  }

  /// =============================================================
  /// SEARCH MESSAGE
  /// =============================================================

  void _showSearchMessage(
      BuildContext context,
      ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
          const Text(
            'Search Messages',
          ),
          content:
          const TextField(
            autofocus: true,
            decoration:
            InputDecoration(
              hintText:
              'Search...',
              prefixIcon:
              Icon(
                Icons
                    .search_rounded,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
              child:
              const Text(
                'Close',
              ),
            ),
          ],
        );
      },
    );
  }

  /// =============================================================
  /// POST NOTICE
  /// =============================================================

  void _showPostNoticeMessage(
      BuildContext context,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'New Message feature is not connected yet.',
          ),
          behavior:
          SnackBarBehavior.floating,
        ),
      );
  }
}

/// ===============================================================
/// LOADING
/// ===============================================================

class _MessengerLoading
    extends StatelessWidget {
  const _MessengerLoading();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Shimmer.fromColors(
      baseColor:
      Colors.grey.shade100,
      highlightColor:
      Colors.white,
      child: ListView.builder(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        itemCount: 8,
        itemBuilder:
            (context, index) {
          return Container(
            height: 78,
            margin:
            const EdgeInsets.only(
              bottom: 2,
            ),
            decoration:
            const BoxDecoration(
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }
}

/// ===============================================================
/// ERROR
/// ===============================================================

class _MessengerError
    extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _MessengerError({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final message =
    error.toString().replaceFirst(
      'Exception: ',
      '',
    );

    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration:
              BoxDecoration(
                color: AppColors
                    .error
                    .withValues(alpha: .08),
                shape:
                BoxShape.circle,
              ),
              child:
              const Icon(
                Icons
                    .cloud_off_rounded,
                color:
                AppColors.error,
                size: 35,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            const Text(
              'Unable to load messages',
              style:
              TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              message,
              textAlign:
              TextAlign.center,
              style:
              const TextStyle(
                color: AppColors
                    .textSecondary,
                fontSize: 12,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            FilledButton.icon(
              onPressed:
              onRetry,
              icon:
              const Icon(
                Icons
                    .refresh_rounded,
              ),
              label:
              const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }
}