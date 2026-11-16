import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/calculations.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';

const _red = Color(0xFFDC2626);

enum _Availability { all, vacant, vacatingSoon, full, billDue }

enum _AcFilter { any, ac, nonAc }

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  String _query = '';
  _Availability _availability = _Availability.all;
  _AcFilter _ac = _AcFilter.any;

  /// Beds per room (sharing); null = any.
  int? _sharing;

  @override
  Widget build(BuildContext context) {
    final rooms = [...ref.watch(roomsProvider)]
      ..sort((a, b) => a.number.compareTo(b.number));
    final tenants = ref.watch(tenantsProvider);
    final occupancy = occupancyByRoom(tenants);
    final leaving = upcomingVacancies(tenants);
    final billDue = electricityDueByRoom(ref.watch(electricityDuesProvider));
    final sharingOptions = rooms.map((r) => r.beds).toSet().toList()..sort();

    List<Tenant> leavingIn(Room r) =>
        leaving.where((t) => t.roomId == r.id).toList();

    final shown = rooms.where((r) {
      final filled = occupancy[r.id] ?? 0;
      final q = _query.toLowerCase();
      if (q.isNotEmpty &&
          !r.number.toLowerCase().contains(q) &&
          !r.floor.toLowerCase().contains(q)) {
        return false;
      }
      if (_ac == _AcFilter.ac && !r.isAC) return false;
      if (_ac == _AcFilter.nonAc && r.isAC) return false;
      if (_sharing != null && r.beds != _sharing) return false;
      return switch (_availability) {
        _Availability.all => true,
        _Availability.vacant => filled < r.beds,
        _Availability.vacatingSoon => leavingIn(r).isNotEmpty,
        _Availability.full => filled >= r.beds,
        _Availability.billDue => (billDue[r.id] ?? 0) > 0,
      };
    }).toList();

    final totalBeds = rooms.fold<int>(0, (s, r) => s + r.beds);
    final filledBeds = occupancy.values.fold<int>(0, (s, n) => s + n);
    final filtered = _ac != _AcFilter.any ||
        _sharing != null ||
        _availability != _Availability.all ||
        _query.isNotEmpty;

    Widget chipRow(List<Widget> chips) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final c in chips)
              Padding(padding: const EdgeInsets.only(right: 8), child: c),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Rooms'))),
      floatingActionButton: rooms.isEmpty
          ? null
          : AddButton(
              label: context.tr('Add Room'),
              onPressed: () => context.push('/rooms/new')),
      body: rooms.isEmpty
          ? Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  icon: Icons.meeting_room_rounded,
                  title: 'No rooms yet',
                  message:
                      'Add your rooms with number of beds and rent.\nThen you can assign tenants to them.',
                  actionLabel: 'Add your first room',
                  onAction: () => context.push('/rooms/new'),
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
                      Text(
                        '${rooms.length} rooms · $filledBeds of $totalBeds beds filled'
                        '${leaving.isEmpty ? '' : ' · ${leaving.length} leaving soon'}',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      SearchField(
                          hint: context.tr('Search room number or floor'),
                          onChanged: (v) => setState(() => _query = v)),
                      const SizedBox(height: 12),
                      chipRow([
                        for (final f in _Availability.values)
                          ChoiceChip(
                            avatar: f == _Availability.billDue
                                ? const Icon(Icons.bolt_rounded, size: 18)
                                : null,
                            label: Text(context.tr(switch (f) {
                              _Availability.all => 'All',
                              _Availability.vacant => 'Has vacancy',
                              _Availability.vacatingSoon => 'Vacating soon',
                              _Availability.full => 'Full',
                              _Availability.billDue => 'Bill pending',
                            })),
                            selected: _availability == f,
                            onSelected: (_) =>
                                setState(() => _availability = f),
                          ),
                      ]),
                      const SizedBox(height: 8),
                      chipRow([
                        for (final f in _AcFilter.values)
                          ChoiceChip(
                            label: Text(context.tr(switch (f) {
                              _AcFilter.any => 'AC & Non-AC',
                              _AcFilter.ac => 'AC',
                              _AcFilter.nonAc => 'Non-AC',
                            })),
                            selected: _ac == f,
                            onSelected: (_) => setState(() => _ac = f),
                          ),
                        const SizedBox(
                            height: 24, child: VerticalDivider(width: 8)),
                        for (final n in sharingOptions)
                          FilterChip(
                            label: Text(n == 1
                                ? context.tr('Single')
                                : context.tr('{n}-sharing', {'n': n})),
                            selected: _sharing == n,
                            onSelected: (on) =>
                                setState(() => _sharing = on ? n : null),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      if (filtered)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            Expanded(
                              child: Text(
                                  'Showing ${shown.length} of ${rooms.length} rooms',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _availability = _Availability.all;
                                _ac = _AcFilter.any;
                                _sharing = null;
                              }),
                              child: Text(context.tr('Clear filters')),
                            ),
                          ]),
                        ),
                      if (shown.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No rooms match these filters.',
                              textAlign: TextAlign.center),
                        ),
                      for (final room in shown) ...[
                        _RoomCard(
                          room: room,
                          filled: occupancy[room.id] ?? 0,
                          leaving: leavingIn(room),
                          billDue: billDue[room.id] ?? 0,
                          onTap: () => context.push('/rooms/${room.id}'),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.filled,
    required this.leaving,
    required this.billDue,
    required this.onTap,
  });

  final Room room;
  final int filled;

  /// Staying tenants with a relieving date, soonest first.
  final List<Tenant> leaving;

  /// Unpaid electricity for this room.
  final double billDue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final beds = room.beds;
    final isFull = filled >= beds;
    final color = isFull ? AppColors.warning : AppColors.success;
    final today = dateOnly(DateTime.now());
    return Card(
      shape: billDue > 0
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: _red.withValues(alpha: 0.5)))
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const IconBadge(
                    icon: Icons.meeting_room_rounded, color: AppColors.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('Room {n}', {'n': room.number}),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        [
                          if (room.floor.isNotEmpty)
                            context.tr('Floor {f}', {'f': room.floor}),
                          beds == 1
                              ? context.tr('Single')
                              : context.tr('{n}-sharing', {'n': beds}),
                          room.isAC ? 'AC' : context.tr('Non-AC'),
                        ].join(' · '),
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                StatusChip(
                    isFull
                        ? context.tr('Full')
                        : context.tr('{n} vacant', {'n': beds - filled}),
                    color: color),
                for (final t in leaving)
                  StatusChip(
                    moveOutPending(t, today)
                        ? context.tr('Move-out pending')
                        : context.tr(
                            '1 vacant from {d}', {'d': fmtDate(t.vacantFrom!)}),
                    color: moveOutPending(t, today) ? _red : AppColors.purple,
                  ),
                if (billDue > 0)
                  StatusChip(
                      context.tr('⚡ Bill {a} pending', {'a': money(billDue)}),
                      color: _red),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: beds == 0 ? 0 : (filled / beds).clamp(0, 1),
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Text(
                      context.tr(
                          '{n} of {b} beds filled', {'n': filled, 'b': beds}),
                      style: theme.textTheme.bodySmall),
                ),
                Text(context.tr('{a} / bed', {'a': money(room.rent)}),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
