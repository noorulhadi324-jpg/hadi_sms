import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/main_wrapper.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  final SupabaseClient _client = SupabaseConfig.client;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  int? _schoolId;

  double _collected = 0;
  double _pending = 0;
  double _overdue = 0;

  int _paymentCount = 0;
  int _pendingCount = 0;
  int _overdueCount = 0;
  int _categoryCount = 0;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _studentFees = [];
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _recentPayments = [];

  String? _selectedClassName;

  bool get _isMobile {
    return MediaQuery.of(context).size.width < 600;
  }

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
  }

  // ============================================================
  // SCHOOL ID
  // ============================================================

  Future<int?> _getSchoolId() async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      return null;
    }

    try {
      final profile = await _client
          .from('profiles')
          .select('school_id')
          .eq('id', userId)
          .maybeSingle();

      final value = profile?['school_id'];

      final schoolId = value is int
          ? value
          : int.tryParse(value?.toString() ?? '');

      if (schoolId != null) {
        return schoolId;
      }
    } catch (_) {}

    try {
      final school = await _client
          .from('schools')
          .select('id')
          .eq('principal_id', userId)
          .maybeSingle();

      final value = school?['id'];

      final schoolId = value is int
          ? value
          : int.tryParse(value?.toString() ?? '');

      if (schoolId == null) {
        return null;
      }

      try {
        await _client
            .from('profiles')
            .update({'school_id': schoolId})
            .eq('id', userId);
      } catch (_) {}

      return schoolId;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // LOAD FINANCE DATA
  // ============================================================

  Future<void> _loadFinanceData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final schoolId = await _getSchoolId();

      if (schoolId == null) {
        throw Exception(
          'Your account is not linked to a school.',
        );
      }

      _schoolId = schoolId;

      await _loadStudents(schoolId);
      await _loadCategories(schoolId);
      await _loadStudentFees(schoolId);
      await _loadPayments(schoolId);

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
        '${e.message}\n\nCode: ${e.code ?? 'unknown'}';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst(
          'Exception: ',
          '',
        );
        _loading = false;
      });
    }
  }

  // ============================================================
  // STUDENTS
  // ============================================================

  Future<void> _loadStudents(int schoolId) async {
    final response = await _client
        .from('students')
        .select(
      'id, admission_number, full_name, '
          'class_name, section_name, is_active',
    )
        .eq('school_id', schoolId)
        .order('full_name');

    _students = List<Map<String, dynamic>>.from(response);
  }

  // ============================================================
  // CATEGORIES
  // ============================================================

  Future<void> _loadCategories(int schoolId) async {
    final response = await _client
        .from('fee_categories')
        .select(
      'id, name, amount, description, is_active',
    )
        .eq('school_id', schoolId)
        .eq('is_active', true)
        .order('name');

    _categories = List<Map<String, dynamic>>.from(response);

    _categoryCount = _categories.length;
  }

  // ============================================================
  // STUDENT FEES
  // ============================================================

  Future<void> _loadStudentFees(int schoolId) async {
    final response = await _client
        .from('student_fees')
        .select(
      'id, school_id, student_id, '
          'fee_category_id, amount, due_date, status',
    )
        .eq('school_id', schoolId)
        .order('due_date');

    _studentFees = List<Map<String, dynamic>>.from(response);
  }

  // ============================================================
  // PAYMENTS
  // ============================================================

  Future<void> _loadPayments(int schoolId) async {
    final response = await _client
        .from('fee_payments')
        .select(
      'id, student_id, fee_category_id, '
          'amount, payment_date, status, '
          'payment_method, receipt_number, notes',
    )
        .eq('school_id', schoolId)
        .order(
      'payment_date',
      ascending: false,
    );

    _payments = List<Map<String, dynamic>>.from(response);

    double collected = 0;
    int paymentCount = 0;

    for (final payment in _payments) {
      if (_isPaidStatus(
        payment['status']?.toString().toLowerCase(),
      )) {
        collected += _toDouble(payment['amount']);
        paymentCount++;
      }
    }

    _collected = collected;
    _paymentCount = paymentCount;

    _recentPayments = _payments.take(10).toList();

    for (final payment in _recentPayments) {
      payment['_student'] =
          _studentById(payment['student_id']);
    }

    _calculateTotals();
  }

  // ============================================================
  // TOTALS
  // ============================================================

  void _calculateTotals() {
    double pending = 0;
    double overdue = 0;

    int pendingCount = 0;
    int overdueCount = 0;

    final today = DateTime.now();

    for (final fee in _studentFees) {
      final assigned = _toDouble(fee['amount']);

      final paid = _feePaidForAssignment(fee);

      final balance = assigned - paid;

      if (balance <= 0) {
        continue;
      }

      final dueDate = DateTime.tryParse(
        fee['due_date']?.toString() ?? '',
      );

      if (dueDate != null &&
          dueDate.isBefore(
            DateTime(
              today.year,
              today.month,
              today.day,
            ),
          )) {
        overdue += balance;
        overdueCount++;
      } else {
        pending += balance;
        pendingCount++;
      }
    }

    _pending = pending;
    _overdue = overdue;

    _pendingCount = pendingCount;
    _overdueCount = overdueCount;
  }

  // ============================================================
  // HELPERS
  // ============================================================

  bool _isPaidStatus(String? status) {
    return status == 'paid' ||
        status == 'confirmed' ||
        status == 'completed';
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }

  String _money(double amount) {
    return 'PKR ${amount.toStringAsFixed(0)}';
  }

  String _dateOnly(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic>? _studentById(dynamic id) {
    for (final student in _students) {
      if (student['id'].toString() == id.toString()) {
        return student;
      }
    }

    return null;
  }

  Map<String, dynamic>? _categoryById(dynamic id) {
    for (final category in _categories) {
      if (category['id'].toString() == id.toString()) {
        return category;
      }
    }

    return null;
  }

  double _feePaidForAssignment(Map<String, dynamic> fee) {
    double paid = 0;
    for (final payment in _payments) {
      if (!_isPaidStatus(payment['status']?.toString().toLowerCase())) continue;
      if ('${payment['student_fee_id']}' == '${fee['id']}') {
        paid += _toDouble(payment['amount']);
        continue;
      }

      // Legacy rows without a fee id are only assigned within the same month.
      final feeMonth = DateTime.tryParse(fee['fee_month']?.toString() ?? '');
      final paymentDate = DateTime.tryParse(payment['payment_date']?.toString() ?? '');
      final sameMonth = feeMonth != null && paymentDate != null &&
          feeMonth.year == paymentDate.year && feeMonth.month == paymentDate.month;
      if (payment['student_fee_id'] == null && sameMonth &&
          '${payment['student_id']}' == '${fee['student_id']}' &&
          '${payment['fee_category_id']}' == '${fee['fee_category_id']}') {
        paid += _toDouble(payment['amount']);
      }
    }
    return paid.clamp(0, _toDouble(fee['amount'])).toDouble();
  }

  double _studentTotalFee(dynamic studentId) {
    double total = 0;

    for (final fee in _studentFees) {
      if (fee['student_id'].toString() ==
          studentId.toString()) {
        total += _toDouble(fee['amount']);
      }
    }

    return total;
  }

  double _studentPaidFee(dynamic studentId) {
    double total = 0;

    for (final payment in _payments) {
      if (payment['student_id'].toString() ==
          studentId.toString()) {
        if (_isPaidStatus(
          payment['status']?.toString().toLowerCase(),
        )) {
          total += _toDouble(payment['amount']);
        }
      }
    }

    return total;
  }

  Map<String, dynamic>? _pendingAdmissionFee(
      dynamic studentId,
      ) {
    final admissionCategory = _categories.where(
          (category) {
        final name =
            category['name']?.toString().trim().toLowerCase() ??
                '';

        return name == 'admission fee';
      },
    );

    if (admissionCategory.isEmpty) {
      return null;
    }

    final categoryId = admissionCategory.first['id'];

    for (final fee in _studentFees) {
      if (fee['student_id'].toString() ==
          studentId.toString() &&
          fee['fee_category_id'].toString() ==
              categoryId.toString()) {
        final paid = _feePaidForAssignment(fee);

        final amount = _toDouble(fee['amount']);

        if (amount > paid) {
          return fee;
        }
      }
    }

    return null;
  }

  // ============================================================
  // COLLECT FEE
  // ============================================================

  Future<void> _openCollectFee({
    Map<String, dynamic>? selectedStudent,
    Map<String, dynamic>? selectedFee,
  }) async {
    if (_schoolId == null) return;

    if (_students.isEmpty) {
      _showMessage('No students found.');
      return;
    }

    if (_categories.isEmpty) {
      _showMessage(
        'Please create a Fee Category first.',
      );

      await _openAddCategory();
      return;
    }

    Map<String, dynamic>? student = selectedStudent;
    Map<String, dynamic>? category;

    final amountController = TextEditingController();
    final notesController = TextEditingController();

    DateTime paymentDate = DateTime.now();

    String paymentMethod = 'Cash';

    if (selectedFee != null) {
      student = _studentById(
        selectedFee['student_id'],
      );

      category = _categoryById(
        selectedFee['fee_category_id'],
      );

      final assigned = _toDouble(
        selectedFee['amount'],
      );

      final paid = _feePaidForAssignment(
        selectedFee,
      );

      final balance = (assigned - paid)
          .clamp(0, double.infinity)
          .toDouble();

      amountController.text =
          balance.toStringAsFixed(0);
    }

    try {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
                context,
                setDialogState,
                ) {
              return AlertDialog(
                title: const Text('Collect Fee'),
                content: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<
                            Map<String, dynamic>>(
                          initialValue: student,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Student',
                            prefixIcon: Icon(
                              Icons.person_outline,
                            ),
                          ),
                          items: _students.map((item) {
                            final active =
                                item['is_active'] == true;

                            return DropdownMenuItem<
                                Map<String, dynamic>>(
                              value: item,
                              child: Text(
                                '${item['full_name']} • '
                                    '${item['class_name'] ?? '-'}'
                                    '-${item['section_name'] ?? '-'}'
                                    '${active ? '' : ' • INACTIVE'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: selectedFee != null
                              ? null
                              : (value) {
                            setDialogState(() {
                              student = value;
                              category = null;
                              amountController.clear();
                            });
                          },
                        ),

                        const SizedBox(height: 14),

                        DropdownButtonFormField<
                            Map<String, dynamic>>(
                          initialValue: category,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Fee Category',
                            prefixIcon: Icon(
                              Icons.category_outlined,
                            ),
                          ),
                          items: _categories.map((item) {
                            return DropdownMenuItem<
                                Map<String, dynamic>>(
                              value: item,
                              child: Text(
                                '${item['name']} • '
                                    '${_money(_toDouble(item['amount']))}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: selectedFee != null
                              ? null
                              : (value) {
                            setDialogState(() {
                              category = value;

                              if (value != null) {
                                amountController.text =
                                    _toDouble(
                                      value['amount'],
                                    ).toStringAsFixed(0);
                              }
                            });
                          },
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          controller: amountController,
                          keyboardType:
                          const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixText: 'PKR ',
                            prefixIcon: Icon(
                              Icons.payments_outlined,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        DropdownButtonFormField<String>(
                          initialValue: paymentMethod,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Payment Method',
                            prefixIcon: Icon(
                              Icons.account_balance_wallet_outlined,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Cash',
                              child: Text('Cash'),
                            ),
                            DropdownMenuItem(
                              value: 'Bank Transfer',
                              child: Text('Bank Transfer'),
                            ),
                            DropdownMenuItem(
                              value: 'Online',
                              child: Text('Online'),
                            ),
                            DropdownMenuItem(
                              value: 'Cheque',
                              child: Text('Cheque'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;

                            setDialogState(() {
                              paymentMethod = value;
                            });
                          },
                        ),

                        const SizedBox(height: 14),

                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.calendar_today_outlined,
                          ),
                          title: const Text(
                            'Payment Date',
                          ),
                          subtitle: Text(
                            _dateOnly(paymentDate),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                          ),
                          onTap: () async {
                            final selected =
                            await showDatePicker(
                              context: dialogContext,
                              initialDate: paymentDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );

                            if (selected != null) {
                              setDialogState(() {
                                paymentDate = selected;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 8),

                        TextField(
                          controller: notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            prefixIcon: Icon(
                              Icons.notes_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () {
                      Navigator.of(
                        dialogContext,
                      ).pop(false);
                    },
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                      final amount =
                      double.tryParse(
                        amountController.text.trim(),
                      );

                      if (student == null) {
                        _showMessage(
                          'Please select a student.',
                        );
                        return;
                      }

                      if (category == null) {
                        _showMessage(
                          'Please select a fee category.',
                        );
                        return;
                      }

                      if (amount == null ||
                          amount <= 0) {
                        _showMessage(
                          'Please enter a valid amount.',
                        );
                        return;
                      }

                      Navigator.of(
                        dialogContext,
                      ).pop(false);

                      await _savePayment(
                        studentId: student!['id'],
                        categoryId: category!['id'],
                        amount: amount,
                        paymentDate: paymentDate,
                        paymentMethod: paymentMethod,
                        notes: notesController.text.trim(),
                        feeId: selectedFee?['id'],
                      );
                    },
                    icon: const Icon(
                      Icons.check_circle_outline,
                    ),
                    label: const Text('Collect Fee'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      amountController.dispose();
      notesController.dispose();
    }
  }

  // ============================================================
  // SAVE PAYMENT
  // ============================================================

  Future<void> _savePayment({
    required dynamic studentId,
    required dynamic categoryId,
    required double amount,
    required DateTime paymentDate,
    required String paymentMethod,
    required String notes,
    dynamic feeId,
  }) async {
    if (_schoolId == null) return;

    if (!mounted) return;

    setState(() {
      _saving = true;
    });

    try {
      final userId = _client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception(
          'No authenticated user found.',
        );
      }

      if (feeId != null) {
        final fee = await _client
            .from('student_fees')
            .select(
          'id, amount, student_id, fee_category_id',
        )
            .eq('school_id', _schoolId!)
            .eq('id', feeId)
            .maybeSingle();

        if (fee == null) {
          throw Exception(
            'Fee record was not found.',
          );
        }

        final alreadyPaid =
        _feePaidForAssignment(fee);

        final balance = (_toDouble(
          fee['amount'],
        ) -
            alreadyPaid)
            .clamp(
          0,
          double.infinity,
        )
            .toDouble();

        if (amount > balance) {
          throw Exception(
            'Amount cannot be greater than remaining balance ${_money(balance)}.',
          );
        }
      }

      final payment = await _client
          .from('fee_payments')
          .insert({
        'school_id': _schoolId,
        'student_id': studentId,
        'fee_category_id': categoryId,
        'amount': amount,
        'payment_date': _dateOnly(paymentDate),
        'status': 'paid',
        'payment_method': paymentMethod,
        'notes': notes.isEmpty ? null : notes,
        'created_by': userId,
      })
          .select('id, receipt_number')
          .single();

      final paymentId = payment['id'];

      String receiptNumber =
          payment['receipt_number']?.toString() ?? '';

      if (receiptNumber.trim().isEmpty) {
        receiptNumber =
        'RCP-${DateTime.now().millisecondsSinceEpoch}';

        try {
          await _client
              .from('fee_payments')
              .update({
            'receipt_number': receiptNumber,
          })
              .eq('id', paymentId);
        } catch (_) {}
      }

      try {
        await _client.from('fee_receipts').insert({
          'school_id': _schoolId,
          'student_id': studentId,
          'payment_id': paymentId,
          'receipt_number': receiptNumber,
          'amount': amount,
          'issued_at':
          DateTime.now().toUtc().toIso8601String(),
          'created_by': userId,
        });
      } catch (_) {}

      if (feeId != null) {
        final fee = await _client
            .from('student_fees')
            .select(
          'id, amount, student_id, fee_category_id',
        )
            .eq('school_id', _schoolId!)
            .eq('id', feeId)
            .maybeSingle();

        if (fee != null) {
          final paid = _feePaidForAssignment(fee);

          final totalPaid = paid + amount;

          final assigned =
          _toDouble(fee['amount']);

          if (totalPaid >= assigned) {
            await _client
                .from('student_fees')
                .update({
              'status': 'paid',
            })
                .eq('school_id', _schoolId!)
                .eq('id', feeId);
          }
        }
      } else {
        final fees = await _client
            .from('student_fees')
            .select(
          'id, amount, student_id, fee_category_id',
        )
            .eq('school_id', _schoolId!)
            .eq('student_id', studentId)
            .eq('fee_category_id', categoryId)
            .order('due_date');

        for (final fee in fees) {
          final assigned =
          _toDouble(fee['amount']);

          final paidBefore =
          _feePaidForAssignment(fee);

          final balance =
              assigned - paidBefore;

          if (balance <= 0) {
            continue;
          }

          if (amount >= balance) {
            await _client
                .from('student_fees')
                .update({
              'status': 'paid',
            })
                .eq('school_id', _schoolId!)
                .eq('id', fee['id']);
          }

          break;
        }
      }

      final categoryName = _categoryById(categoryId)?['name']
          ?.toString()
          .trim()
          .toLowerCase();

      if (categoryName == 'admission fee') {
        final admissionFees = await _client
            .from('student_fees')
            .select(
          'id, amount, student_id, fee_category_id, status',
        )
            .eq('school_id', _schoolId!)
            .eq('student_id', studentId)
            .eq('fee_category_id', categoryId);

        double assignedTotal = 0;

        for (final fee in admissionFees) {
          assignedTotal += _toDouble(
            fee['amount'],
          );
        }

        final paymentsForAdmission = _payments
            .where(
              (payment) =>
          payment['student_id'].toString() ==
              studentId.toString() &&
              payment['fee_category_id'].toString() ==
                  categoryId.toString() &&
              _isPaidStatus(
                payment['status']
                    ?.toString()
                    .toLowerCase(),
              ),
        )
            .fold<double>(
          0,
              (sum, payment) =>
          sum + _toDouble(payment['amount']),
        );

        final totalPaid =
            paymentsForAdmission + amount;

        if (assignedTotal > 0 &&
            totalPaid >= assignedTotal) {
          await _client
              .from('students')
              .update({
            'is_active': true,
          })
              .eq('id', studentId)
              .eq('school_id', _schoolId!);
        }
      }

      if (!mounted) return;

      _showMessage(
        'Payment saved successfully. Receipt: $receiptNumber',
        success: true,
      );

      await _loadFinanceData();
    } on PostgrestException catch (e) {
      if (!mounted) return;

      _showMessage(
        '${e.message}\nCode: ${e.code ?? 'unknown'}',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // ADD CATEGORY
  // ============================================================

  Future<void> _openAddCategory() async {
    if (_schoolId == null) return;

    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Add Fee Category',
            ),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization:
                      TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        hintText:
                        'e.g. Admission Fee',
                        prefixIcon: Icon(
                          Icons.category_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountController,
                      keyboardType:
                      const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: 'PKR ',
                        prefixIcon: Icon(
                          Icons.payments_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller:
                      descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        prefixIcon: Icon(
                          Icons.description_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: _saving
                    ? null
                    : () {
                  Navigator.of(
                    dialogContext,
                  ).pop();
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                  final name =
                  nameController.text.trim();

                  final amount =
                  double.tryParse(
                    amountController.text.trim(),
                  );

                  if (name.isEmpty) {
                    _showMessage(
                      'Enter category name.',
                    );
                    return;
                  }

                  if (amount == null ||
                      amount <= 0) {
                    _showMessage(
                      'Enter a valid amount.',
                    );
                    return;
                  }

                  setState(() {
                    _saving = true;
                  });

                  try {
                    await _client
                        .from('fee_categories')
                        .insert({
                      'school_id': _schoolId,
                      'name': name,
                      'amount': amount,
                      'description':
                      descriptionController
                          .text
                          .trim()
                          .isEmpty
                          ? null
                          : descriptionController
                          .text
                          .trim(),
                      'is_active': true,
                    });

                    if (!dialogContext.mounted) {
                      return;
                    }

                    Navigator.of(
                      dialogContext,
                    ).pop();

                    _showMessage(
                      'Fee category created successfully.',
                      success: true,
                    );

                    await _loadFinanceData();
                  } on PostgrestException catch (e) {
                    if (mounted) {
                      _showMessage(
                        '${e.message}\nCode: ${e.code ?? 'unknown'}',
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      _showMessage(
                        e.toString().replaceFirst(
                          'Exception: ',
                          '',
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        _saving = false;
                      });
                    }
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );
    } finally {
      nameController.dispose();
      amountController.dispose();
      descriptionController.dispose();
    }
  }

  // ============================================================
  // STUDENT FEES DIALOG
  // ============================================================

  Future<void> _openStudentFees(
      Map<String, dynamic> student,
      ) async {
    final fees = _studentFees
        .where(
          (fee) =>
      fee['student_id'].toString() ==
          student['id'].toString(),
    )
        .toList();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            '${student['full_name'] ?? 'Student'} - Fees',
          ),
          content: SizedBox(
            width: 650,
            child: fees.isEmpty
                ? const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No fees assigned.',
              ),
            )
                : ListView.separated(
              shrinkWrap: true,
              itemCount: fees.length,
              separatorBuilder: (_, __) =>
              const Divider(),
              itemBuilder: (
                  context,
                  index,
                  ) {
                final fee = fees[index];

                final category =
                _categoryById(
                  fee['fee_category_id'],
                );

                final categoryName =
                    category?['name']
                        ?.toString() ??
                        'Fee';

                final amount =
                _toDouble(fee['amount']);

                final paid =
                _feePaidForAssignment(
                  fee,
                );

                final balance = (amount - paid)
                    .clamp(
                  0,
                  double.infinity,
                )
                    .toDouble();

                final dueDate =
                    fee['due_date']
                        ?.toString() ??
                        '-';

                final isPaid =
                    balance <= 0;

                return ListTile(
                  contentPadding:
                  EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                    (isPaid
                        ? AppColors.success
                        : AppColors.warning)
                        .withValues(alpha: .10),
                    child: Icon(
                      isPaid
                          ? Icons.check_circle_outline
                          : Icons.schedule_outlined,
                      color: isPaid
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                  title: Text(
                    categoryName,
                    style: const TextStyle(
                      fontWeight:
                      FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    'Assigned: ${_money(amount)}\n'
                        'Paid: ${_money(paid)} • '
                        'Balance: ${_money(balance)}\n'
                        'Due: $dueDate',
                  ),
                  isThreeLine: true,
                  trailing: isPaid
                      ? const Icon(
                    Icons.lock_outline,
                    color:
                    AppColors.textMuted,
                  )
                      : IconButton(
                    tooltip:
                    'Collect Fee',
                    icon: const Icon(
                      Icons.payments_outlined,
                      color:
                      AppColors.success,
                    ),
                    onPressed: () {
                      Navigator.of(
                        dialogContext,
                      ).pop();

                      _openCollectFee(
                        selectedStudent:
                        student,
                        selectedFee: fee,
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // FEE MANAGEMENT
  // ============================================================

  Widget _buildFeeManagement() {
    if (_students.isEmpty) {
      return _emptyCard('No students found.');
    }

    final classNames = <String>{};

    for (final student in _students) {
      final value =
          student['class_name']?.toString().trim() ?? '';

      if (value.isNotEmpty) {
        classNames.add(value);
      }
    }

    final classes = classNames.toList()
      ..sort(
            (a, b) => a.toLowerCase().compareTo(
          b.toLowerCase(),
        ),
      );

    if (classes.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Student Fees',
            onRefresh: _loadFinanceData,
          ),
          const SizedBox(height: 12),
          ..._students.map(_buildStudentFeeCard),
        ],
      );
    }

    if (_selectedClassName == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            'Classes',
            onRefresh: _loadFinanceData,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (
                context,
                constraints,
                ) {
              final width =
              constraints.maxWidth >= 900
                  ? (constraints.maxWidth - 24) / 3
                  : constraints.maxWidth >= 600
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: classes.map(
                      (className) {
                    final count = _students
                        .where(
                          (s) =>
                      (s['class_name']
                          ?.toString()
                          .trim() ??
                          '') ==
                          className,
                    )
                        .length;

                    double total = 0;
                    double paid = 0;

                    for (final student in _students) {
                      if ((student['class_name']
                          ?.toString()
                          .trim() ??
                          '') ==
                          className) {
                        total += _studentTotalFee(
                          student['id'],
                        );

                        paid += _studentPaidFee(
                          student['id'],
                        );
                      }
                    }

                    final pending = (total - paid)
                        .clamp(
                      0,
                      double.infinity,
                    )
                        .toDouble();

                    return SizedBox(
                      width: width,
                      child: Card(
                        child: InkWell(
                          borderRadius:
                          BorderRadius.circular(
                            20,
                          ),
                          onTap: () {
                            setState(() {
                              _selectedClassName =
                                  className;
                            });
                          },
                          child: Padding(
                            padding:
                            const EdgeInsets.all(
                              18,
                            ),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration:
                                      BoxDecoration(
                                        color: AppColors
                                            .primary
                                            .withValues(
                                          alpha: .10,
                                        ),
                                        borderRadius:
                                        BorderRadius
                                            .circular(
                                          14,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons
                                            .school_outlined,
                                        color:
                                        AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 12,
                                    ),
                                    Expanded(
                                      child: Text(
                                        className,
                                        overflow:
                                        TextOverflow
                                            .ellipsis,
                                        style:
                                        const TextStyle(
                                          fontSize: 16,
                                          fontWeight:
                                          FontWeight
                                              .w900,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons
                                          .chevron_right_rounded,
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: 14,
                                ),
                                Text(
                                  '$count Students',
                                  style:
                                  const TextStyle(
                                    color: AppColors
                                        .textSecondary,
                                    fontSize: 12,
                                    fontWeight:
                                    FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child:
                                      _classMiniAmount(
                                        'Paid',
                                        paid,
                                        AppColors
                                            .success,
                                      ),
                                    ),
                                    Expanded(
                                      child:
                                      _classMiniAmount(
                                        'Pending',
                                        pending,
                                        AppColors
                                            .warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ).toList(),
              );
            },
          ),
        ],
      );
    }

    final classStudents = _students.where(
          (student) {
        return (student['class_name']
            ?.toString()
            .trim() ??
            '') ==
            _selectedClassName;
      },
    ).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isMobile)
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back to Classes',
                    onPressed: () {
                      setState(() {
                        _selectedClassName = null;
                      });
                    },
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '$_selectedClassName',
                      overflow:
                      TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding:
                const EdgeInsets.only(
                  left: 12,
                ),
                child: Text(
                  '${classStudents.length} Students',
                  style: const TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              Align(
                alignment:
                Alignment.centerRight,
                child: TextButton.icon(
                  onPressed:
                  _loadFinanceData,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Refresh',
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              IconButton(
                tooltip: 'Back to Classes',
                onPressed: () {
                  setState(() {
                    _selectedClassName = null;
                  });
                },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                ),
              ),
              Expanded(
                child: Text(
                  '$_selectedClassName — '
                      '${classStudents.length} Students',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed:
                _loadFinanceData,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                ),
                label: const Text(
                  'Refresh',
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        if (classStudents.isEmpty)
          _emptyCard(
            'No students found in this class.',
          )
        else
          ...classStudents.map(
            _buildStudentFeeCard,
          ),
      ],
    );
  }

  Widget _sectionTitle(
      String title, {
        VoidCallback? onRefresh,
      }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (onRefresh != null)
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(
              Icons.refresh_rounded,
              size: 18,
            ),
            label: const Text(
              'Refresh',
            ),
          ),
      ],
    );
  }

  Widget _classMiniAmount(
      String label,
      double amount,
      Color color,
      ) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _money(amount),
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STUDENT FEE CARD
  // ============================================================

  Widget _buildStudentFeeCard(
      Map<String, dynamic> student,
      ) {
    final id = student['id'];

    final total = _studentTotalFee(id);
    final paid = _studentPaidFee(id);

    final pending = (total - paid)
        .clamp(
      0,
      double.infinity,
    )
        .toDouble();

    final active =
        student['is_active'] == true;

    final admissionFee =
    _pendingAdmissionFee(id);

    final name =
        student['full_name']?.toString() ??
            'Student';

    final className =
        student['class_name']?.toString() ??
            '-';

    final section =
        student['section_name']?.toString() ??
            '-';

    final admission =
        student['admission_number']?.toString() ??
            '-';

    final initial = name.isEmpty
        ? '?'
        : name.substring(0, 1).toUpperCase();

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding: EdgeInsets.all(
          _isMobile ? 12 : 16,
        ),
        child: Column(
          children: [
            // TOP
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                  AppColors.primary
                      .withValues(alpha: .10),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color:
                      AppColors.primary,
                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment:
                        WrapCrossAlignment.center,
                        children: [
                          ConstrainedBox(
                            constraints:
                            BoxConstraints(
                              maxWidth: _isMobile
                                  ? 180
                                  : 300,
                            ),
                            child: Text(
                              name,
                              overflow:
                              TextOverflow.ellipsis,
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          _statusChip(active),
                        ],
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Class $className-$section',
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                          color:
                          AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        'ID $admission',
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                          color:
                          AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  tooltip:
                  'View Student Fees',
                  onPressed: () =>
                      _openStudentFees(
                        student,
                      ),
                  icon: const Icon(
                    Icons.receipt_long_outlined,
                  ),
                ),

                IconButton(
                  tooltip: 'Assign Fee',
                  onPressed: _saving
                      ? null
                      : () => _openAssignFee(
                    selectedStudent:
                    student,
                  ),
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color:
                    AppColors.primary,
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // AMOUNTS
            if (_isMobile)
              Column(
                children: [
                  Row(
                    children: [
                      _feeAmount(
                        'Total',
                        total,
                        AppColors.primary,
                      ),
                      _feeAmount(
                        'Paid',
                        paid,
                        AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _feeAmount(
                        'Pending',
                        pending,
                        AppColors.warning,
                      ),
                    ],
                  ),
                  if (admissionFee != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child:
                      FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () =>
                            _openCollectFee(
                              selectedStudent:
                              student,
                              selectedFee:
                              admissionFee,
                            ),
                        icon: const Icon(
                          Icons.payments_outlined,
                          size: 17,
                        ),
                        label: const Text(
                          'Collect Admission Fee',
                        ),
                      ),
                    ),
                  ],
                ],
              )
            else
              Row(
                children: [
                  _feeAmount(
                    'Total',
                    total,
                    AppColors.primary,
                  ),
                  _feeAmount(
                    'Paid',
                    paid,
                    AppColors.success,
                  ),
                  _feeAmount(
                    'Pending',
                    pending,
                    AppColors.warning,
                  ),
                  if (admissionFee != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child:
                      FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () =>
                            _openCollectFee(
                              selectedStudent:
                              student,
                              selectedFee:
                              admissionFee,
                            ),
                        icon: const Icon(
                          Icons.payments_outlined,
                          size: 17,
                        ),
                        label: const Text(
                          'Collect Admission Fee',
                        ),
                      ),
                    ),
                  ],
                ],
              ),

            // WARNING
            if (!active &&
                admissionFee != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning
                      .withValues(alpha: .08),
                  borderRadius:
                  BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning
                        .withValues(alpha: .20),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color:
                      AppColors.warning,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Admission Fee is pending. '
                            'Student will automatically become ACTIVE after full payment.',
                        style:
                        TextStyle(
                          fontSize: 11,
                          color:
                          AppColors.warning,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FEE AMOUNT
  // ============================================================

  Widget _feeAmount(
      String label,
      double amount,
      Color color,
      ) {
    return Expanded(
      child: Padding(
        padding:
        const EdgeInsets.only(
          right: 10,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color:
                AppColors.textSecondary,
                fontSize: 9,
                fontWeight:
                FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _money(amount),
              overflow:
              TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight:
                FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STATUS CHIP
  // ============================================================

  Widget _statusChip(bool active) {
    final color = active
        ? AppColors.success
        : AppColors.error;

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight:
          FontWeight.w900,
        ),
      ),
    );
  }

  // ============================================================
  // CLASS SUMMARY
  // ============================================================

  Widget _buildClassSummary() {
    final selected =
        _selectedClassName;

    final students = selected == null
        ? _students
        : _students
        .where(
          (s) =>
      (s['class_name']
          ?.toString()
          .trim() ??
          '') ==
          selected,
    )
        .toList();

    double total = 0;
    double paid = 0;

    for (final s in students) {
      total += _studentTotalFee(s['id']);
      paid += _studentPaidFee(s['id']);
    }

    final pending = (total - paid)
        .clamp(
      0,
      double.infinity,
    )
        .toDouble();

    Widget box(
        String label,
        String value,
        Color color,
        IconData icon,
        ) {
      return Container(
        padding:
        const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .06),
          borderRadius:
          BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: .15),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color,
              size: 21,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color:
                      AppColors.textSecondary,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    overflow:
                    TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: color,
                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      margin:
      const EdgeInsets.only(
        bottom: 20,
      ),
      child: Padding(
        padding:
        const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              selected == null
                  ? 'All Students Summary'
                  : '$selected Summary',
              style: const TextStyle(
                fontSize: 16,
                fontWeight:
                FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (
                  context,
                  constraints,
                  ) {
                final children = [
                  box(
                    'Students',
                    students.length.toString(),
                    AppColors.primary,
                    Icons.people_outline,
                  ),
                  box(
                    'Total Fee',
                    _money(total),
                    AppColors.primary,
                    Icons.receipt_long_outlined,
                  ),
                  box(
                    'Collected',
                    _money(paid),
                    AppColors.success,
                    Icons.check_circle_outline,
                  ),
                  box(
                    'Pending',
                    _money(pending),
                    AppColors.warning,
                    Icons.pending_actions_outlined,
                  ),
                ];

                if (constraints.maxWidth >= 800) {
                  return Row(
                    children: [
                      Expanded(
                        child: children[0],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: children[1],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: children[2],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: children[3],
                      ),
                    ],
                  );
                }

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children:
                  children.map(
                        (w) {
                      return SizedBox(
                        width: constraints.maxWidth >=
                            520
                            ? (constraints.maxWidth -
                            10) /
                            2
                            : constraints.maxWidth,
                        child: w,
                      );
                    },
                  ).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final horizontalPadding =
    MediaQuery.of(context).size.width < 600
        ? 12.0
        : 24.0;

    return MainWrapper(
      child: RefreshIndicator(
        onRefresh: _loadFinanceData,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16,
          ),
          children: [
            _buildHeader(),

            const SizedBox(height: 20),

            if (_loading)
              _buildLoading()
            else if (_error != null)
              _buildError()
            else ...[
                _buildMetrics(),

                const SizedBox(height: 20),

                _buildCategoryCard(),

                const SizedBox(height: 20),

                _buildClassSummary(),

                const SizedBox(height: 8),

                _buildFeeManagement(),

                const SizedBox(height: 28),

                _buildTransactionsHeader(),

                const SizedBox(height: 12),

                _buildTransactions(),
              ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    if (_isMobile) {
      return Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            'Finance Hub',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Monitor revenue, pending fees and collections.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
              _loading || _saving
                  ? null
                  : () =>
                  _openCollectFee(),
              icon: const Icon(
                Icons.payments_outlined,
              ),
              label: const Text(
                'Collect Fee',
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'Finance Hub',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Monitor revenue, pending fees and collections.',
                style: TextStyle(
                  color:
                  AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed:
          _loading || _saving
              ? null
              : () =>
              _openCollectFee(),
          icon: const Icon(
            Icons.payments_outlined,
          ),
          label: const Text(
            'Collect Fee',
          ),
        ),
      ],
    );
  }

  // ============================================================
  // METRICS
  // ============================================================

  Widget _buildMetrics() {
    return LayoutBuilder(
      builder: (
          context,
          constraints,
          ) {
        final cards = [
          _metricCard(
            'Collected',
            _money(_collected),
            '$_paymentCount payments',
            AppColors.success,
            Icons.account_balance_wallet_rounded,
          ),
          _metricCard(
            'Pending',
            _money(_pending),
            '$_pendingCount fees',
            AppColors.warning,
            Icons.schedule_rounded,
          ),
          _metricCard(
            'Overdue',
            _money(_overdue),
            '$_overdueCount fees',
            AppColors.error,
            Icons.warning_amber_rounded,
          ),
          _metricCard(
            'Fee Categories',
            _categoryCount.toString(),
            'Active categories',
            AppColors.primary,
            Icons.category_rounded,
          ),
        ];

        if (constraints.maxWidth >= 900) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 16),
              Expanded(child: cards[1]),
              const SizedBox(width: 16),
              Expanded(child: cards[2]),
              const SizedBox(width: 16),
              Expanded(child: cards[3]),
            ],
          );
        }

        if (constraints.maxWidth >= 600) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: cards[0],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: cards[1],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: cards[2],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: cards[3],
                  ),
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            cards[0],
            const SizedBox(height: 12),
            cards[1],
            const SizedBox(height: 12),
            cards[2],
            const SizedBox(height: 12),
            cards[3],
          ],
        );
      },
    );
  }

  Widget _metricCard(
      String title,
      String value,
      String subtitle,
      Color color,
      IconData icon,
      ) {
    return Container(
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color:
                    AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration:
                BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 21,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            overflow:
            TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight:
              FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color:
              AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EDIT CATEGORY
  // ============================================================

  Future<void> _openEditCategory(
      Map<String, dynamic> category,
      ) async {
    final nameController =
    TextEditingController(
      text: category['name']?.toString() ?? '',
    );

    final amountController =
    TextEditingController(
      text: _toDouble(
        category['amount'],
      ).toStringAsFixed(0),
    );

    final descriptionController =
    TextEditingController(
      text:
      category['description']?.toString() ?? '',
    );

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          bool saving = false;

          return StatefulBuilder(
            builder: (
                context,
                setDialogState,
                ) {
              return AlertDialog(
                title: const Text(
                  'Edit Fee Category',
                ),
                content: SizedBox(
                  width: 450,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        TextField(
                          controller:
                          nameController,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Category Name',
                            prefixIcon:
                            Icon(
                              Icons.category_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller:
                          amountController,
                          keyboardType:
                          const TextInputType
                              .numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Amount',
                            prefixText:
                            'PKR ',
                            prefixIcon:
                            Icon(
                              Icons.payments_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller:
                          descriptionController,
                          maxLines: 3,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Description',
                            prefixIcon:
                            Icon(
                              Icons.description_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () =>
                        Navigator.of(
                          dialogContext,
                        ).pop(),
                    child:
                    const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                      final name =
                      nameController
                          .text
                          .trim();

                      final amount =
                      double.tryParse(
                        amountController
                            .text
                            .trim(),
                      );

                      if (name.isEmpty) {
                        _showMessage(
                          'Enter category name.',
                        );
                        return;
                      }

                      if (amount ==
                          null ||
                          amount <= 0) {
                        _showMessage(
                          'Enter a valid amount.',
                        );
                        return;
                      }

                      setDialogState(
                            () {
                          saving = true;
                        },
                      );

                      try {
                        await _client
                            .from(
                          'fee_categories',
                        )
                            .update({
                          'name':
                          name,
                          'amount':
                          amount,
                          'description':
                          descriptionController
                              .text
                              .trim()
                              .isEmpty
                              ? null
                              : descriptionController
                              .text
                              .trim(),
                        })
                            .eq(
                          'id',
                          category['id'],
                        )
                            .eq(
                          'school_id',
                          _schoolId!,
                        );

                        if (!dialogContext
                            .mounted) {
                          return;
                        }

                        Navigator.of(
                          dialogContext,
                        ).pop();

                        _showMessage(
                          'Fee category updated successfully.',
                          success:
                          true,
                        );

                        await _loadFinanceData();
                      } on PostgrestException catch (e) {
                        if (mounted) {
                          _showMessage(
                            '${e.message}\nCode: ${e.code ?? 'unknown'}',
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          _showMessage(
                            e.toString()
                                .replaceFirst(
                              'Exception: ',
                              '',
                            ),
                          );
                        }
                      } finally {
                        if (dialogContext
                            .mounted) {
                          setDialogState(
                                () {
                              saving = false;
                            },
                          );
                        }
                      }
                    },
                    child: const Text(
                      'Save Changes',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      amountController.dispose();
      descriptionController.dispose();
    }
  }

  // ============================================================
  // DELETE CATEGORY
  // ============================================================

  Future<void> _deleteCategory(
      Map<String, dynamic> category,
      ) async {
    if (_schoolId == null) return;

    final name =
        category['name']?.toString() ??
            'this category';

    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Fee Category?',
          ),
          content: Text(
            'Delete "$name"?\n\n'
                'If this category is already used by student fees or payments, '
                'it is safer to deactivate it instead.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(
                    dialogContext,
                  ).pop(false),
              child:
              const Text('Cancel'),
            ),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(
                    dialogContext,
                  ).pop(true),
              child:
              const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _client
          .from('fee_categories')
          .delete()
          .eq('id', category['id'])
          .eq(
        'school_id',
        _schoolId!,
      );

      _showMessage(
        'Fee category deleted successfully.',
        success: true,
      );

      await _loadFinanceData();
    } on PostgrestException catch (e) {
      try {
        await _client
            .from('fee_categories')
            .update({
          'is_active': false,
        })
            .eq(
          'id',
          category['id'],
        )
            .eq(
          'school_id',
          _schoolId!,
        );

        _showMessage(
          'Category is already in use, so it was deactivated instead.',
          success: true,
        );

        await _loadFinanceData();
      } catch (_) {
        _showMessage(
          '${e.message}\nCode: ${e.code ?? 'unknown'}',
        );
      }
    } catch (e) {
      _showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // ADD CLASS MONTHLY CATEGORY
  // ============================================================

  Future<void>
  _openAddClassMonthlyCategory() async {
    if (_schoolId == null) return;

    final classNames = <String>{};

    for (final student in _students) {
      final value =
          student['class_name']
              ?.toString()
              .trim() ??
              '';

      if (value.isNotEmpty) {
        classNames.add(value);
      }
    }

    final classes =
    classNames.toList()..sort();

    if (classes.isEmpty) {
      _showMessage(
        'No classes found. Add students first.',
      );
      return;
    }

    String selectedClass =
        classes.first;

    final amountController =
    TextEditingController();

    final descriptionController =
    TextEditingController();

    String categoryName(
        String className,
        ) {
      return '$className Monthly Fee';
    }

    void loadExisting() {
      final existingForClass =
      _categories.where(
            (category) {
          final name =
              category['name']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
                  '';

          return name ==
              categoryName(
                selectedClass,
              ).toLowerCase();
        },
      ).toList();

      if (existingForClass.isNotEmpty) {
        amountController.text =
            _toDouble(
              existingForClass.first[
              'amount'],
            ).toStringAsFixed(0);

        descriptionController.text =
            existingForClass.first[
            'description']
                ?.toString() ??
                '';
      } else {
        amountController.clear();
        descriptionController.clear();
      }
    }

    loadExisting();

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          bool saving = false;

          return StatefulBuilder(
            builder: (
                context,
                setDialogState,
                ) {
              return AlertDialog(
                title: const Text(
                  'Add Class Monthly Fee',
                ),
                content: SizedBox(
                  width: 450,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<
                            String>(
                          initialValue:
                          selectedClass,
                          isExpanded: true,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Class',
                            prefixIcon:
                            Icon(
                              Icons.school_outlined,
                            ),
                          ),
                          items:
                          classes.map(
                                (name) {
                              return DropdownMenuItem<
                                  String>(
                                value: name,
                                child:
                                Text(
                                  name,
                                ),
                              );
                            },
                          ).toList(),
                          onChanged:
                          saving
                              ? null
                              : (
                              value,
                              ) {
                            if (value ==
                                null) {
                              return;
                            }

                            setDialogState(
                                  () {
                                selectedClass =
                                    value;

                                loadExisting();
                              },
                            );
                          },
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                        Text(
                          categoryName(
                            selectedClass,
                          ),
                          style:
                          const TextStyle(
                            fontWeight:
                            FontWeight.w800,
                            color:
                            AppColors.primary,
                          ),
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                        TextField(
                          controller:
                          amountController,
                          keyboardType:
                          const TextInputType
                              .numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Monthly Fee',
                            prefixText:
                            'PKR ',
                            prefixIcon:
                            Icon(
                              Icons.payments_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                        TextField(
                          controller:
                          descriptionController,
                          maxLines: 2,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Description',
                            prefixIcon:
                            Icon(
                              Icons.description_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () =>
                        Navigator.of(
                          dialogContext,
                        ).pop(),
                    child:
                    const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                      final amount =
                      double.tryParse(
                        amountController
                            .text
                            .trim(),
                      );

                      if (amount ==
                          null ||
                          amount <= 0) {
                        _showMessage(
                          'Enter a valid monthly fee.',
                        );
                        return;
                      }

                      setDialogState(
                            () {
                          saving = true;
                        },
                      );

                      try {
                        final name =
                        categoryName(
                          selectedClass,
                        );

                        final existing =
                        _categories.where(
                              (category) {
                            final n =
                                category[
                                'name']
                                    ?.toString()
                                    .trim()
                                    .toLowerCase() ??
                                    '';

                            return n ==
                                name
                                    .toLowerCase();
                          },
                        ).toList();

                        if (existing
                            .isNotEmpty) {
                          await _client
                              .from(
                            'fee_categories',
                          )
                              .update({
                            'amount':
                            amount,
                            'description':
                            descriptionController
                                .text
                                .trim()
                                .isEmpty
                                ? null
                                : descriptionController
                                .text
                                .trim(),
                            'is_active':
                            true,
                          })
                              .eq(
                            'id',
                            existing.first[
                            'id'],
                          )
                              .eq(
                            'school_id',
                            _schoolId!,
                          );
                        } else {
                          await _client
                              .from(
                            'fee_categories',
                          )
                              .insert({
                            'school_id':
                            _schoolId,
                            'name':
                            name,
                            'amount':
                            amount,
                            'description':
                            descriptionController
                                .text
                                .trim()
                                .isEmpty
                                ? 'Monthly fee for $selectedClass'
                                : descriptionController
                                .text
                                .trim(),
                            'is_active':
                            true,
                          });
                        }

                        if (!dialogContext
                            .mounted) {
                          return;
                        }

                        Navigator.of(
                          dialogContext,
                        ).pop();

                        _showMessage(
                          existing.isNotEmpty
                              ? '$name updated successfully.'
                              : '$name created successfully.',
                          success:
                          true,
                        );

                        await _loadFinanceData();
                      } on PostgrestException catch (e) {
                        if (mounted) {
                          _showMessage(
                            '${e.message}\nCode: ${e.code ?? 'unknown'}',
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          _showMessage(
                            e.toString()
                                .replaceFirst(
                              'Exception: ',
                              '',
                            ),
                          );
                        }
                      } finally {
                        if (dialogContext
                            .mounted) {
                          setDialogState(
                                () {
                              saving = false;
                            },
                          );
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.save_outlined,
                    ),
                    label: const Text(
                      'Save Class Fee',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      amountController.dispose();
      descriptionController.dispose();
    }
  }

  // ============================================================
  // ASSIGN FEE
  // ============================================================

  Future<void> _openAssignFee({
    Map<String, dynamic>?
    selectedStudent,
  }) async {
    if (_schoolId == null) return;

    if (_students.isEmpty) {
      _showMessage(
        'No students found.',
      );
      return;
    }

    if (_categories.isEmpty) {
      _showMessage(
        'Please create a Fee Category first.',
      );
      return;
    }

    Map<String, dynamic>? student =
        selectedStudent;

    Map<String, dynamic>? category;

    final amountController =
    TextEditingController();

    DateTime dueDate =
    DateTime.now().add(
      const Duration(
        days: 30,
      ),
    );

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (
                context,
                setDialogState,
                ) {
              return AlertDialog(
                title: const Text(
                  'Assign Fee',
                ),
                content: SizedBox(
                  width: 480,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<
                            Map<String, dynamic>>(
                          initialValue: student,
                          isExpanded: true,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Student',
                            prefixIcon:
                            Icon(
                              Icons.person_outline,
                            ),
                          ),
                          items: _students.map(
                                (item) {
                              return DropdownMenuItem<
                                  Map<String, dynamic>>(
                                value: item,
                                child:
                                Text(
                                  '${item['full_name']} • '
                                      '${item['class_name'] ?? '-'}'
                                      '-${item['section_name'] ?? '-'}',
                                  overflow:
                                  TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ).toList(),
                          onChanged:
                              (value) {
                            setDialogState(
                                  () {
                                student =
                                    value;
                              },
                            );
                          },
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                        DropdownButtonFormField<
                            Map<String, dynamic>>(
                          initialValue: category,
                          isExpanded: true,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Fee Category',
                            prefixIcon:
                            Icon(
                              Icons.category_outlined,
                            ),
                          ),
                          items:
                          _categories.map(
                                (item) {
                              return DropdownMenuItem<
                                  Map<String, dynamic>>(
                                value: item,
                                child:
                                Text(
                                  '${item['name']} • '
                                      '${_money(_toDouble(item['amount']))}',
                                  overflow:
                                  TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ).toList(),
                          onChanged:
                              (value) {
                            setDialogState(
                                  () {
                                category =
                                    value;

                                if (value !=
                                    null) {
                                  amountController
                                      .text =
                                      _toDouble(
                                        value[
                                        'amount'],
                                      ).toStringAsFixed(
                                        0,
                                      );
                                }
                              },
                            );
                          },
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                        TextField(
                          controller:
                          amountController,
                          keyboardType:
                          const TextInputType
                              .numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Amount',
                            prefixText:
                            'PKR ',
                            prefixIcon:
                            Icon(
                              Icons.payments_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                        ListTile(
                          contentPadding:
                          EdgeInsets.zero,
                          leading:
                          const Icon(
                            Icons.calendar_today_outlined,
                          ),
                          title:
                          const Text(
                            'Due Date',
                          ),
                          subtitle:
                          Text(
                            _dateOnly(
                              dueDate,
                            ),
                          ),
                          onTap: () async {
                            final selected =
                            await showDatePicker(
                              context:
                              dialogContext,
                              initialDate:
                              dueDate,
                              firstDate:
                              DateTime(
                                2020,
                              ),
                              lastDate:
                              DateTime(
                                2100,
                              ),
                            );

                            if (selected !=
                                null) {
                              setDialogState(
                                    () {
                                  dueDate =
                                      selected;
                                },
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () =>
                        Navigator.of(
                          dialogContext,
                        ).pop(),
                    child:
                    const Text(
                      'Cancel',
                    ),
                  ),
                  FilledButton(
                    onPressed: _saving
                        ? null
                        : () async {
                      final amount =
                      double.tryParse(
                        amountController
                            .text
                            .trim(),
                      );

                      if (student ==
                          null) {
                        _showMessage(
                          'Please select a student.',
                        );
                        return;
                      }

                      if (category ==
                          null) {
                        _showMessage(
                          'Please select a fee category.',
                        );
                        return;
                      }

                      if (amount ==
                          null ||
                          amount <= 0) {
                        _showMessage(
                          'Please enter a valid amount.',
                        );
                        return;
                      }

                      Navigator.of(
                        dialogContext,
                      ).pop();

                      await _saveAssignedFee(
                        studentId:
                        student![
                        'id'],
                        categoryId:
                        category![
                        'id'],
                        amount:
                        amount,
                        dueDate:
                        dueDate,
                      );
                    },
                    child:
                    const Text(
                      'Assign Fee',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      amountController.dispose();
    }
  }

  // ============================================================
  // SAVE ASSIGNED FEE
  // ============================================================

  Future<void> _saveAssignedFee({
    required dynamic studentId,
    required dynamic categoryId,
    required double amount,
    required DateTime dueDate,
  }) async {
    if (_schoolId == null) return;

    if (!mounted) return;

    setState(() {
      _saving = true;
    });

    try {
      await _client
          .from('student_fees')
          .insert({
        'school_id': _schoolId,
        'student_id': studentId,
        'fee_category_id': categoryId,
        'amount': amount,
        'due_date': _dateOnly(dueDate),
        'status': 'pending',
      });

      _showMessage(
        'Fee assigned successfully.',
        success: true,
      );

      await _loadFinanceData();
    } on PostgrestException catch (e) {
      if (mounted) {
        _showMessage(
          '${e.message}\nCode: ${e.code ?? 'unknown'}',
        );
      }
    } catch (e) {
      if (mounted) {
        _showMessage(
          e.toString().replaceFirst(
            'Exception: ',
            '',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // MONTHLY FEE GENERATION
  // ============================================================

  Future<void> _openMonthlyFeeGeneration() async {
    if (_schoolId == null) return;

    final classNames = <String>{};

    for (final student in _students) {
      final value =
          student['class_name']
              ?.toString()
              .trim() ??
              '';

      if (value.isNotEmpty) {
        classNames.add(value);
      }
    }

    final classes =
    classNames.toList()..sort();

    if (classes.isEmpty) {
      _showMessage(
        'No classes found. Add students first.',
      );
      return;
    }

    String? selectedClass;

    DateTime selectedMonth =
    DateTime.now();

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          bool generating = false;

          return StatefulBuilder(
            builder: (
                context,
                setDialogState,
                ) {
              return AlertDialog(
                title: const Text(
                  'Generate Monthly Fee',
                ),
                content: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<
                            String?>(
                          initialValue:
                          selectedClass,
                          isExpanded: true,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Class',
                            prefixIcon:
                            Icon(
                              Icons.school_outlined,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<
                                String?>(
                              value: null,
                              child:
                              Text(
                                'All Classes',
                              ),
                            ),
                            ...classes.map(
                                  (name) =>
                                  DropdownMenuItem<
                                      String?>(
                                    value:
                                    name,
                                    child:
                                    Text(
                                      name,
                                    ),
                                  ),
                            ),
                          ],
                          onChanged:
                          generating
                              ? null
                              : (
                              value,
                              ) {
                            setDialogState(
                                  () {
                                selectedClass =
                                    value;
                              },
                            );
                          },
                        ),
                        const SizedBox(
                          height: 14,
                        ),
                        if (selectedClass !=
                            null)
                          Builder(
                            builder:
                                (context) {
                              final expected =
                                  '${selectedClass!} Monthly Fee';

                              final category =
                              _categories
                                  .where(
                                    (c) {
                                  return (c[
                                  'name']
                                      ?.toString()
                                      .trim()
                                      .toLowerCase() ??
                                      '') ==
                                      expected
                                          .toLowerCase();
                                },
                              ).toList();

                              return Container(
                                width:
                                double.infinity,
                                padding:
                                const EdgeInsets.all(
                                  12,
                                ),
                                decoration:
                                BoxDecoration(
                                  color: category
                                      .isEmpty
                                      ? AppColors
                                      .warning
                                      .withValues(
                                    alpha: .08,
                                  )
                                      : AppColors
                                      .primary
                                      .withValues(
                                    alpha: .06,
                                  ),
                                  borderRadius:
                                  BorderRadius.circular(
                                    12,
                                  ),
                                ),
                                child:
                                Row(
                                  children: [
                                    Icon(
                                      category
                                          .isEmpty
                                          ? Icons
                                          .warning_amber_rounded
                                          : Icons
                                          .category_outlined,
                                      color: category
                                          .isEmpty
                                          ? AppColors
                                          .warning
                                          : AppColors
                                          .primary,
                                    ),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    Expanded(
                                      child:
                                      Text(
                                        category
                                            .isEmpty
                                            ? 'No category found for $selectedClass. Create "$expected" first.'
                                            : '$expected • ${_money(_toDouble(category.first['amount']))}',
                                        style:
                                        const TextStyle(
                                          fontSize:
                                          12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        else
                          const Text(
                            'All Classes: each class will use its own Monthly Fee category.',
                            style:
                            TextStyle(
                              fontSize: 11,
                              color: AppColors
                                  .textSecondary,
                            ),
                          ),
                        const SizedBox(
                          height: 14,
                        ),
                        ListTile(
                          contentPadding:
                          EdgeInsets.zero,
                          leading:
                          const Icon(
                            Icons
                                .calendar_month_outlined,
                          ),
                          title:
                          const Text(
                            'Fee Month',
                          ),
                          subtitle:
                          Text(
                            '${selectedMonth.year}-'
                                '${selectedMonth.month.toString().padLeft(2, '0')}',
                          ),
                          onTap:
                          generating
                              ? null
                              : () async {
                            final picked =
                            await showDatePicker(
                              context:
                              dialogContext,
                              initialDate:
                              selectedMonth,
                              firstDate:
                              DateTime(
                                2020,
                              ),
                              lastDate:
                              DateTime(
                                2100,
                              ),
                            );

                            if (picked !=
                                null) {
                              setDialogState(
                                    () {
                                  selectedMonth =
                                      DateTime(
                                        picked.year,
                                        picked.month,
                                        1,
                                      );
                                },
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                    generating
                        ? null
                        : () =>
                        Navigator.of(
                          dialogContext,
                        ).pop(),
                    child:
                    const Text(
                      'Cancel',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed:
                    generating
                        ? null
                        : () async {
                      setDialogState(
                            () {
                          generating =
                          true;
                        },
                      );

                      try {
                        final targetClassNames =
                        selectedClass ==
                            null
                            ? classes
                            : [
                          selectedClass!
                        ];

                        final start =
                        DateTime(
                          selectedMonth
                              .year,
                          selectedMonth
                              .month,
                          1,
                        );

                        final end =
                        DateTime(
                          selectedMonth
                              .month ==
                              12
                              ? selectedMonth
                              .year +
                              1
                              : selectedMonth
                              .year,
                          selectedMonth
                              .month ==
                              12
                              ? 1
                              : selectedMonth
                              .month +
                              1,
                          1,
                        );

                        int generated =
                        0;

                        int skipped =
                        0;

                        final missingCategories =
                        <String>[];

                        for (final className
                        in targetClassNames) {
                          final expectedName =
                              '$className Monthly Fee';

                          final matchingCategories =
                          _categories.where(
                                (category) {
                              final name =
                                  category[
                                  'name']
                                      ?.toString()
                                      .trim()
                                      .toLowerCase() ??
                                      '';

                              return name ==
                                  expectedName
                                      .toLowerCase();
                            },
                          ).toList();

                          if (matchingCategories
                              .isEmpty) {
                            missingCategories
                                .add(
                              expectedName,
                            );
                            continue;
                          }

                          final category =
                              matchingCategories
                                  .first;

                          final categoryId =
                          category[
                          'id'];

                          final amount =
                          _toDouble(
                            category[
                            'amount'],
                          );

                          if (amount <=
                              0) {
                            continue;
                          }

                          final targetStudents =
                          _students.where(
                                (student) {
                              if (student[
                              'is_active'] !=
                                  true) {
                                return false;
                              }

                              return (student[
                              'class_name']
                                  ?.toString()
                                  .trim() ??
                                  '') ==
                                  className;
                            },
                          ).toList();

                          if (targetStudents
                              .isEmpty) {
                            continue;
                          }

                          final existing =
                          await _client
                              .from(
                            'student_fees',
                          )
                              .select(
                            'student_id',
                          )
                              .eq(
                            'school_id',
                            _schoolId!,
                          )
                              .eq(
                            'fee_category_id',
                            categoryId,
                          )
                              .gte(
                            'due_date',
                            _dateOnly(
                              start,
                            ),
                          )
                              .lt(
                            'due_date',
                            _dateOnly(
                              end,
                            ),
                          );

                          final existingIds =
                          <String>{};

                          for (final row
                          in existing) {
                            existingIds.add(
                              row['student_id']
                                  .toString(),
                            );
                          }

                          final rows =
                          <Map<String,
                              dynamic>>[];

                          for (final student
                          in targetStudents) {
                            if (existingIds
                                .contains(
                              student['id']
                                  .toString(),
                            )) {
                              skipped++;
                              continue;
                            }

                            rows.add({
                              'school_id':
                              _schoolId,
                              'student_id':
                              student[
                              'id'],
                              'fee_category_id':
                              categoryId,
                              'amount':
                              amount,
                              'due_date':
                              _dateOnly(
                                start,
                              ),
                              'status':
                              'pending',
                            });
                          }

                          if (rows
                              .isNotEmpty) {
                            await _client
                                .from(
                              'student_fees',
                            )
                                .insert(
                              rows,
                            );

                            generated +=
                                rows.length;
                          }
                        }

                        if (dialogContext
                            .mounted) {
                          Navigator.of(
                            dialogContext,
                          ).pop();
                        }

                        var message =
                            'Generated $generated monthly fees. '
                            '$skipped already existed.';

                        if (missingCategories
                            .isNotEmpty) {
                          message +=
                          '\nMissing categories: '
                              '${missingCategories.join(', ')}';
                        }

                        _showMessage(
                          message,
                          success:
                          missingCategories
                              .isEmpty,
                        );

                        await _loadFinanceData();
                      } on PostgrestException catch (e) {
                        if (mounted) {
                          _showMessage(
                            '${e.message}\nCode: ${e.code ?? 'unknown'}',
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          _showMessage(
                            e.toString()
                                .replaceFirst(
                              'Exception: ',
                              '',
                            ),
                          );
                        }
                      } finally {
                        if (dialogContext
                            .mounted) {
                          setDialogState(
                                () {
                              generating =
                              false;
                            },
                          );
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.auto_awesome,
                    ),
                    label: const Text(
                      'Generate',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {}
  }

  // ============================================================
  // CATEGORY CARD
  // ============================================================

  Widget _buildCategoryCard() {
    return Card(
      child: Padding(
        padding:
        EdgeInsets.all(
          _isMobile ? 14 : 20,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // RESPONSIVE HEADER
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration:
                  BoxDecoration(
                    color: AppColors.primary
                        .withValues(alpha: .10),
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: const Icon(
                    Icons.category_rounded,
                    color:
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fee Categories',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Create, view, edit and manage fee amounts.',
                        style: TextStyle(
                          color: AppColors
                              .textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // BUTTONS
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed:
                  _openAddClassMonthlyCategory,
                  icon: const Icon(
                    Icons.school_outlined,
                    size: 18,
                  ),
                  label: const Text(
                    'Class Monthly Fee',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed:
                  _openAddCategory,
                  icon: const Icon(
                    Icons.add,
                    size: 18,
                  ),
                  label: const Text(
                    'Add Category',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed:
                  _openMonthlyFeeGeneration,
                  icon: const Icon(
                    Icons.auto_awesome,
                    size: 18,
                  ),
                  label: const Text(
                    'Generate Monthly Fee',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            if (_categories.isEmpty)
              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(20),
                decoration:
                BoxDecoration(
                  color:
                  AppColors.background,
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                ),
                child: const Text(
                  'No fee categories found. Add Admission Fee or Monthly Fee first.',
                  textAlign:
                  TextAlign.center,
                  style: TextStyle(
                    color:
                    AppColors.textSecondary,
                  ),
                ),
              )
            else
              Column(
                children:
                _categories.map(
                      (category) {
                    final amount =
                    _toDouble(
                      category['amount'],
                    );

                    final name =
                        category['name']
                            ?.toString() ??
                            'Fee';

                    final description =
                        category['description']
                            ?.toString() ??
                            '';

                    return Container(
                      margin:
                      const EdgeInsets.only(
                        bottom: 10,
                      ),
                      decoration:
                      BoxDecoration(
                        border: Border.all(
                          color:
                          AppColors.border,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: Padding(
                        padding:
                        const EdgeInsets.all(
                          10,
                        ),
                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration:
                              BoxDecoration(
                                color: AppColors
                                    .primary
                                    .withValues(
                                  alpha: .10,
                                ),
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  12,
                                ),
                              ),
                              child:
                              const Icon(
                                Icons
                                    .payments_outlined,
                                color:
                                AppColors
                                    .primary,
                              ),
                            ),

                            const SizedBox(
                              width: 10,
                            ),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  Text(
                                    name,
                                    overflow:
                                    TextOverflow
                                        .ellipsis,
                                    style:
                                    const TextStyle(
                                      fontWeight:
                                      FontWeight
                                          .w800,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 4,
                                  ),
                                  Text(
                                    description.isEmpty
                                        ? 'Selected amount: ${_money(amount)}'
                                        : '$description • ${_money(amount)}',
                                    maxLines: 2,
                                    overflow:
                                    TextOverflow
                                        .ellipsis,
                                    style:
                                    const TextStyle(
                                      fontSize: 11,
                                      color: AppColors
                                          .textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(
                              width: 6,
                            ),

                            if (_isMobile)
                              PopupMenuButton<
                                  String>(
                                onSelected:
                                    (value) {
                                  if (value ==
                                      'edit') {
                                    _openEditCategory(
                                      category,
                                    );
                                  }

                                  if (value ==
                                      'delete') {
                                    _deleteCategory(
                                      category,
                                    );
                                  }
                                },
                                itemBuilder:
                                    (context) {
                                  return const [
                                    PopupMenuItem(
                                      value:
                                      'edit',
                                      child:
                                      Text(
                                        'Edit',
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value:
                                      'delete',
                                      child:
                                      Text(
                                        'Delete',
                                      ),
                                    ),
                                  ];
                                },
                              )
                            else
                              Row(
                                mainAxisSize:
                                MainAxisSize
                                    .min,
                                children: [
                                  Text(
                                    _money(
                                      amount,
                                    ),
                                    style:
                                    const TextStyle(
                                      fontWeight:
                                      FontWeight
                                          .w900,
                                      color: AppColors
                                          .primary,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 8,
                                  ),
                                  IconButton(
                                    tooltip:
                                    'Edit Category',
                                    onPressed:
                                    _saving
                                        ? null
                                        : () =>
                                        _openEditCategory(
                                          category,
                                        ),
                                    icon:
                                    const Icon(
                                      Icons
                                          .edit_outlined,
                                      size: 20,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip:
                                    'Delete Category',
                                    onPressed:
                                    _saving
                                        ? null
                                        : () =>
                                        _deleteCategory(
                                          category,
                                        ),
                                    icon:
                                    const Icon(
                                      Icons
                                          .delete_outline,
                                      size: 20,
                                      color:
                                      AppColors
                                          .error,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TRANSACTIONS HEADER
  // ============================================================

  Widget _buildTransactionsHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Recent Payments',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
              FontWeight.w800,
            ),
          ),
        ),
        TextButton(
          onPressed:
          _loadFinanceData,
          child:
          const Text('Refresh'),
        ),
      ],
    );
  }

  // ============================================================
  // TRANSACTIONS
  // ============================================================

  Widget _buildTransactions() {
    if (_recentPayments.isEmpty) {
      return _emptyCard(
        'No payments yet.',
      );
    }

    return Column(
      children:
      _recentPayments.map(
            (payment) {
          final student =
          payment['_student']
          as Map<String, dynamic>?;

          final studentName =
              student?['full_name']
                  ?.toString() ??
                  'Student';

          final className =
              student?['class_name']
                  ?.toString() ??
                  '-';

          final section =
              student?['section_name']
                  ?.toString() ??
                  '-';

          final category =
          _categoryById(
            payment[
            'fee_category_id'],
          );

          final categoryName =
              category?['name']
                  ?.toString() ??
                  'Fee';

          final amount =
          _toDouble(
            payment['amount'],
          );

          final status =
              payment['status']
                  ?.toString()
                  .toLowerCase() ??
                  'paid';

          final paid =
          _isPaidStatus(status);

          final color = paid
              ? AppColors.success
              : status == 'overdue'
              ? AppColors.error
              : AppColors.warning;

          return Padding(
            padding:
            const EdgeInsets.only(
              bottom: 12,
            ),
            child: Card(
              child: Padding(
                padding:
                EdgeInsets.all(
                  _isMobile ? 12 : 8,
                ),
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor:
                      color.withValues(alpha: .10),
                      child: Icon(
                        Icons
                            .receipt_long_rounded,
                        color: color,
                        size: 20,
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
                            studentName,
                            overflow:
                            TextOverflow.ellipsis,
                            style:
                            const TextStyle(
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            'Class $className-$section',
                            overflow:
                            TextOverflow.ellipsis,
                            style:
                            const TextStyle(
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '$categoryName • '
                                '${payment['payment_date'] ?? '-'}',
                            overflow:
                            TextOverflow.ellipsis,
                            style:
                            const TextStyle(
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.end,
                      children: [
                        Text(
                          _money(amount),
                          style:
                          const TextStyle(
                            fontWeight:
                            FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          status.toUpperCase(),
                          style:
                          TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight:
                            FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ).toList(),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _emptyCard(String text) {
    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(30),
        child: Center(
          child: Text(
            text,
            textAlign:
            TextAlign.center,
            style: const TextStyle(
              color:
              AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return Column(
      children:
      List.generate(
        6,
            (index) {
          return Container(
            height: 100,
            margin:
            const EdgeInsets.only(
              bottom: 14,
            ),
            decoration:
            BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(
                20,
              ),
              border: Border.all(
                color:
                AppColors.border,
              ),
            ),
            child:
            const Center(
              child:
              CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Padding(
      padding:
      const EdgeInsets.all(30),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 50,
          ),
          const SizedBox(height: 14),
          Text(
            _error ??
                'Unable to load finance data.',
            textAlign:
            TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed:
            _loadFinanceData,
            child:
            const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message, {
        bool success = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 4,
          overflow:
          TextOverflow.ellipsis,
        ),
        backgroundColor:
        success
            ? AppColors.success
            : null,
      ),
    );
  }
}