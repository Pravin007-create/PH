import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/calculations.dart';
import 'common.dart';

Color dueColor(DueStatus s) => switch (s) {
      DueStatus.paid => AppColors.success,
      DueStatus.due => AppColors.warning,
      DueStatus.upcoming => Colors.blueGrey,
      DueStatus.overdue => const Color(0xFFDC2626),
    };

/// "Overdue 8 days" (red) · "Due by 5 Nov" (amber) · "Paid" (green).
class DueChip extends StatelessWidget {
  const DueChip(this.due, {super.key});
  final TenantDue due;

  @override
  Widget build(BuildContext context) =>
      StatusChip(due.label, color: dueColor(due.status));
}
