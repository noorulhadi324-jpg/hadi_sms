import 'package:flutter/material.dart';

import '../../../finance/presentation/screens/finance_screen.dart';

/// Accounting and Finance use the same live ledger data in HADI SMS.
/// Keeping this route as a thin alias avoids showing a second, fake dashboard.
class AccountingScreen extends StatelessWidget {
  const AccountingScreen({super.key});

  @override
  Widget build(BuildContext context) => const FinanceScreen();
}
