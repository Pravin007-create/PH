import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/calculations.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';

enum _RoomFilter { all, vacant, full }

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  String _query = '';
  _RoomFilter _filter = _RoomFilter.all;

  @override
  Widget build(BuildContext context) {
    final rooms = [...ref.watch(roomsProvider)]
      ..sort((a, b) => a.number.compareTo(b.number));
    final occupancy = occupancyByRoom(ref.watch(tenantsProvider));

    final shown = rooms.where((r) {
      final filled = occupancy[r.id] ?? 0;
      final matches = _query.isEmpty ||
          r.number.toLowerCase().contains(_query.toLowerCase()) ||
          r.floor.toLowerCase().contains(_query.toLowerCase());
      return matches &&
          switch (_filter) {
            _RoomFilter.all => true,
            _RoomFilter.vacant => filled < r.beds,
            _RoomFilter.full => filled >= r.beds,
          };
    }).toList();

    final totalBeds = rooms.fold<int>(0, (s, r) => s + r.beds);
    final filledBeds = occupancy.values.fold<int>(0, (s, n) => s + n);

    return Scaffold(
      appBar: AppBar(title: const Text('Rooms')),
      floatingActionButton: rooms.isEmpty
          ? null
          : AddButton(
              label: 'Add Room', onPressed: () => context.push('/rooms/new')),
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
                        '${rooms.length} rooms · $filledBeds of $totalBeds beds filled',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      SearchField(
                          hint: 'Search room number or floor',
                          onChanged: (v) => setState(() => _query = v)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, children: [
                        for (final f in _RoomFilter.values)
                          ChoiceChip(
                            label: Text(switch (f) {
                              _RoomFilter.all => 'All',
                              _RoomFilter.vacant => 'Has vacancy',
                              _RoomFilter.full => 'Full',
                            }),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      if (shown.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No rooms match your search.',
                              textAlign: TextAlign.center),
                        ),
                      for (final room in shown) ...[
                        _RoomCard(
                          number: room.number,
                          floor: room.floor,
                          isAC: room.isAC,
                          rent: room.rent,
                          beds: room.beds,
                          filled: occupancy[room.id] ?? 0,
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
    required this.number,
    required this.floor,
    required this.isAC,
    required this.rent,
    required this.beds,
    required this.filled,
    required this.onTap,
  });

  final String number;
  final String floor;
  final bool isAC;
  final double rent;
  final int beds;
  final int filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFull = filled >= beds;
    final color = isFull ? AppColors.warning : AppColors.success;
    return Card(
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
                      Text('Room $number',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        [
                          if (floor.isNotEmpty) 'Floor $floor',
                          '$beds-sharing',
                          if (isAC) 'AC',
                        ].join(' · '),
                        style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                StatusChip(
                    isFull ? 'Full' : '${beds - filled} vacant',
                    color: color),
              ]),
              const SizedBox(height: 14),
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
                  child: Text('$filled of $beds beds filled',
                      style: theme.textTheme.bodySmall),
                ),
                Text('${money(rent)} / bed',
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
