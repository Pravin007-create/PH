import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';

const _red = Color(0xFFDC2626);

/// A saved payment. Payments can't be edited — only deleted, and a deleted
/// payment is kept in the "Deleted payments" log.
class PaymentDetailScreen extends ConsumerWidget {
  const PaymentDetailScreen({super.key, required this.paymentId});
  final String paymentId;

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Payment p, String tenantName) async {
    // null = cancelled, otherwise the (possibly empty) reason.
    final why = await showDialog<String>(
      context: context,
      builder: (_) => _DeleteDialog(
          message: '${money(p.amount)} from $tenantName will be removed from '
              'dues and reports. It stays visible in "Deleted payments".'),
    );
    if (why == null || !context.mounted) return;
    ref.read(deletedPaymentsProvider.notifier).save(DeletedPayment(
          payment: p,
          deletedAt: DateTime.now(),
          tenantName: tenantName,
          reason: why,
        ));
    ref.read(paymentsProvider.notifier).remove(p.id);
    showSaved(context, 'Payment deleted · kept in Deleted payments');
    context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(paymentsProvider);
    final p = ref.read(paymentsProvider.notifier).byId(paymentId);
    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment')),
        body: const Center(child: Text('This payment no longer exists.')),
      );
    }
    final tenant = ref.read(tenantsProvider.notifier).byId(p.tenantId);
    final room = ref.read(roomsProvider.notifier).byId(tenant?.roomId);
    final tenantName = tenant?.name ?? 'Deleted tenant';

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Details')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: PageBody(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _red,
                side: const BorderSide(color: _red),
              ),
              onPressed: () => _delete(context, ref, p, tenantName),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete Payment'),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PaymentCard(
                    payment: p,
                    tenantName: tenantName,
                    roomNumber: room?.number,
                    onTenantTap: tenant == null
                        ? null
                        : () => context.push('/tenants/${tenant.id}')),
                const SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Saved payments can\'t be edited. If something is wrong, '
                      'delete it and record it again.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Amount header + detail rows, shared by payment and deleted-payment views.
class PaymentCard extends StatelessWidget {
  const PaymentCard({
    super.key,
    required this.payment,
    required this.tenantName,
    this.roomNumber,
    this.onTenantTap,
    this.extra = const [],
    this.color = AppColors.success,
  });

  final Payment payment;
  final String tenantName;
  final String? roomNumber;
  final VoidCallback? onTenantTap;
  final List<Widget> extra;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    Widget row(IconData icon, String label, String value) => ListTile(
          dense: true,
          leading: Icon(icon),
          title: Text(label),
          trailing: Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        );
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Column(children: [
              Text(money(p.amount),
                  style: TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 4),
              Text('${p.type.label} · ${fmtMonth(p.month)}',
                  style: Theme.of(context).textTheme.titleSmall),
            ]),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.person_outline_rounded),
            title: const Text('Tenant'),
            trailing: Text(
                roomNumber == null
                    ? tenantName
                    : '$tenantName · Room $roomNumber',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            onTap: onTenantTap,
          ),
          row(Icons.calendar_today_rounded, 'Date received', fmtDate(p.date)),
          row(Icons.account_balance_wallet_outlined, 'Paid by', p.mode),
          if (p.note.isNotEmpty) row(Icons.notes_rounded, 'Note', p.note),
          ...extra,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.message});
  final String message;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Delete this payment?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Wrong amount entered',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(context, _reason.text.trim()),
            child: const Text('Delete'),
          ),
        ],
      );
}
