import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/format.dart';
import '../../data/calculations.dart';
import '../../data/models.dart';

/// Everything a report needs, captured at the moment of download.
class ReportData {
  ReportData({
    required this.month,
    required this.profile,
    required this.rooms,
    required this.tenants,
    required this.payments,
    required this.expenses,
  }) : summary = summarize(month, rooms, tenants, payments, expenses,
            rules: RentRules.of(profile));

  final DateTime month;
  final PgProfile profile;
  final List<Room> rooms;
  final List<Tenant> tenants;
  final List<Payment> payments;
  final List<Expense> expenses;
  final MonthSummary summary;

  String roomOf(Tenant t) {
    for (final r in rooms) {
      if (r.id == t.roomId) return r.number;
    }
    return '-';
  }

  String tenantName(String id) {
    for (final t in tenants) {
      if (t.id == id) return t.name;
    }
    return 'Deleted tenant';
  }
}

enum ReportType {
  summary('Monthly Summary',
      'Income, expenses, profit, occupancy and pending rent in one page'),
  rent('Rent Collection & Dues',
      'Every tenant: rent, amount paid and balance due for the month'),
  expenses('Expense Report', 'All expenses for the month with category totals'),
  tenants('Tenant List', 'All current tenants with room, phone, rent and deposit');

  const ReportType(this.title, this.description);
  final String title;
  final String description;

  String fileName(DateTime month) =>
      '${title.replaceAll(RegExp(r'[^A-Za-z]+'), '_')}_${fmtMonthShort(month).replaceAll(' ', '_')}.pdf';
}

const _brand = PdfColor.fromInt(0xFF4F46E5);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _green = PdfColor.fromInt(0xFF16A34A);
const _orange = PdfColor.fromInt(0xFFEA580C);
const _light = PdfColor.fromInt(0xFFF3F4F6);

Future<Uint8List> buildReport(ReportType type, ReportData d) async {
  final doc = pw.Document(
    title: '${type.title} - ${fmtMonth(d.month)}',
    author: d.profile.pgName.isEmpty ? 'PG Hostel Manager' : d.profile.pgName,
  );

  final content = switch (type) {
    ReportType.summary => _summary(d),
    ReportType.rent => _rent(d),
    ReportType.expenses => _expenses(d),
    ReportType.tenants => _tenants(d),
  };

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    header: (ctx) => _header(d, type),
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Generated on ${fmtDate(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: _muted)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _muted)),
      ],
    ),
    build: (ctx) => content,
  ));
  return doc.save();
}

pw.Widget _header(ReportData d, ReportType type) {
  final p = d.profile;
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 16),
    padding: const pw.EdgeInsets.only(bottom: 10),
    decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _brand, width: 2))),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(p.pgName.isEmpty ? 'PG Hostel' : p.pgName,
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: _brand)),
              if (p.address.isNotEmpty)
                pw.Text(p.address,
                    style: const pw.TextStyle(fontSize: 9, color: _muted)),
              if (p.ownerName.isNotEmpty || p.phone.isNotEmpty)
                pw.Text(
                    [p.ownerName, if (p.phone.isNotEmpty) '+91 ${p.phone}']
                        .where((s) => s.isNotEmpty)
                        .join('  |  '),
                    style: const pw.TextStyle(fontSize: 9, color: _muted)),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(type.title,
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text(type == ReportType.tenants
                ? 'As of ${fmtDate(DateTime.now())}'
                : fmtMonth(d.month)),
            if (type == ReportType.rent || type == ReportType.summary)
              pw.Text('Rent due by ${fmtDate(d.summary.dueDate)}',
                  style: const pw.TextStyle(fontSize: 9, color: _muted)),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _kpi(String label, String value, {PdfColor color = PdfColors.black}) =>
    pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.all(4),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
            color: _light, borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _muted)),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );

pw.Widget _title(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
      child: pw.Text(text,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
    );

pw.Widget _table(List<String> headers, List<List<String>> rows,
    {Map<int, pw.Alignment> align = const {}, List<String>? totalRow}) {
  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: [...rows, if (totalRow != null) totalRow],
    border: null,
    headerStyle: pw.TextStyle(
        fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
    headerDecoration: const pw.BoxDecoration(color: _brand),
    cellStyle: const pw.TextStyle(fontSize: 9),
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _light, width: 0.5))),
    oddRowDecoration: const pw.BoxDecoration(color: _light),
    cellAlignments: align,
    headerAlignments: align,
  );
}

pw.Widget _empty(String text) => pw.Padding(
      padding: const pw.EdgeInsets.all(12),
      child: pw.Text(text, style: const pw.TextStyle(color: _muted)),
    );

List<pw.Widget> _summary(ReportData d) {
  final s = d.summary;
  final right = {1: pw.Alignment.centerRight};
  return [
    pw.Row(children: [
      _kpi('Total income', moneyPdf(s.totalIncome), color: _green),
      _kpi('Total expenses', moneyPdf(s.expenses), color: _orange),
      _kpi('Net profit', moneyPdf(s.net),
          color: s.net >= 0 ? _green : PdfColors.red),
    ]),
    pw.Row(children: [
      _kpi('Rent collected', moneyPdf(s.rentCollected)),
      _kpi('Rent pending', moneyPdf(s.pendingRent), color: _orange),
      _kpi('Collection rate', '${(s.collectionRate * 100).round()}%'),
    ]),
    pw.Row(children: [
      _kpi('Rooms', '${d.rooms.length}'),
      _kpi('Beds occupied', '${s.occupiedBeds} / ${s.totalBeds}'),
      _kpi('Active tenants', '${s.activeTenants}'),
    ]),
    _title('Income'),
    _table(['Item', 'Amount'], [
      ['Rent expected', moneyPdf(s.rentExpected)],
      ['Rent collected', moneyPdf(s.rentCollected)],
      for (final t in PaymentType.values.where((t) => t != PaymentType.rent))
        [
          t.label,
          moneyPdf(d.payments
              .where((p) => p.type == t && sameMonth(p.month, d.month))
              .fold<double>(0, (a, p) => a + p.amount))
        ],
    ], align: right, totalRow: ['Total income', moneyPdf(s.totalIncome)]),
    _title('Expenses by category'),
    if (s.expenseByCategory.isEmpty)
      _empty('No expenses recorded this month.')
    else
      _table(
        ['Category', 'Amount'],
        [
          for (final e in (s.expenseByCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value))))
            [e.key, moneyPdf(e.value)]
        ],
        align: right,
        totalRow: ['Total expenses', moneyPdf(s.expenses)],
      ),
    _title('Pending rent (${s.unpaid.length} tenants, ${s.overdue.length} overdue)'),
    if (s.unpaid.isEmpty)
      _empty('All rent collected for this month.')
    else
      _table(
        ['Tenant', 'Room', 'Phone', 'Status', 'Due'],
        [
          for (final u in s.unpaid)
            [
              u.tenant.name,
              d.roomOf(u.tenant),
              u.tenant.phone,
              u.isOverdue ? 'OVERDUE ${u.daysOverdue}d' : 'Due ${fmtDate(u.dueDate)}',
              moneyPdf(u.due)
            ]
        ],
        align: {4: pw.Alignment.centerRight},
      ),
  ];
}

List<pw.Widget> _rent(ReportData d) {
  final s = d.summary;
  return [
    pw.Row(children: [
      _kpi('Expected', moneyPdf(s.rentExpected)),
      _kpi('Collected', moneyPdf(s.rentCollected), color: _green),
      _kpi('Pending', moneyPdf(s.pendingRent), color: _orange),
    ]),
    _title('Rent status'),
    if (s.dues.isEmpty)
      _empty('No tenants stayed during this month.')
    else
      _table(
        ['Tenant', 'Room', 'Phone', 'Rent', 'Paid', 'Balance', 'Status'],
        [
          for (final x in s.dues)
            [
              x.tenant.name,
              d.roomOf(x.tenant),
              x.tenant.phone,
              moneyPdf(x.tenant.rent),
              moneyPdf(x.paid),
              moneyPdf(x.due),
              x.isPaid
                  ? 'Paid'
                  : x.isOverdue
                      ? 'OVERDUE ${x.daysOverdue}d'
                      : (x.paid > 0 ? 'Partial' : 'Not paid yet'),
            ]
        ],
        align: {
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
          5: pw.Alignment.centerRight,
        },
        totalRow: [
          'Total',
          '',
          '',
          moneyPdf(s.rentExpected),
          moneyPdf(s.dues.fold<double>(0, (a, x) => a + x.paid)),
          moneyPdf(s.pendingRent),
          ''
        ],
      ),
    _title('All payments received for ${fmtMonth(d.month)}'),
    () {
      final list = d.payments.where((p) => sameMonth(p.month, d.month)).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      if (list.isEmpty) return _empty('No payments recorded.');
      return _table(
        ['Date', 'Tenant', 'Type', 'Mode', 'Amount'],
        [
          for (final p in list)
            [fmtDate(p.date), d.tenantName(p.tenantId), p.type.label, p.mode,
              moneyPdf(p.amount)]
        ],
        align: {4: pw.Alignment.centerRight},
        totalRow: ['Total', '', '', '',
          moneyPdf(list.fold<double>(0, (a, p) => a + p.amount))],
      );
    }(),
  ];
}

List<pw.Widget> _expenses(ReportData d) {
  final list = d.expenses.where((e) => sameMonth(e.date, d.month)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final s = d.summary;
  return [
    pw.Row(children: [
      _kpi('Total expenses', moneyPdf(s.expenses), color: _orange),
      _kpi('Number of entries', '${list.length}'),
      _kpi('Categories', '${s.expenseByCategory.length}'),
    ]),
    _title('By category'),
    if (s.expenseByCategory.isEmpty)
      _empty('No expenses recorded this month.')
    else
      _table(
        ['Category', 'Amount', 'Share'],
        [
          for (final e in (s.expenseByCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value))))
            [
              e.key,
              moneyPdf(e.value),
              '${(e.value / s.expenses * 100).round()}%'
            ]
        ],
        align: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
      ),
    _title('All expenses'),
    if (list.isEmpty)
      _empty('No expenses recorded this month.')
    else
      _table(
        ['Date', 'Description', 'Category', 'Amount'],
        [
          for (final e in list)
            [fmtDate(e.date), e.title, e.category, moneyPdf(e.amount)]
        ],
        align: {3: pw.Alignment.centerRight},
        totalRow: ['Total', '', '', moneyPdf(s.expenses)],
      ),
  ];
}

List<pw.Widget> _tenants(ReportData d) {
  final active = d.tenants.where((t) => t.isActive).toList()
    ..sort((a, b) => d.roomOf(a).compareTo(d.roomOf(b)));
  return [
    pw.Row(children: [
      _kpi('Active tenants', '${active.length}'),
      _kpi('Monthly rent total',
          moneyPdf(active.fold<double>(0, (a, t) => a + t.rent))),
      _kpi('Deposits held',
          moneyPdf(active.fold<double>(0, (a, t) => a + t.deposit))),
    ]),
    _title('Current tenants'),
    if (active.isEmpty)
      _empty('No active tenants.')
    else
      _table(
        ['#', 'Name', 'Room', 'Phone', 'Joined', 'Rent', 'Deposit'],
        [
          for (var i = 0; i < active.length; i++)
            [
              '${i + 1}',
              active[i].name,
              d.roomOf(active[i]),
              active[i].phone,
              fmtDate(active[i].joinDate),
              moneyPdf(active[i].rent),
              moneyPdf(active[i].deposit),
            ]
        ],
        align: {5: pw.Alignment.centerRight, 6: pw.Alignment.centerRight},
      ),
  ];
}

/// One-page move-out settlement receipt to give the tenant.
Future<Uint8List> buildSettlementPdf(
    PgProfile profile, Tenant tenant, String? roomNumber) async {
  final s = tenant.settlement!;
  final doc = pw.Document(title: 'Settlement - ${tenant.name}');
  pw.Widget row(String a, String b, {bool bold = false, PdfColor? color}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        child: pw.Row(children: [
          pw.Expanded(
              child: pw.Text(a,
                  style: pw.TextStyle(
                      fontWeight: bold ? pw.FontWeight.bold : null))),
          pw.Text(b,
              style: pw.TextStyle(
                  fontWeight: bold ? pw.FontWeight.bold : null, color: color)),
        ]),
      );
  final owes = s.stillOwed > 0;
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(40),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(profile.pgName.isEmpty ? 'PG Hostel' : profile.pgName,
            style: pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold, color: _brand)),
        if (profile.address.isNotEmpty)
          pw.Text(profile.address,
              style: const pw.TextStyle(fontSize: 10, color: _muted)),
        if (profile.phone.isNotEmpty)
          pw.Text('+91 ${profile.phone}',
              style: const pw.TextStyle(fontSize: 10, color: _muted)),
        pw.Divider(color: _brand, thickness: 2),
        pw.SizedBox(height: 8),
        pw.Text('Move-out Settlement',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
              color: _light, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Tenant: ${tenant.name}'),
              pw.Text('Mobile: +91 ${tenant.phone}'),
              if (roomNumber != null) pw.Text('Room: $roomNumber'),
              pw.Text('Joined: ${fmtDate(tenant.joinDate)}'),
              pw.Text('Moved out: ${fmtDate(s.date)}'),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        row('Advance / deposit held', moneyPdf(s.deposit)),
        if (s.collectedNow > 0)
          row('Add: cash collected at move-out', moneyPdf(s.collectedNow)),
        if (s.rentAdjusted > 0)
          row('Less: pending rent (${s.rentMonths.join(', ')})',
              moneyPdf(s.rentAdjusted)),
        for (final d in s.deductions)
          row('Less: ${d.label}', moneyPdf(d.amount)),
        pw.Divider(),
        row(owes ? 'Balance to be paid by tenant' : 'Amount refunded to tenant',
            moneyPdf(owes ? s.stillOwed : s.refund),
            bold: true, color: owes ? PdfColors.red : _green),
        pw.Spacer(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(children: [
              pw.SizedBox(width: 150, child: pw.Divider()),
              pw.Text('Owner signature',
                  style: const pw.TextStyle(fontSize: 9, color: _muted)),
            ]),
            pw.Column(children: [
              pw.SizedBox(width: 150, child: pw.Divider()),
              pw.Text('Tenant signature',
                  style: const pw.TextStyle(fontSize: 9, color: _muted)),
            ]),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text('Generated on ${fmtDate(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: _muted)),
      ],
    ),
  ));
  return doc.save();
}
