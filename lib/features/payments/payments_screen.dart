import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/calculations.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  DateTime _month = monthOf(DateTime.now());
  bool _showDues = true;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(monthSummaryProvider(_month));
    final tenants = ref.watch(tenantsProvider.notifier);
    ref.watch(tenantsProvider);
    final rooms = ref.read(roomsProvider.notifier);
    final payments = ref
        .watch(paymentsProvider)
        .where((p) => sameMonth(p.month, _month))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      floatingActionButton: AddButton(
        label: 'Record Payment',
        onPressed: () => context.push('/payments/new'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MonthSwitcher(
                    month: _month,
                    onChanged: (m) => setState(() => _month = m)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.check_circle_rounded,
                      label: 'Rent collected',
                      value: money(s.rentCollected),
                      caption: '${(s.collectionRate * 100).round()}% of ${money(s.rentExpected)}',
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      icon: Icons.pending_actions_rounded,
                      label: 'Pending rent',
                      value: money(s.pendingRent),
                      caption: '${s.unpaid.length} tenants',
                      color: AppColors.warning,
                    ),
                  ),
                ]),
                if (s.otherIncome > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                      '+ ${money(s.otherIncome)} other income (electricity, deposits, etc.)',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                        value: true,
                        label: Text('Rent status (${s.dues.length})'),
                        icon: const Icon(Icons.fact_check_outlined)),
                    ButtonSegment(
                        value: false,
                        label: Text('Payments (${payments.length})'),
                        icon: const Icon(Icons.receipt_long_outlined)),
                  ],
                  selected: {_showDues},
                  onSelectionChanged: (v) =>
                      setState(() => _showDues = v.first),
                ),
                const SizedBox(height: 12),
                if (_showDues) ...[
                  if (s.dues.isEmpty)
                    const EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'No tenants this month',
                      message: 'Rent status appears here once you add tenants.',
                    ),
                  for (final d in s.dues) ...[
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        onTap: () => context.push('/tenants/${d.tenant.id}'),
                        leading: CircleAvatar(child: Text(initials(d.tenant.name))),
                        title: Text(d.tenant.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${rooms.byId(d.tenant.roomId) == null ? 'No room' : 'Room ${rooms.byId(d.tenant.roomId)!.number}'}'
                          ' · Paid ${money(d.paid)} of ${money(d.tenant.rent)}',
                          maxLines: 2,
                        ),
                        trailing: d.isPaid
                            ? const StatusChip('Paid', color: AppColors.success)
                            : FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 36),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14)),
                                onPressed: () => context.push(
                                    '/payments/new?tenant=${d.tenant.id}'),
                                child: const Text('Collect'),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ] else ...[
                  if (payments.isEmpty)
                    EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'No payments in ${fmtMonth(_month)}',
                      message: 'Tap "Record Payment" when a tenant pays.',
                    ),
                  for (final p in payments) ...[
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        onTap: () => context.push('/payments/${p.id}'),
                        leading: const IconBadge(
                            icon: Icons.south_west_rounded,
                            color: AppColors.success),
                        title: Text(
                            tenants.byId(p.tenantId)?.name ?? 'Deleted tenant',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                            '${p.type.label} · ${fmtDate(p.date)} · ${p.mode}'),
                        trailing: Text(money(p.amount),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.success)),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
