import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom tab bar on phones, side rail on tablets.
class AppShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 840;

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
                    for (final t in _tabs)
                      NavigationRailDestination(
                        icon: Icon(t.$1),
                        selectedIcon: Icon(t.$2),
                        label: Text(t.$3),
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
                  for (final t in _tabs)
                    NavigationDestination(
                      icon: Icon(t.$1),
                      selectedIcon: Icon(t.$2),
                      label: t.$3,
                    ),
                ],
              ),
      ),
    );
  }
}
