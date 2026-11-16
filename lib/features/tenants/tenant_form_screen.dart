import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/calculations.dart';
import '../../data/documents.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';
import '../../widgets/due_chip.dart';
import '../reports/report_builder.dart';
import 'documents_section.dart';

/// Add a tenant ([tenantId] == null), or view one with an Edit button.
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
  late DateTime? _relievingDate = _existing?.relievingDate;

  bool get _isEdit => _existing != null;

  /// Existing tenant: false = view mode, true = editing.
  bool _editing = false;

  void _cancelEdit() {
    final t = ref.read(tenantsProvider.notifier).byId(_existing!.id)!;
    setState(() {
      _name.text = t.name;
      _phone.text = t.phone;
      _rent.text = t.rent.toStringAsFixed(0);
      _deposit.text = t.deposit == 0 ? '' : t.deposit.toStringAsFixed(0);
      _notes.text = t.notes;
      _roomId = t.roomId;
      _joinDate = t.joinDate;
      _relievingDate = t.relievingDate;
      _editing = false;
    });
  }

  String _rentForRoom(String? roomId) {
    final room = ref.read(roomsProvider.notifier).byId(roomId);
    return room == null ? '' : room.rent.toStringAsFixed(0);
  }

  /// New tenant: id chosen up front so documents can be stored before Save.
  late final String _id = _existing?.id ?? newId();

  /// Documents added in the Add Tenant form (saved with the tenant).
  List<TenantDocument> _docs = [];
  bool _docsSubmitted = false;
  bool _saved = false;
  String? _docsDir;

  @override
  void initState() {
    super.initState();
    ref.read(docsDirProvider.future).then((d) => _docsDir = d).ignore();
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _rent, _deposit, _notes]) {
      c.dispose();
    }
    // Add form closed without saving: remove the photos it stored.
    if (!_isEdit && !_saved && _docs.isNotEmpty && _docsDir != null) {
      deleteDocumentFiles(_docsDir!, _docs);
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final live = ref.read(tenantsProvider.notifier).byId(_existing?.id);
    final tenant = Tenant(
      id: _id,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      roomId: _roomId,
      rent: double.parse(_rent.text.trim()),
      deposit: double.tryParse(_deposit.text.trim()) ?? 0,
      joinDate: _joinDate,
      relievingDate: _relievingDate,
      leaveDate: live?.leaveDate,
      notes: _notes.text.trim(),
      createdAt: live?.createdAt ?? DateTime.now(),
      settlement: live?.settlement,
      documents: live?.documents ?? _docs,
      documentsSubmitted: live?.documentsSubmitted ?? _docsSubmitted,
    );
    _saved = true;
    ref.read(tenantsProvider.notifier).save(tenant);
    if (_isEdit) {
      showSaved(context, '${tenant.name} updated');
      setState(() => _editing = false);
    } else {
      showSaved(context, '${tenant.name} added');
      context.pop();
    }
  }

  Future<void> _toggleMoveOut() async {
    final store = ref.read(tenantsProvider.notifier);
    final t = store.byId(_existing!.id)!;
    if (t.isActive) {
      // Settlement: advance − pending rent − deductions = refund.
      context.push('/tenants/${t.id}/move-out');
      return;
    }
    final ok = await confirmDialog(context,
        title: 'Move ${t.name} back in?',
        message: 'The move-out settlement record will be removed. '
            'Rent already adjusted from the advance stays recorded as paid.',
        confirmLabel: 'Move back in',
        destructive: false);
    if (!ok || !mounted) return;
    store.save(t.copyWith(
        clearLeaveDate: true, clearSettlement: true, clearRelievingDate: true));
    showSaved(context, '${t.name} is staying again');
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Delete ${_existing!.name}?',
        message:
            'This also hides them from reports. To keep history, use "Mark as moved out" instead.');
    if (!ok || !mounted) return;
    final docs =
        ref.read(tenantsProvider.notifier).byId(_existing!.id)?.documents;
    ref.read(tenantsProvider.notifier).remove(_existing!.id);
    if (docs != null && docs.isNotEmpty && _docsDir != null) {
      deleteDocumentFiles(_docsDir!, docs);
    }
    showSaved(context, 'Tenant deleted');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = [...ref.watch(roomsProvider)]
      ..sort((a, b) => a.number.compareTo(b.number));
    final occupancy = occupancyByRoom(ref.watch(tenantsProvider));
    // Earliest date a bed frees up in each room (someone else leaving).
    final leavingByRoom = <String, DateTime>{};
    for (final t in upcomingVacancies(ref.watch(tenantsProvider))) {
      if (t.roomId != null && t.id != _existing?.id) {
        leavingByRoom.putIfAbsent(t.roomId!, () => t.vacantFrom!);
      }
    }
    final live = _isEdit
        ? ref
            .watch(tenantsProvider)
            .where((t) => t.id == _existing!.id)
            .firstOrNull
        : null;
    if (_isEdit && live == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('This tenant no longer exists.')));
    }
    final viewing = _isEdit && !_editing;

    return PopScope(
      // Back while editing = cancel editing, not leave the page.
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing) _cancelEdit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _editing
              ? IconButton(
                  tooltip: 'Cancel editing',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _cancelEdit)
              : null,
          title: Text(!_isEdit
              ? 'Add Tenant'
              : _editing
                  ? 'Edit Tenant'
                  : 'Tenant Details'),
          actions: [
            if (viewing) ...[
              TextButton.icon(
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              IconButton(
                tooltip: 'Delete tenant',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _delete,
              ),
            ],
          ],
        ),
        bottomNavigationBar: viewing
            ? null
            : SaveBar(
                label: _isEdit ? 'Save Changes' : 'Save Tenant',
                onPressed: _save),
        body: viewing
            ? ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  PageBody(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TenantActions(
                            tenant: live!, onMoveOut: _toggleMoveOut),
                        _TenantInfo(tenant: live),
                        const FormLabel('Documents'),
                        DocumentsSection(
                          tenantId: live.id,
                          documents: live.documents,
                          submitted: live.documentsSubmitted,
                          // Saved straight away on the tenant page.
                          onChanged: (docs, submitted) => ref
                              .read(tenantsProvider.notifier)
                              .save(ref
                                  .read(tenantsProvider.notifier)
                                  .byId(live.id)!
                                  .copyWith(
                                      documents: docs,
                                      documentsSubmitted: submitted)),
                        ),
                        _PaymentHistory(tenantId: live.id),
                      ],
                    ),
                  ),
                ],
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
                            initialValue: rooms.any((r) => r.id == _roomId)
                                ? _roomId
                                : null,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Room',
                              prefixIcon:
                                  const Icon(Icons.meeting_room_outlined),
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
                                  // A full room can still be chosen if it's this
                                  // tenant's room, or someone in it is leaving.
                                  enabled: (occupancy[r.id] ?? 0) < r.beds ||
                                      r.id == _existing?.roomId ||
                                      leavingByRoom.containsKey(r.id),
                                  child: Text(
                                    'Room ${r.number}  ·  ${occupancy[r.id] ?? 0}/${r.beds} filled'
                                    '${(occupancy[r.id] ?? 0) < r.beds || r.id == _existing?.roomId ? '' : leavingByRoom.containsKey(r.id) ? '  (free from ${fmtDate(leavingByRoom[r.id]!)})' : '  (full)'}',
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
                          OptionalDateField(
                            label: 'Relieving date (optional)',
                            value: _relievingDate,
                            firstDate: _joinDate,
                            emptyText: 'Not leaving',
                            helperText: _relievingDate == null
                                ? 'Set when the tenant gives notice'
                                : 'Bed will be shown vacant from '
                                    '${fmtDate(_relievingDate!.add(const Duration(days: 1)))}',
                            onChanged: (d) =>
                                setState(() => _relievingDate = d),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _notes,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Notes (optional)',
                              hintText: 'Emergency contact, etc.',
                              prefixIcon: Icon(Icons.notes_rounded),
                            ),
                          ),
                          if (!_isEdit) ...[
                            const FormLabel('Documents (optional)'),
                            DocumentsSection(
                              tenantId: _id,
                              documents: _docs,
                              submitted: _docsSubmitted,
                              onChanged: (docs, submitted) => setState(() {
                                _docs = docs;
                                _docsSubmitted = submitted;
                              }),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Read-only tenant details (view mode).
class _TenantInfo extends ConsumerWidget {
  const _TenantInfo({required this.tenant});
  final Tenant tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref
        .watch(roomsProvider)
        .where((r) => r.id == tenant.roomId)
        .firstOrNull;
    Widget info(IconData icon, String label, String value,
            {VoidCallback? onTap}) =>
        ListTile(
          dense: true,
          leading: Icon(icon),
          title: Text(label),
          onTap: onTap,
          trailing: Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormLabel('Details'),
        Card(
          child: Column(children: [
            ListTile(
              leading: CircleAvatar(child: Text(initials(tenant.name))),
              title: Text(tenant.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('+91 ${tenant.phone}'),
                  if (tenant.isActive && !tenant.documentsSubmitted)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: DocsPendingChip(),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            info(Icons.meeting_room_outlined, 'Room',
                room == null ? 'Not assigned' : 'Room ${room.number}',
                onTap: room == null
                    ? null
                    : () => context.push('/rooms/${room.id}')),
            info(Icons.currency_rupee_rounded, 'Monthly rent',
                money(tenant.rent)),
            info(Icons.savings_outlined, 'Security deposit',
                tenant.deposit == 0 ? '—' : money(tenant.deposit)),
            info(Icons.calendar_today_rounded, 'Joined',
                fmtDate(tenant.joinDate)),
            if (tenant.isActive && tenant.relievingDate != null)
              info(Icons.event_busy_rounded, 'Relieving date',
                  fmtDate(tenant.relievingDate!)),
            if (tenant.leaveDate != null)
              info(Icons.logout_rounded, 'Moved out',
                  fmtDate(tenant.leaveDate!)),
            if (tenant.notes.isNotEmpty)
              ListTile(
                dense: true,
                leading: const Icon(Icons.notes_rounded),
                title: const Text('Notes'),
                subtitle: Text(tenant.notes),
              ),
          ]),
        ),
      ],
    );
  }
}

class _TenantActions extends ConsumerWidget {
  const _TenantActions({required this.tenant, required this.onMoveOut});
  final Tenant tenant;
  final VoidCallback onMoveOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(tenantsProvider);
    final tenant =
        ref.read(tenantsProvider.notifier).byId(this.tenant.id) ?? this.tenant;
    final month = ref.watch(currentRentMonthProvider);
    final dues = ref.watch(monthSummaryProvider(month)).dues;
    TenantDue? due;
    for (final d in dues) {
      if (d.tenant.id == tenant.id) due = d;
    }
    final olderOverdue = ref
        .watch(overdueProvider)
        .where((d) => d.tenant.id == tenant.id && !sameMonth(d.month, month))
        .toList();
    final power = ref
        .watch(electricityDuesProvider)
        .where((d) => d.tenant.id == tenant.id)
        .toList();
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
                  DueChip(due),
              ]),
              if (tenant.isActive && tenant.relievingDate != null)
                _RelievingBanner(tenant: tenant),
              if (due != null && !due.isPaid && tenant.isActive) ...[
                const SizedBox(height: 4),
                Text(
                    '${money(due.due)} to pay · due by ${fmtDate(due.dueDate)}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              for (final d in olderOverdue)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: InkWell(
                    onTap: () => context.push(
                        '/payments/new?tenant=${tenant.id}&month=${d.month.toIso8601String()}'),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 18, color: Color(0xFFDC2626)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            '${fmtMonth(d.month)}: ${money(d.due)} overdue',
                            style: const TextStyle(
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w600)),
                      ),
                      CollectButton(
                          onPressed: () => context.push(
                              '/payments/new?tenant=${tenant.id}&month=${d.month.toIso8601String()}')),
                    ]),
                  ),
                ),
              for (final d in power)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: InkWell(
                    onTap: () => context.push(
                        '/payments/new?tenant=${tenant.id}&type=electricity&month=${d.month.toIso8601String()}'),
                    child: Row(children: [
                      const Icon(Icons.bolt_rounded,
                          size: 18, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            'Electricity ${fmtMonthShort(d.month)}: ${money(d.due)} pending',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      CollectButton(
                          onPressed: () => context.push(
                              '/payments/new?tenant=${tenant.id}&type=electricity&month=${d.month.toIso8601String()}')),
                    ]),
                  ),
                ),
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
              if (tenant.settlement != null) _SettlementSummary(tenant: tenant),
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

/// Shown on a moved-out tenant: how the advance was settled.
class _SettlementSummary extends ConsumerWidget {
  const _SettlementSummary({required this.tenant});
  final Tenant tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = tenant.settlement!;
    Widget line(String a, String b, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(a)),
            Text(b,
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ]),
        );
    const red = Color(0xFFDC2626);
    final owes = s.stillOwed > 0;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Move-out settlement · ${fmtDate(s.date)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          line('Advance held', money(s.deposit)),
          if (s.collectedNow > 0)
            line('+ Cash collected', money(s.collectedNow)),
          if (s.rentAdjusted > 0)
            line('− Rent (${s.rentMonths.join(', ')})', money(s.rentAdjusted),
                color: red),
          for (final d in s.deductions)
            line('− ${d.label}', money(d.amount), color: red),
          const Divider(),
          line(owes ? 'Still to collect' : 'Refunded to tenant',
              money(owes ? s.stillOwed : s.refund),
              color: owes ? red : AppColors.success),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final room = ref.read(roomsProvider.notifier).byId(tenant.roomId);
              final bytes = await buildSettlementPdf(
                  ref.read(profileProvider), tenant, room?.number);
              await Printing.sharePdf(
                  bytes: bytes,
                  filename:
                      'Settlement_${tenant.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf');
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download settlement PDF'),
          ),
        ],
      ),
    );
  }
}

/// "Leaving on 30 Nov · bed free from 1 Dec" or, once the date has passed,
/// a red reminder to finish the move-out.
class _RelievingBanner extends StatelessWidget {
  const _RelievingBanner({required this.tenant});
  final Tenant tenant;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final date = dateOnly(tenant.relievingDate!);
    final pending = moveOutPending(tenant, today);
    final days = date.difference(today).inDays;
    final color = pending ? const Color(0xFFDC2626) : AppColors.purple;
    final text = pending
        ? 'Relieving date ${fmtDate(date)} has passed. Tap "Move out" to settle the advance.'
        : days == 0
            ? 'Leaving today · bed free from ${fmtDate(tenant.vacantFrom!)}'
            : 'Leaving on ${fmtDate(date)} (in $days day${days == 1 ? '' : 's'}) · '
                'bed free from ${fmtDate(tenant.vacantFrom!)}';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(pending ? Icons.warning_amber_rounded : Icons.event_busy_rounded,
            color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
