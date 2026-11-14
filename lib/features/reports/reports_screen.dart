import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';
import 'report_builder.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _month = monthOf(DateTime.now());
  ReportType? _busy;

  ReportData _data() => ReportData(
        month: _month,
        profile: ref.read(profileProvider),
        rooms: ref.read(roomsProvider),
        tenants: ref.read(tenantsProvider),
        payments: ref.read(paymentsProvider),
        expenses: ref.read(expensesProvider),
        electricityBills: ref.read(electricityBillsProvider),
      );

  /// Opens the phone's share sheet: Save to Files / Drive, WhatsApp, email...
  Future<void> _download(ReportType type) async {
    setState(() => _busy = type);
    try {
      final bytes = await buildReport(type, _data());
      await Printing.sharePdf(bytes: bytes, filename: type.fileName(_month));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not create the report: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// Opens the print dialog (also offers "Save as PDF").
  Future<void> _print(ReportType type) async {
    final data = _data();
    await Printing.layoutPdf(
      name: type.fileName(_month),
      onLayout: (_) => buildReport(type, data),
    );
  }

  static const _icons = {
    ReportType.summary: (Icons.insights_rounded, AppColors.seed),
    ReportType.rent: (Icons.fact_check_rounded, AppColors.success),
    ReportType.expenses: (Icons.receipt_long_rounded, AppColors.pink),
    ReportType.tenants: (Icons.people_alt_rounded, AppColors.purple),
    ReportType.electricity: (Icons.bolt_rounded, AppColors.warning),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose a month, then download a report as PDF. You can save it to your phone or share it on WhatsApp / email.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                MonthSwitcher(
                    month: _month,
                    onChanged: (m) => setState(() => _month = m)),
                const SizedBox(height: 12),
                for (final type in ReportType.values) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconBadge(
                                  icon: _icons[type]!.$1,
                                  color: _icons[type]!.$2,
                                  size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(type.title,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(type.description,
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(
                              flex: 3,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 44)),
                                onPressed:
                                    _busy == null ? () => _download(type) : null,
                                icon: _busy == type
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.download_rounded,
                                        size: 20),
                                label: const Text('Download PDF'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 44)),
                                onPressed:
                                    _busy == null ? () => _print(type) : null,
                                icon: const Icon(Icons.print_rounded, size: 20),
                                label: const Text('Print'),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
