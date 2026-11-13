import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import 'models.dart';
import 'store.dart';

/// Pure calculations shared by the dashboard, screens and PDF reports.

/// Was the tenant staying at any point during [month]?
bool stayedIn(Tenant t, DateTime month) {
  final start = monthOf(month);
  final end = addMonths(start, 1);
  return t.joinDate.isBefore(end) &&
      (t.leaveDate == null || !t.leaveDate!.isBefore(start));
}

class TenantDue {
  const TenantDue(this.tenant, this.paid);
  final Tenant tenant;
  final double paid;
  double get due => max(0, tenant.rent - paid);
  bool get isPaid => due <= 0;
}

/// Rent status of every tenant who stayed during [month].
List<TenantDue> rentStatusFor(
    DateTime month, List<Tenant> tenants, List<Payment> payments) {
  final list = <TenantDue>[];
  for (final t in tenants.where((t) => stayedIn(t, month))) {
    final paid = payments
        .where((p) =>
            p.tenantId == t.id &&
            p.type == PaymentType.rent &&
            sameMonth(p.month, month))
        .fold<double>(0, (s, p) => s + p.amount);
    list.add(TenantDue(t, paid));
  }
  list.sort((a, b) => b.due.compareTo(a.due));
  return list;
}

class MonthSummary {
  MonthSummary({
    required this.month,
    required this.rentExpected,
    required this.rentCollected,
    required this.otherIncome,
    required this.expenses,
    required this.totalBeds,
    required this.occupiedBeds,
    required this.activeTenants,
    required this.dues,
    required this.expenseByCategory,
  });

  final DateTime month;
  final double rentExpected;
  final double rentCollected;
  final double otherIncome;
  final double expenses;
  final int totalBeds;
  final int occupiedBeds;
  final int activeTenants;
  final List<TenantDue> dues;
  final Map<String, double> expenseByCategory;

  double get totalIncome => rentCollected + otherIncome;
  double get net => totalIncome - expenses;
  double get pendingRent => max(0, rentExpected - rentCollected);
  int get vacantBeds => max(0, totalBeds - occupiedBeds);
  List<TenantDue> get unpaid => dues.where((d) => !d.isPaid).toList();
  double get collectionRate =>
      rentExpected <= 0 ? 0 : (rentCollected / rentExpected).clamp(0, 1);
}

MonthSummary summarize(DateTime month, List<Room> rooms, List<Tenant> tenants,
    List<Payment> payments, List<Expense> expenses) {
  final dues = rentStatusFor(month, tenants, payments);
  final monthPayments = payments.where((p) => sameMonth(p.month, month));
  final monthExpenses = expenses.where((e) => sameMonth(e.date, month));
  final byCategory = <String, double>{};
  for (final e in monthExpenses) {
    byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
  }
  return MonthSummary(
    month: monthOf(month),
    rentExpected: dues.fold(0, (s, d) => s + d.tenant.rent),
    rentCollected: dues.fold(0, (s, d) => s + min(d.paid, d.tenant.rent)),
    otherIncome: monthPayments
        .where((p) => p.type != PaymentType.rent)
        .fold(0, (s, p) => s + p.amount),
    expenses: monthExpenses.fold(0, (s, e) => s + e.amount),
    totalBeds: rooms.fold(0, (s, r) => s + r.beds),
    occupiedBeds: tenants.where((t) => t.isActive && t.roomId != null).length,
    activeTenants: tenants.where((t) => t.isActive).length,
    dues: dues,
    expenseByCategory: byCategory,
  );
}

/// Active tenants per room id.
Map<String, int> occupancyByRoom(List<Tenant> tenants) {
  final map = <String, int>{};
  for (final t in tenants.where((t) => t.isActive && t.roomId != null)) {
    map[t.roomId!] = (map[t.roomId!] ?? 0) + 1;
  }
  return map;
}

/// Summary for any month, kept up to date as data changes.
final monthSummaryProvider =
    Provider.family<MonthSummary, DateTime>((ref, month) {
  return summarize(
    month,
    ref.watch(roomsProvider),
    ref.watch(tenantsProvider),
    ref.watch(paymentsProvider),
    ref.watch(expensesProvider),
  );
});
