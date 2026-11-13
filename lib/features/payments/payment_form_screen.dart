import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/calculations.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';

/// Record a new payment. Saved payments can't be edited, only deleted
/// (see PaymentDetailScreen).
class PaymentFormScreen extends ConsumerStatefulWidget {
  const PaymentFormScreen({super.key, this.tenantId, this.month, this.type});
  final String? tenantId;

  /// Pre-selected type (e.g. electricity from a room bill).
  final PaymentType? type;

  /// Rent month to pay for (e.g. an older overdue month).
  final DateTime? month;

  @override
  ConsumerState<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends ConsumerState<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late String? _tenantId = widget.tenantId;
  late PaymentType _type = widget.type ?? PaymentType.rent;
  // Defaults to the rent month being collected now (October on 3 Nov for an
  // end-of-month PG).
  late DateTime _month =
      (widget.month == null ? null : monthOf(widget.month!)) ??
          ref.read(currentRentMonthProvider);
  DateTime _date = DateTime.now();
  String _mode = 'Cash';
  late final TextEditingController _amount;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: _suggestedAmount());
    _note = TextEditingController();
  }

  /// Rent or electricity still due for the tenant and month.
  String _suggestedAmount() {
    final tenant = ref.read(tenantsProvider.notifier).byId(_tenantId);
    if (tenant == null) return '';
    double due = 0;
    if (_type == PaymentType.rent) {
      due = dueOf(tenant, _month, ref.read(paymentsProvider),
              ref.read(rentRulesProvider), DateTime.now())
          .due;
    } else if (_type == PaymentType.electricity) {
      due = ref
          .read(electricityDuesProvider)
          .where((d) => d.tenant.id == tenant.id && sameMonth(d.month, _month))
          .fold(0.0, (s, d) => s + d.due);
    }
    return due > 0 ? due.toStringAsFixed(0) : '';
  }

  void _refreshSuggestion() => _amount.text = _suggestedAmount();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final tenant = ref.read(tenantsProvider.notifier).byId(_tenantId)!;
    ref.read(paymentsProvider.notifier).save(Payment(
          id: newId(),
          tenantId: tenant.id,
          amount: double.parse(_amount.text.trim()),
          type: _type,
          month: _month,
          date: _date,
          mode: _mode,
          note: _note.text.trim(),
        ));
    showSaved(context,
        '${money(double.parse(_amount.text.trim()))} from ${tenant.name} saved');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = ref.read(roomsProvider.notifier);
    final tenants = ref
        .watch(tenantsProvider)
        .where((t) => t.isActive || t.id == _tenantId)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final months = [
      for (var i = -12; i <= 1; i++) addMonths(monthOf(DateTime.now()), i)
    ];
    if (!months.any((m) => sameMonth(m, _month))) months.insert(0, _month);

    return Scaffold(
      appBar: AppBar(title: const Text('Record Payment')),
      bottomNavigationBar: tenants.isEmpty
          ? null
          : SaveBar(label: 'Save Payment', onPressed: _save),
      body: tenants.isEmpty
          ? Center(
              child: EmptyState(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Add a tenant first',
                message: 'Payments are recorded against a tenant.',
                actionLabel: 'Add Tenant',
                onAction: () => context.pushReplacement('/tenants/new'),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  PageBody(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const FormLabel('Who paid?'),
                        DropdownButtonFormField<String>(
                          initialValue: tenants.any((t) => t.id == _tenantId)
                              ? _tenantId
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Tenant *',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          items: [
                            for (final t in tenants)
                              DropdownMenuItem(
                                value: t.id,
                                child: Text(
                                  rooms.byId(t.roomId) == null
                                      ? t.name
                                      : '${t.name}  ·  Room ${rooms.byId(t.roomId)!.number}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          validator: (v) =>
                              v == null ? 'Please choose a tenant' : null,
                          onChanged: (v) => setState(() {
                            _tenantId = v;
                            _refreshSuggestion();
                          }),
                        ),
                        const FormLabel('Payment for'),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final t in PaymentType.values)
                            ChoiceChip(
                              label: Text(t.label),
                              selected: _type == t,
                              onSelected: (_) => setState(() {
                                _type = t;
                                _refreshSuggestion();
                              }),
                            ),
                        ]),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<DateTime>(
                          initialValue:
                              months.firstWhere((m) => sameMonth(m, _month)),
                          decoration: const InputDecoration(
                            labelText: 'For month',
                            prefixIcon: Icon(Icons.event_note_rounded),
                          ),
                          items: [
                            for (final m in months.reversed)
                              DropdownMenuItem(
                                  value: m, child: Text(fmtMonth(m))),
                          ],
                          onChanged: (v) => setState(() {
                            _month = v ?? _month;
                            _refreshSuggestion();
                          }),
                        ),
                        const FormLabel('Amount'),
                        TextFormField(
                          controller: _amount,
                          keyboardType: TextInputType.number,
                          inputFormatters: decimalOnly,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            labelText: 'Amount received *',
                            prefixText: '₹ ',
                            prefixIcon:
                                const Icon(Icons.currency_rupee_rounded),
                            helperText: (_type == PaymentType.rent ||
                                        _type == PaymentType.electricity) &&
                                    _tenantId != null
                                ? 'Filled with the amount due — change if different'
                                : 'Payments can\'t be edited after saving',
                          ),
                          validator: (v) {
                            final err = amountField(v, 'amount');
                            if (err != null) return err;
                            return double.parse(v!.trim()) <= 0
                                ? 'Amount must be more than 0'
                                : null;
                          },
                        ),
                        const FormLabel('Paid by'),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final m in paymentModes)
                            ChoiceChip(
                              label: Text(m),
                              selected: _mode == m,
                              onSelected: (_) => setState(() => _mode = m),
                            ),
                        ]),
                        const SizedBox(height: 14),
                        DateField(
                          label: 'Date received',
                          value: _date,
                          onChanged: (d) => setState(() => _date = d),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _note,
                          decoration: const InputDecoration(
                            labelText: 'Note (optional)',
                            hintText: 'e.g. UPI ref number',
                            prefixIcon: Icon(Icons.notes_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
