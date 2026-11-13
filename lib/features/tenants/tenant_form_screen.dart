import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/calculations.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';

/// Add a tenant ([tenantId] == null) or view/edit an existing one.
class TenantFormScreen extends ConsumerStatefulWidget {
  const TenantFormScreen({super.key, this.tenantId, this.roomId});
  final String? tenantId;

  /// Pre-selected room when adding from a room page.
  final String? roomId;

  @override
  ConsumerState<TenantFormScreen> createState() => _TenantFormScreenState();
}

class _TenantFormScreenState extends ConsumerState<TenantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Tenant? _existing =
      ref.read(tenantsProvider.notifier).byId(widget.tenantId);
  late final _name = TextEditingController(text: _existing?.name);
  late final _phone = TextEditingController(text: _existing?.phone);
  late final _rent = TextEditingController(
      text: _existing?.rent.toStringAsFixed(0) ?? _rentForRoom(widget.roomId));
  late final _deposit = TextEditingController(
      text: _existing == null || _existing!.deposit == 0
          ? ''
          : _existing!.deposit.toStringAsFixed(0));
  late final _notes = TextEditingController(text: _existing?.notes);
  late String? _roomId = _existing?.roomId ?? widget.roomId;
  late DateTime _joinDate = _existing?.joinDate ?? DateTime.now();

  bool get _isEdit => _existing != null;

  String _rentForRoom(String? roomId) {
    final room = ref.read(roomsProvider.notifier).byId(roomId);
    return room == null ? '' : room.rent.toStringAsFixed(0);
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _rent, _deposit, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final tenant = Tenant(
      id: _existing?.id ?? newId(),
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      roomId: _roomId,
      rent: double.parse(_rent.text.trim()),
      deposit: double.tryParse(_deposit.text.trim()) ?? 0,
      joinDate: _joinDate,
      leaveDate: _existing?.leaveDate,
      notes: _notes.text.trim(),
    );
    ref.read(tenantsProvider.notifier).save(tenant);
    showSaved(context,
        _isEdit ? '${tenant.name} updated' : '${tenant.name} added');
    context.pop();
  }

  Future<void> _toggleMoveOut() async {
    final t = _existing!;
    final store = ref.read(tenantsProvider.notifier);
    if (t.isActive) {
      final ok = await confirmDialog(context,
          title: 'Mark ${t.name} as moved out?',
          message:
              'Their bed becomes vacant. Payment history is kept for reports.',
          confirmLabel: 'Move out',
          destructive: false);
      if (!ok || !mounted) return;
      store.save(t.copyWith(leaveDate: DateTime.now()));
      showSaved(context, '${t.name} marked as moved out');
    } else {
      store.save(t.copyWith(clearLeaveDate: true));
      showSaved(context, '${t.name} is staying again');
    }
    context.pop();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Delete ${_existing!.name}?',
        message:
            'This also hides them from reports. To keep history, use "Mark as moved out" instead.');
    if (!ok || !mounted) return;
    ref.read(tenantsProvider.notifier).remove(_existing!.id);
    showSaved(context, 'Tenant deleted');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = [...ref.watch(roomsProvider)]
      ..sort((a, b) => a.number.compareTo(b.number));
    final occupancy = occupancyByRoom(ref.watch(tenantsProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Tenant Details' : 'Add Tenant'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Delete tenant',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      bottomNavigationBar: SaveBar(
          label: _isEdit ? 'Save Changes' : 'Save Tenant', onPressed: _save),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isEdit) _TenantActions(tenant: _existing!, onMoveOut: _toggleMoveOut),
                  const FormLabel('Personal details'),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name *',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) => requiredField(v, 'name'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: digitsOnly,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Mobile number *',
                      prefixText: '+91 ',
                      prefixIcon: Icon(Icons.phone_outlined),
                      counterText: '',
                    ),
                    validator: phoneField,
                  ),
                  const FormLabel('Room & rent'),
                  DropdownButtonFormField<String?>(
                    initialValue: rooms.any((r) => r.id == _roomId) ? _roomId : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Room',
                      prefixIcon: const Icon(Icons.meeting_room_outlined),
                      helperText: rooms.isEmpty
                          ? 'No rooms yet — add rooms from the Rooms tab'
                          : null,
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('No room assigned')),
                      for (final r in rooms)
                        DropdownMenuItem(
                          value: r.id,
                          // A full room can still be chosen if it's this tenant's room.
                          enabled: (occupancy[r.id] ?? 0) < r.beds ||
                              r.id == _existing?.roomId,
                          child: Text(
                            'Room ${r.number}  ·  ${occupancy[r.id] ?? 0}/${r.beds} filled'
                            '${(occupancy[r.id] ?? 0) >= r.beds && r.id != _existing?.roomId ? '  (full)' : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _roomId = v;
                      final rent = _rentForRoom(v);
                      if (rent.isNotEmpty) _rent.text = rent;
                    }),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _rent,
                    keyboardType: TextInputType.number,
                    inputFormatters: decimalOnly,
                    decoration: const InputDecoration(
                      labelText: 'Monthly rent *',
                      prefixText: '₹ ',
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                    ),
                    validator: (v) => amountField(v, 'monthly rent'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _deposit,
                    keyboardType: TextInputType.number,
                    inputFormatters: decimalOnly,
                    decoration: const InputDecoration(
                      labelText: 'Security deposit (optional)',
                      prefixText: '₹ ',
                      prefixIcon: Icon(Icons.savings_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DateField(
                    label: 'Joining date',
                    value: _joinDate,
                    onChanged: (d) => setState(() => _joinDate = d),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _notes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'ID proof, emergency contact, etc.',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  if (_isEdit) _PaymentHistory(tenantId: _existing!.id),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TenantActions extends ConsumerWidget {
  const _TenantActions({required this.tenant, required this.onMoveOut});
  final Tenant tenant;
  final VoidCallback onMoveOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = monthOf(DateTime.now());
    final dues = ref.watch(monthSummaryProvider(month)).dues;
    TenantDue? due;
    for (final d in dues) {
      if (d.tenant.id == tenant.id) due = d;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Text('Rent for ${fmtMonth(month)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (!tenant.isActive)
                  StatusChip(
                      'Moved out ${tenant.leaveDate == null ? '' : fmtDate(tenant.leaveDate!)}',
                      color: Colors.grey)
                else if (due != null)
                  due.isPaid
                      ? const StatusChip('Paid', color: AppColors.success)
                      : StatusChip('Due ${money(due.due)}',
                          color: AppColors.warning),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                if (tenant.isActive) ...[
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44)),
                      onPressed: () =>
                          context.push('/payments/new?tenant=${tenant.id}'),
                      icon: const Icon(Icons.currency_rupee_rounded, size: 18),
                      label: const Text('Record Payment'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44)),
                    onPressed: onMoveOut,
                    icon: Icon(
                        tenant.isActive
                            ? Icons.logout_rounded
                            : Icons.login_rounded,
                        size: 18),
                    label: Text(tenant.isActive ? 'Move out' : 'Move back in'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentHistory extends ConsumerWidget {
  const _PaymentHistory({required this.tenantId});
  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref
        .watch(paymentsProvider)
        .where((p) => p.tenantId == tenantId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormLabel('Payment history (${payments.length})'),
        if (payments.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No payments recorded yet.'),
            ),
          )
        else
          Card(
            child: Column(children: [
              for (final p in payments)
                ListTile(
                  dense: true,
                  onTap: () => context.push('/payments/${p.id}'),
                  title: Text('${p.type.label} · ${fmtMonthShort(p.month)}'),
                  subtitle: Text('${fmtDate(p.date)} · ${p.mode}'),
                  trailing: Text(money(p.amount),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.success)),
                ),
            ]),
          ),
      ],
    );
  }
}
