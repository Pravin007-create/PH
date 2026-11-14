import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/calculations.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';

const _red = Color(0xFFDC2626);

/// "101" → "102", "A-09" → "A-10", "G" → null (no number to increase).
String? nextRoomNumber(String number, int step) {
  final m = RegExp(r'^(.*?)(\d+)$').firstMatch(number.trim());
  if (m == null) return null;
  final digits = m.group(2)!;
  final n = int.parse(digits) + step;
  return '${m.group(1)}${n.toString().padLeft(digits.length, '0')}';
}

/// Room numbers for [count] rooms starting at [first]: 101, 102, 103...
List<String> autoRoomNumbers(String first, int count) => [
      for (var i = 0; i < count; i++)
        i == 0 ? first.trim() : (nextRoomNumber(first, i) ?? ''),
    ];

/// Add rooms ([roomId] == null), or view a room with an Edit button.
class RoomFormScreen extends ConsumerStatefulWidget {
  const RoomFormScreen({super.key, this.roomId});
  final String? roomId;

  @override
  ConsumerState<RoomFormScreen> createState() => _RoomFormScreenState();
}

class _RoomFormScreenState extends ConsumerState<RoomFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String? _id =
      ref.read(roomsProvider.notifier).byId(widget.roomId)?.id;
  final _number = TextEditingController();
  final _floor = TextEditingController();
  final _rent = TextEditingController();
  final _notes = TextEditingController();
  final _meter = TextEditingController();
  int _beds = 2;
  bool _isAC = false;
  bool _separateElectricity = false;

  // Adding several rooms of the same type.
  int _count = 1;
  bool _autoNumber = true;
  final _manualNumbers = <TextEditingController>[];

  /// Existing room: false = view mode, true = editing.
  bool _editing = false;

  bool get _isNew => _id == null;
  Room? get _room => ref.read(roomsProvider.notifier).byId(_id);

  @override
  void initState() {
    super.initState();
    _fillFromRoom();
  }

  void _fillFromRoom() {
    final r = _room;
    _number.text = r?.number ?? '';
    _floor.text = r?.floor ?? '';
    _rent.text = r == null ? '' : r.rent.toStringAsFixed(0);
    _notes.text = r?.notes ?? '';
    _beds = r?.beds ?? 2;
    _isAC = r?.isAC ?? false;
    _separateElectricity = r?.separateElectricity ?? false;
    _meter.text =
        r == null || r.meterReading == 0 ? '' : fmtUnits(r.meterReading);
  }

  @override
  void dispose() {
    for (final c in [
      _number,
      _floor,
      _rent,
      _notes,
      _meter,
      ..._manualNumbers
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setCount(int n) {
    setState(() {
      _count = n.clamp(1, 50);
      // Manual list: keep what was typed, fill new rows with auto numbers.
      final auto = autoRoomNumbers(_number.text, _count);
      while (_manualNumbers.length < _count) {
        _manualNumbers
            .add(TextEditingController(text: auto[_manualNumbers.length]));
      }
      while (_manualNumbers.length > _count) {
        _manualNumbers.removeLast().dispose();
      }
    });
  }

  void _setAuto(bool auto) {
    setState(() {
      _autoNumber = auto;
      if (!auto) {
        // Start the manual list from the auto numbers.
        final nums = autoRoomNumbers(_number.text, _count);
        for (var i = 0; i < _count; i++) {
          _manualNumbers[i].text = nums[i];
        }
      }
    });
  }

  List<String> get _numbersToCreate {
    if (_count == 1) return [_number.text.trim()];
    if (_autoNumber) return autoRoomNumbers(_number.text, _count);
    return [for (final c in _manualNumbers) c.text.trim()];
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final numbers = _isNew ? _numbersToCreate : [_number.text.trim()];
    if (numbers.any((n) => n.isEmpty)) {
      _snack(_autoNumber && _count > 1
          ? 'Starting number must end with a number (e.g. 101) to number '
              'rooms automatically. Or choose "Enter manually".'
          : 'Please enter every room number.');
      return;
    }
    final lower = numbers.map((n) => n.toLowerCase()).toList();
    if (lower.toSet().length != lower.length) {
      _snack('Room numbers must be different.');
      return;
    }
    final taken = ref
        .read(roomsProvider)
        .where((r) => r.id != _id && lower.contains(r.number.toLowerCase()))
        .map((r) => r.number)
        .toList();
    if (taken.isNotEmpty) {
      _snack('Room ${taken.join(', ')} already exists.');
      return;
    }

    final store = ref.read(roomsProvider.notifier);
    final base = DateTime.now().microsecondsSinceEpoch;
    for (final (i, number) in numbers.indexed) {
      store.save(Room(
        id: _id ?? '${base + i}',
        number: number,
        floor: _floor.text.trim(),
        beds: _beds,
        rent: double.parse(_rent.text.trim()),
        isAC: _isAC,
        separateElectricity: _separateElectricity,
        meterReading: double.tryParse(_meter.text.trim()) ?? 0,
        notes: _notes.text.trim(),
      ));
    }
    if (_isNew) {
      showSaved(
          context,
          numbers.length == 1
              ? 'Room ${numbers.first} added'
              : '${numbers.length} rooms added (${numbers.first} – ${numbers.last})');
      context.pop();
    } else {
      showSaved(context, 'Room ${numbers.first} updated');
      setState(() => _editing = false);
    }
  }

  void _cancelEdit() => setState(() {
        _fillFromRoom();
        _editing = false;
      });

  Future<void> _delete() async {
    final room = _room!;
    final inRoom = ref
        .read(tenantsProvider)
        .where((t) => t.isActive && t.roomId == room.id)
        .length;
    if (inRoom > 0) {
      _snack(
          'This room has $inRoom tenant(s). Move them out or change their room first.');
      return;
    }
    final ok = await confirmDialog(context,
        title: 'Delete Room ${room.number}?',
        message: 'This cannot be undone.');
    if (!ok || !mounted) return;
    ref.read(roomsProvider.notifier).remove(room.id);
    showSaved(context, 'Room deleted');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(roomsProvider);
    final room = _room;
    if (!_isNew && room == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('This room no longer exists.')));
    }
    final showForm = _isNew || _editing;

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
          title: Text(_isNew
              ? 'Add Room'
              : _editing
                  ? 'Edit Room ${room!.number}'
                  : 'Room ${room!.number}'),
          actions: [
            if (!_isNew && !_editing) ...[
              TextButton.icon(
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              IconButton(
                tooltip: 'Delete room',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _delete,
              ),
            ],
          ],
        ),
        bottomNavigationBar: showForm
            ? SaveBar(
                label: _isNew
                    ? (_count == 1 ? 'Save Room' : 'Create $_count Rooms')
                    : 'Save Changes',
                onPressed: _save)
            : null,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            PageBody(child: showForm ? _form(context) : _RoomView(room: room!)),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final multi = _isNew && _count > 1;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isNew) ...[
            const FormLabel('How many rooms of this type?'),
            _Stepper(
              value: _count,
              min: 1,
              max: 50,
              caption: _count == 1
                  ? 'One room'
                  : '$_count rooms with the same details',
              onChanged: _setCount,
              lessTooltip: 'Fewer rooms',
              moreTooltip: 'More rooms',
            ),
          ],
          const FormLabel('Room details'),
          if (multi) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: true,
                    icon: Icon(Icons.auto_awesome_rounded),
                    label: Text('Auto numbers')),
                ButtonSegment(
                    value: false,
                    icon: Icon(Icons.edit_note_rounded),
                    label: Text('Enter manually')),
              ],
              selected: {_autoNumber},
              onSelectionChanged: (s) => _setAuto(s.first),
            ),
            const SizedBox(height: 14),
          ],
          if (!multi || _autoNumber) ...[
            TextFormField(
              controller: _number,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: multi ? 'Starting room number *' : 'Room number *',
                hintText: 'e.g. 101',
                prefixIcon: const Icon(Icons.tag_rounded),
              ),
              validator: (v) => requiredField(v, 'room number'),
            ),
            if (multi) _NumberPreview(numbers: _numbersToCreate),
          ] else
            for (final (i, c) in _manualNumbers.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextFormField(
                  controller: c,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Room ${i + 1} number *',
                    prefixIcon: const Icon(Icons.tag_rounded),
                  ),
                  validator: (v) => requiredField(v, 'room number'),
                ),
              ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _floor,
            decoration: const InputDecoration(
              labelText: 'Floor (optional)',
              hintText: 'e.g. Ground, 1, 2',
              prefixIcon: Icon(Icons.stairs_rounded),
            ),
          ),
          const FormLabel('Number of beds (sharing)'),
          _Stepper(
            value: _beds,
            min: 1,
            max: 20,
            caption: _beds == 1 ? 'Single room' : '$_beds-sharing',
            onChanged: (v) => setState(() => _beds = v),
            lessTooltip: 'Fewer beds',
            moreTooltip: 'More beds',
          ),
          const FormLabel('Rent'),
          TextFormField(
            controller: _rent,
            keyboardType: TextInputType.number,
            inputFormatters: decimalOnly,
            decoration: const InputDecoration(
              labelText: 'Monthly rent per bed *',
              prefixText: '₹ ',
              prefixIcon: Icon(Icons.currency_rupee_rounded),
              helperText: 'Used as default rent for new tenants',
            ),
            validator: (v) => amountField(v, 'rent'),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              SwitchListTile(
                value: _isAC,
                onChanged: (v) => setState(() => _isAC = v),
                secondary: const Icon(Icons.ac_unit_rounded),
                title: const Text('AC room'),
              ),
              const Divider(height: 1),
              CheckboxListTile(
                value: _separateElectricity,
                onChanged: (v) =>
                    setState(() => _separateElectricity = v ?? false),
                secondary: const Icon(Icons.bolt_rounded),
                title: const Text('Electricity bill separate'),
                subtitle: const Text(
                    'Room bill is split equally between the tenants staying in it'),
              ),
              if (_separateElectricity)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: TextFormField(
                    controller: _meter,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: decimalOnly,
                    decoration: InputDecoration(
                      labelText: 'Units run till now (meter reading)',
                      suffixText: 'units',
                      prefixIcon: const Icon(Icons.speed_rounded),
                      helperText: _isNew && _count > 1
                          ? 'Same for all new rooms — change each room later'
                          : 'Current reading on the room\'s meter. Updated '
                              'automatically when you add a bill.',
                      helperMaxLines: 2,
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Attached bathroom, balcony, etc.',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.caption,
    required this.onChanged,
    required this.lessTooltip,
    required this.moreTooltip,
  });
  final int value;
  final int min;
  final int max;
  final String caption;
  final ValueChanged<int> onChanged;
  final String lessTooltip;
  final String moreTooltip;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            IconButton.filledTonal(
              tooltip: lessTooltip,
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              child: Column(children: [
                Text('$value',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text(caption, textAlign: TextAlign.center),
              ]),
            ),
            IconButton.filledTonal(
              tooltip: moreTooltip,
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ]),
        ),
      );
}

class _NumberPreview extends StatelessWidget {
  const _NumberPreview({required this.numbers});
  final List<String> numbers;

  @override
  Widget build(BuildContext context) {
    final bad = numbers.skip(1).any((n) => n.isEmpty);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: bad
          ? Text(
              'Starting number must end with a number (e.g. 101 or A1) to '
              'number rooms automatically.',
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(color: _red))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rooms that will be created:',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final n in numbers)
                    if (n.isNotEmpty)
                      StatusChip('Room $n', color: AppColors.seed),
                ]),
              ],
            ),
    );
  }
}

/// Read-only room page.
class _RoomView extends ConsumerWidget {
  const _RoomView({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsHere = ref
        .watch(tenantsProvider)
        .where((t) => t.isActive && t.roomId == room.id)
        .toList();
    Widget info(IconData icon, String label, String value) => ListTile(
          dense: true,
          leading: Icon(icon),
          title: Text(label),
          trailing: Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Card(
          child: Column(children: [
            info(Icons.tag_rounded, 'Room number', room.number),
            if (room.floor.isNotEmpty)
              info(Icons.stairs_rounded, 'Floor', room.floor),
            info(Icons.bed_outlined, 'Beds',
                room.beds == 1 ? 'Single' : '${room.beds}-sharing'),
            info(
                Icons.currency_rupee_rounded, 'Rent per bed', money(room.rent)),
            info(Icons.ac_unit_rounded, 'AC', room.isAC ? 'Yes' : 'No'),
            info(Icons.bolt_rounded, 'Electricity',
                room.separateElectricity ? 'Separate (split)' : 'Included'),
            if (room.separateElectricity)
              info(Icons.speed_rounded, 'Units run till now',
                  '${fmtUnits(room.meterReading)} units'),
            if (room.notes.isNotEmpty)
              ListTile(
                dense: true,
                leading: const Icon(Icons.notes_rounded),
                title: const Text('Notes'),
                subtitle: Text(room.notes),
              ),
          ]),
        ),
        FormLabel('Tenants in this room (${tenantsHere.length}/${room.beds})'),
        Card(
          child: Column(children: [
            for (final t in tenantsHere)
              ListTile(
                leading: CircleAvatar(child: Text(initials(t.name))),
                title: Text(t.name),
                subtitle: Text(t.relievingDate == null
                    ? t.phone
                    : '${t.phone} · leaving ${fmtDate(t.relievingDate!)}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/tenants/${t.id}'),
              ),
            if (tenantsHere.length < room.beds ||
                tenantsHere.any((t) => t.relievingDate != null))
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: const Text('Add tenant to this room'),
                subtitle: tenantsHere.length < room.beds
                    ? null
                    : Text(
                        'Bed free from ${fmtDate(upcomingVacancies(tenantsHere).first.vacantFrom!)}'),
                onTap: () => context.push('/tenants/new?room=${room.id}'),
              ),
          ]),
        ),
        if (room.separateElectricity) _ElectricitySection(room: room),
      ],
    );
  }
}

class _ElectricitySection extends ConsumerWidget {
  const _ElectricitySection({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref
        .watch(electricityBillsProvider)
        .where((b) => b.roomId == room.id)
        .toList();
    final shares = electricityShares(
        bills, ref.watch(tenantsProvider), ref.watch(paymentsProvider));
    final sorted = [...bills]..sort((a, b) => b.month.compareTo(a.month));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FormLabel('Electricity bills'),
        FilledButton.tonalIcon(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => ElectricityBillSheet(room: room),
          ),
          icon: const Icon(Icons.bolt_rounded),
          label: const Text('Add Electricity Bill +'),
        ),
        const SizedBox(height: 8),
        if (sorted.isEmpty)
          Text(
              'Enter the room\'s bill each month. It is split equally between '
              'the tenants who stayed in the room that month.',
              style: Theme.of(context).textTheme.bodySmall)
        else
          for (final b in sorted)
            _BillCard(
                bill: b,
                shares: shares.where((s) => s.bill.id == b.id).toList()),
      ],
    );
  }
}

class _BillCard extends ConsumerWidget {
  const _BillCard({required this.bill, required this.shares});
  final ElectricityBill bill;
  final List<ElectricityDue> shares;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = shares.fold<double>(0, (s, d) => s + d.due);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const IconBadge(
                icon: Icons.bolt_rounded, color: AppColors.warning),
            title: Text('${fmtMonth(bill.month)} · ${money(bill.amount)}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text([
              if (bill.fromMeter)
                'Meter ${fmtUnits(bill.previousReading ?? 0)} → ${fmtUnits(bill.currentReading!)} = '
                    '${fmtUnits(bill.units)} units × ${money(bill.unitRate ?? 0)}'
              else if (bill.units > 0)
                '${fmtUnits(bill.units)} units',
              '${bill.tenantIds.length} people · ${money(bill.share)} each',
            ].join('\n')),
            isThreeLine: bill.fromMeter,
            trailing: IconButton(
              tooltip: 'Delete bill',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final ok = await confirmDialog(context,
                    title: 'Delete ${fmtMonth(bill.month)} bill?',
                    message: 'Electricity payments already recorded are kept.');
                if (ok) {
                  ref.read(electricityBillsProvider.notifier).remove(bill.id);
                  // Undo the meter update if this was the latest bill.
                  final rooms = ref.read(roomsProvider.notifier);
                  final room = rooms.byId(bill.roomId);
                  if (room != null &&
                      bill.fromMeter &&
                      room.meterReading == bill.currentReading) {
                    rooms.save(
                        room.copyWith(meterReading: bill.previousReading ?? 0));
                  }
                }
              },
            ),
          ),
          for (final s in shares)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 72, right: 12),
              title: Text(s.tenant.name),
              subtitle: Text(s.isPaid
                  ? 'Paid ${money(s.share)}'
                  : s.paid > 0
                      ? 'Paid ${money(s.paid)} · ${money(s.due)} pending'
                      : '${money(s.due)} pending'),
              trailing: s.isPaid
                  ? const StatusChip('Paid', color: AppColors.success)
                  : TextButton(
                      onPressed: () => context.push(
                          '/payments/new?tenant=${s.tenant.id}&type=electricity'
                          '&month=${bill.month.toIso8601String()}'),
                      child: const Text('Collect'),
                    ),
            ),
          if (pending > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
              child: Text('${money(pending)} still to collect',
                  style: const TextStyle(
                      color: _red, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet: enter a month's bill for a room and split it.
/// Meter mode: (new reading − last reading) × unit rate = amount; the new
/// reading is then saved on the room as "units run till now".
class ElectricityBillSheet extends ConsumerStatefulWidget {
  const ElectricityBillSheet({super.key, required this.room});
  final Room room;

  @override
  ConsumerState<ElectricityBillSheet> createState() =>
      _ElectricityBillSheetState();
}

class _ElectricityBillSheetState extends ConsumerState<ElectricityBillSheet> {
  final _formKey = GlobalKey<FormState>();
  late final double _rate = ref.read(profileProvider).unitRate;
  late bool _useMeter = _rate > 0;
  late final _last = TextEditingController(
      text: widget.room.meterReading == 0
          ? ''
          : fmtUnits(widget.room.meterReading));
  final _now = TextEditingController();
  late final _unitRate =
      TextEditingController(text: _rate == 0 ? '' : fmtUnits(_rate));
  final _amount = TextEditingController();
  final _units = TextEditingController();
  // The bill usually arrives after the month ends → default last month.
  DateTime _month = addMonths(monthOf(DateTime.now()), -1);
  late Set<String> _selected = _defaultTenants();

  Set<String> _defaultTenants() =>
      tenantsInRoomFor(widget.room.id, _month, ref.read(tenantsProvider))
          .map((t) => t.id)
          .toSet();

  @override
  void dispose() {
    for (final c in [_last, _now, _unitRate, _amount, _units]) {
      c.dispose();
    }
    super.dispose();
  }

  double _n(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;
  double get _meterUnits => max(0, _n(_now) - _n(_last));
  double get _total => _useMeter ? _meterUnits * _n(_unitRate) : _n(_amount);

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose who shares this bill.')));
      return;
    }
    if (_total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bill amount is ₹0. Check the readings.')));
      return;
    }
    ref.read(electricityBillsProvider.notifier).save(ElectricityBill(
          id: newId(),
          roomId: widget.room.id,
          month: _month,
          amount: double.parse(_total.toStringAsFixed(2)),
          units: _useMeter ? _meterUnits : _n(_units),
          previousReading: _useMeter ? _n(_last) : null,
          currentReading: _useMeter ? _n(_now) : null,
          unitRate: _useMeter ? _n(_unitRate) : null,
          tenantIds: _selected.toList(),
          createdAt: DateTime.now(),
        ));
    if (_useMeter) {
      // New reading becomes the room's "units run till now".
      final rooms = ref.read(roomsProvider.notifier);
      final room = rooms.byId(widget.room.id);
      if (room != null) rooms.save(room.copyWith(meterReading: _n(_now)));
    }
    Navigator.pop(context);
    showSaved(context,
        'Electricity bill ${money(_total)} added for ${fmtMonth(_month)}');
  }

  InputDecoration _dec(String label,
          {String? suffix, String? prefix, String? helper}) =>
      InputDecoration(
          labelText: label,
          suffixText: suffix,
          prefixText: prefix,
          helperText: helper,
          helperMaxLines: 2);

  @override
  Widget build(BuildContext context) {
    final allTenants = ref.watch(tenantsProvider);
    // Anyone who stayed in the room that month, plus anyone already ticked.
    final candidates = {
      for (final t in tenantsInRoomFor(widget.room.id, _month, allTenants))
        t.id: t,
      for (final t in allTenants.where((t) => _selected.contains(t.id)))
        t.id: t,
    }.values.toList();
    final total = _total;
    final share = _selected.isEmpty ? 0.0 : total / _selected.length;
    final months = [
      for (var i = 0; i >= -12; i--) addMonths(monthOf(DateTime.now()), i)
    ];
    void refresh(String _) => setState(() {});

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Electricity bill · Room ${widget.room.number}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                DropdownButtonFormField<DateTime>(
                  initialValue: months.firstWhere((m) => sameMonth(m, _month)),
                  decoration: const InputDecoration(
                    labelText: 'Bill for month',
                    prefixIcon: Icon(Icons.event_note_rounded),
                  ),
                  items: [
                    for (final m in months)
                      DropdownMenuItem(value: m, child: Text(fmtMonth(m))),
                  ],
                  onChanged: (v) => setState(() {
                    _month = v ?? _month;
                    _selected = _defaultTenants();
                  }),
                ),
                const SizedBox(height: 14),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: true,
                        icon: Icon(Icons.speed_rounded, size: 18),
                        label: Text('Meter reading')),
                    ButtonSegment(
                        value: false,
                        icon: Icon(Icons.currency_rupee_rounded, size: 18),
                        label: Text('Enter amount')),
                  ],
                  selected: {_useMeter},
                  onSelectionChanged: (v) =>
                      setState(() => _useMeter = v.first),
                ),
                const SizedBox(height: 14),
                if (_useMeter) ...[
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _last,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: decimalOnly,
                        onChanged: refresh,
                        decoration: _dec('Units run till now', suffix: 'units'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _now,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: decimalOnly,
                        onChanged: refresh,
                        decoration: _dec('Now unit *', suffix: 'units'),
                        validator: (v) {
                          final now = double.tryParse(v?.trim() ?? '');
                          if (now == null) return 'Enter reading';
                          if (now < _n(_last)) return 'Less than last';
                          return null;
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _unitRate,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: decimalOnly,
                    onChanged: refresh,
                    decoration: _dec('Unit rate *',
                        prefix: '₹ ',
                        suffix: '/ unit',
                        helper: _rate == 0
                            ? 'Tip: save the unit rate in PG details to fill this automatically'
                            : 'From PG details · change for this bill if needed'),
                    validator: (v) =>
                        (double.tryParse(v?.trim() ?? '') ?? 0) <= 0
                            ? 'Enter unit rate'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  _CalcCard(lines: [
                    ('Now unit', fmtUnits(_n(_now))),
                    ('− Units run till now', fmtUnits(_n(_last))),
                    ('= Units used', fmtUnits(_meterUnits)),
                    ('× Unit rate', money(_n(_unitRate))),
                  ], total: total),
                ] else ...[
                  Row(children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _amount,
                        keyboardType: TextInputType.number,
                        inputFormatters: decimalOnly,
                        onChanged: refresh,
                        decoration: _dec('Bill amount *', prefix: '₹ '),
                        validator: (v) {
                          final err = amountField(v, 'amount');
                          if (err != null) return err;
                          return double.parse(v!.trim()) <= 0
                              ? 'More than 0'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _units,
                        keyboardType: TextInputType.number,
                        inputFormatters: decimalOnly,
                        decoration: _dec('Units (optional)'),
                      ),
                    ),
                  ]),
                ],
                const FormLabel('Split between'),
                if (candidates.isEmpty)
                  Text('No tenants stayed in this room in ${fmtMonth(_month)}.',
                      style: Theme.of(context).textTheme.bodySmall)
                else
                  Card(
                    child: Column(children: [
                      for (final t in candidates)
                        CheckboxListTile(
                          value: _selected.contains(t.id),
                          onChanged: (v) => setState(() => v == true
                              ? _selected.add(t.id)
                              : _selected.remove(t.id)),
                          title: Text(t.name),
                          subtitle: t.isActive
                              ? null
                              : Text('Moved out ${fmtDate(t.leaveDate!)}'),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                    ]),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.bolt_rounded, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_selected.isEmpty
                          ? 'Choose who shares the bill'
                          : '${money(total)} ÷ ${_selected.length} = '
                              '${money(share)} per person'),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                      total > 0 ? 'Save Bill · ${money(total)}' : 'Save Bill'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Now unit 1350 / − last 1250 / = 100 units / × ₹8 / Amount ₹800".
class _CalcCard extends StatelessWidget {
  const _CalcCard({required this.lines, required this.total});
  final List<(String, String)> lines;
  final double total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        for (final (label, value) in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Expanded(child: Text(label)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
        const Divider(height: 16),
        Row(children: [
          const Expanded(
              child: Text('Bill amount',
                  style: TextStyle(fontWeight: FontWeight.w700))),
          Text(money(total),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary)),
        ]),
      ]),
    );
  }
}
