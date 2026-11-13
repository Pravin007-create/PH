import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';

/// Add a new room ([roomId] == null) or edit an existing one.
class RoomFormScreen extends ConsumerStatefulWidget {
  const RoomFormScreen({super.key, this.roomId});
  final String? roomId;

  @override
  ConsumerState<RoomFormScreen> createState() => _RoomFormScreenState();
}

class _RoomFormScreenState extends ConsumerState<RoomFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Room? _existing =
      ref.read(roomsProvider.notifier).byId(widget.roomId);
  late final _number = TextEditingController(text: _existing?.number);
  late final _floor = TextEditingController(text: _existing?.floor);
  late final _rent = TextEditingController(
      text: _existing?.rent.toStringAsFixed(0) ?? '');
  late final _notes = TextEditingController(text: _existing?.notes);
  late int _beds = _existing?.beds ?? 2;
  late bool _isAC = _existing?.isAC ?? false;

  bool get _isEdit => _existing != null;

  @override
  void dispose() {
    for (final c in [_number, _floor, _rent, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final number = _number.text.trim();
    final duplicate = ref.read(roomsProvider).any((r) =>
        r.number.toLowerCase() == number.toLowerCase() && r.id != _existing?.id);
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Room $number already exists.')));
      return;
    }
    ref.read(roomsProvider.notifier).save(Room(
          id: _existing?.id ?? newId(),
          number: number,
          floor: _floor.text.trim(),
          beds: _beds,
          rent: double.parse(_rent.text.trim()),
          isAC: _isAC,
          notes: _notes.text.trim(),
        ));
    showSaved(context, _isEdit ? 'Room $number updated' : 'Room $number added');
    context.pop();
  }

  Future<void> _delete() async {
    final inRoom = ref
        .read(tenantsProvider)
        .where((t) => t.isActive && t.roomId == _existing!.id)
        .length;
    if (inRoom > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'This room has $inRoom tenant(s). Move them out or change their room first.')));
      return;
    }
    final ok = await confirmDialog(context,
        title: 'Delete Room ${_existing!.number}?',
        message: 'This cannot be undone.');
    if (!ok || !mounted) return;
    ref.read(roomsProvider.notifier).remove(_existing!.id);
    showSaved(context, 'Room deleted');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tenantsHere = _isEdit
        ? ref
            .watch(tenantsProvider)
            .where((t) => t.isActive && t.roomId == _existing!.id)
            .toList()
        : <Tenant>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Room' : 'Add Room'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Delete room',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      bottomNavigationBar:
          SaveBar(label: _isEdit ? 'Save Changes' : 'Save Room', onPressed: _save),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FormLabel('Room details'),
                  TextFormField(
                    controller: _number,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Room number *',
                      hintText: 'e.g. 101',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                    validator: (v) => requiredField(v, 'room number'),
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(children: [
                        IconButton.filledTonal(
                          tooltip: 'Fewer beds',
                          onPressed:
                              _beds > 1 ? () => setState(() => _beds--) : null,
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        Expanded(
                          child: Column(children: [
                            Text('$_beds',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            Text(_beds == 1 ? 'Single room' : '$_beds-sharing'),
                          ]),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'More beds',
                          onPressed:
                              _beds < 20 ? () => setState(() => _beds++) : null,
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ]),
                    ),
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
                    child: SwitchListTile(
                      value: _isAC,
                      onChanged: (v) => setState(() => _isAC = v),
                      secondary: const Icon(Icons.ac_unit_rounded),
                      title: const Text('AC room'),
                    ),
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
                  if (_isEdit) ...[
                    FormLabel(
                        'Tenants in this room (${tenantsHere.length}/$_beds)'),
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
                        if (tenantsHere.length < _beds)
                          ListTile(
                            leading: const Icon(Icons.person_add_alt_1_rounded),
                            title: const Text('Add tenant to this room'),
                            onTap: () => context
                                .push('/tenants/new?room=${_existing!.id}'),
                          ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
