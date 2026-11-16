import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/calculations.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final PgProfile _p = ref.read(profileProvider);
  late final _pgName = TextEditingController(text: _p.pgName);
  late final _owner = TextEditingController(text: _p.ownerName);
  late final _phone = TextEditingController(text: _p.phone);
  late final _address = TextEditingController(text: _p.address);
  late final _unitRate =
      TextEditingController(text: _p.unitRate == 0 ? '' : _trim(_p.unitRate));
  late RentCycle _cycle = _p.rentCycle;
  late int _dueDays = _p.dueDays;

  @override
  void dispose() {
    for (final c in [_pgName, _owner, _phone, _address, _unitRate]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(profileProvider.notifier).save(PgProfile(
          pgName: _pgName.text.trim(),
          ownerName: _owner.text.trim(),
          phone: _phone.text.trim(),
          address: _address.text.trim(),
          rentCycle: _cycle,
          dueDays: _dueDays,
          unitRate: double.tryParse(_unitRate.text.trim()) ?? 0,
          language: ref.read(profileProvider).language,
        ));
    showSaved(context, 'PG details saved');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PG Details')),
      bottomNavigationBar: SaveBar(label: 'Save Details', onPressed: _save),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FormLabel('Shown on the home screen and on reports'),
                  TextFormField(
                    controller: _pgName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'PG / Hostel name *',
                      prefixIcon: Icon(Icons.apartment_rounded),
                    ),
                    validator: (v) => requiredField(v, 'PG name'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _owner,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Owner name *',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) => requiredField(v, 'owner name'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: digitsOnly,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Contact number (optional)',
                      prefixText: '+91 ',
                      prefixIcon: Icon(Icons.phone_outlined),
                      counterText: '',
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? null : phoneField(v),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _address,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Address (optional)',
                      prefixIcon: Icon(Icons.location_on_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  ..._rentRules(context),
                  const FormLabel('Electricity'),
                  TextFormField(
                    controller: _unitRate,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: decimalOnly,
                    decoration: const InputDecoration(
                      labelText: 'Unit rate (per unit)',
                      prefixText: '₹ ',
                      suffixText: '/ unit',
                      prefixIcon: Icon(Icons.bolt_rounded),
                      helperText: 'Used for rooms with separate electricity: '
                          '(new reading − last reading) × unit rate',
                      helperMaxLines: 2,
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

  List<Widget> _rentRules(BuildContext context) {
    final rules = RentRules(cycle: _cycle, dueDays: _dueDays);
    final example = rules.currentRentMonth(DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    return [
      const FormLabel('Rent collection'),
      Text('When do you collect rent for a month?',
          style: TextStyle(color: scheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      SegmentedButton<RentCycle>(
        segments: const [
          ButtonSegment(
              value: RentCycle.monthStart,
              label: Text('Start of month'),
              icon: Icon(Icons.first_page_rounded)),
          ButtonSegment(
              value: RentCycle.monthEnd,
              label: Text('End of month'),
              icon: Icon(Icons.last_page_rounded)),
        ],
        selected: {_cycle},
        onSelectionChanged: (v) => setState(() => _cycle = v.first),
      ),
      const SizedBox(height: 16),
      Text('How many days do tenants get to pay?',
          style: TextStyle(color: scheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            IconButton.filledTonal(
              tooltip: 'Fewer days',
              onPressed: _dueDays > 1 ? () => setState(() => _dueDays--) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              child: Column(children: [
                Text('$_dueDays',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(_dueDays == 1 ? 'day to pay' : 'days to pay'),
              ]),
            ),
            IconButton.filledTonal(
              tooltip: 'More days',
              onPressed:
                  _dueDays < 28 ? () => setState(() => _dueDays++) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      // Live example so the owner can see exactly what the setting means.
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rules.describe(example),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Between ${fmtDate(rules.collectFrom(example))} and '
                    '${fmtDate(rules.dueDate(example))} unpaid rent shows as '
                    '"Due". After ${fmtDate(rules.dueDate(example))} it shows '
                    'as OVERDUE with an alert on the home screen.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

/// 8.0 → "8", 8.5 → "8.5"
String _trim(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

