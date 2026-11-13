import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pg_hostel_management/features/bed_management/models/bed.dart';
import 'package:pg_hostel_management/features/bed_management/providers/bed_provider.dart';
import 'package:pg_hostel_management/features/expenses/models/expense.dart';
import 'package:pg_hostel_management/features/expenses/providers/expense_provider.dart';
import 'package:pg_hostel_management/features/rent_payment/models/rent_payment.dart';
import 'package:pg_hostel_management/features/rent_payment/providers/rent_payment_provider.dart';
import 'package:pg_hostel_management/features/room_management/providers/room_provider.dart';
import 'package:pg_hostel_management/features/tenant_management/providers/tenant_provider.dart';

/// Summary figures computed from the other feature providers.
final dashboardProvider = Provider<Map<String, dynamic>>((ref) {
  final rooms = ref.watch(roomProvider);
  final beds = ref.watch(bedProvider);
  final tenants = ref.watch(tenantProvider);
  final payments = ref.watch(rentPaymentProvider);
  final expenses = ref.watch(expenseProvider);

  final recentPayments = [...payments]
    ..sort((RentPayment a, RentPayment b) => b.paymentDate.compareTo(a.paymentDate));
  final recentExpenses = [...expenses]
    ..sort((Expense a, Expense b) => b.date.compareTo(a.date));

  return {
    'totalRooms': rooms.length,
    'totalBeds': beds.length,
    'availableBeds': beds.where((b) => b.status == BedStatus.available).length,
    'occupiedBeds': beds.where((b) => b.status == BedStatus.occupied).length,
    'totalTenants': tenants.length,
    'monthlyRevenue': rooms.fold<double>(0, (sum, r) => sum + r.monthlyRent),
    'outstandingBalance':
        tenants.fold<double>(0, (sum, t) => sum + t.outstandingBalance),
    'recentPayments': recentPayments.take(5).toList(),
    'recentExpenses': recentExpenses.take(5).toList(),
  };
});
