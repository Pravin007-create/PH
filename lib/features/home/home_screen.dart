import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/calculations.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = monthOf(DateTime.now());
    final s = ref.watch(monthSummaryProvider(month));
    final profile = ref.watch(profileProvider);
    final rooms = ref.watch(roomsProvider);
    final tenants = ref.watch(tenantsProvider);
    final payments = [...ref.watch(paymentsProvider)]
      ..sort((a, b) => b.date.compareTo(a.date));
    final tenantStore = ref.read(tenantsProvider.notifier);
    final unpaid = s.unpaid;

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
                      caption: '${unpaid.length} tenants',
                      color: AppColors.warning,
                      onTap: () => context.go('/payments'),
                    ),
                    StatCard(
                      icon: Icons.receipt_long_rounded,
                      label: 'Expenses',
                      value: money(s.expenses),
                      caption: 'This month',
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
                      action: unpaid.isEmpty ? null : 'See all',
                      onAction: () => context.go('/payments')),
                  if (s.dues.isEmpty)
                    const _InfoTile(
                      icon: Icons.info_outline_rounded,
                      text: 'Add tenants to start tracking rent.',
                    )
                  else if (unpaid.isEmpty)
                    const _InfoTile(
                      icon: Icons.verified_rounded,
                      text: 'All rent collected for this month.',
                      color: AppColors.success,
                    )
                  else
                    Card(
                      child: Column(children: [
                        for (final d in unpaid.take(5)) ...[
                          if (d != unpaid.first) const Divider(height: 1),
                          _DueTile(due: d),
                        ],
                      ]),
                    ),

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
          Text('Rent collected · ${fmtMonth(s.month)}',
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
      subtitle: Text(
          '${room == null ? 'No room' : 'Room ${room.number}'} · Due ${money(due.due)}'),
      trailing: FilledButton.tonal(
        style: FilledButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14)),
        onPressed: () => context.push('/payments/new?tenant=${due.tenant.id}'),
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
