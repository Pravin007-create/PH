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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The rent month being collected now (October on 3 Nov for an
    // end-of-month PG), not simply the calendar month.
    final month = ref.watch(currentRentMonthProvider);
    final s = ref.watch(monthSummaryProvider(month));
    final calendarMonth = monthOf(DateTime.now());
    final monthExpenses =
        ref.watch(monthSummaryProvider(calendarMonth)).expenses;
    final overdue = ref.watch(overdueProvider);
    final profile = ref.watch(profileProvider);
    final rooms = ref.watch(roomsProvider);
    final tenants = ref.watch(tenantsProvider);
    final payments = [...ref.watch(paymentsProvider)]
      ..sort((a, b) => b.date.compareTo(a.date));
    final tenantStore = ref.read(tenantsProvider.notifier);
    final unpaid = s.unpaid;
    // Overdue (any month, oldest first), then this rent month's due/upcoming.
    final pending = [...overdue, ...unpaid.where((d) => !d.isOverdue)];
    final power = ref.watch(electricityDuesProvider);
    final leaving = upcomingVacancies(tenants);
    final today = dateOnly(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(profile: profile, summary: s),
                  _RentAlert(summary: s, overdue: overdue),

                  if (rooms.isEmpty || tenants.isEmpty)
                    _GetStarted(
                      hasProfile: !profile.isEmpty,
                      hasRooms: rooms.isNotEmpty,
                      hasTenants: tenants.isNotEmpty,
                    ),

                  const SectionHeader('Overview'),
                  ResponsiveGrid(children: [
                    StatCard(
                      icon: Icons.bed_rounded,
                      label: 'Beds occupied',
                      value: '${s.occupiedBeds} / ${s.totalBeds}',
                      caption: '${s.vacantBeds} vacant',
                      color: AppColors.info,
                      onTap: () => context.go('/rooms'),
                    ),
                    StatCard(
                      icon: Icons.people_rounded,
                      label: 'Active tenants',
                      value: '${s.activeTenants}',
                      caption: '${rooms.length} rooms',
                      color: AppColors.purple,
                      onTap: () => context.go('/tenants'),
                    ),
                    StatCard(
                      icon: Icons.pending_actions_rounded,
                      label: 'Pending rent',
                      value: money(s.pendingRent),
                      caption: overdue.isEmpty
                          ? '${unpaid.length} tenants'
                          : '${overdue.map((d) => d.tenant.id).toSet().length} overdue',
                      color: overdue.isEmpty
                          ? AppColors.warning
                          : const Color(0xFFDC2626),
                      onTap: () => context.go('/payments'),
                    ),
                    StatCard(
                      icon: Icons.receipt_long_rounded,
                      label: 'Expenses',
                      value: money(monthExpenses),
                      caption: fmtMonthShort(calendarMonth),
                      color: AppColors.pink,
                      onTap: () => context.push('/expenses'),
                    ),
                  ]),

                  const SectionHeader('Quick actions'),
                  ResponsiveGrid(minItemWidth: 100, spacing: 10, children: [
                    _QuickAction(
                      icon: Icons.person_add_alt_1_rounded,
                      label: 'Add Tenant',
                      color: AppColors.purple,
                      onTap: () => context.push('/tenants/new'),
                    ),
                    _QuickAction(
                      icon: Icons.currency_rupee_rounded,
                      label: 'Record Payment',
                      color: AppColors.success,
                      onTap: () => context.push('/payments/new'),
                    ),
                    _QuickAction(
                      icon: Icons.add_card_rounded,
                      label: 'Add Expense',
                      color: AppColors.pink,
                      onTap: () => context.push('/expenses/new'),
                    ),
                    _QuickAction(
                      icon: Icons.add_home_work_rounded,
                      label: 'Add Room',
                      color: AppColors.info,
                      onTap: () => context.push('/rooms/new'),
                    ),
                    _QuickAction(
                      icon: Icons.download_rounded,
                      label: 'Reports',
                      color: AppColors.seed,
                      onTap: () => context.push('/reports'),
                    ),
                    _QuickAction(
                      icon: Icons.storefront_rounded,
                      label: 'PG Details',
                      color: AppColors.warning,
                      onTap: () => context.push('/profile'),
                    ),
                  ]),

                  SectionHeader('Pending rent · ${fmtMonthShort(month)}',
                      action: pending.isEmpty ? null : 'See all',
                      onAction: () => context.go('/payments')),
                  if (s.dues.isEmpty)
                    const _InfoTile(
                      icon: Icons.info_outline_rounded,
                      text: 'Add tenants to start tracking rent.',
                    )
                  else if (pending.isEmpty)
                    const _InfoTile(
                      icon: Icons.verified_rounded,
                      text: 'All rent collected for this month.',
                      color: AppColors.success,
                    )
                  else
                    Card(
                      child: Column(children: [
                        for (final d in pending.take(6)) ...[
                          if (d != pending.first) const Divider(height: 1),
                          _DueTile(due: d),
                        ],
                      ]),
                    ),

                  if (leaving.isNotEmpty) ...[
                    SectionHeader('Upcoming vacancies (${leaving.length})'),
                    Card(
                      child: Column(children: [
                        for (final t in leaving.take(6)) ...[
                          if (t != leaving.first) const Divider(height: 1),
                          ListTile(
                            onTap: () => context.push('/tenants/${t.id}'),
                            leading: IconBadge(
                                icon: moveOutPending(t, today)
                                    ? Icons.warning_amber_rounded
                                    : Icons.event_busy_rounded,
                                color: moveOutPending(t, today)
                                    ? const Color(0xFFDC2626)
                                    : AppColors.purple),
                            title: Text(
                                'Room ${rooms.where((r) => r.id == t.roomId).firstOrNull?.number ?? '-'} · ${t.name}'),
                            subtitle: Text(moveOutPending(t, today)
                                ? 'Left ${fmtDate(t.relievingDate!)} · complete move-out'
                                : '1 bed free from ${fmtDate(t.vacantFrom!)}'),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ]),
                    ),
                  ],

                  if (power.isNotEmpty) ...[
                    SectionHeader(
                        'Electricity to collect · ${money(power.fold<double>(0, (a, d) => a + d.due))}'),
                    Card(
                      child: Column(children: [
                        for (final d in power.take(6)) ...[
                          if (d != power.first) const Divider(height: 1),
                          ListTile(
                            leading: const IconBadge(
                                icon: Icons.bolt_rounded,
                                color: AppColors.warning),
                            title: Text(d.tenant.name),
                            subtitle: Text(
                                'Room ${rooms.where((r) => r.id == d.bill.roomId).firstOrNull?.number ?? '-'} · ${fmtMonthShort(d.month)}'),
                            trailing: TextButton(
                              onPressed: () => context.push(
                                  '/payments/new?tenant=${d.tenant.id}&type=electricity&month=${d.month.toIso8601String()}'),
                              child: Text('Collect ${money(d.due)}'),
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ],

                  SectionHeader('Recent payments',
                      action: payments.isEmpty ? null : 'See all',
                      onAction: () => context.go('/payments')),
                  if (payments.isEmpty)
                    const _InfoTile(
                      icon: Icons.receipt_outlined,
                      text: 'Payments you record will appear here.',
                    )
                  else
                    Card(
                      child: Column(children: [
                        for (final p in payments.take(5)) ...[
                          if (p != payments.first) const Divider(height: 1),
                          ListTile(
                            onTap: () => context.push('/payments/${p.id}'),
                            leading: const IconBadge(
                                icon: Icons.south_west_rounded,
                                color: AppColors.success),
                            title: Text(
                                tenantStore.byId(p.tenantId)?.name ??
                                    'Deleted tenant',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                                '${p.type.label} · ${fmtDate(p.date)}'),
                            trailing: Text(
                              money(p.amount),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.success),
                            ),
                          ),
                        ],
                      ]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.summary});
  final PgProfile profile;
  final MonthSummary summary;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = summary;
    const white = Colors.white;
    final white70 = Colors.white.withValues(alpha: 0.8);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, Color.lerp(scheme.primary, AppColors.purple, 0.6)!],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_greeting${profile.ownerName.isEmpty ? '' : ', ${profile.ownerName}'}',
                    style: TextStyle(color: white70, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.pgName.isEmpty ? 'PG Hostel Manager' : profile.pgName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: white, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: const Icon(Icons.apartment_rounded, color: white),
            ),
          ]),
          const SizedBox(height: 20),
          Text('Rent for ${fmtMonth(s.month)} · due ${fmtDate(s.dueDate)}',
              style: TextStyle(color: white70, fontSize: 13)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(
                text: money(s.rentCollected),
                style: const TextStyle(
                    color: white, fontSize: 28, fontWeight: FontWeight.w800),
              ),
              TextSpan(
                text: '  of ${money(s.rentExpected)}',
                style: TextStyle(color: white70, fontSize: 15),
              ),
            ])),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: s.collectionRate,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(white),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _HeaderPill('${(s.collectionRate * 100).round()}% collected'),
            _HeaderPill('Net ${money(s.net)}'),
          ]),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(children: [
              IconBadge(icon: icon, color: color, size: 44),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

class _DueTile extends ConsumerWidget {
  const _DueTile({required this.due});
  final TenantDue due;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.read(roomsProvider.notifier).byId(due.tenant.roomId);
    return ListTile(
      onTap: () => context.push('/tenants/${due.tenant.id}'),
      leading: CircleAvatar(child: Text(initials(due.tenant.name))),
      title: Text(due.tenant.name,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${room == null ? 'No room' : 'Room ${room.number}'} · ${money(due.due)}'
              '${sameMonth(due.month, monthOf(DateTime.now())) ? '' : ' · ${fmtMonthShort(due.month)}'}'),
          const SizedBox(height: 4),
          DueChip(due),
        ],
      ),
      isThreeLine: true,
      trailing: FilledButton.tonal(
        style: FilledButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14)),
        onPressed: () => context.push(
            '/payments/new?tenant=${due.tenant.id}&month=${due.month.toIso8601String()}'),
        child: const Text('Collect'),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(icon, color: c),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: c))),
        ]),
      ),
    );
  }
}

class _GetStarted extends StatelessWidget {
  const _GetStarted({
    required this.hasProfile,
    required this.hasRooms,
    required this.hasTenants,
  });
  final bool hasProfile;
  final bool hasRooms;
  final bool hasTenants;

  @override
  Widget build(BuildContext context) {
    Widget step(int n, String title, String sub, bool done, String route) =>
        ListTile(
          onTap: done ? null : () => context.push(route),
          leading: CircleAvatar(
            backgroundColor: done
                ? AppColors.success
                : Theme.of(context).colorScheme.primaryContainer,
            child: done
                ? const Icon(Icons.check_rounded, color: Colors.white)
                : Text('$n'),
          ),
          title: Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: done ? TextDecoration.lineThrough : null)),
          subtitle: Text(sub),
          trailing: done ? null : const Icon(Icons.chevron_right_rounded),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Get started in 3 steps',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            step(1, 'Add PG details', 'Name, owner and contact', hasProfile,
                '/profile'),
            step(2, 'Add your rooms', 'Room number, beds and rent', hasRooms,
                '/rooms/new'),
            step(3, 'Add tenants', 'Assign tenants to rooms', hasTenants,
                '/tenants/new'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Red alert when rent is overdue; amber reminder during the collection
/// window; blue note before collection opens.
class _RentAlert extends StatelessWidget {
  const _RentAlert({required this.summary, required this.overdue});
  final MonthSummary summary;
  final List<TenantDue> overdue;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final today = dateOnly(DateTime.now());

    if (overdue.isNotEmpty) {
      final amount = overdue.fold<double>(0, (a, d) => a + d.due);
      final people = overdue.map((d) => d.tenant.id).toSet().length;
      final older = overdue.where((d) => !sameMonth(d.month, s.month)).length;
      return _banner(
        context,
        color: const Color(0xFFDC2626),
        icon: Icons.warning_amber_rounded,
        title: '$people ${people == 1 ? 'tenant has' : 'tenants have'} '
            'not paid · ${money(amount)} overdue',
        message: 'Due date ${fmtDate(s.dueDate)} has passed.'
            '${older > 0 ? ' Includes $older unpaid ${older == 1 ? 'month' : 'months'} from before.' : ''}',
        action: 'View overdue',
        onAction: () => context.go('/payments'),
        strong: true,
      );
    }

    final unpaid = s.unpaid;
    if (unpaid.isEmpty) return const SizedBox.shrink();

    if (!today.isBefore(s.collectFrom)) {
      final left = s.dueDate.difference(today).inDays;
      return _banner(
        context,
        color: AppColors.warning,
        icon: Icons.notifications_active_outlined,
        title: 'Rent collection is open · ${unpaid.length} '
            '${unpaid.length == 1 ? 'tenant' : 'tenants'} to pay',
        message: left == 0
            ? 'Last day today (${fmtDate(s.dueDate)}). Collect ${money(s.pendingRent)}.'
            : 'Collect ${money(s.pendingRent)} by ${fmtDate(s.dueDate)} '
                '($left ${left == 1 ? 'day' : 'days'} left).',
        action: 'Collect now',
        onAction: () => context.go('/payments'),
      );
    }

    return _banner(
      context,
      color: AppColors.info,
      icon: Icons.event_outlined,
      title: 'Next rent collection from ${fmtDate(s.collectFrom)}',
      message: '${money(s.pendingRent)} due by ${fmtDate(s.dueDate)}.',
    );
  }

  Widget _banner(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required String message,
    String? action,
    VoidCallback? onAction,
    bool strong = false,
  }) {
    final fg = strong ? Colors.white : color;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: strong ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: strong ? 1 : 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: fg, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(message,
                          style: TextStyle(
                              color: strong
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : Theme.of(context).colorScheme.onSurface)),
                    ],
                  ),
                ),
              ],
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    backgroundColor: strong ? Colors.white : color,
                    foregroundColor: strong ? color : Colors.white,
                  ),
                  onPressed: onAction,
                  child: Text(action),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
