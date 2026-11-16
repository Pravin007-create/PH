import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/calculations.dart';

/// Bottom tab bar on phones, side rail on tablets.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _tabs = [
    (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home'),
    (Icons.meeting_room_outlined, Icons.meeting_room_rounded, 'Rooms'),
    (Icons.people_outline_rounded, Icons.people_rounded, 'Tenants'),
    (Icons.payments_outlined, Icons.payments_rounded, 'Payments'),
    (Icons.grid_view_outlined, Icons.grid_view_rounded, 'More'),
  ];

  void _go(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= 840;
    final overdueCount =
        ref.watch(overdueProvider).map((d) => d.tenant.id).toSet().length;

    // Red badge with the number of overdue tenants on the Payments tab.
    Widget icon(int i, IconData data) => i == 3 && overdueCount > 0
        ? Badge(label: Text('$overdueCount'), child: Icon(data))
        : Icon(data);

    // Back on any tab other than Home goes to Home instead of closing the app.
    return PopScope(
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: isWide
            ? Row(children: [
                NavigationRail(
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: _go,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final (i, t) in _tabs.indexed)
                      NavigationRailDestination(
                        icon: icon(i, t.$1),
                        selectedIcon: icon(i, t.$2),
                        label: Text(context.tr(t.$3)),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: shell),
              ])
            : shell,
        bottomNavigationBar: isWide
            ? null
            : NavigationBar(
                selectedIndex: shell.currentIndex,
                onDestinationSelected: _go,
                destinations: [
                  for (final (i, t) in _tabs.indexed)
                    NavigationDestination(
                      icon: icon(i, t.$1),
                      selectedIcon: icon(i, t.$2),
                      label: context.tr(t.$3),
                    ),
                ],
              ),
      ),
    );
  }
}
