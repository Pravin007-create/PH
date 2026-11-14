import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_hostel_management/core/app.dart';
import 'package:pg_hostel_management/core/format.dart';
import 'package:pg_hostel_management/core/router.dart';
import 'package:pg_hostel_management/data/models.dart';
import 'package:pg_hostel_management/data/store.dart';
import 'package:pg_hostel_management/features/reports/report_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpApp(WidgetTester tester,
    {Size size = const Size(360, 740),
    List<Override> overrides = const []}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  AuthState.passwordVerified = true;
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs), ...overrides],
    child: const PGHostelApp(),
  ));
  await tester.pumpAndSettle();
}

/// Taps a widget, scrolling it into view first.
Future<void> tapOn(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> back(WidgetTester tester) async {
  expect(await tester.binding.handlePopRoute(), isTrue,
      reason: 'Back must be handled by the app, not close it');
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Home dashboard shows overview, quick actions and setup steps',
      (tester) async {
    await pumpApp(tester);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Get started in 3 steps'), findsOneWidget);
    expect(find.text('Beds occupied'), findsOneWidget);
    expect(find.text('Pending rent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add Room button opens form, saves, and room appears in list',
      (tester) async {
    await pumpApp(tester);
    await tapOn(tester, find.text('Rooms'));
    expect(find.text('No rooms yet'), findsOneWidget);

    await tapOn(tester, find.text('Add your first room'));
    expect(find.text('Add Room'), findsOneWidget);

    // Saving an empty form shows a message instead of silently doing nothing.
    await tapOn(tester, find.text('Save Room'));
    expect(find.text('Please enter room number'), findsOneWidget);

    await enter(tester, 'Room number *', '101');
    await enter(tester, 'Monthly rent per bed *', '6000');
    await tapOn(tester, find.byTooltip('More beds')); // 2 -> 3 beds
    await tapOn(tester, find.text('Save Room'));

    expect(find.text('Room 101'), findsOneWidget);
    expect(find.text('3 vacant'), findsOneWidget);
    // The labelled "Add Room" button is shown once a room exists.
    expect(
        find.widgetWithText(FloatingActionButton, 'Add Room'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Full flow: room -> tenant -> payment updates dashboard',
      (tester) async {
    await pumpApp(tester);

    // Add a room from the Home quick action.
    await tapOn(tester, find.text('Add Room'));
    await enter(tester, 'Room number *', 'A1');
    await enter(tester, 'Monthly rent per bed *', '5000');
    await tapOn(tester, find.text('Save Room'));
    expect(find.text('Overview'), findsOneWidget); // back on Home

    // Add a tenant in that room.
    await tapOn(tester, find.text('Add Tenant'));
    await enter(tester, 'Full name *', 'Ravi Kumar');
    await enter(tester, 'Mobile number *', '9876543210');
    await tapOn(tester, find.text('No room assigned'));
    await tapOn(tester, find.textContaining('Room A1').last);
    // Rent auto-filled from the room.
    expect(find.widgetWithText(TextFormField, '5000'), findsOneWidget);
    await tapOn(tester, find.text('Save Tenant'));

    expect(find.text(money(5000)), findsWidgets); // pending rent on dashboard
    expect(find.text('Ravi Kumar'), findsOneWidget); // in pending list

    // Collect rent from the dashboard pending list.
    await tapOn(tester, find.text('Collect'));
    // Amount pre-filled with the due amount.
    expect(find.widgetWithText(TextFormField, '5000'), findsOneWidget);
    await tapOn(tester, find.text('UPI'));
    await tapOn(tester, find.text('Save Payment'));

    expect(find.text('All rent collected for this month.'), findsOneWidget);
    expect(find.text('100% collected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back returns one step; on a tab it goes Home, not exit',
      (tester) async {
    await pumpApp(tester);
    await tapOn(tester, find.text('Tenants'));
    await tapOn(tester, find.text('Add your first tenant'));
    expect(find.text('Save Tenant'), findsOneWidget);

    await back(tester); // form -> Tenants tab
    expect(find.text('No tenants yet'), findsOneWidget);

    await back(tester); // Tenants tab -> Home tab
    expect(find.text('Overview'), findsOneWidget);
  });

  for (final tab in ['Home', 'Rooms', 'Tenants', 'Payments', 'More']) {
    testWidgets('$tab tab fits a 320px phone', (tester) async {
      await pumpApp(tester, size: const Size(320, 640));
      await tapOn(tester, find.text(tab).last);
      expect(tester.takeException(), isNull);
    });
  }

  for (final page in [
    ('Add Room', 'Save Room'),
    ('Add Tenant', 'Save Tenant'),
    ('Record Payment', 'Add a tenant first'),
    ('Add Expense', 'Save Expense'),
    ('Reports', 'Monthly Summary'),
    ('PG Details', 'Save Details'),
  ]) {
    testWidgets('${page.$1} page fits a 320px phone and Back works',
        (tester) async {
      await pumpApp(tester, size: const Size(320, 640));
      await tapOn(tester, find.text(page.$1));
      expect(find.text(page.$2), findsWidgets);
      expect(tester.takeException(), isNull);
      await back(tester);
      expect(find.text('Overview'), findsOneWidget);
    });
  }

  testWidgets('Tablet width uses side navigation rail', (tester) async {
    await pumpApp(tester, size: const Size(1100, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('All PDF reports generate', () async {
    final month = monthOf(DateTime.now());
    final data = ReportData(
      month: month,
      profile: const PgProfile(pgName: 'Sunrise PG', ownerName: 'Owner'),
      rooms: const [Room(id: 'r1', number: '101', beds: 2, rent: 6000)],
      tenants: [
        Tenant(
            id: 't1',
            name: 'Ravi',
            phone: '9876543210',
            roomId: 'r1',
            rent: 6000,
            joinDate: DateTime(2026, 1, 1)),
        Tenant(
            id: 't2',
            name: 'Anil',
            phone: '9876500000',
            roomId: 'r1',
            rent: 6000,
            joinDate: DateTime(2026, 1, 1)),
      ],
      payments: [
        Payment(
            id: 'p1',
            tenantId: 't1',
            amount: 6000,
            type: PaymentType.rent,
            month: month,
            date: DateTime.now()),
      ],
      expenses: [
        Expense(
            id: 'e1',
            title: 'EB bill',
            category: 'Electricity',
            amount: 2500,
            date: DateTime.now()),
      ],
      electricityBills: [
        ElectricityBill(
            id: 'b1',
            roomId: 'r1',
            month: month,
            amount: 800,
            units: 100,
            previousReading: 1250,
            currentReading: 1350,
            unitRate: 8,
            tenantIds: const ['t1', 't2'],
            createdAt: DateTime.now()),
      ],
    );
    expect(data.summary.rentCollected, 6000);
    expect(data.summary.pendingRent, 6000);
    expect(data.summary.net, 3500);
    for (final type in ReportType.values) {
      final bytes = await buildReport(type, data);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF', reason: type.title);
    }
  });
}
