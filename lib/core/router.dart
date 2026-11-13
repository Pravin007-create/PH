import 'package:go_router/go_router.dart';
import 'package:pg_hostel_management/features/activation/activation_screen.dart';
import 'features/pg_profile/pg_profile_screen.dart';
import 'features/room_management/room_management_screen.dart';
import 'features/bed_management/bed_management_screen.dart';
import 'features/tenant_management/tenant_management_screen.dart';
import 'features/rent_payment/rent_payment_screen.dart';
import 'features/electricity_bills/electricity_bills_screen.dart';
import 'features/expenses/expenses_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/backup_restore/backup_restore_screen.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const PGHostelApp(
        isActivated: true,
        database: null,
      ),
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/activation',
      builder: (context, state) => const activation.ActivationScreen(),
    ),
    GoRoute(
      path: '/pg-profile',
      builder: (context, state) => const PGProfileScreen(),
    ),
    GoRoute(
      path: '/room-management',
      builder: (context, state) => const RoomManagementScreen(),
    ),
    GoRoute(
      path: '/bed-management',
      builder: (context, state) => const BedManagementScreen(),
    ),
    GoRoute(
      path: '/tenant-management',
      builder: (context, state) => const TenantManagementScreen(),
    ),
    GoRoute(
      path: '/rent-payment',
      builder: (context, state) => const RentPaymentScreen(),
    ),
    GoRoute(
      path: '/electricity-bills',
      builder: (context, state) => const ElectricityBillsScreen(),
    ),
    GoRoute(
      path: '/expenses',
      builder: (context, state) => const ExpensesScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/backup-restore',
      builder: (context, state) => const BackupRestoreScreen(),
    ),
  ],
  initialLocation: '/',
);