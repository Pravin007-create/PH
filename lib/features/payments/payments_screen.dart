import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/calculations.dart';
import '../../data/models.dart';
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

    // Icons + text only where there's room; small phones get text only.
    final wideTabs = MediaQuery.sizeOf(context).width >= 420;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Payments')), actions: [
        IconButton(
          tooltip: context.tr('Deleted payments'),
          icon: const Icon(Icons.history_rounded),
          onPressed: () => context.push('/payments/deleted'),
        ),
      ]),
      floatingActionButton: AddButton(
        label: context.tr('Record Payment'),
        onPressed: () => context.push('/payments/new'),
      ),
      body: Column(children: [
        // Month bar stays fixed at the top while the list scrolls.
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: PageBody(
              child: MonthSwitcher(
                  prominent: true,
                  month: _month,
                  onChanged: (m) => setState(() => _month = m)),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              PageBody(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    SegmentedButton<_Tab>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        padding: WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 4)),
                      ),
                      segments: [
                        ButtonSegment(
                            value: _Tab.rent,
                            tooltip: context.tr('Rent status'),
                            label: Text(context.tr('Rent')),
                            icon: wideTabs
                                ? const Icon(Icons.fact_check_outlined, size: 18)
                                : null),
                        ButtonSegment(
                            value: _Tab.electricity,
                            tooltip: context.tr('Electricity bills'),
                            label: Text(context.tr('Electricity')),
                            icon: wideTabs
                                ? const Icon(Icons.bolt_rounded, size: 18)
                                : null),
                        ButtonSegment(
                            value: _Tab.payments,
                            tooltip: context.tr('Payments received'),
                            label: Text(context.tr('Payments')),
                            icon: wideTabs
                                ? const Icon(Icons.receipt_long_outlined,
                                    size: 18)
                                : null),
                      ],
                      selected: {_tab},
                      onSelectionChanged: (v) => setState(() => _tab = v.first),
                    ),
                    const SizedBox(height: 12),
                    // Summary cards follow the selected tab.
                    switch (_tab) {
                      _Tab.rent => _RentHeader(summary: s),
                      _Tab.electricity => _ElectricityCards(month: _month),
                      _Tab.payments => _PaymentsCards(payments: payments),
                    },
                    const SizedBox(height: 12),
                    if (_tab == _Tab.electricity)
                      _ElectricityTab(month: _month)
                    else if (_tab == _Tab.rent) ...[
                      if (s.dues.isEmpty)
                        const EmptyState(
                          icon: Icons.people_outline_rounded,
                          title: 'No tenants this month',
                          message:
                              'Rent status appears here once you add tenants.',
                        ),
                      for (final d in s.dues) ...[
                        Card(
                          color: d.isOverdue
                              ? const Color(0xFFDC2626).withValues(alpha: 0.06)
                              : null,
                          shape: d.isOverdue
                              ? RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(
                                      color: Color(0xFFDC2626)))
                              : null,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            // Paid → payment details; nothing paid → tenant.
                            onTap: () => openPaymentsFor(context, ref,
                                tenantId: d.tenant.id,
                                month: _month,
                                type: PaymentType.rent),
                            leading: CircleAvatar(
                                child: Text(initials(d.tenant.name))),
                            title: Text(d.tenant.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            isThreeLine: true,
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${rooms.byId(d.tenant.roomId) == null ? context.tr('No room') : context.tr('Room {n}', {
                                          'n': rooms
                                              .byId(d.tenant.roomId)!
                                              .number
                                        })}'
                                  ' · ${context.tr('Paid {a} of {b}', {
                                        'a': money(d.paid),
                                        'b': money(d.tenant.rent)
                                      })}',
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 4),
                                DueChip(d),
                              ],
                            ),
                            trailing: d.isPaid
                                ? null
                                : CollectButton(
                                    onPressed: () => context.push(
                                        '/payments/new?tenant=${d.tenant.id}&month=${_month.toIso8601String()}'),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ] else ...[
                      if (payments.isEmpty)
                        EmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: context.tr(
                              'No payments in {m}', {'m': fmtMonth(_month)}),
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
                                tenants.byId(p.tenantId)?.name ??
                                    'Deleted tenant',
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
        ),
      ]),
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
    final older =
        shares.where((d) => !d.isPaid && d.month.isBefore(month)).toList();
    String roomNo(String id) =>
        rooms.where((r) => r.id == id).firstOrNull?.number ?? '-';

    Widget shareTile(ElectricityDue d, {bool showMonth = false}) => ListTile(
          onTap: () => openPaymentsFor(context, ref,
              tenantId: d.tenant.id,
              month: d.month,
              type: PaymentType.electricity),
          leading: CircleAvatar(child: Text(initials(d.tenant.name))),
          title:
              Text(d.tenant.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(context.tr('Room {r} · share {a}', {
                'r': roomNo(d.bill.roomId) +
                    (showMonth ? ' · ${fmtMonthShort(d.month)}' : ''),
                'a': money(d.share),
              }) +
              (d.isPaid || d.paid == 0
                  ? ''
                  : ' · ${context.tr('Paid')} ${money(d.paid)}')),
          trailing: d.isPaid
              ? StatusChip(context.tr('Paid'), color: AppColors.success)
              : CollectButton(
                  onPressed: () => context.push(
                      '/payments/new?tenant=${d.tenant.id}&type=electricity'
                      '&month=${d.month.toIso8601String()}'),
                ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  child: Text(context.tr('Room {n}', {'n': roomNo(roomId)}),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: () => context.push('/rooms/$roomId'),
                  child: Text(
                      'Bill ${money(bills.where((b) => b.roomId == roomId && sameMonth(b.month, month)).fold<double>(0, (a, b) => a + b.amount))}'),
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
                style:
                    const TextStyle(color: red, fontWeight: FontWeight.w700)),
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

/// Opens what was paid: one payment → its details; several → a list to
/// choose from; none yet → the tenant's page.
Future<void> openPaymentsFor(BuildContext context, WidgetRef ref,
    {required String tenantId,
    required DateTime month,
    required PaymentType type}) async {
  final list = ref
      .read(paymentsProvider)
      .where((p) =>
          p.tenantId == tenantId && p.type == type && sameMonth(p.month, month))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  if (list.isEmpty) {
    context.push('/tenants/$tenantId');
  } else if (list.length == 1) {
    context.push('/payments/${list.single.id}');
  } else {
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                  '${list.length} ${type.label.toLowerCase()} payments · '
                  '${fmtMonth(month)} · ${money(list.fold<double>(0, (a, p) => a + p.amount))}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final p in list)
              ListTile(
                leading: const IconBadge(
                    icon: Icons.south_west_rounded, color: AppColors.success),
                title: Text(money(p.amount),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${fmtDate(p.date)} · ${p.mode}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(ctx, p.id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (id != null && context.mounted) context.push('/payments/$id');
  }
}

/// Rent tab header: collection window, overdue banner, collected / pending.
class _RentHeader extends StatelessWidget {
  const _RentHeader({required this.summary});
  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Icon(Icons.event_available_rounded, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              context.tr('Collect from {a} · due by {b}',
                  {'a': fmtDate(s.collectFrom), 'b': fmtDate(s.dueDate)}),
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
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('{n} overdue · {a} not paid after {d}', {
                    'n': s.overdue.length,
                    'a': money(s.overdueAmount),
                    'd': fmtDate(s.dueDate),
                  }),
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
              label: context.tr('Rent collected'),
              value: money(s.rentCollected),
              caption: context.tr('{p}% of {a}', {
                'p': (s.collectionRate * 100).round(),
                'a': money(s.rentExpected)
              }),
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              icon: Icons.pending_actions_rounded,
              label: context.tr('Pending rent'),
              value: money(s.pendingRent),
              caption: context.tr('{n} tenants', {'n': s.unpaid.length}),
              color: s.overdue.isEmpty
                  ? AppColors.warning
                  : const Color(0xFFDC2626),
            ),
          ),
        ]),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Electricity tab header: collected / pending for the month's bills.
class _ElectricityCards extends ConsumerWidget {
  const _ElectricityCards({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(electricityBillsProvider);
    final shares = electricityShares(
            bills, ref.watch(tenantsProvider), ref.watch(paymentsProvider))
        .where((d) => sameMonth(d.month, month))
        .toList();
    final billed = bills
        .where((b) => sameMonth(b.month, month))
        .fold<double>(0, (a, b) => a + b.amount);
    final collected = shares.fold<double>(0, (a, d) => a + d.paid);
    final pending = shares.fold<double>(0, (a, d) => a + d.due);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(
          child: StatCard(
            icon: Icons.bolt_rounded,
            label: context.tr('Electricity collected'),
            value: money(collected),
            caption: context.tr('of {a} billed', {'a': money(billed)}),
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            icon: Icons.pending_actions_rounded,
            label: context.tr('Electricity pending'),
            value: money(pending),
            caption: context.tr(
                '{n} tenants', {'n': shares.where((d) => !d.isPaid).length}),
            color: pending > 0 ? const Color(0xFFDC2626) : AppColors.warning,
          ),
        ),
      ]),
    );
  }
}

/// Payments tab header: everything received for the month.
class _PaymentsCards extends StatelessWidget {
  const _PaymentsCards({required this.payments});
  final List<Payment> payments;

  @override
  Widget build(BuildContext context) {
    final total = payments.fold<double>(0, (a, p) => a + p.amount);
    final rent = payments
        .where((p) => p.type == PaymentType.rent)
        .fold<double>(0, (a, p) => a + p.amount);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(
          child: StatCard(
            icon: Icons.account_balance_wallet_rounded,
            label: context.tr('Received this month'),
            value: money(total),
            caption: context.tr('{n} payments', {'n': payments.length}),
            color: AppColors.seed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            icon: Icons.bolt_rounded,
            label: context.tr('Other received'),
            value: money(total - rent),
            caption: context.tr('Electricity, deposit, other'),
            color: AppColors.info,
          ),
        ),
      ]),
    );
  }
}
