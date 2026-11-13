import 'package:intl/intl.dart';

final _inr =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _plain = NumberFormat.decimalPattern('en_IN');

/// ₹12,500 — for the app UI.
String money(num value) => _inr.format(value.round());

/// Rs. 12,500 — for PDFs (built-in PDF fonts have no ₹ glyph).
String moneyPdf(num value) => 'Rs. ${_plain.format(value.round())}';

String fmtDate(DateTime d) => DateFormat('d MMM yyyy').format(d);
String fmtMonth(DateTime d) => DateFormat('MMMM yyyy').format(d);
String fmtMonthShort(DateTime d) => DateFormat('MMM yyyy').format(d);

/// First day of the month containing [d].
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);
DateTime addMonths(DateTime month, int n) =>
    DateTime(month.year, month.month + n);
bool sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

String newId() => DateTime.now().microsecondsSinceEpoch.toString();

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}
