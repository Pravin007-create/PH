import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/calculations.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';
import '../../widgets/due_chip.dart';

class TenantsScreen extends ConsumerStatefulWidget {
  const TenantsScreen({super.key});

  @override
  ConsumerState<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends ConsumerState<TenantsScreen> {
  String _query = '';
  bool _showActive = true;
  bool _docsPendingOnly = false;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(tenantsProvider);
    final rooms = ref.watch(roomsProvider.notifier);
    ref.watch(roomsProvider);
    final month = ref.watch(currentRentMonthProvider);
    final status = {
      for (final d in ref.watch(monthSummaryProvider(month)).dues)
        d.tenant.id: d
    };
    // Tenants with overdue rent from any month.
    final overdueIds = {
      for (final d in ref.watch(overdueProvider)) d.tenant.id
    };

    final q = _query.toLowerCase();
    final shown = all.where((t) {
      if (t.isActive != _showActive) return false;
      if (_docsPendingOnly && t.documentsSubmitted) return false;
      if (q.isEmpty) return true;
      final room = rooms.byId(t.roomId);
      return t.name.toLowerCase().contains(q) ||
          t.phone.contains(q) ||
          (room?.number.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final activeCount = all.where((t) => t.isActive).length;
    final docsPending =
        all.where((t) => t.isActive && !t.documentsSubmitted).length;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Tenants'))),
      floatingActionButton: all.isEmpty
          ? null
          : AddButton(
              label: context.tr('Add Tenant'),
              onPressed: () => context.push('/tenants/new')),
      body: all.isEmpty
          ? Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.people_rounded,
                  title: 'No tenants yet',
                  message:
                      'Add a tenant with their phone number, room and monthly rent.',
                  actionLabel: 'Add your first tenant',
                  onAction: () => context.push('/tenants/new'),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                PageBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SearchField(
                          hint: context.tr('Search name, phone or room'),
                          onChanged: (v) => setState(() => _query = v)),
                      const SizedBox(height: 12),
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(
                              value: true,
                              label: Text(context
                                  .tr('Staying ({n})', {'n': activeCount})),
                              icon: const Icon(Icons.home_rounded)),
                          ButtonSegment(
                              value: false,
                              label: Text(context.tr('Moved out ({n})',
                                  {'n': all.length - activeCount})),
                              icon: const Icon(Icons.logout_rounded)),
                        ],
                        selected: {_showActive},
                        onSelectionChanged: (v) =>
                            setState(() => _showActive = v.first),
                      ),
                      if (_showActive && (docsPending > 0 || _docsPendingOnly))
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FilterChip(
                              avatar: const Icon(Icons.gpp_maybe_rounded,
                                  size: 18, color: Color(0xFFDC2626)),
                              label: Text(context.tr('Documents pending ({n})',
                                  {'n': docsPending})),
                              selected: _docsPendingOnly,
                              onSelected: (v) =>
                                  setState(() => _docsPendingOnly = v),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _query.isNotEmpty
                                ? 'No tenants match your search.'
                                : _showActive
                                    ? 'No tenants staying right now.'
                                    : 'No tenants have moved out.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final t in shown) ...[
                        Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            onTap: () => context.push('/tenants/${t.id}'),
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: Text(initials(t.name)),
                            ),
                            title: Text(t.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  [
                                    rooms.byId(t.roomId) == null
                                        ? context.tr('No room')
                                        : context.tr('Room {n}', {
                                            'n': rooms.byId(t.roomId)!.number
                                          }),
                                    money(t.rent),
                                    if (t.isActive && t.relievingDate != null)
                                      context.tr('Leaving {d}',
                                          {'d': fmtDate(t.relievingDate!)}),
                                  ].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (t.isActive && !t.documentsSubmitted)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: DocsPendingChip(short: true),
                                  ),
                              ],
                            ),
                            trailing: !t.isActive
                                ? StatusChip(context.tr('Moved out'),
                                    color: Colors.grey)
                                : overdueIds.contains(t.id) &&
                                        !(status[t.id]?.isOverdue ?? false)
                                    ? StatusChip(context.tr('Overdue'),
                                        color: const Color(0xFFDC2626))
                                    : status[t.id] == null
                                        ? null
                                        : DueChip(status[t.id]!),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
