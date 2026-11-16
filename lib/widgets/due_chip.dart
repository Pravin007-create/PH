import 'package:flutter/material.dart';

import '../core/format.dart';
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
      StatusChip(dueLabel(context, due), color: dueColor(due.status));
}

/// Translated "Overdue 8 days" / "Due by 5 Nov" / "From 31 Oct" / "Paid".
String dueLabel(BuildContext context, TenantDue d) {
  String short(DateTime x) => fmtDate(x).replaceAll(RegExp(r' \d{4}$'), '');
  return switch (d.status) {
    DueStatus.paid => context.tr('Paid'),
    DueStatus.overdue => d.daysOverdue == 1
        ? context.tr('Overdue 1 day')
        : context.tr('Overdue {n} days', {'n': d.daysOverdue}),
    DueStatus.due => d.daysLeft == 0
        ? context.tr('Due today')
        : context.tr('Due by {d}', {'d': short(d.dueDate)}),
    DueStatus.upcoming => context.tr('From {d}', {'d': short(d.collectFrom)}),
  };
}

/// Red "Document proof not submitted" badge for tenants without ID proof.
class DocsPendingChip extends StatelessWidget {
  const DocsPendingChip({super.key, this.short = false});
  final bool short;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text.rich(
        TextSpan(children: [
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.gpp_maybe_rounded, size: 14, color: red),
            ),
          ),
          TextSpan(
              text: context.tr(short
                  ? 'ID proof not submitted'
                  : 'Document proof not submitted')),
        ]),
        style: const TextStyle(
            color: red, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
