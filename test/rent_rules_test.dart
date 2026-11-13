import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_hostel_management/data/calculations.dart';
import 'package:pg_hostel_management/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test.dart' as w;

Tenant tenant({DateTime? join, DateTime? added, double rent = 6000}) => Tenant(
      id: 't1',
      name: 'Ravi',
      phone: '9876543210',
      rent: rent,
      joinDate: join ?? DateTime(2026, 1, 1),
      createdAt: added ?? DateTime(2026, 1, 1),
    );

Payment rentPayment(DateTime month, double amount) => Payment(
      id: 'p${month.month}',
      tenantId: 't1',
      amount: amount,
      type: PaymentType.rent,
      month: month,
      date: DateTime(2026, 11, 2),
    );

void main() {
  group('End of month, 5 days to pay (owner example)', () {
    const rules = RentRules(cycle: RentCycle.monthEnd, dueDays: 5);
    final oct = DateTime(2026, 10);

    test('October rent: collect from 31 Oct, due by 5 Nov', () {
      expect(rules.collectFrom(oct), DateTime(2026, 10, 31));
      expect(rules.dueDate(oct), DateTime(2026, 11, 5));
    });

    test('Between 31 Oct and 5 Nov, the rent being collected is October', () {
      expect(rules.currentRentMonth(DateTime(2026, 10, 31)), oct);
      expect(rules.currentRentMonth(DateTime(2026, 11, 3)), oct);
      expect(rules.currentRentMonth(DateTime(2026, 11, 13)), oct);
      expect(rules.currentRentMonth(DateTime(2026, 11, 30)),
          DateTime(2026, 11));
    });

    test('1-5 Nov unpaid = "Due"; from 6 Nov = OVERDUE', () {
      DueStatus on(DateTime day) =>
          dueOf(tenant(), oct, const [], rules, day).status;
      expect(on(DateTime(2026, 10, 20)), DueStatus.upcoming);
      expect(on(DateTime(2026, 11, 1)), DueStatus.due);
      expect(on(DateTime(2026, 11, 5)), DueStatus.due); // last day is fine
      expect(on(DateTime(2026, 11, 6)), DueStatus.overdue);
      final d = dueOf(tenant(), oct, const [], rules, DateTime(2026, 11, 13));
      expect(d.daysOverdue, 8);
      expect(d.label, 'Overdue 8 days');
    });

    test('Paying clears it; partial payment stays overdue', () {
      final day = DateTime(2026, 11, 13);
      expect(dueOf(tenant(), oct, [rentPayment(oct, 6000)], rules, day).status,
          DueStatus.paid);
      final partial = dueOf(tenant(), oct, [rentPayment(oct, 4000)], rules, day);
      expect(partial.status, DueStatus.overdue);
      expect(partial.due, 2000);
    });
  });

  group('Start of month, 5 days to pay', () {
    const rules = RentRules(cycle: RentCycle.monthStart, dueDays: 5);
    final nov = DateTime(2026, 11);

    test('November rent: collect from 1 Nov, due by 5 Nov', () {
      expect(rules.collectFrom(nov), DateTime(2026, 11, 1));
      expect(rules.dueDate(nov), DateTime(2026, 11, 5));
      expect(rules.currentRentMonth(DateTime(2026, 11, 13)), nov);
    });

    test('Tenant joining 20 Nov gets 5 days from joining, not overdue at once',
        () {
      final t = tenant(join: DateTime(2026, 11, 20), added: DateTime(2026, 11, 20));
      final d = dueOf(t, nov, const [], rules, DateTime(2026, 11, 22));
      expect(d.dueDate, DateTime(2026, 11, 25));
      expect(d.status, DueStatus.due);
    });
  });

  group('Overdue from earlier months', () {
    const rules = RentRules(cycle: RentCycle.monthStart, dueDays: 5);

    test('Unpaid Sep, Oct and Nov are all overdue on 13 Nov', () {
      final list = overdueRent(
          [tenant(join: DateTime(2026, 9, 1), added: DateTime(2026, 9, 1))],
          [],
          rules,
          DateTime(2026, 11, 13));
      expect(list.map((d) => d.month.month), [9, 10, 11]);
    });

    test('Months before the tenant was added to the app are not counted', () {
      // Joined in January, but only added to the app on 10 Nov.
      final list = overdueRent(
          [tenant(join: DateTime(2026, 1, 1), added: DateTime(2026, 11, 10))],
          [],
          rules,
          DateTime(2026, 11, 13));
      expect(list.map((d) => d.month.month), [11]);
    });
  });

  testWidgets('Home shows red overdue alert and Payments tab badge',
      (tester) async {
    final now = DateTime.now();
    final added = DateTime(now.year, now.month - 3, 1);
    SharedPreferences.setMockInitialValues({
      'profile': jsonEncode({'pgName': 'Test PG', 'rentCycle': 'monthStart', 'dueDays': 5}),
      'tenants': jsonEncode([
        {
          'id': 't1',
          'name': 'Ravi Kumar',
          'phone': '9876543210',
          'rent': 6000,
          'joinDate': added.toIso8601String(),
          'createdAt': added.toIso8601String(),
        }
      ]),
    });
    await w.pumpApp(tester);
    expect(find.textContaining('not paid ·'), findsOneWidget);
    expect(find.textContaining('overdue'), findsWidgets);
    expect(find.text('View overdue'), findsOneWidget);
    expect(find.byType(Badge), findsOneWidget); // on Payments tab
    expect(find.textContaining('Overdue'), findsWidgets); // chip in list
    expect(tester.takeException(), isNull);
  });
}
