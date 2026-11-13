import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';
import 'payment_detail_screen.dart';

const _red = Color(0xFFDC2626);

/// Log of every deleted payment (read-only).
class DeletedPaymentsScreen extends ConsumerWidget {
  const DeletedPaymentsScreen({super.key});

  void _show(BuildContext context, DeletedPayment d) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: PaymentCard(
            payment: d.payment,
            tenantName: d.tenantName.isEmpty ? 'Unknown' : d.tenantName,
            color: _red,
            extra: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Deleted on'),
                trailing: Text(fmtDate(d.deletedAt),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              if (d.reason.isNotEmpty)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Reason'),
                  subtitle: Text(d.reason),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = [...ref.watch(deletedPaymentsProvider)]
      ..sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    final total = list.fold<double>(0, (s, d) => s + d.payment.amount);

    return Scaffold(
      appBar: AppBar(title: const Text('Deleted Payments')),
      body: list.isEmpty
          ? const Center(
              child: EmptyState(
                icon: Icons.history_rounded,
                title: 'No deleted payments',
                message: 'When a payment is deleted, it is kept here as a log.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                PageBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          '${list.length} deleted · ${money(total)} in total. '
                          'These are not counted in dues or reports.',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Card(
                        child: Column(children: [
                          for (final d in list)
                            ListTile(
                              onTap: () => _show(context, d),
                              leading: const CircleAvatar(
                                backgroundColor: Color(0x1FDC2626),
                                child: Icon(Icons.delete_outline_rounded,
                                    color: _red),
                              ),
                              title: Text(
                                  '${d.tenantName.isEmpty ? 'Unknown' : d.tenantName} · ${d.payment.type.label}'),
                              subtitle: Text(
                                  '${fmtMonthShort(d.payment.month)} · deleted ${fmtDate(d.deletedAt)}'
                                  '${d.reason.isEmpty ? '' : '\n${d.reason}'}'),
                              isThreeLine: d.reason.isNotEmpty,
                              trailing: Text(money(d.payment.amount),
                                  style: const TextStyle(
                                      color: _red,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.lineThrough)),
                            ),
                        ]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
