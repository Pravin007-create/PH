import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_hostel_management/core/format.dart';
import 'package:pg_hostel_management/data/calculations.dart';
import 'package:pg_hostel_management/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test.dart' as w;

void main() {
  const rules = RentRules(cycle: RentCycle.monthStart, dueDays: 5);
  final t = Tenant(
    id: 't1',
    name: 'Ravi',
    phone: '9876543210',
    rent: 6000,
    deposit: 10000,
    joinDate: DateTime(2026, 9, 1),
    createdAt: DateTime(2026, 9, 1),
  );
  final leave = DateTime(2026, 11, 20);

  test('Pending rent at move-out: every unpaid month up to leaving month', () {
    final paidSep = Payment(
        id: 'p',
        tenantId: 't1',
        amount: 6000,
        type: PaymentType.rent,
        month: DateTime(2026, 9),
        date: DateTime(2026, 9, 2));
    final rent = unpaidRentUntil(t, leave, [paidSep], rules);
    expect(rent.map((d) => d.month.month), [10, 11]); // Oct + Nov
  });

  test('Advance 10,000 − rent 6,000 − cleaning 500 = refund 3,500', () {
    final rent = unpaidRentUntil(t, leave, const [], rules)
        .where((d) => d.month.month == 11)
        .toList();
    final r = settle(
      tenant: t,
      date: leave,
      deposit: 10000,
      rent: rent,
      deductions: const [Deduction('Cleaning', 500)],
      idGen: () => 'x',
    );
    expect(r.settlement.refund, 3500);
    expect(r.settlement.stillOwed, 0);
    expect(r.settlement.rentAdjusted, 6000);
    // Rent cleared from the advance is recorded as a rent payment.
    expect(r.payments.where((p) => p.type == PaymentType.rent).single.amount,
        6000);
    expect(r.payments.every((p) => p.mode == adjustedFromDeposit), isTrue);
  });

  test('Advance not enough: oldest month cleared first, rest still owed', () {
    // Sep, Oct, Nov unpaid = 18,000; advance 10,000.
    final rent = unpaidRentUntil(t, leave, const [], rules);
    final r = settle(
        tenant: t, date: leave, deposit: 10000, rent: rent, idGen: () => 'x');
    expect(r.settlement.refund, 0);
    expect(r.settlement.stillOwed, 8000);
    final byMonth = {for (final p in r.payments) p.month.month: p.amount};
    expect(byMonth, {9: 6000, 10: 4000}); // Nov not covered
  });

  test('Cash collected now covers the shortfall', () {
    final rent = unpaidRentUntil(t, leave, const [], rules);
    final r = settle(
        tenant: t,
        date: leave,
        deposit: 10000,
        collectedNow: 8000,
        rent: rent,
        idGen: () => 'x');
    expect(r.settlement.stillOwed, 0);
    expect(r.settlement.refund, 0);
  });

  test('Waived months are not counted as pending or overdue later', () {
    final moved = t.copyWith(
      leaveDate: leave,
      settlement: Settlement(
        date: leave,
        deposit: 10000,
        rentAdjusted: 0,
        rentMonths: const [],
        refund: 10000,
        waivedMonths: [DateTime(2026, 9), DateTime(2026, 10), DateTime(2026, 11)],
      ),
    );
    expect(unpaidRentUntil(moved, leave, const [], rules), isEmpty);
    expect(overdueRent([moved], const [], rules, DateTime(2026, 12, 20)),
        isEmpty);
  });

  testWidgets('Move-out screen: settle advance, refund, tenant closed',
      (tester) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).toIso8601String();
    SharedPreferences.setMockInitialValues({
      'profile': jsonEncode({'pgName': 'Test PG'}),
      'tenants': jsonEncode([
        {
          'id': 't1',
          'name': 'Ravi Kumar',
          'phone': '9876543210',
          'rent': 6000,
          'deposit': 10000,
          'joinDate': start,
          'createdAt': start,
        }
      ]),
    });
    await w.pumpApp(tester);
    await w.tapOn(tester, find.text('Tenants'));
    await w.tapOn(tester, find.text('Ravi Kumar'));
    await w.tapOn(tester, find.text('Move out'));

    // Pending rent picked up automatically; refund = 10,000 − 6,000.
    expect(find.text('${fmtMonth(DateTime(now.year, now.month))} rent'),
        findsOneWidget);
    expect(find.text('Refund to tenant'), findsOneWidget);
    expect(find.text(money(4000)), findsWidgets);

    // Add a cleaning deduction of 500 → refund 3,500.
    await w.tapOn(tester, find.text('Cleaning'));
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '500');
    await tester.pumpAndSettle();
    expect(find.text(money(3500)), findsWidgets);
    expect(tester.takeException(), isNull);

    await w.tapOn(tester, find.textContaining('Confirm · Refund'));
    await w.tapOn(tester, find.text('Confirm move-out'));

    // Back on tenant page: moved out, settlement shown.
    expect(find.textContaining('Move-out settlement'), findsOneWidget);
    expect(find.text('Refunded to tenant'), findsOneWidget);
    expect(find.text('Move back in'), findsOneWidget);
    expect(find.text('Download settlement PDF'), findsOneWidget);
  });
}
