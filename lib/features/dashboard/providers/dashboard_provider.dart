import 'package:pg_hostel_management/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/securestorage/securestorage_service.dart';

final dashboardProvider = StateNotifierProvider<DashboardNotifier, Map<String, dynamic>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final storage = ref.read(secureStorageServiceProvider);
  return DashboardNotifier(db, storage);
});

class DashboardNotifier extends StateNotifier<Map<String, dynamic>> {
  final AppDatabase _db;
  final SecureStorageService _storage;

  DashboardNotifier(this._db, this._storage) : super(_initialDashboard);

  static Map<String, dynamic> get _initialDashboard => {
    'totalRooms': 0,
    'totalBeds': 0,
    'availableBeds': 0,
    'occupiedBeds': 0,
    'totalTenants': 0,
    'monthlyRevenue': 0.0,
    'outstandingBalance': 0.0,
    'recentPayments': [],
    'recentExpenses': [],
  };

  void loadData() async {
    // Load data from database
    final rooms = await _db.readAllRooms();
    final beds = await _db.readAllBeds();
    final tenants = await _db.readAllTenants();
    final payments = await _db.readAllRentPayments();
    final expenses = await _db.readAllExpenses();

    final totalRooms = rooms.length;
    final totalBeds = beds.length;
    final availableBeds = beds.where((b) => b.status == BedStatus.available.name).length;
    final occupiedBeds = beds.where((b) => b.status == BedStatus.occupied.name).length;
    final totalTenants = tenants.length;
    final monthlyRevenue = _calculateMonthlyRevenue(rooms);
    final outstandingBalance = _calculateOutstandingBalance(tenants);

    state = {
      ...state,
      'totalRooms': totalRooms,
      'totalBeds': totalBeds,
      'availableBeds': availableBeds,
      'occupiedBeds': occupiedBeds,
      'totalTenants': totalTenants,
      'monthlyRevenue': monthlyRevenue,
      'outstandingBalance': outstandingBalance,
      'recentPayments': _getRecentPayments(payments),
      'recentExpenses': _getRecentExpenses(expenses),
    };
  }

  double _calculateMonthlyRevenue(List<Room> rooms) {
    return rooms.fold(0.0, (sum, room) => sum + room.monthlyRent);
  }

  double _calculateOutstandingBalance(List<Tenant> tenants) {
    return tenants.fold(0.0, (sum, tenant) => sum + tenant.outstandingBalance);
  }

  List _getRecentPayments(List<RentPayment> payments) {
    return payments
        .sort((a, b) => b.paymentDate.compareTo(a.paymentDate))
        .take(5)
        .toList();
  }

  List _getRecentExpenses(List<Expense> expenses) {
    return expenses
        .sort((a, b) => b.date.compareTo(a.date))
        .take(5)
        .toList();
  }
}