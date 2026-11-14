import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/calculations.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';
import '../../widgets/due_chip.dart';

enum _Tab { rent, electricity, payments }

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  // Starts on the rent month being collected now.
  late DateTime _month = ref.read(currentRentMonthProvider);
  _Tab _tab = _Tab.rent;

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
      appBar: AppBar(title: const Text('Payments'), actions: [
        IconButton(
          tooltip: 'Deleted payments',
          icon: const Icon(Icons.history_rounded),
          onPressed: () => context.push('/payments/deleted'),
        ),
      ]),
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
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.event_available_rounded, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Collect from ${fmtDate(s.collectFrom)} · due by ${fmtDate(s.dueDate)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ]),
                if (s.overdue.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.white),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${s.overdue.length} overdue · ${money(s.overdueAmount)} not paid after ${fmtDate(s.dueDate)}',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: StatCard(
                      icon: Icons.check_circle_rounded,
                      label: 'Rent collected',
                      value: money(s.rentCollected),
                      caption:
                          '${(s.collectionRate * 100).round()}% of ${money(s.rentExpected)}',
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
                SegmentedButton<_Tab>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    padding: WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 4)),
                  ),
                  segments: const [
                    ButtonSegment(
                        value: _Tab.rent,
                        tooltip: 'Rent status',
                        label: Text('Rent'),
                        icon: Icon(Icons.fact_check_outlined, size: 18)),
                    ButtonSegment(
                        value: _Tab.electricity,
                        tooltip: 'Electricity bills',
                        label: Text('Electricity'),
                        icon: Icon(Icons.bolt_rounded, size: 18)),
                    ButtonSegment(
                        value: _Tab.payments,
                        tooltip: 'Payments received',
                        label: Text('Payments'),
                        icon: Icon(Icons.receipt_long_outlined, size: 18)),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (v) => setState(() => _tab = v.first),
                ),
                const SizedBox(height: 12),
                if (_tab == _Tab.electricity)
                  _ElectricityTab(month: _month)
                else if (_tab == _Tab.rent) ...[
                  if (s.dues.isEmpty)
                    const EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'No tenants this month',
                      message: 'Rent status appears here once you add tenants.',
                    ),
                  for (final d in s.dues) ...[
                    Card(
                      color: d.isOverdue
                          ? const Color(0xFFDC2626).withValues(alpha: 0.06)
                          : null,
                      shape: d.isOverdue
                          ? RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFDC2626)))
                          : null,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        onTap: () => context.push('/tenants/${d.tenant.id}'),
                        leading:
                            CircleAvatar(child: Text(initials(d.tenant.name))),
                        title: Text(d.tenant.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        isThreeLine: true,
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${rooms.byId(d.tenant.roomId) == null ? 'No room' : 'Room ${rooms.byId(d.tenant.roomId)!.number}'}'
                              ' · Paid ${money(d.paid)} of ${money(d.tenant.rent)}',
                              maxLines: 2,
                            ),
                            const SizedBox(height: 4),
                            DueChip(d),
                          ],
                        ),
                        trailing: d.isPaid
                            ? null
                            : FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 36),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14)),
                                onPressed: () => context.push(
                                    '/payments/new?tenant=${d.tenant.id}&month=${_month.toIso8601String()}'),
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

/// Electricity bills for the month: each tenant's share, paid or pending.
class _ElectricityTab extends ConsumerWidget {
  const _ElectricityTab({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const red = Color(0xFFDC2626);
    final rooms = ref.watch(roomsProvider);
    final bills = ref.watch(electricityBillsProvider);
    final shares = electricityShares(
        bills, ref.watch(tenantsProvider), ref.watch(paymentsProvider));
    final thisMonth = shares.where((d) => sameMonth(d.month, month)).toList();
    final older = shares
        .where((d) => !d.isPaid && d.month.isBefore(month))
        .toList();
    final billed = bills
        .where((b) => sameMonth(b.month, month))
        .fold<double>(0, (a, b) => a + b.amount);
    final collected = thisMonth.fold<double>(0, (a, d) => a + d.paid);
    final pending = thisMonth.fold<double>(0, (a, d) => a + d.due);
    String roomNo(String id) =>
        rooms.where((r) => r.id == id).firstOrNull?.number ?? '-';

    Widget shareTile(ElectricityDue d, {bool showMonth = false}) => ListTile(
          onTap: () => context.push('/tenants/${d.tenant.id}'),
          leading: CircleAvatar(child: Text(initials(d.tenant.name))),
          title: Text(d.tenant.name,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              'Room ${roomNo(d.bill.roomId)}${showMonth ? ' · ${fmtMonthShort(d.month)}' : ''}'
              ' · share ${money(d.share)}'),
          trailing: d.isPaid
              ? const StatusChip('Paid', color: AppColors.success)
              : FilledButton.tonal(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12)),
                  onPressed: () => context.push(
                      '/payments/new?tenant=${d.tenant.id}&type=electricity'
                      '&month=${d.month.toIso8601String()}'),
                  child: Text('Collect ${money(d.due)}'),
                ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: StatCard(
              icon: Icons.bolt_rounded,
              label: 'Collected',
              value: money(collected),
              caption: 'of ${money(billed)} billed',
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              icon: Icons.pending_actions_rounded,
              label: 'Pending',
              value: money(pending),
              caption:
                  '${thisMonth.where((d) => !d.isPaid).length} tenants',
              color: pending > 0 ? red : AppColors.warning,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (thisMonth.isEmpty)
          EmptyState(
            icon: Icons.bolt_rounded,
            title: 'No electricity bills for ${fmtMonth(month)}',
            message: 'Open a room with "Electricity bill separate" ticked '
                'and tap "Add Electricity Bill +".',
          )
        else
          for (final roomId in {for (final d in thisMonth) d.bill.roomId}) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
              child: Row(children: [
                Expanded(
                  child: Text('Room ${roomNo(roomId)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: () => context.push('/rooms/$roomId'),
                  child: Text('Bill ${money(bills.where((b) => b.roomId == roomId && sameMonth(b.month, month)).fold<double>(0, (a, b) => a + b.amount))}'),
                ),
              ]),
            ),
            Card(
              child: Column(children: [
                for (final d in thisMonth.where((d) => d.bill.roomId == roomId))
                  shareTile(d),
              ]),
            ),
            const SizedBox(height: 8),
          ],
        if (older.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Text(
                'Pending from earlier months · ${money(older.fold<double>(0, (a, d) => a + d.due))}',
                style: const TextStyle(color: red, fontWeight: FontWeight.w700)),
          ),
          Card(
            child: Column(children: [
              for (final d in older) shareTile(d, showMonth: true),
            ]),
          ),
        ],
      ],
    );
  }
}
