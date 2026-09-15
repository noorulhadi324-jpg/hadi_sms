import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/report_export_service.dart';
import '../../../../core/widgets/main_wrapper.dart';

class FeesScreen extends StatefulWidget {
  const FeesScreen({super.key});
  @override
  State<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends State<FeesScreen> {
  final _client = SupabaseConfig.client;
  final _amountController = TextEditingController();
  bool _loading = true;
  bool _working = false;
  int? _schoolId;
  String _schoolName = 'HADI SMS';
  List<Map<String, dynamic>> _fees = [];
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _amountController.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw Exception('Please login again.');
      final profile = await _client.from('profiles').select('school_id').eq('id', uid).maybeSingle();
      _schoolId = (profile?['school_id'] as num?)?.toInt();
      if (_schoolId == null) throw Exception('School profile is not linked.');
      final school = await _client.from('schools').select('school_name').eq('id', _schoolId!).maybeSingle();
      _schoolName = (school?['school_name'] as String?) ?? 'HADI SMS';
      final data = await Future.wait([
        _client.from('student_fees').select('id,student_id,fee_category_id,amount,due_date,status,fee_month').eq('school_id', _schoolId!).order('fee_month', ascending: false),
        _client.from('students').select('id,full_name,admission_number,class_name,section_name').eq('school_id', _schoolId!).order('full_name'),
      ]);
      if (!mounted) return;
      setState(() { _fees = List<Map<String,dynamic>>.from(data[0] as List); _students = List<Map<String,dynamic>>.from(data[1] as List); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  String _studentName(dynamic id) {
    for (final s in _students) { if ('${s['id']}' == '$id') return '${s['full_name'] ?? 'Student'}'; }
    return 'Student #$id';
  }
  double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  Future<void> _generateCurrentMonth() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final month = DateTime(DateTime.now().year, DateTime.now().month, 1).toIso8601String().substring(0, 10);
      final result = await _client.rpc('generate_monthly_student_fees', params: {'p_fee_month': month});
      await _load();
      _message('$result نئے fee records تیار کیے گئے۔');
    } catch (e) { _message('Fee generation failed: $e'); }
    finally { if (mounted) setState(() => _working = false); }
  }

  Future<void> _collectPayment(Map<String,dynamic> fee) async {
    _amountController.text = '${fee['amount'] ?? ''}';
    final amount = await showDialog<double>(context: context, builder: (context) => AlertDialog(
      title: Text('Collect Fee — ${_studentName(fee['student_id'])}'),
      content: TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Payment amount', prefixText: 'Rs. ')),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, double.tryParse(_amountController.text.trim())), child: const Text('Continue'))],
    ));
    if (amount == null || amount <= 0) return;
    try {
      setState(() => _working = true);
      final result = await _client.rpc('record_fee_payment', params: {'p_student_fee_id': fee['id'], 'p_amount': amount, 'p_payment_method': 'cash', 'p_notes': null});
      await _load();
      final receipt = result is List && result.isNotEmpty ? result.first['receipt_number'] : 'generated';
      _message('Payment recorded. Receipt: $receipt');
    } catch (e) { _message('Payment failed: $e'); }
    finally { if (mounted) setState(() => _working = false); }
  }

  Future<void> _createOtherChallan() async {
    final typeController = TextEditingController(text: 'Admission Fee');
    final referenceController = TextEditingController();
    final amountController = TextEditingController();
    final dueDateController = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        String selectedType = 'Admission Fee';
        const types = ['Admission Fee', 'Exam Fee', 'Transport Fee', 'Fine / Other'];
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Create Other Challan'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Challan type'),
                    items: types.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedType = value;
                          typeController.text = value;
                        });
                      }
                    },
                  ),
                  TextField(controller: referenceController, decoration: const InputDecoration(labelText: 'Student / reference (optional)')),
                  TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: 'Rs. ')),
                  TextField(controller: dueDateController, decoration: const InputDecoration(labelText: 'Due date (YYYY-MM-DD)')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text.trim());
                  if (amount == null || amount <= 0) return;
                  Navigator.pop(context, {
                    'type': selectedType,
                    'reference': referenceController.text.trim(),
                    'amount': amount.toStringAsFixed(2),
                    'dueDate': dueDateController.text.trim(),
                  });
                },
                child: const Text('Create PDF'),
              ),
            ],
          ),
        );
      },
    );
    typeController.dispose();
    referenceController.dispose();
    amountController.dispose();
    dueDateController.dispose();
    if (result == null) return;
    try {
      final file = await ReportExportService.exportPdf(
        title: result['type'] ?? 'Other Challan',
        schoolName: _schoolName,
        headers: const ['Type', 'Student / Reference', 'Amount', 'Due Date'],
        rows: [[result['type'] ?? '-', result['reference']?.isEmpty == true ? '-' : result['reference']!, 'Rs. ${result['amount']}', result['dueDate'] ?? '-']],
      );
      await ReportExportService.shareFile(file, subject: result['type'] ?? 'Other Challan');
    } catch (e) {
      _message('Other challan failed: $e');
    }
  }

  Future<void> _exportChallan(Map<String, dynamic> fee) async {
    try {
      final student = _students.cast<Map<String, dynamic>>().firstWhere(
        (s) => '${s['id']}' == '${fee['student_id']}',
        orElse: () => <String, dynamic>{},
      );
      final file = await ReportExportService.exportPdf(
        title: 'Fee Challan',
        schoolName: _schoolName,
        headers: const ['Student', 'Admission No.', 'Fee Month', 'Due Date', 'Amount', 'Status'],
        rows: [[
          _studentName(fee['student_id']),
          '${student['admission_number'] ?? '-'}',
          '${fee['fee_month'] ?? '-'}',
          '${fee['due_date'] ?? '-'}',
          'Rs. ${fee['amount'] ?? 0}',
          '${fee['status'] ?? 'unpaid'}',
        ]],
      );
      await ReportExportService.shareFile(file, subject: 'Fee Challan');
    } catch (e) {
      _message('Challan generation failed: $e');
    }
  }

  Future<void> _exportPendingChallans() async {
    try {
      final pending = _fees.where((fee) => '${fee['status']}'.toLowerCase() != 'paid').toList();
      if (pending.isEmpty) {
        _message('No pending fee challans found.');
        return;
      }
      final file = await ReportExportService.exportPdf(
        title: 'Pending Fee Challans',
        schoolName: _schoolName,
        headers: const ['Student', 'Fee Month', 'Due Date', 'Amount', 'Status'],
        rows: pending.map((fee) => [
          _studentName(fee['student_id']),
          '${fee['fee_month'] ?? '-'}',
          '${fee['due_date'] ?? '-'}',
          'Rs. ${fee['amount'] ?? 0}',
          '${fee['status'] ?? 'unpaid'}',
        ]).toList(),
      );
      await ReportExportService.shareFile(file, subject: 'Pending Fee Challans');
    } catch (e) {
      _message('Challan export failed: $e');
    }
  }

  Future<void> _export() async {
    try {
      final file = await ReportExportService.exportExcel(title: 'Fee Register', headers: const ['Student','Fee Month','Due Date','Amount','Status'], rows: _fees.map((f) => [_studentName(f['student_id']), '${f['fee_month'] ?? ''}', '${f['due_date'] ?? ''}', '${f['amount'] ?? 0}', '${f['status'] ?? ''}']).toList(), schoolName: _schoolName);
      await ReportExportService.shareFile(file, subject: 'Fee Register');
    } catch (e) { _message('Export failed: $e'); }
  }

  void _message(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }

  @override
  Widget build(BuildContext context) => MainWrapper(child: RefreshIndicator(onRefresh: _load, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16,20,16,32), children: [
    Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Fees & Challan', style: TextStyle(fontSize:25,fontWeight:FontWeight.w900)), SizedBox(height:4), Text('Live fees, automatic monthly generation, payments and receipts.', style: TextStyle(color:AppColors.textSecondary,fontSize:13))])), if (_working) const SizedBox(width:24,height:24,child:CircularProgressIndicator(strokeWidth:2))]),
    const SizedBox(height:18),
    Wrap(spacing:8,runSpacing:8,children: [FilledButton.icon(onPressed:_working?null:_generateCurrentMonth,icon:const Icon(Icons.auto_awesome_rounded),label:const Text('Generate Current Month')), OutlinedButton.icon(onPressed:_working?null:_export,icon:const Icon(Icons.table_view_rounded),label:const Text('Export Excel')), OutlinedButton.icon(onPressed:_working?null:_exportPendingChallans,icon:const Icon(Icons.picture_as_pdf_rounded),label:const Text('Pending Challans')), OutlinedButton.icon(onPressed:_working?null:_createOtherChallan,icon:const Icon(Icons.add_card_rounded),label:const Text('Other Challan'))]),
    const SizedBox(height:18),
    if (_loading) const Center(child:Padding(padding:EdgeInsets.all(40),child:CircularProgressIndicator())) else ...[_stats(),const SizedBox(height:18),_list()],
  ])));

  Widget _stats() {
    final total = _fees.fold<double>(0,(s,f)=>s+_num(f['amount']));
    final paid = _fees.where((f)=>'${f['status']}'.toLowerCase()=='paid').fold<double>(0,(s,f)=>s+_num(f['amount']));
    return LayoutBuilder(builder:(context,c){ final n=c.maxWidth>=900?4:c.maxWidth>=560?2:1; final cards=[_stat('Records','${_fees.length}',Icons.receipt_long_rounded),_stat('Assigned','Rs. ${total.toStringAsFixed(0)}',Icons.account_balance_wallet_rounded),_stat('Collected','Rs. ${paid.toStringAsFixed(0)}',Icons.check_circle_rounded),_stat('Pending','Rs. ${(total-paid).toStringAsFixed(0)}',Icons.pending_actions_rounded)]; if(n==1)return Column(children:cards.map((x)=>Padding(padding:const EdgeInsets.only(bottom:10),child:x)).toList()); return GridView.count(crossAxisCount:n,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:2.5,children:cards); });
  }
  Widget _stat(String t,String v,IconData i)=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[Icon(i,color:AppColors.primary),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(t,style:const TextStyle(color:AppColors.textSecondary,fontSize:12)),Text(v,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:18))]))])));
  Widget _list()=>Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Student Fee Register',style:TextStyle(fontWeight:FontWeight.w800,fontSize:17)),const SizedBox(height:12),if(_fees.isEmpty)const Padding(padding:EdgeInsets.all(28),child:Center(child:Text('No fee records yet. Use Generate Current Month.'))) else ..._fees.take(100).map((f)=>ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(child:Text(_studentName(f['student_id']).substring(0,1).toUpperCase())),title:Text(_studentName(f['student_id']),style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('Month: ${f['fee_month']??'-'} • Due: ${f['due_date']??'-'}'),trailing:Wrap(spacing:6,crossAxisAlignment:WrapCrossAlignment.center,children:[Text('Rs. ${f['amount']??0}',style:const TextStyle(fontWeight:FontWeight.w800)),Chip(label:Text('${f['status']??'unpaid'}')),IconButton(onPressed:_working?null:()=>_exportChallan(f),icon:const Icon(Icons.print_rounded),tooltip:'Print challan'),if('${f['status']}'.toLowerCase()!='paid')IconButton(onPressed:_working?null:()=>_collectPayment(f),icon:const Icon(Icons.payments_rounded),tooltip:'Collect payment')])))])));
}
