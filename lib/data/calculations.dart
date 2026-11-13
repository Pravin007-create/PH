import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import 'models.dart';
import 'store.dart';

/// Pure calculations shared by the dashboard, screens and PDF reports.

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The PG's rent collection rules (from PG Details).
class RentRules {
  const RentRules({this.cycle = RentCycle.monthStart, this.dueDays = 5});

  factory RentRules.of(PgProfile p) =>
      RentRules(cycle: p.rentCycle, dueDays: p.dueDays);

  final RentCycle cycle;
  final int dueDays;

  /// First day rent for [month] can be collected.
  /// Start: 1 Nov for November. End: 31 Oct for October.
  DateTime collectFrom(DateTime month) => cycle == RentCycle.monthStart
      ? DateTime(month.year, month.month, 1)
      : DateTime(month.year, month.month + 1, 0); // last day of month

  /// Last day to pay rent for [month] without being overdue.
  /// Start + 5: 5 Nov for November. End + 5: 5 Nov for October.
  DateTime dueDate(DateTime month) => cycle == RentCycle.monthStart
      ? DateTime(month.year, month.month, dueDays)
      : DateTime(month.year, month.month + 1, dueDays);

  /// The rent month currently being collected on [today].
  /// End-of-month PGs collect the previous month's rent until the last day
  /// of the current month.
  DateTime currentRentMonth(DateTime today) {
    final m = monthOf(today);
    if (cycle == RentCycle.monthStart) return m;
    return dateOnly(today) == collectFrom(m) ? m : addMonths(m, -1);
  }

  /// Due date for one tenant: someone who joins after collection started
  /// gets [dueDays] days from their joining date instead.
  DateTime dueDateFor(Tenant t, DateTime month) {
    final base = dueDate(month);
    final join = dateOnly(t.joinDate);
    if (join.isAfter(collectFrom(month))) {
      final fromJoin = join.add(Duration(days: dueDays));
      if (fromJoin.isAfter(base)) return fromJoin;
    }
    return base;
  }

  /// "Rent for October is collected from 31 Oct and due by 5 Nov."
  String describe(DateTime month) =>
      'Rent for ${fmtMonth(month)} is collected from '
      '${fmtDate(collectFrom(month))} and due by ${fmtDate(dueDate(month))}.';
}

/// Rent for [month] was waived at move-out.
bool isWaived(Tenant t, DateTime month) =>
    t.settlement?.waivedMonths.any((m) => sameMonth(m, month)) ?? false;

/// Was the tenant staying (and charged rent) at any point during [month]?
bool stayedIn(Tenant t, DateTime month) {
  final start = monthOf(month);
  final end = addMonths(start, 1);
  return t.joinDate.isBefore(end) &&
      (t.leaveDate == null || !t.leaveDate!.isBefore(start)) &&
      !isWaived(t, month);
}

enum DueStatus {
  paid,

  /// Collection window hasn't started yet.
  upcoming,

  /// In the collection window, before the due date.
  due,

  /// Due date has passed and rent isn't fully paid.
  overdue,
}

class TenantDue {
  const TenantDue({
    required this.tenant,
    required this.month,
    required this.paid,
    required this.collectFrom,
    required this.dueDate,
    required this.today,
  });

  final Tenant tenant;
  final DateTime month;
  final double paid;
  final DateTime collectFrom;
  final DateTime dueDate;
  final DateTime today;

  double get due => max(0, tenant.rent - paid);
  bool get isPaid => due <= 0;
  bool get isPartial => !isPaid && paid > 0;

  DueStatus get status {
    if (isPaid) return DueStatus.paid;
    final t = dateOnly(today);
    if (t.isAfter(dueDate)) return DueStatus.overdue;
    if (t.isBefore(collectFrom)) return DueStatus.upcoming;
    return DueStatus.due;
  }

  bool get isOverdue => status == DueStatus.overdue;
  int get daysOverdue =>
      isOverdue ? dateOnly(today).difference(dueDate).inDays : 0;
  int get daysLeft =>
      status == DueStatus.due ? dueDate.difference(dateOnly(today)).inDays : 0;

  /// Short label for chips: "Overdue 8 days", "Due by 5 Nov", "Paid".
  String get label => switch (status) {
        DueStatus.paid => 'Paid',
        DueStatus.overdue =>
          'Overdue $daysOverdue ${daysOverdue == 1 ? 'day' : 'days'}',
        DueStatus.due => daysLeft == 0
            ? 'Due today'
            : 'Due by ${fmtDate(dueDate).replaceAll(RegExp(r' \d{4}$'), '')}',
        DueStatus.upcoming =>
          'From ${fmtDate(collectFrom).replaceAll(RegExp(r' \d{4}$'), '')}',
      };
}

double _rentPaid(Tenant t, DateTime month, List<Payment> payments) => payments
    .where((p) =>
        p.tenantId == t.id &&
        p.type == PaymentType.rent &&
        sameMonth(p.month, month))
    .fold<double>(0, (s, p) => s + p.amount);

TenantDue dueOf(Tenant t, DateTime month, List<Payment> payments,
        RentRules rules, DateTime today) =>
    TenantDue(
      tenant: t,
      month: monthOf(month),
      paid: _rentPaid(t, month, payments),
      collectFrom: rules.collectFrom(month),
      dueDate: rules.dueDateFor(t, month),
      today: today,
    );

/// Rent status of every tenant who stayed during [month].
/// Sorted: overdue first (longest first), then due, upcoming, paid.
List<TenantDue> rentStatusFor(DateTime month, List<Tenant> tenants,
    List<Payment> payments, RentRules rules, DateTime today) {
  final list = [
    for (final t in tenants.where((t) => stayedIn(t, month)))
      dueOf(t, month, payments, rules, today)
  ];
  list.sort((a, b) {
    final s = a.status.index.compareTo(b.status.index);
    if (s != 0) {
      // overdue (3) > due (2) > upcoming (1) > paid (0)
      return -s;
    }
    return b.due.compareTo(a.due);
  });
  return list;
}

/// Every unpaid month whose due date has passed, across all months since
/// each tenant was added to the app. Oldest first.
List<TenantDue> overdueRent(List<Tenant> tenants, List<Payment> payments,
    RentRules rules, DateTime today) {
  final current = rules.currentRentMonth(today);
  final result = <TenantDue>[];
  for (final t in tenants) {
    final joined = monthOf(t.joinDate);
    final tracked = rules.currentRentMonth(t.addedOn);
    var m = joined.isAfter(tracked) ? joined : tracked;
    while (!m.isAfter(current)) {
      if (stayedIn(t, m)) {
        final d = dueOf(t, m, payments, rules, today);
        if (d.isOverdue) result.add(d);
      }
      m = addMonths(m, 1);
    }
  }
  result.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return result;
}

class MonthSummary {
  MonthSummary({
    required this.month,
    required this.rules,
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
  final RentRules rules;
  final double rentExpected;
  final double rentCollected;
  final double otherIncome;
  final double expenses;
  final int totalBeds;
  final int occupiedBeds;
  final int activeTenants;
  final List<TenantDue> dues;
  final Map<String, double> expenseByCategory;

  DateTime get dueDate => rules.dueDate(month);
  DateTime get collectFrom => rules.collectFrom(month);
  double get totalIncome => rentCollected + otherIncome;
  double get net => totalIncome - expenses;
  double get pendingRent => max(0, rentExpected - rentCollected);
  int get vacantBeds => max(0, totalBeds - occupiedBeds);
  List<TenantDue> get unpaid => dues.where((d) => !d.isPaid).toList();
  List<TenantDue> get overdue => dues.where((d) => d.isOverdue).toList();
  double get overdueAmount => overdue.fold(0, (s, d) => s + d.due);
  double get collectionRate =>
      rentExpected <= 0 ? 0 : (rentCollected / rentExpected).clamp(0, 1);
}

MonthSummary summarize(DateTime month, List<Room> rooms, List<Tenant> tenants,
    List<Payment> payments, List<Expense> expenses,
    {RentRules rules = const RentRules(), DateTime? today}) {
  final now = today ?? DateTime.now();
  final dues = rentStatusFor(month, tenants, payments, rules, now);
  final monthPayments = payments.where((p) => sameMonth(p.month, month));
  final monthExpenses = expenses.where((e) => sameMonth(e.date, month));
  final byCategory = <String, double>{};
  for (final e in monthExpenses) {
    byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
  }
  return MonthSummary(
    month: monthOf(month),
    rules: rules,
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

final rentRulesProvider =
    Provider<RentRules>((ref) => RentRules.of(ref.watch(profileProvider)));

/// The rent month being collected today (e.g. October, on 3 November, for
/// an end-of-month PG).
final currentRentMonthProvider = Provider<DateTime>(
    (ref) => ref.watch(rentRulesProvider).currentRentMonth(DateTime.now()));

/// Summary for any month, kept up to date as data changes.
final monthSummaryProvider =
    Provider.family<MonthSummary, DateTime>((ref, month) {
  return summarize(
    month,
    ref.watch(roomsProvider),
    ref.watch(tenantsProvider),
    ref.watch(paymentsProvider),
    ref.watch(expensesProvider),
    rules: ref.watch(rentRulesProvider),
  );
});

/// All overdue rent (this and earlier months).
final overdueProvider = Provider<List<TenantDue>>((ref) => overdueRent(
      ref.watch(tenantsProvider),
      ref.watch(paymentsProvider),
      ref.watch(rentRulesProvider),
      DateTime.now(),
    ));

// ---------------------------------------------------------------------------
// Move-out settlement
// ---------------------------------------------------------------------------

/// Every month with rent still unpaid for [t], up to the month they leave
/// (they stayed part of that month, so it is owed). Oldest first.
/// Months before the tenant was added to the app are skipped.
List<TenantDue> unpaidRentUntil(
    Tenant t, DateTime leaveDate, List<Payment> payments, RentRules rules) {
  final last = monthOf(leaveDate);
  final joined = monthOf(t.joinDate);
  final tracked = rules.currentRentMonth(t.addedOn);
  var m = joined.isAfter(tracked) ? joined : tracked;
  final result = <TenantDue>[];
  while (!m.isAfter(last)) {
    final d = dueOf(t, m, payments, rules, leaveDate);
    if (!d.isPaid && !isWaived(t, m)) result.add(d);
    m = addMonths(m, 1);
  }
  return result;
}

class SettlementResult {
  const SettlementResult(this.settlement, this.payments);
  final Settlement settlement;

  /// Payments to record: rent and deductions cleared from the advance.
  final List<Payment> payments;
}

/// Uses the advance (+ any cash collected now) to clear [rent] months oldest
/// first, then [deductions]. What remains is refunded to the tenant.
SettlementResult settle({
  required Tenant tenant,
  required DateTime date,
  required double deposit,
  double collectedNow = 0,
  required List<TenantDue> rent,
  List<Deduction> deductions = const [],
  List<DateTime> waivedMonths = const [],
  String Function()? idGen,
}) {
  var id = 0;
  String nextId() => idGen?.call() ?? '${newId()}_${id++}';
  var available = deposit + collectedNow;
  final payments = <Payment>[];
  var rentAdjusted = 0.0;
  final months = <String>[];
  var owed = 0.0;

  final sorted = [...rent]..sort((a, b) => a.month.compareTo(b.month));
  for (final d in sorted) {
    final take = min(available, d.due);
    if (take > 0) {
      payments.add(Payment(
        id: nextId(),
        tenantId: tenant.id,
        amount: take,
        type: PaymentType.rent,
        month: d.month,
        date: date,
        mode: adjustedFromDeposit,
        note: 'Move-out settlement',
      ));
      rentAdjusted += take;
      months.add(fmtMonth(d.month));
      available -= take;
    }
    owed += d.due - take;
  }

  for (final x in deductions.where((x) => x.amount > 0)) {
    final take = min(available, x.amount);
    if (take > 0) {
      payments.add(Payment(
        id: nextId(),
        tenantId: tenant.id,
        amount: take,
        type: x.type ?? PaymentType.other,
        month: x.month ?? monthOf(date),
        date: date,
        mode: adjustedFromDeposit,
        note: 'Move-out: ${x.label}',
      ));
      available -= take;
    }
    owed += x.amount - take;
  }

  return SettlementResult(
    Settlement(
      date: date,
      deposit: deposit,
      collectedNow: collectedNow,
      rentAdjusted: rentAdjusted,
      rentMonths: months,
      deductions: deductions.where((x) => x.amount > 0).toList(),
      refund: available,
      stillOwed: owed,
      waivedMonths: waivedMonths,
    ),
    payments,
  );
}

// ---------------------------------------------------------------------------
// Electricity (rooms billed separately)
// ---------------------------------------------------------------------------

/// One tenant's unpaid share of a room electricity bill.
class ElectricityDue {
  const ElectricityDue(this.bill, this.tenant, this.paid);
  final ElectricityBill bill;
  final Tenant tenant;
  final double paid;

  DateTime get month => bill.month;
  double get share => bill.share;
  double get due => max(0, share - paid);
  bool get isPaid => due < 0.5;
}

/// Electricity paid by [tenantId] for [month].
double electricityPaid(
        String tenantId, DateTime month, List<Payment> payments) =>
    payments
        .where((p) =>
            p.tenantId == tenantId &&
            p.type == PaymentType.electricity &&
            sameMonth(p.month, month))
        .fold(0.0, (s, p) => s + p.amount);

/// Each tenant's share of every bill (paid and unpaid), newest month first.
/// Several bills for the same tenant and month are combined against the
/// electricity payments for that month.
List<ElectricityDue> electricityShares(
    List<ElectricityBill> bills, List<Tenant> tenants, List<Payment> payments) {
  final byId = {for (final t in tenants) t.id: t};
  final sorted = [...bills]..sort((a, b) {
      final c = b.month.compareTo(a.month);
      return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
    });
  // Payments for a tenant+month are used up bill by bill.
  final left = <String, double>{};
  final result = <ElectricityDue>[];
  for (final b in sorted) {
    for (final id in b.tenantIds) {
      final t = byId[id];
      if (t == null) continue;
      final key = '$id|${b.month.year}-${b.month.month}';
      final available = left[key] ?? electricityPaid(id, b.month, payments);
      final used = min(available, b.share);
      left[key] = available - used;
      result.add(ElectricityDue(b, t, used));
    }
  }
  return result;
}

/// Unpaid electricity shares only.
List<ElectricityDue> electricityDues(List<ElectricityBill> bills,
        List<Tenant> tenants, List<Payment> payments) =>
    electricityShares(bills, tenants, payments)
        .where((d) => !d.isPaid)
        .toList();

/// Tenants staying in [roomId] at any point during [month].
List<Tenant> tenantsInRoomFor(
        String roomId, DateTime month, List<Tenant> tenants) =>
    tenants.where((t) {
      if (t.roomId != roomId) return false;
      final start = monthOf(month);
      final end = addMonths(start, 1);
      return t.joinDate.isBefore(end) &&
          (t.leaveDate == null || !t.leaveDate!.isBefore(start));
    }).toList();

final electricityDuesProvider = Provider<List<ElectricityDue>>((ref) =>
    electricityDues(ref.watch(electricityBillsProvider),
        ref.watch(tenantsProvider), ref.watch(paymentsProvider)));
