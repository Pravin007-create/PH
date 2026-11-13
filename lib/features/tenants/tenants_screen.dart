import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/calculations.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';

class TenantsScreen extends ConsumerStatefulWidget {
  const TenantsScreen({super.key});

  @override
  ConsumerState<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends ConsumerState<TenantsScreen> {
  String _query = '';
  bool _showActive = true;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(tenantsProvider);
    final rooms = ref.watch(roomsProvider.notifier);
    ref.watch(roomsProvider);
    final month = monthOf(DateTime.now());
    final status = {
      for (final d in ref.watch(monthSummaryProvider(month)).dues)
        d.tenant.id: d
    };

    final q = _query.toLowerCase();
    final shown = all.where((t) {
      if (t.isActive != _showActive) return false;
      if (q.isEmpty) return true;
      final room = rooms.byId(t.roomId);
      return t.name.toLowerCase().contains(q) ||
          t.phone.contains(q) ||
          (room?.number.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final activeCount = all.where((t) => t.isActive).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Tenants')),
      floatingActionButton: all.isEmpty
          ? null
          : AddButton(
              label: 'Add Tenant',
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
                          hint: 'Search name, phone or room',
                          onChanged: (v) => setState(() => _query = v)),
                      const SizedBox(height: 12),
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(
                              value: true,
                              label: Text('Staying ($activeCount)'),
                              icon: const Icon(Icons.home_rounded)),
                          ButtonSegment(
                              value: false,
                              label: Text(
                                  'Moved out (${all.length - activeCount})'),
                              icon: const Icon(Icons.logout_rounded)),
                        ],
                        selected: {_showActive},
                        onSelectionChanged: (v) =>
                            setState(() => _showActive = v.first),
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
                            subtitle: Text(
                              [
                                rooms.byId(t.roomId) == null
                                    ? 'No room'
                                    : 'Room ${rooms.byId(t.roomId)!.number}',
                                money(t.rent),
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: !t.isActive
                                ? const StatusChip('Moved out',
                                    color: Colors.grey)
                                : status[t.id] == null
                                    ? null
                                    : status[t.id]!.isPaid
                                        ? const StatusChip('Paid',
                                            color: AppColors.success)
                                        : StatusChip(
                                            'Due ${money(status[t.id]!.due)}',
                                            color: AppColors.warning),
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
