import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/expenses/expense_form_screen.dart';
import '../features/expenses/expenses_screen.dart';
import '../features/home/home_screen.dart';
import '../features/more/more_screen.dart';
import '../features/more/profile_screen.dart';
import '../features/payments/deleted_payments_screen.dart';
import '../features/payments/payment_detail_screen.dart';
import '../features/payments/payment_form_screen.dart';
import '../features/payments/payments_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/rooms/room_form_screen.dart';
import '../features/rooms/rooms_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/tenants/move_out_screen.dart';
import '../features/tenants/tenant_form_screen.dart';
import '../features/tenants/tenants_screen.dart';
import '../data/models.dart';
import 'password_gate.dart';

export 'package:go_router/go_router.dart';

/// Whether the developer password has been entered on this device.
class AuthState {
  static bool passwordVerified = false;
}

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() => GoRouter(
      navigatorKey: _rootKey,
      initialLocation: '/home',
      redirect: (context, state) {
        final atGate = state.matchedLocation == '/password';
        if (!AuthState.passwordVerified && !atGate) return '/password';
        if (AuthState.passwordVerified && atGate) return '/home';
        if (state.matchedLocation == '/') return '/home';
        return null;
      },
      routes: [
        GoRoute(path: '/', redirect: (_, __) => '/home'),
        GoRoute(path: '/password', builder: (_, __) => const PasswordGate()),

        // Main tabs (bottom navigation bar).
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/rooms', builder: (_, __) => const RoomsScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/tenants', builder: (_, __) => const TenantsScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/payments',
                  builder: (_, __) => const PaymentsScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/more', builder: (_, __) => const MoreScreen()),
            ]),
          ],
        ),

        // Full-screen pages opened on top of the tabs (Back returns).
        GoRoute(path: '/rooms/new', builder: (_, __) => const RoomFormScreen()),
        GoRoute(
            path: '/rooms/:id',
            builder: (_, s) => RoomFormScreen(roomId: s.pathParameters['id'])),
        GoRoute(
            path: '/tenants/new',
            builder: (_, s) =>
                TenantFormScreen(roomId: s.uri.queryParameters['room'])),
        GoRoute(
            path: '/tenants/:id/move-out',
            builder: (_, s) =>
                MoveOutScreen(tenantId: s.pathParameters['id']!)),
        GoRoute(
            path: '/tenants/:id',
            builder: (_, s) =>
                TenantFormScreen(tenantId: s.pathParameters['id'])),
        GoRoute(
            path: '/payments/new',
            builder: (_, s) => PaymentFormScreen(
                  tenantId: s.uri.queryParameters['tenant'],
                  month:
                      DateTime.tryParse(s.uri.queryParameters['month'] ?? ''),
                  type: PaymentType.values
                      .where((t) => t.name == s.uri.queryParameters['type'])
                      .firstOrNull,
                )),
        GoRoute(
            path: '/payments/deleted',
            builder: (_, __) => const DeletedPaymentsScreen()),
        GoRoute(
            path: '/payments/:id',
            builder: (_, s) =>
                PaymentDetailScreen(paymentId: s.pathParameters['id']!)),
        GoRoute(path: '/expenses', builder: (_, __) => const ExpensesScreen()),
        GoRoute(
            path: '/expenses/new',
            builder: (_, __) => const ExpenseFormScreen()),
        GoRoute(
            path: '/expenses/:id',
            builder: (_, s) =>
                ExpenseFormScreen(expenseId: s.pathParameters['id'])),
        GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      ],
    );
