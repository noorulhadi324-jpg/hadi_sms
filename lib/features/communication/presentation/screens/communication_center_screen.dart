import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';
import '../../data/repositories/communication_repository_impl.dart';
import '../controllers/communication_controller.dart';
import '../widgets/communication_widgets.dart';

class CommunicationCenterScreen extends ConsumerStatefulWidget {
  const CommunicationCenterScreen({super.key});

  @override
  ConsumerState<CommunicationCenterScreen> createState() => _CommunicationCenterScreenState();
}

class _CommunicationCenterScreenState extends ConsumerState<CommunicationCenterScreen> {
  final _searchController = TextEditingController();
  int? _schoolId;
  String? _userId;
  String _role = '';
  bool _loading = true;
  String? _error;
  int _tab = 0;
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _threads = [];
  int? _selectedThreadId;
  List<Map<String, dynamic>> _messages = [];
  bool _messagesLoading = false;
  String _search = '';

  SupabaseClient get _client => SupabaseConfig.client;
  bool get _canManageAnnouncements => _role == 'principal' || _role == 'staff';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('آپ لاگ اِن نہیں ہیں۔');
      final profile = await _client.from('profiles').select('school_id,role,is_active').eq('id', user.id).maybeSingle();
      final schoolId = (profile?['school_id'] as num?)?.toInt();
      if (schoolId == null) throw Exception('آپ کے اکاؤنٹ کے ساتھ اسکول منسلک نہیں ہے۔');
      if (profile?['is_active'] == false) throw Exception('آپ کا اکاؤنٹ غیر فعال ہے۔');

      _schoolId = schoolId;
      _userId = user.id;
      _role = profile?['role']?.toString() ?? '';

      final repository = ref.read(communicationRepositoryProvider);
      final announcements = await repository.getSchoolNotifications(schoolId);
      final users = await repository.getSchoolUsers(schoolId);
      final threads = await repository.getThreads(schoolId);

      if (!mounted) return;
      setState(() {
        _announcements = announcements.map((n) => n.toMap()).toList();
        _users = users.where((u) => u['id']?.toString() != user.id).toList();
        _threads = threads.map((t) => {
          'id': t.id,
          'school_id': t.schoolId,
          'title': t.title,
          'thread_type': t.threadType,
          'created_by': t.createdBy,
          'created_at': t.createdAt.toIso8601String(),
          'updated_at': t.updatedAt.toIso8601String(),
          'is_archived': t.isArchived,
        }).toList();
        _loading = false;
      });
      if (_selectedThreadId != null && !_threads.any((t) => t['id'] == _selectedThreadId)) {
        _selectedThreadId = null;
        _messages = [];
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadMessages(int threadId) async {
    setState(() => _messagesLoading = true);
    try {
      final rows = await _client
          .from('communication_messages')
          .select('id,thread_id,sender_id,body,created_at,is_deleted')
          .eq('thread_id', threadId)
          .order('created_at');
      final senderIds = rows.map((r) => r['sender_id'].toString()).toSet().toList();
      final names = <String, String>{};
      if (senderIds.isNotEmpty) {
        final profiles = await _client.from('profiles').select('id,full_name,role').inFilter('id', senderIds);
        for (final p in profiles) {
          names[p['id'].toString()] = p['full_name']?.toString().trim().isNotEmpty == true
              ? p['full_name'].toString()
              : 'User';
        }
      }
      if (!mounted) return;
      setState(() {
        _messages = rows.map((r) {
          final map = Map<String, dynamic>.from(r);
          map['sender_name'] = names[r['sender_id'].toString()] ?? 'User';
          return map;
        }).toList();
        _messagesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messagesLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    final threadId = _selectedThreadId;
    final userId = _userId;
    if (threadId == null || userId == null || text.trim().isEmpty) return;
    try {
      await ref.read(communicationRepositoryProvider).sendMessage(
        threadId: threadId,
        senderId: userId,
        body: text,
      );
      await _loadMessages(threadId);
      await _load();
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _createThread() async {
    final schoolId = _schoolId;
    final userId = _userId;
    if (schoolId == null || userId == null) return;

    final title = TextEditingController();
    final selected = <String>{};
    String type = 'direct';

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          final visibleUsers = _users.where((u) {
            final q = _searchController.text.trim().toLowerCase();
            if (q.isEmpty) return true;
            return '${u['full_name'] ?? ''} ${u['email'] ?? ''} ${u['role'] ?? ''}'.toLowerCase().contains(q);
          }).toList();
          return AlertDialog(
            title: const Text('نئی گفتگو'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'گفتگو کا عنوان (اختیاری)', prefixIcon: Icon(Icons.title_rounded)),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'direct', label: Text('Direct'), icon: Icon(Icons.person_rounded)),
                        ButtonSegment(value: 'group', label: Text('Group'), icon: Icon(Icons.groups_rounded)),
                      ],
                      selected: {type},
                      onSelectionChanged: (v) => setDialogState(() => type = v.first),
                    ),
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerLeft, child: Text(type == 'direct' ? 'شخص منتخب کریں' : 'ٹیم کے اراکین منتخب کریں', style: const TextStyle(fontWeight: FontWeight.w800))),
                    const SizedBox(height: 8),
                    ...visibleUsers.map((u) {
                      final id = u['id'].toString();
                      final name = u['full_name']?.toString().trim().isNotEmpty == true ? u['full_name'].toString() : (u['email']?.toString() ?? 'User');
                      final role = u['role']?.toString() ?? '';
                      return CheckboxListTile(
                        dense: true,
                        value: selected.contains(id),
                        title: Text(name),
                        subtitle: Text(role.toUpperCase()),
                        onChanged: (value) {
                          setDialogState(() {
                            if (type == 'direct') selected.clear();
                            if (value == true) selected.add(id); else selected.remove(id);
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              FilledButton(onPressed: selected.isEmpty ? null : () => Navigator.pop(dialogContext, true), child: const Text('Create')),
            ],
          );
        });
      },
    );

    if (created != true || selected.isEmpty) return;
    try {
      final id = await ref.read(communicationRepositoryProvider).createThread(
        schoolId: schoolId,
        createdBy: userId,
        title: title.text,
        threadType: type,
        memberIds: selected.toList(),
      );
      title.dispose();
      await _load();
      if (!mounted) return;
      setState(() {
        _tab = 1;
        _selectedThreadId = id;
      });
      await _loadMessages(id);
    } catch (e) {
      title.dispose();
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _createAnnouncement() async {
    final schoolId = _schoolId;
    if (schoolId == null || !_canManageAnnouncements) return;
    final title = TextEditingController();
    final body = TextEditingController();
    String target = 'all';
    String category = 'general';

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('نیا اعلان'),
          content: SizedBox(
            width: 520,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان')),
              const SizedBox(height: 10),
              TextField(controller: body, minLines: 4, maxLines: 7, decoration: const InputDecoration(labelText: 'پیغام')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: target,
                decoration: const InputDecoration(labelText: 'کس کو دکھانا ہے؟'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('سب')),
                  DropdownMenuItem(value: 'teacher', child: Text('Teachers')),
                  DropdownMenuItem(value: 'parent', child: Text('Parents')),
                  DropdownMenuItem(value: 'staff', child: Text('Staff')),
                ],
                onChanged: (v) => setDialogState(() => target = v ?? 'all'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const ['general', 'academic', 'attendance', 'fee', 'urgent'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setDialogState(() => category = v ?? 'general'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Publish')),
          ],
        );
      }),
    );

    if (created != true) {
      title.dispose();
      body.dispose();
      return;
    }
    if (title.text.trim().isEmpty || body.text.trim().isEmpty) {
      title.dispose();
      body.dispose();
      _showError('عنوان اور پیغام دونوں ضروری ہیں۔');
      return;
    }
    try {
      await _client.from('notifications').insert({
        'school_id': schoolId,
        'title': title.text.trim(),
        'description': body.text.trim(),
        'message': body.text.trim(),
        'category': category,
        'type': 'announcement',
        'target_role': target == 'all' ? null : target,
        'is_active': true,
        'is_read': false,
        'created_by': _userId,
      });
      title.dispose();
      body.dispose();
      await _load();
    } catch (e) {
      title.dispose();
      body.dispose();
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteAnnouncement(int id) async {
    if (!_canManageAnnouncements) return;
    try {
      await _client.from('notifications').delete().eq('id', id).eq('school_id', _schoolId!);
      await _load();
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return MainWrapper(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : LayoutBuilder(builder: (context, constraints) {
                  final mobile = constraints.maxWidth < 850;
                  return Column(children: [
                    _header(mobile),
                    Expanded(child: _tab == 0 ? _announcementsView(mobile) : _chatView(mobile)),
                  ]);
                }),
    );
  }

  Widget _header(bool mobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(mobile ? 16 : 28, 18, mobile ? 16 : 28, 14),
      child: Column(children: [
        Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.forum_rounded, color: AppColors.primary)),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Communication', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)), SizedBox(height: 3), Text('Announcements, team chat and school communication', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))])),
          IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
          if (_tab == 1) IconButton(onPressed: _createThread, tooltip: 'New chat', icon: const Icon(Icons.add_comment_rounded)),
          if (_tab == 0 && _canManageAnnouncements) FilledButton.icon(onPressed: _createAnnouncement, icon: const Icon(Icons.campaign_rounded, size: 17), label: Text(mobile ? 'New' : 'New Announcement')),
        ]),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerLeft, child: SegmentedButton<int>(segments: const [ButtonSegment(value: 0, label: Text('Announcements'), icon: Icon(Icons.campaign_rounded)), ButtonSegment(value: 1, label: Text('Team Chat'), icon: Icon(Icons.chat_rounded))], selected: {_tab}, onSelectionChanged: (v) => setState(() => _tab = v.first))),
      ]),
    );
  }

  Widget _announcementsView(bool mobile) {
    final visible = _announcements.where((n) {
      final target = n['target_role']?.toString();
      final allowed = target == null || target.isEmpty || target == 'all' || target == _role || _canManageAnnouncements;
      final q = _search.trim().toLowerCase();
      final text = '${n['title'] ?? ''} ${n['description'] ?? ''} ${n['message'] ?? ''}'.toLowerCase();
      return allowed && (q.isEmpty || text.contains(q));
    }).toList();
    return Column(children: [
      Padding(padding: EdgeInsets.symmetric(horizontal: mobile ? 16 : 28, vertical: 8), child: TextField(onChanged: (v) => setState(() => _search = v), decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'Search announcements...', suffixIcon: _search.isEmpty ? null : IconButton(onPressed: () { _searchController.clear(); setState(() => _search = ''); }, icon: const Icon(Icons.clear_rounded))))),
      Expanded(child: visible.isEmpty ? _empty(Icons.campaign_outlined, 'کوئی اعلان موجود نہیں') : ListView.separated(padding: EdgeInsets.all(mobile ? 12 : 24), itemCount: visible.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, i) => _announcementCard(visible[i]))),
    ]);
  }

  Widget _announcementCard(Map<String, dynamic> n) {
    final title = n['title']?.toString().trim().isNotEmpty == true ? n['title'].toString() : 'School Announcement';
    final body = n['message']?.toString().trim().isNotEmpty == true ? n['message'].toString() : (n['description']?.toString() ?? '');
    final target = n['target_role']?.toString();
    final category = n['category']?.toString() ?? 'general';
    final id = (n['id'] as num?)?.toInt();
    return Card(elevation: 0, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () => _showAnnouncement(n), child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 46, height: 46, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .1), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.campaign_rounded, color: AppColors.primary)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))), if (target != null) _chip(target),]), const SizedBox(height: 5), Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)), const SizedBox(height: 8), Row(children: [ _chip(category), const Spacer(), Text(_formatDate(n['created_at']), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)), if (_canManageAnnouncements && id != null) IconButton(onPressed: () => _deleteAnnouncement(id), icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.redAccent))])]))])));
  }

  Widget _chatView(bool mobile) {
    if (_selectedThreadId == null) {
      return _threadList(mobile);
    }
    return _chatDetail(mobile);
  }

  Widget _threadList(bool mobile) {
    final visible = _threads.where((t) {
      final q = _search.trim().toLowerCase();
      final title = _threadTitle(t).toLowerCase();
      return q.isEmpty || title.contains(q);
    }).toList();
    return Column(children: [
      Padding(padding: EdgeInsets.fromLTRB(mobile ? 16 : 28, 8, mobile ? 16 : 28, 4), child: TextField(onChanged: (v) => setState(() => _search = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search conversations...'))),
      Expanded(child: visible.isEmpty ? _empty(Icons.chat_bubble_outline_rounded, 'ابھی کوئی گفتگو نہیں۔ نئی گفتگو شروع کریں۔') : ListView.separated(padding: EdgeInsets.all(mobile ? 12 : 24), itemCount: visible.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, i) => _threadCard(visible[i]))),
    ]);
  }

  Widget _threadCard(Map<String, dynamic> t) {
    final id = (t['id'] as num).toInt();
    final title = _threadTitle(t);
    return Card(elevation: 0, child: ListTile(leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: .1), child: Icon(t['thread_type'] == 'group' ? Icons.groups_rounded : Icons.person_rounded, color: AppColors.primary)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(t['thread_type'] == 'group' ? 'Team conversation' : 'Direct conversation'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () async { setState(() => _selectedThreadId = id); await _loadMessages(id); }));
  }

  Widget _chatDetail(bool mobile) {
    final thread = _threads.firstWhere((t) => t['id'] == _selectedThreadId, orElse: () => {});
    final title = _threadTitle(thread);
    return Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))), child: Row(children: [IconButton(onPressed: () => setState(() { _selectedThreadId = null; _messages = []; }), icon: const Icon(Icons.arrow_back_rounded)), CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: .1), child: Icon(thread['thread_type'] == 'group' ? Icons.groups_rounded : Icons.person_rounded, color: AppColors.primary)), const SizedBox(width: 10), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))), IconButton(onPressed: () => _loadMessages(_selectedThreadId!), icon: const Icon(Icons.refresh_rounded))]),
      Expanded(child: _messagesLoading ? const Center(child: CircularProgressIndicator()) : _messages.isEmpty ? _empty(Icons.forum_outlined, 'اس گفتگو میں ابھی کوئی پیغام نہیں۔') : ListView.builder(padding: const EdgeInsets.all(18), itemCount: _messages.length, itemBuilder: (_, i) => _messageBubble(_messages[i]))),
      _Composer(onSend: _sendMessage),
    ]);
  }

  Widget _messageBubble(Map<String, dynamic> m) {
    final mine = m['sender_id']?.toString() == _userId;
    return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(constraints: const BoxConstraints(maxWidth: 650), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.fromLTRB(14, 10, 14, 9), decoration: BoxDecoration(color: mine ? AppColors.primary : Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: mine ? null : Border.all(color: AppColors.border)), child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [if (!mine) Text(m['sender_name']?.toString() ?? 'User', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)), const SizedBox(height: 2), Text(m['body']?.toString() ?? '', style: TextStyle(color: mine ? Colors.white : null, height: 1.4)), const SizedBox(height: 3), Text(_formatTime(m['created_at']), style: TextStyle(color: mine ? Colors.white70 : AppColors.textMuted, fontSize: 9))]));
  }

  String _threadTitle(Map<String, dynamic> t) {
    final title = t['title']?.toString().trim() ?? '';
    if (title.isNotEmpty) return title;
    return t['thread_type'] == 'group' ? 'Team Chat' : 'Direct Chat';
  }

  Widget _chip(String text) => Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(20)), child: Text(text, style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w800)));

  Widget _empty(IconData icon, String text) => Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 54, color: AppColors.primary.withValues(alpha: .35)), const SizedBox(height: 12), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700))])));

  Widget _errorView() => Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, size: 50, color: Colors.redAccent), const SizedBox(height: 12), Text(_error ?? 'Error', textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'))])));

  void _showAnnouncement(Map<String, dynamic> n) {
    showDialog(context: context, builder: (_) => AlertDialog(title: Text(n['title']?.toString() ?? 'Announcement'), content: SingleChildScrollView(child: Text(n['message']?.toString().trim().isNotEmpty == true ? n['message'].toString() : (n['description']?.toString() ?? ''))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final h = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final ap = date.hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $ap';
  }
}

class _Composer extends StatefulWidget {
  final Future<void> Function(String) onSend;
  const _Composer({required this.onSend});

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final controller = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    await widget.onSend(text);
    controller.clear();
    if (mounted) setState(() => sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: Container(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: TextField(controller: controller, minLines: 1, maxLines: 5, textInputAction: TextInputAction.newline, decoration: const InputDecoration(hintText: 'پیغام لکھیں...', prefixIcon: Icon(Icons.message_outlined)))), const SizedBox(width: 8), IconButton.filled(onPressed: sending ? null : send, icon: sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded))]));
  }
}
