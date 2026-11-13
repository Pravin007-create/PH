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
  }

  @override
  void dispose() {
    for (final c in [_number, _floor, _rent, _notes, ..._manualNumbers]) {
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
                subtitle: Text(t.phone),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/tenants/${t.id}'),
              ),
            if (tenantsHere.length < room.beds)
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: const Text('Add tenant to this room'),
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
            subtitle: Text(
                '${bill.units > 0 ? '${bill.units.toStringAsFixed(0)} units · ' : ''}'
                '${bill.tenantIds.length} people · ${money(bill.share)} each'),
            trailing: IconButton(
              tooltip: 'Delete bill',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final ok = await confirmDialog(context,
                    title: 'Delete ${fmtMonth(bill.month)} bill?',
                    message: 'Electricity payments already recorded are kept.');
                if (ok) {
                  ref.read(electricityBillsProvider.notifier).remove(bill.id);
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
class ElectricityBillSheet extends ConsumerStatefulWidget {
  const ElectricityBillSheet({super.key, required this.room});
  final Room room;

  @override
  ConsumerState<ElectricityBillSheet> createState() =>
      _ElectricityBillSheetState();
}

class _ElectricityBillSheetState extends ConsumerState<ElectricityBillSheet> {
  final _formKey = GlobalKey<FormState>();
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
    _amount.dispose();
    _units.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose who shares this bill.')));
      return;
    }
    ref.read(electricityBillsProvider.notifier).save(ElectricityBill(
          id: newId(),
          roomId: widget.room.id,
          month: _month,
          amount: double.parse(_amount.text.trim()),
          units: double.tryParse(_units.text.trim()) ?? 0,
          tenantIds: _selected.toList(),
          createdAt: DateTime.now(),
        ));
    Navigator.pop(context);
    showSaved(context, 'Electricity bill added for ${fmtMonth(_month)}');
  }

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
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    final share = _selected.isEmpty ? 0.0 : amount / _selected.length;
    final months = [
      for (var i = 0; i >= -12; i--) addMonths(monthOf(DateTime.now()), i)
    ];

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
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _amount,
                      keyboardType: TextInputType.number,
                      inputFormatters: decimalOnly,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Bill amount *',
                        prefixText: '₹ ',
                      ),
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
                      decoration:
                          const InputDecoration(labelText: 'Units (optional)'),
                    ),
                  ),
                ]),
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
                          : '${money(amount)} ÷ ${_selected.length} = '
                              '${money(share)} per person'),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save Bill'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
