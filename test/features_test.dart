import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_hostel_management/core/format.dart';
import 'package:pg_hostel_management/data/backup.dart';
import 'package:pg_hostel_management/data/calculations.dart';
import 'package:pg_hostel_management/data/documents.dart';
import 'package:pg_hostel_management/data/models.dart';
import 'package:pg_hostel_management/data/store.dart';
import 'package:pg_hostel_management/features/rooms/room_form_screen.dart';
import 'package:pg_hostel_management/widgets/common.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widget_test.dart' as w;

ProviderContainer container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Room numbers', () {
    test('auto numbering keeps prefix and zero padding', () {
      expect(autoRoomNumbers('101', 3), ['101', '102', '103']);
      expect(autoRoomNumbers('A-09', 3), ['A-09', 'A-10', 'A-11']);
      expect(autoRoomNumbers('G', 2), ['G', '']); // can't increase
    });
  });

  testWidgets('Add 3 rooms of the same type at once (auto + manual numbers)',
      (tester) async {
    await w.pumpApp(tester);
    await w.tapOn(tester, find.text('Rooms'));
    await w.tapOn(tester, find.text('Add your first room'));

    await w.tapOn(tester, find.byTooltip('More rooms'));
    await w.tapOn(tester, find.byTooltip('More rooms')); // 3 rooms
    await w.enter(tester, 'Starting room number *', '201');
    await w.enter(tester, 'Monthly rent per bed *', '5000');
    expect(find.text('Room 203'), findsOneWidget); // preview

    // Switch to manual and change the last number.
    await w.tapOn(tester, find.text('Enter manually'));
    await w.enter(tester, 'Room 3 number *', '210');
    await w.tapOn(tester, find.text('Create 3 Rooms'));

    final rooms = container(tester).read(roomsProvider);
    expect(rooms.map((r) => r.number), ['201', '202', '210']);
    expect(rooms.every((r) => r.rent == 5000 && r.beds == 2), isTrue);
    expect(rooms.map((r) => r.id).toSet().length, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Room opens read-only; Edit button enables editing',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'rooms': jsonEncode([
        {'id': 'r1', 'number': '101', 'beds': 2, 'rent': 6000}
      ]),
    });
    await w.pumpApp(tester);
    await w.tapOn(tester, find.text('Rooms'));
    await w.tapOn(tester, find.text('Room 101'));

    expect(find.byType(TextFormField), findsNothing); // view mode
    expect(find.text('Save Changes'), findsNothing);

    await w.tapOn(tester, find.text('Edit'));
    await w.enter(tester, 'Monthly rent per bed *', '6500');
    await w.tapOn(tester, find.text('Electricity bill separate'));
    await w.tapOn(tester, find.text('Save Changes'));

    expect(find.byType(TextFormField), findsNothing); // back to view mode
    expect(find.text(money(6500)), findsOneWidget);
    expect(find.text('Separate (split)'), findsOneWidget);

    // Back while editing cancels the edit and stays on the page.
    await w.tapOn(tester, find.text('Edit'));
    await w.enter(tester, 'Monthly rent per bed *', '9999');
    await w.back(tester);
    expect(find.text('Room 101'), findsWidgets);
    expect(find.text(money(6500)), findsOneWidget);
  });

  testWidgets('Tenant opens read-only; Edit then Save updates details',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'tenants': jsonEncode([
        {
          'id': 't1',
          'name': 'Ravi Kumar',
          'phone': '9876543210',
          'rent': 6000,
          'joinDate': DateTime(2026, 11, 1).toIso8601String(),
        }
      ]),
    });
    await w.pumpApp(tester);
    await w.tapOn(tester, find.text('Tenants'));
    await w.tapOn(tester, find.text('Ravi Kumar'));
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Tenant Details'), findsOneWidget);

    await w.tapOn(tester, find.text('Edit'));
    await w.enter(tester, 'Mobile number *', '9000000001');
    await w.tapOn(tester, find.text('Save Changes'));
    expect(find.text('+91 9000000001'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('Payment cannot be edited; delete keeps it in the log',
      (tester) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'tenants': jsonEncode([
        {
          'id': 't1',
          'name': 'Ravi Kumar',
          'phone': '9876543210',
          'rent': 6000,
          'joinDate': DateTime(now.year, now.month).toIso8601String(),
        }
      ]),
      'payments': jsonEncode([
        Payment(
                id: 'p1',
                tenantId: 't1',
                amount: 6000,
                type: PaymentType.rent,
                month: DateTime(now.year, now.month),
                date: now)
            .toJson()
      ]),
    });
    await w.pumpApp(tester);
    await w.tapOn(tester, find.text('Payments'));
    await w.tapOn(tester, find.byTooltip('Payments received')); // segment
    await w.tapOn(tester, find.textContaining('Rent · '));

    expect(find.text('Payment Details'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Save Changes'), findsNothing);
    expect(find.text('Save Payment'), findsNothing);

    await w.tapOn(tester, find.text('Delete Payment'));
    await tester.enterText(
        find.widgetWithText(TextField, 'Reason (optional)'), 'Wrong amount');
    await w.tapOn(tester, find.text('Delete'));

    final c = container(tester);
    expect(c.read(paymentsProvider), isEmpty);
    expect(c.read(deletedPaymentsProvider).single.reason, 'Wrong amount');

    await w.tapOn(tester, find.byTooltip('Deleted payments'));
    expect(find.text('Ravi Kumar · Rent'), findsOneWidget);
    expect(find.textContaining('Wrong amount'), findsOneWidget);
  });

  group('Electricity split', () {
    final a = Tenant(
        id: 'a', name: 'A', phone: '1', rent: 1, joinDate: DateTime(2026, 1));
    final b = Tenant(
        id: 'b', name: 'B', phone: '2', rent: 1, joinDate: DateTime(2026, 1));
    final bill = ElectricityBill(
        id: 'e',
        roomId: 'r',
        month: DateTime(2026, 10),
        amount: 900,
        tenantIds: const ['a', 'b'],
        createdAt: DateTime(2026, 11));

    test('Bill is split equally; payments clear each share', () {
      expect(bill.share, 450);
      final paid = Payment(
          id: 'p',
          tenantId: 'a',
          amount: 450,
          type: PaymentType.electricity,
          month: DateTime(2026, 10),
          date: DateTime(2026, 11, 2));
      final dues = electricityDues([bill], [a, b], [paid]);
      expect(dues.map((d) => d.tenant.id), ['b']);
      expect(dues.single.due, 450);
    });

    test('Only tenants staying that month are in the room', () {
      final left = Tenant(
          id: 'c',
          name: 'C',
          phone: '3',
          rent: 1,
          roomId: 'r',
          joinDate: DateTime(2026, 1),
          leaveDate: DateTime(2026, 9, 10));
      final stay = Tenant(
          id: 'd',
          name: 'D',
          phone: '4',
          rent: 1,
          roomId: 'r',
          joinDate: DateTime(2026, 1));
      expect(
          tenantsInRoomFor('r', DateTime(2026, 10), [left, stay])
              .map((t) => t.id),
          ['d']);
    });
  });

  testWidgets('Room electricity bill → each tenant owes a share',
      (tester) async {
    final join = DateTime(2026, 1, 1).toIso8601String();
    SharedPreferences.setMockInitialValues({
      'rooms': jsonEncode([
        {
          'id': 'r1',
          'number': '101',
          'beds': 2,
          'rent': 6000,
          'separateElectricity': true
        }
      ]),
      'tenants': jsonEncode([
        for (final n in ['Asha', 'Bala'])
          {
            'id': n,
            'name': n,
            'phone': '9876543210',
            'roomId': 'r1',
            'rent': 6000,
            'joinDate': join,
            'createdAt': join,
          }
      ]),
    });
    await w.pumpApp(tester);
    await w.tapOn(tester, find.text('Rooms'));
    await w.tapOn(tester, find.text('Room 101'));
    await w.tapOn(tester, find.text('Add Electricity Bill +'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Bill amount *'), '1200');
    await tester.pumpAndSettle();
    expect(find.textContaining('= ${money(600)} per person'), findsOneWidget);
    await w.tapOn(tester, find.textContaining('Save Bill'));

    expect(find.text('${money(600)} pending'), findsNWidgets(2));
    expect(container(tester).read(electricityDuesProvider).length, 2);

    // Collect from Asha: amount pre-filled with her share.
    await w.tapOn(tester, find.text('Collect'));
    expect(find.widgetWithText(TextFormField, '600'), findsOneWidget);
    await w.tapOn(tester, find.text('Save Payment'));
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('${money(600)} pending'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Backup', () {
    test('Export then import restores everything', () async {
      SharedPreferences.setMockInitialValues({
        'profile': jsonEncode({'pgName': 'Sunrise PG'}),
        'rooms': jsonEncode([
          {'id': 'r1', 'number': '101', 'beds': 2, 'rent': 6000}
        ]),
        'tenants': jsonEncode([
          {
            'id': 't1',
            'name': 'Ravi',
            'phone': '9876543210',
            'rent': 6000,
            'joinDate': DateTime(2026, 1).toIso8601String(),
          }
        ]),
      });
      final prefs = await SharedPreferences.getInstance();
      final json = exportBackup(prefs);
      final summary = readBackup(json);
      expect(summary.rooms, 1);
      expect(summary.tenants, 1);
      expect(summary.pgName, 'Sunrise PG');

      await prefs.clear();
      await importBackup(prefs, json);
      expect(jsonDecode(prefs.getString('rooms')!), hasLength(1));
      expect(jsonDecode(prefs.getString('profile')!)['pgName'], 'Sunrise PG');
    });

    test('Wrong or damaged file is rejected and nothing changes', () async {
      SharedPreferences.setMockInitialValues({'rooms': '[]'});
      final prefs = await SharedPreferences.getInstance();
      expect(() => importBackup(prefs, 'hello'),
          throwsA(isA<BackupException>()));
      expect(() => importBackup(prefs, '{"rooms": []}'),
          throwsA(isA<BackupException>()));
      expect(
          () => importBackup(prefs,
              '{"format": "$backupFormat", "rooms": [{"id": 1}]}'),
          throwsA(isA<BackupException>()));
      expect(prefs.getString('rooms'), '[]');
    });
  });

  testWidgets('More: no Lock option; Export and Import shown', (tester) async {
    await w.pumpApp(tester);
    await w.tapOn(tester, find.text('More'));
    expect(find.text('Lock app'), findsNothing);
    expect(find.text('Export all data'), findsOneWidget);
    expect(find.text('Import data'), findsOneWidget);
    expect(find.text('Deleted payments'), findsOneWidget);
  });

  testWidgets('Move-out adds pending electricity as a deduction',
      (tester) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month).toIso8601String();
    SharedPreferences.setMockInitialValues({
      'tenants': jsonEncode([
        {
          'id': 't1',
          'name': 'Ravi Kumar',
          'phone': '9876543210',
          'roomId': 'r1',
          'rent': 6000,
          'deposit': 10000,
          'joinDate': start,
          'createdAt': start,
        }
      ]),
      'electricity_bills': jsonEncode([
        ElectricityBill(
                id: 'e1',
                roomId: 'r1',
                month: DateTime(now.year, now.month),
                amount: 800,
                tenantIds: const ['t1'],
                createdAt: now)
            .toJson()
      ]),
    });
    await w.pumpApp(tester);
    await w.tapOn(tester, find.text('Tenants'));
    await w.tapOn(tester, find.text('Ravi Kumar'));
    expect(find.textContaining('Electricity'), findsWidgets);
    await w.tapOn(tester, find.text('Move out'));

    // 10,000 − 6,000 rent − 800 electricity = 3,200.
    expect(find.text(money(3200)), findsWidgets);
    await w.tapOn(tester, find.textContaining('Confirm · Refund'));
    await w.tapOn(tester, find.text('Confirm move-out'));

    final c = container(tester);
    expect(c.read(electricityDuesProvider), isEmpty);
    expect(
        c
            .read(paymentsProvider)
            .where((p) => p.type == PaymentType.electricity)
            .single
            .amount,
        800);
  });

  group('Rooms list, relieving date, electricity tab', () {
    final join = DateTime(2026, 1, 1).toIso8601String();
    final soon = DateTime.now().add(const Duration(days: 10));
    final soonDay = DateTime(soon.year, soon.month, soon.day);
    final freeFrom = DateTime(soon.year, soon.month, soon.day + 1);
    void seed() => SharedPreferences.setMockInitialValues({
          'rooms': jsonEncode([
            {'id': 'r1', 'number': '101', 'beds': 2, 'rent': 6000,
              'isAC': true, 'separateElectricity': true},
            {'id': 'r2', 'number': '102', 'beds': 3, 'rent': 4000},
            {'id': 'r3', 'number': '103', 'beds': 1, 'rent': 9000,
              'isAC': true},
          ]),
          'tenants': jsonEncode([
            {'id': 'a', 'name': 'Asha', 'phone': '9876543210',
              'roomId': 'r1', 'rent': 6000, 'joinDate': join,
              'createdAt': join},
            {'id': 'b', 'name': 'Bala', 'phone': '9876543211',
              'roomId': 'r1', 'rent': 6000, 'joinDate': join,
              'createdAt': join, 'relievingDate': soonDay.toIso8601String()},
          ]),
          'electricity_bills': jsonEncode([
            ElectricityBill(
                    id: 'e1',
                    roomId: 'r1',
                    month: DateTime(DateTime.now().year, DateTime.now().month),
                    amount: 1000,
                    tenantIds: const ['a', 'b'],
                    createdAt: DateTime.now())
                .toJson()
          ]),
        });

    testWidgets('Room card shows bill pending + upcoming vacancy; filters work',
        (tester) async {
      seed();
      await w.pumpApp(tester, size: const Size(320, 700));
      await w.tapOn(tester, find.text('Rooms'));
      expect(find.text('⚡ Bill ${money(1000)} pending'), findsOneWidget);
      expect(find.text('1 vacant from ${fmtDate(freeFrom)}'), findsOneWidget);

      await w.tapOn(tester, find.text('Non-AC'));
      expect(find.text('Room 102'), findsOneWidget);
      expect(find.text('Room 101'), findsNothing);

      await w.tapOn(tester, find.text('AC'));
      await w.tapOn(tester, find.text('Single'));
      expect(find.text('Room 103'), findsOneWidget);
      expect(find.text('Room 101'), findsNothing);

      await w.tapOn(tester, find.text('Clear filters'));
      await w.tapOn(tester, find.text('Bill pending'));
      expect(find.text('Room 101'), findsOneWidget);
      expect(find.text('Room 102'), findsNothing);

      await w.tapOn(tester, find.text('Vacating soon'));
      expect(find.text('Room 101'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Relieving date: tenant banner, Home vacancies, move-out date',
        (tester) async {
      seed();
      await w.pumpApp(tester);
      expect(find.text('Upcoming vacancies (1)'), findsOneWidget);
      expect(find.text('1 bed free from ${fmtDate(freeFrom)}'), findsOneWidget);

      await w.tapOn(tester, find.text('Tenants'));
      await w.tapOn(tester, find.text('Bala'));
      expect(find.textContaining('Leaving on ${fmtDate(soonDay)}'),
          findsOneWidget);
      await w.tapOn(tester, find.text('Move out'));
      expect(find.text(fmtDate(soonDay)), findsOneWidget); // default date
    });

    testWidgets('Relieving date can be set and cleared in the tenant form',
        (tester) async {
      seed();
      await w.pumpApp(tester);
      await w.tapOn(tester, find.text('Tenants'));
      await w.tapOn(tester, find.text('Bala'));
      await w.tapOn(tester, find.text('Edit'));
      expect(find.textContaining('Bed will be shown vacant from'), findsOneWidget);
      await w.tapOn(tester, find.byTooltip('Clear Relieving date (optional)'));
      await w.tapOn(tester, find.text('Save Changes'));
      final t = container(tester).read(tenantsProvider.notifier).byId('b')!;
      expect(t.relievingDate, isNull);
    });

    testWidgets('Payments → Electricity tab lists shares, fits 320px',
        (tester) async {
      seed();
      await w.pumpApp(tester, size: const Size(320, 700));
      await w.tapOn(tester, find.text('Payments'));
      await w.tapOn(tester, find.byTooltip('Electricity bills'));
      expect(find.text('Room 101'), findsOneWidget);
      expect(find.textContaining('share ${money(500)}'), findsNWidgets(2));
      expect(find.text('Collect'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('Tenant documents', () {
    test('storeDocument copies the file into the folder; delete removes it',
        () async {
      final tmp = await Directory.systemTemp.createTemp('docs_test');
      final src = File('${tmp.path}/IMG_001.JPG')..writeAsBytesSync([1, 2, 3]);
      final dir = '${tmp.path}/tenant_docs';
      final d = await storeDocument(
          docsDir: dir, tenantId: 't1', sourcePath: src.path, label: 'Aadhaar card');
      expect(d.path, startsWith('t1_'));
      expect(d.path, endsWith('.jpg'));
      expect(File(docFilePath(dir, d)).readAsBytesSync(), [1, 2, 3]);
      // Round-trips through JSON with the tenant.
      final t = Tenant(
              id: 't1',
              name: 'R',
              phone: '1',
              rent: 1,
              joinDate: DateTime(2026),
              documents: [d],
              documentsSubmitted: true)
          .toJson();
      final back = Tenant.fromJson(jsonDecode(jsonEncode(t)));
      expect(back.documents.single.path, d.path);
      expect(back.documentsSubmitted, isTrue);
      await deleteDocumentFiles(dir, [d]);
      expect(File(docFilePath(dir, d)).existsSync(), isFalse);
      await tmp.delete(recursive: true);
    });

    testWidgets('Badge when documents not submitted; checkbox clears it',
        (tester) async {
      final join = DateTime(2026, 1, 1).toIso8601String();
      SharedPreferences.setMockInitialValues({
        'tenants': jsonEncode([
          {'id': 'a', 'name': 'Asha', 'phone': '9876543210', 'rent': 6000,
            'joinDate': join},
          {'id': 'b', 'name': 'Bala', 'phone': '9876543211', 'rent': 6000,
            'joinDate': join, 'documentsSubmitted': true},
        ]),
      });
      await w.pumpApp(tester, size: const Size(320, 700));
      await w.tapOn(tester, find.text('Tenants'));
      expect(find.textContaining('ID proof not submitted'), findsOneWidget); // Asha only
      await w.tapOn(tester, find.text('Documents pending (1)'));
      expect(find.text('Bala'), findsNothing);
      await w.tapOn(tester, find.text('Documents pending (1)'));

      await w.tapOn(tester, find.text('Asha'));
      expect(find.textContaining('Document proof not submitted'), findsWidgets);
      await w.tapOn(tester, find.text('Documents submitted'));
      expect(find.text('ID proof collected'), findsOneWidget);
      expect(
          container(tester)
              .read(tenantsProvider.notifier)
              .byId('a')!
              .documentsSubmitted,
          isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Stored documents show as thumbnails and can be deleted',
        (tester) async {
      final tmp = Directory.systemTemp.createTempSync('docs_ui');
      File('${tmp.path}/a_1.pdf').writeAsBytesSync([1]);
      File('${tmp.path}/a_2.jpg').writeAsBytesSync([1]);
      final join = DateTime(2026, 1, 1).toIso8601String();
      final added = DateTime(2026, 11, 1).toIso8601String();
      SharedPreferences.setMockInitialValues({
        'tenants': jsonEncode([
          {
            'id': 'a', 'name': 'Asha', 'phone': '9876543210', 'rent': 6000,
            'joinDate': join, 'documentsSubmitted': true,
            'documents': [
              {'id': '1', 'label': 'Rental agreement', 'path': 'a_1.pdf',
                'addedAt': added},
              {'id': '2', 'label': 'Aadhaar card', 'path': 'a_2.jpg',
                'addedAt': added},
            ],
          },
        ]),
      });
      await w.pumpApp(tester,
          overrides: [docsDirProvider.overrideWith((ref) async => tmp.path)]);
      await w.tapOn(tester, find.text('Tenants'));
      await w.tapOn(tester, find.text('Asha'));
      expect(find.text('Aadhaar card'), findsOneWidget);
      expect(find.text('Rental agreement'), findsOneWidget);
      expect(find.text('Add Document + (2 added)'), findsOneWidget);

      await w.tapOn(tester, find.text('Aadhaar card'));
      expect(find.byTooltip('Share'), findsOneWidget);
      await w.tapOn(tester, find.byTooltip('Delete document'));
      await w.tapOn(tester, find.text('Delete'));
      expect(find.text('Aadhaar card'), findsNothing);
      expect(File('${tmp.path}/a_2.jpg').existsSync(), isFalse);
      expect(
          container(tester).read(tenantsProvider.notifier).byId('a')!.documents
              .map((d) => d.label),
          ['Rental agreement']);
    });

    testWidgets('Add Document sheet offers camera, gallery and PDF',
        (tester) async {
      final tmp = Directory.systemTemp.createTempSync('docs_sheet');
      await w.pumpApp(tester,
          overrides: [docsDirProvider.overrideWith((ref) async => tmp.path)]);
      await w.tapOn(tester, find.text('Tenants'));
      await w.tapOn(tester, find.text('Add your first tenant'));
      await w.tapOn(tester, find.text('Add Document +'));
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(find.text('Upload PDF'), findsOneWidget);
      expect(find.text('Aadhaar card'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
      'Meter bill: (now − units run) × rate, split, room reading updated',
      (tester) async {
    final join = DateTime(2026, 1, 1).toIso8601String();
    SharedPreferences.setMockInitialValues({
      'profile': jsonEncode({'pgName': 'Test PG', 'unitRate': 8}),
      'rooms': jsonEncode([
        {'id': 'r1', 'number': '101', 'beds': 2, 'rent': 6000,
          'separateElectricity': true, 'meterReading': 1250}
      ]),
      'tenants': jsonEncode([
        for (final n in ['Asha', 'Bala'])
          {'id': n, 'name': n, 'phone': '9876543210', 'roomId': 'r1',
            'rent': 6000, 'joinDate': join, 'createdAt': join}
      ]),
    });
    await w.pumpApp(tester);
    await w.tapOn(tester, find.text('Rooms'));
    await w.tapOn(tester, find.text('Room 101'));
    expect(find.text('1250 units'), findsOneWidget); // units run till now
    await w.tapOn(tester, find.text('Add Electricity Bill +'));

    // Last reading and rate are pre-filled.
    expect(find.widgetWithText(TextFormField, '1250'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '8'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Now unit *'), '1350');
    await tester.pumpAndSettle();
    // 100 units × ₹8 = ₹800 → ₹400 each.
    expect(find.text(money(800)), findsWidgets);
    expect(find.textContaining('= ${money(400)} per person'), findsOneWidget);
    await w.tapOn(tester, find.text('Save Bill · ${money(800)}'));

    final c = container(tester);
    final bill = c.read(electricityBillsProvider).single;
    expect(bill.units, 100);
    expect(bill.previousReading, 1250);
    expect(bill.currentReading, 1350);
    expect(bill.amount, 800);
    expect(c.read(roomsProvider).single.meterReading, 1350);
    expect(find.text('1350 units'), findsOneWidget);
    expect(find.textContaining('Meter 1250 → 1350 = 100 units'), findsOneWidget);

    // Deleting the latest bill puts the meter back.
    await w.tapOn(tester, find.byTooltip('Delete bill'));
    await w.tapOn(tester, find.text('Delete'));
    expect(c.read(roomsProvider).single.meterReading, 1250);
    expect(tester.takeException(), isNull);
  });

  testWidgets('New reading lower than last is rejected', (tester) async {
    SharedPreferences.setMockInitialValues({
      'profile': jsonEncode({'pgName': 'Test PG', 'unitRate': 8}),
      'rooms': jsonEncode([
        {'id': 'r1', 'number': '101', 'beds': 2, 'rent': 6000,
          'separateElectricity': true, 'meterReading': 1250}
      ]),
    });
    await w.pumpApp(tester);
    await w.tapOn(tester, find.text('Rooms'));
    await w.tapOn(tester, find.text('Room 101'));
    await w.tapOn(tester, find.text('Add Electricity Bill +'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Now unit *'), '1200');
    await w.tapOn(tester, find.text('Save Bill'));
    expect(find.text('Less than last'), findsOneWidget);
  });

  testWidgets('Payments: tap paid rent/electricity → payment details; '
      'month bar stays pinned', (tester) async {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final join = DateTime(2026, 1, 1).toIso8601String();
    SharedPreferences.setMockInitialValues({
      'profile': jsonEncode({'pgName': 'Test PG', 'rentCycle': 'monthStart'}),
      'rooms': jsonEncode([
        {'id': 'r1', 'number': '101', 'beds': 9, 'rent': 6000,
          'separateElectricity': true}
      ]),
      'tenants': jsonEncode([
        for (final n in ['Asha', 'Bala', 'Chitra', 'Deepa', 'Esha', 'Farah'])
          {'id': n, 'name': n, 'phone': '9876543210', 'roomId': 'r1',
            'rent': 6000, 'joinDate': join, 'createdAt': join}
      ]),
      'payments': jsonEncode([
        Payment(id: 'p1', tenantId: 'Asha', amount: 6000,
                type: PaymentType.rent, month: month, date: now, mode: 'UPI')
            .toJson(),
        Payment(id: 'p2', tenantId: 'Asha', amount: 300,
                type: PaymentType.electricity, month: month, date: now)
            .toJson(),
      ]),
      'electricity_bills': jsonEncode([
        ElectricityBill(id: 'e1', roomId: 'r1', month: month, amount: 1800,
                tenantIds: const ['Asha', 'Bala', 'Chitra', 'Deepa', 'Esha', 'Farah'],
                createdAt: now)
            .toJson()
      ]),
    });
    await w.pumpApp(tester, size: const Size(320, 640));
    await w.tapOn(tester, find.text('Payments'));
    expect(find.text('MONTH'), findsOneWidget);

    // Scroll to the bottom: month bar is still on screen.
    await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('MONTH').hitTestable(), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();

    // Paid rent row → Payment Details (not the tenant profile).
    await w.tapOn(tester, find.text('Asha'));
    expect(find.text('Payment Details'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);
    await w.back(tester);

    // Unpaid row still opens the tenant.
    await w.tapOn(tester, find.text('Bala'));
    expect(find.text('Tenant Details'), findsOneWidget);
    await w.back(tester);

    // Electricity tab: paid share → its payment.
    await w.tapOn(tester, find.byTooltip('Electricity bills'));
    await w.tapOn(tester, find.text('Asha'));
    expect(find.text('Payment Details'), findsOneWidget);
    expect(find.text(money(300)), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('Backup with documents (.zip)', () {
    Map<String, Object> seedData() => {
          'profile': jsonEncode({'pgName': 'Sunrise PG'}),
          'tenants': jsonEncode([
            {
              'id': 't1', 'name': 'Ravi', 'phone': '9876543210', 'rent': 6000,
              'joinDate': DateTime(2026, 1).toIso8601String(),
              'documentsSubmitted': true,
              'documents': [
                {'id': 'd1', 'label': 'Aadhaar card', 'path': 't1_1.jpg',
                  'addedAt': DateTime(2026, 11).toIso8601String()},
                {'id': 'd2', 'label': 'Agreement', 'path': 't1_2.pdf',
                  'addedAt': DateTime(2026, 11).toIso8601String()},
              ],
            }
          ]),
        };

    test('Export zip includes photos; import on a new phone restores them',
        () async {
      final oldPhone = Directory.systemTemp.createTempSync('old_phone');
      File('${oldPhone.path}/t1_1.jpg').writeAsBytesSync([1, 2, 3]);
      File('${oldPhone.path}/t1_2.pdf').writeAsBytesSync([4, 5]);
      SharedPreferences.setMockInitialValues(seedData());
      final prefs = await SharedPreferences.getInstance();
      final zip = await exportBackupZip(prefs, oldPhone.path);
      expect(readBackupFile(zip).documentFiles, 2);

      // New phone: empty data, a stray old file that should be cleaned up.
      await prefs.clear();
      final newPhone = Directory.systemTemp.createTempSync('new_phone');
      File('${newPhone.path}/old_unused.jpg').writeAsBytesSync([9]);
      final summary = await importBackupFile(prefs, zip, newPhone.path);

      expect(summary.tenants, 1);
      expect(summary.documentFiles, 2);
      expect(File('${newPhone.path}/t1_1.jpg').readAsBytesSync(), [1, 2, 3]);
      expect(File('${newPhone.path}/t1_2.pdf').readAsBytesSync(), [4, 5]);
      expect(File('${newPhone.path}/old_unused.jpg').existsSync(), isFalse);
      expect(jsonDecode(prefs.getString('tenants')!)[0]['documents'],
          hasLength(2));
      oldPhone.deleteSync(recursive: true);
      newPhone.deleteSync(recursive: true);
    });

    test('Old .json backups still import', () async {
      SharedPreferences.setMockInitialValues(seedData());
      final prefs = await SharedPreferences.getInstance();
      final json = exportBackup(prefs);
      await prefs.clear();
      final dir = Directory.systemTemp.createTempSync('json_import');
      final s = await importBackupFile(
          prefs, Uint8List.fromList(utf8.encode(json)), dir.path);
      expect(s.tenants, 1);
      expect(s.documentFiles, 0);
      dir.deleteSync(recursive: true);
    });

    test('Zip entries trying to escape the folder are ignored', () async {
      SharedPreferences.setMockInitialValues(seedData());
      final prefs = await SharedPreferences.getInstance();
      final archive = Archive()
        ..addFile(ArchiveFile.string(backupJsonName, exportBackup(prefs)))
        ..addFile(ArchiveFile.bytes('tenant_docs/../evil.txt', [1]))
        ..addFile(ArchiveFile.bytes('tenant_docs/t1_1.jpg', [7]));
      final zip = ZipEncoder().encodeBytes(archive);
      final dir = Directory.systemTemp.createTempSync('zip_safe');
      final docs = Directory('${dir.path}/tenant_docs')..createSync();
      final s = await importBackupFile(prefs, zip, docs.path);
      expect(s.documentFiles, 1);
      expect(File('${dir.path}/evil.txt').existsSync(), isFalse);
      expect(File('${docs.path}/t1_1.jpg').readAsBytesSync(), [7]);
      dir.deleteSync(recursive: true);
    });

    test('A random zip is rejected', () {
      final zip = ZipEncoder()
          .encodeBytes(Archive()..addFile(ArchiveFile.string('a.txt', 'hi')));
      expect(() => readBackupFile(zip), throwsA(isA<BackupException>()));
    });
  });

  testWidgets('Language: switch to Tamil in PG details, nav + home change',
      (tester) async {
    await w.pumpApp(tester, size: const Size(320, 700));
    expect(find.text('Rooms'), findsOneWidget);
    await w.tapOn(tester, find.text('More'));
    await w.tapOn(tester, find.text('Language / மொழி'));
    await w.tapOn(tester, find.text('தமிழ்'));
    // Bottom navigation and More screen are now in Tamil.
    expect(find.text('அறைகள்'), findsOneWidget);
    expect(find.text('மேலும்'), findsWidgets);
    expect(find.text('அனைத்து தரவையும் ஏற்றுமதி'), findsOneWidget);
    await w.tapOn(tester, find.text('முகப்பு'));
    expect(find.text('சுருக்கம்'), findsOneWidget); // Overview
    expect(
        jsonDecode((await SharedPreferences.getInstance())
            .getString('profile')!)['language'],
        'ta');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Payments: top cards follow the selected tab', (tester) async {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final join = DateTime(2026, 1, 1).toIso8601String();
    SharedPreferences.setMockInitialValues({
      'tenants': jsonEncode([
        {'id': 'a', 'name': 'Asha', 'phone': '9876543210', 'roomId': 'r1',
          'rent': 6000, 'joinDate': join, 'createdAt': join}
      ]),
      'electricity_bills': jsonEncode([
        ElectricityBill(id: 'e1', roomId: 'r1', month: month, amount: 700,
                tenantIds: const ['a'], createdAt: now)
            .toJson()
      ]),
    });
    await w.pumpApp(tester, size: const Size(320, 700));
    await w.tapOn(tester, find.text('Payments'));
    expect(find.text('Rent collected'), findsOneWidget);
    expect(find.text('Electricity pending'), findsNothing);

    await w.tapOn(tester, find.byTooltip('Electricity bills'));
    expect(find.text('Rent collected'), findsNothing);
    expect(find.text('Electricity pending'), findsOneWidget);
    expect(find.text(money(700)), findsWidgets);
    // Amber collect button with the ₹ icon.
    final btn = tester.widget<FilledButton>(find
        .ancestor(of: find.textContaining('Collect'), matching: find.byType(FilledButton))
        .first);
    expect(btn.style?.backgroundColor?.resolve({}), CollectButton.color);

    await w.tapOn(tester, find.byTooltip('Payments received'));
    expect(find.text('Received this month'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Electricity ₹1,000 ÷ 3 → ₹334 + ₹333 + ₹333; paying shares clears all',
      () {
    final now = DateTime(2026, 11, 10);
    final tenants = [
      for (final id in ['a', 'b', 'c'])
        Tenant(id: id, name: id, phone: '1', rent: 1, joinDate: DateTime(2026))
    ];
    final bill = ElectricityBill(
        id: 'e',
        roomId: 'r',
        month: DateTime(2026, 10),
        amount: 1000,
        tenantIds: const ['a', 'b', 'c'],
        createdAt: now);
    expect([for (final t in tenants) bill.shareFor(t.id)], [334, 333, 333]);
    final shares = electricityShares([bill], tenants, [
      for (final t in tenants)
        Payment(
            id: t.id,
            tenantId: t.id,
            amount: bill.shareFor(t.id),
            type: PaymentType.electricity,
            month: DateTime(2026, 10),
            date: now)
    ]);
    expect(shares.every((d) => d.isPaid), isTrue);
    expect(shares.fold<double>(0, (a, d) => a + d.paid), 1000); // collected
    expect(shares.fold<double>(0, (a, d) => a + d.due), 0); // pending
  });

  testWidgets(
      'Record Payment → Electricity picks the bill month, so collected updates',
      (tester) async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    final join = DateTime(2026, 1, 1).toIso8601String();
    SharedPreferences.setMockInitialValues({
      'tenants': jsonEncode([
        for (final n in ['Asha', 'Bala', 'Chitra'])
          {'id': n, 'name': n, 'phone': '9876543210', 'roomId': 'r1',
            'rent': 6000, 'joinDate': join, 'createdAt': join}
      ]),
      'electricity_bills': jsonEncode([
        ElectricityBill(id: 'e1', roomId: 'r1', month: lastMonth, amount: 1000,
                tenantIds: const ['Asha', 'Bala', 'Chitra'], createdAt: now)
            .toJson()
      ]),
    });
    await w.pumpApp(tester);
    await w.tapOn(tester, find.text('Payments'));
    await w.tapOn(tester, find.text('Record Payment'));
    await w.tapOn(tester, find.byType(DropdownButtonFormField<String>));
    await w.tapOn(tester, find.text('Asha').last);
    await w.tapOn(tester, find.text('Electricity'));
    // Month jumps to last month's bill and amount = Asha's share (₹334).
    expect(find.text(fmtMonth(lastMonth)), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '334'), findsOneWidget);
    await w.tapOn(tester, find.text('Save Payment'));

    final c = container(tester);
    final asha = electricityShares(c.read(electricityBillsProvider),
            c.read(tenantsProvider), c.read(paymentsProvider))
        .firstWhere((d) => d.tenant.id == 'Asha');
    expect(asha.isPaid, isTrue);
    expect(asha.paid, 334);
    expect(tester.takeException(), isNull);
  });
}
