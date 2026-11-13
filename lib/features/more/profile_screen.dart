import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void dispose() {
    for (final c in [_pgName, _owner, _phone, _address]) {
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
