import 'package:go_router/go_router.dart';
import 'package:pg_hostel_management/core/password_gate.dart';
import 'package:pg_hostel_management/features/activation/screens/activation_screen.dart';
import 'package:pg_hostel_management/features/backup_restore/screens/backup_restore_screen.dart';
import 'package:pg_hostel_management/features/bed_management/screens/bed_management_screen.dart';
import 'package:pg_hostel_management/features/dashboard/screens/dashboard_screen.dart';
import 'package:pg_hostel_management/features/electricity_bills/screens/electricity_bills_screen.dart';
import 'package:pg_hostel_management/features/expenses/screens/expenses_screen.dart';
import 'package:pg_hostel_management/features/home/home_screen.dart';
import 'package:pg_hostel_management/features/pg_profile/screens/pg_profile_screen.dart';
import 'package:pg_hostel_management/features/rent_payment/screens/rent_payment_screen.dart';
import 'package:pg_hostel_management/features/room_management/screens/room_management_screen.dart';
import 'package:pg_hostel_management/features/tenant_management/screens/tenant_management_screen.dart';

export 'package:go_router/go_router.dart';

/// Whether the developer password has been entered on this device.
/// Set in main() from secure storage and by [PasswordGate] on success.
class AuthState {
  static bool passwordVerified = false;
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final atGate = state.matchedLocation == '/password';
    if (!AuthState.passwordVerified && !atGate) return '/password';
    if (AuthState.passwordVerified && atGate) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/password', builder: (context, state) => const PasswordGate()),
    GoRoute(path: '/activation', builder: (context, state) => const ActivationScreen()),
    GoRoute(path: '/pg-profile', builder: (context, state) => const PGProfileScreen()),
    GoRoute(path: '/room-management', builder: (context, state) => const RoomManagementScreen()),
    GoRoute(path: '/bed-management', builder: (context, state) => const BedManagementScreen()),
    GoRoute(path: '/tenant-management', builder: (context, state) => const TenantManagementScreen()),
    GoRoute(path: '/rent-payment', builder: (context, state) => const RentPaymentScreen()),
    GoRoute(path: '/electricity-bills', builder: (context, state) => const ElectricityBillsScreen()),
    GoRoute(path: '/expenses', builder: (context, state) => const ExpensesScreen()),
    GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
    GoRoute(path: '/backup-restore', builder: (context, state) => const BackupRestoreScreen()),
  ],
);
