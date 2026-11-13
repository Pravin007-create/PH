import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/calculations.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';
import '../../widgets/due_chip.dart';

const _red = Color(0xFFDC2626);
const _quickDeductions = [
  'Cleaning',
  'Damage / repair',
  'Electricity',
  'Key lost',
  'Notice period',
];

class _DeductionRow {
  _DeductionRow([String label = '', String amount = ''])
      : label = TextEditingController(text: label),
        amount = TextEditingController(text: amount);
  final TextEditingController label;
  final TextEditingController amount;

  void dispose() {
    label.dispose();
    amount.dispose();
  }
}

/// Settle the tenant's account: advance − pending rent − deductions = refund.
class MoveOutScreen extends ConsumerStatefulWidget {
  const MoveOutScreen({super.key, required this.tenantId});
  final String tenantId;

  @override
  ConsumerState<MoveOutScreen> createState() => _MoveOutScreenState();
}

class _MoveOutScreenState extends ConsumerState<MoveOutScreen> {
  late final Tenant _tenant =
      ref.read(tenantsProvider.notifier).byId(widget.tenantId)!;
  DateTime _date = dateOnly(DateTime.now());
  late final _deposit = TextEditingController(
      text: _tenant.deposit == 0 ? '' : _tenant.deposit.toStringAsFixed(0));
  final _collected = TextEditingController();
  final _rows = <_DeductionRow>[];

  /// Rent months the owner chose not to charge.
  final _waived = <DateTime>{};

  @override
  void dispose() {
    _deposit.dispose();
    _collected.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  List<Deduction> get _deductions => [
        for (final r in _rows)
          if (_num(r.amount) > 0)
            Deduction(
                r.label.text.trim().isEmpty ? 'Other' : r.label.text.trim(),
                _num(r.amount)),
      ];

  void _addRow([String label = '']) =>
      setState(() => _rows.add(_DeductionRow(label)));

  Future<void> _confirm(SettlementResult preview, List<TenantDue> rent) async {
    final s = preview.settlement;
    final ok = await confirmDialog(
      context,
      title: 'Move out ${_tenant.name}?',
      message: s.stillOwed > 0
          ? '${_tenant.name} still owes ${money(s.stillOwed)}. Unpaid rent will stay in the pending list.'
          : 'Refund ${money(s.refund)} to ${_tenant.name}. Their bed will become vacant.',
      confirmLabel: 'Confirm move-out',
      destructive: false,
    );
    if (!ok || !mounted) return;

    final result = settle(
      tenant: _tenant,
      date: _date,
      deposit: _num(_deposit),
      collectedNow: _num(_collected),
      rent: rent,
      deductions: _deductions,
      waivedMonths: _waived.toList(),
    );
    final payments = ref.read(paymentsProvider.notifier);
    for (final p in result.payments) {
      payments.save(p);
    }
    ref.read(tenantsProvider.notifier).save(
        _tenant.copyWith(leaveDate: _date, settlement: result.settlement));

    showSaved(
        context,
        result.settlement.refund > 0
            ? '${_tenant.name} moved out · refund ${money(result.settlement.refund)}'
            : '${_tenant.name} moved out');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(rentRulesProvider);
    final room = ref.read(roomsProvider.notifier).byId(_tenant.roomId);
    final allRent = unpaidRentUntil(
        _tenant, _date, ref.watch(paymentsProvider), rules);
    final rent =
        allRent.where((d) => !_waived.contains(d.month)).toList();
    final preview = settle(
      tenant: _tenant,
      date: _date,
      deposit: _num(_deposit),
      collectedNow: _num(_collected),
      rent: rent,
      deductions: _deductions,
      idGen: () => 'preview',
    );
    final s = preview.settlement;
    final rentTotal = rent.fold<double>(0, (a, d) => a + d.due);
    final totalDues = rentTotal + s.deductionsTotal;
    final shortBeforeCash = totalDues - _num(_deposit);

    return Scaffold(
      appBar: AppBar(title: const Text('Move Out')),
      bottomNavigationBar: SaveBar(
        label: s.refund > 0
            ? 'Confirm · Refund ${money(s.refund)}'
            : 'Confirm Move-out',
        onPressed: () => _confirm(preview, rent),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(initials(_tenant.name))),
                    title: Text(_tenant.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        '${room == null ? 'No room' : 'Room ${room.number}'} · joined ${fmtDate(_tenant.joinDate)}'),
                  ),
                ),
                const SizedBox(height: 14),
                DateField(
                  label: 'Move-out date',
                  value: _date,
                  onChanged: (d) => setState(() => _date = dateOnly(d)),
                ),

                const FormLabel('1. Advance / deposit held'),
                TextFormField(
                  controller: _deposit,
                  keyboardType: TextInputType.number,
                  inputFormatters: decimalOnly,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    labelText: 'Advance amount',
                    prefixText: '₹ ',
                    prefixIcon: Icon(Icons.savings_outlined),
                    helperText: 'Amount the tenant paid as advance',
                  ),
                ),

                FormLabel('2. Pending rent (${allRent.length})'),
                if (allRent.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.verified_rounded,
                          color: AppColors.success),
                      title: Text('No pending rent'),
                    ),
                  )
                else
                  Card(
                    child: Column(children: [
                      for (final d in allRent)
                        CheckboxListTile(
                          value: !_waived.contains(d.month),
                          onChanged: (v) => setState(() => v == true
                              ? _waived.remove(d.month)
                              : _waived.add(d.month)),
                          title: Text('${fmtMonth(d.month)} rent'),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: DueChip(d)),
                          ),
                          secondary: Text(money(d.due),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                    ]),
                  ),
                if (_waived.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                        'Unticked months are waived (not charged).',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),

                const FormLabel('3. Other deductions'),
                for (final (i, r) in _rows.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: r.label,
                          textCapitalization: TextCapitalization.sentences,
                          decoration:
                              const InputDecoration(labelText: 'For what'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: r.amount,
                          keyboardType: TextInputType.number,
                          inputFormatters: decimalOnly,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                              labelText: 'Amount', prefixText: '₹ '),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove deduction',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _rows.removeAt(i).dispose();
                        }),
                      ),
                    ]),
                  ),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final q in _quickDeductions)
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 18),
                      label: Text(q),
                      onPressed: () => _addRow(q),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Other'),
                    onPressed: _addRow,
                  ),
                ]),

                if (shortBeforeCash > 0) ...[
                  const FormLabel('4. Collect balance from tenant'),
                  TextFormField(
                    controller: _collected,
                    keyboardType: TextInputType.number,
                    inputFormatters: decimalOnly,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Cash collected now (optional)',
                      prefixText: '₹ ',
                      prefixIcon: const Icon(Icons.currency_rupee_rounded),
                      helperText:
                          'Advance is ${money(shortBeforeCash)} short of the dues',
                    ),
                  ),
                ],

                const FormLabel('Settlement'),
                _SummaryCard(
                  deposit: _num(_deposit),
                  collected: _num(_collected),
                  rent: rentTotal,
                  deductions: _deductions,
                  refund: s.refund,
                  stillOwed: s.stillOwed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.deposit,
    required this.collected,
    required this.rent,
    required this.deductions,
    required this.refund,
    required this.stillOwed,
  });

  final double deposit;
  final double collected;
  final double rent;
  final List<Deduction> deductions;
  final double refund;
  final double stillOwed;

  @override
  Widget build(BuildContext context) {
    Widget line(String label, String value, {Color? color, bool bold = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(label)),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          ]),
        );

    final owes = stillOwed > 0;
    final resultColor = owes ? _red : AppColors.success;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            line('Advance held', money(deposit)),
            if (collected > 0) line('+ Cash collected now', money(collected)),
            line('− Pending rent', money(rent), color: _red),
            for (final d in deductions)
              line('− ${d.label}', money(d.amount), color: _red),
            const Divider(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(owes ? Icons.warning_amber_rounded : Icons.undo_rounded,
                    color: resultColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    owes ? 'Tenant must still pay' : 'Refund to tenant',
                    style: TextStyle(
                        color: resultColor, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(money(owes ? stillOwed : refund),
                    style: TextStyle(
                        color: resultColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
