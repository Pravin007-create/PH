import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';
import 'expenses_screen.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, this.expenseId});
  final String? expenseId;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Expense? _existing =
      ref.read(expensesProvider.notifier).byId(widget.expenseId);
  late final _title = TextEditingController(text: _existing?.title);
  late final _amount =
      TextEditingController(text: _existing?.amount.toStringAsFixed(0));
  late final _note = TextEditingController(text: _existing?.note);
  late String _category = _existing?.category ?? expenseCategories.first;
  late DateTime _date = _existing?.date ?? DateTime.now();

  bool get _isEdit => _existing != null;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final title = _title.text.trim().isEmpty ? _category : _title.text.trim();
    ref.read(expensesProvider.notifier).save(Expense(
          id: _existing?.id ?? newId(),
          title: title,
          category: _category,
          amount: double.parse(_amount.text.trim()),
          date: _date,
          note: _note.text.trim(),
        ));
    showSaved(context, _isEdit ? 'Expense updated' : 'Expense added');
    context.pop();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Delete this expense?', message: 'This cannot be undone.');
    if (!ok || !mounted) return;
    ref.read(expensesProvider.notifier).remove(_existing!.id);
    showSaved(context, 'Expense deleted');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Expense' : 'Add Expense'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Delete expense',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      bottomNavigationBar: SaveBar(
          label: _isEdit ? 'Save Changes' : 'Save Expense', onPressed: _save),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            PageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FormLabel('Category'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final c in expenseCategories)
                      ChoiceChip(
                        avatar: Icon(expenseIcon(c), size: 18),
                        label: Text(c),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                  ]),
                  const FormLabel('Details'),
                  TextFormField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: decimalOnly,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      labelText: 'Amount *',
                      prefixText: '₹ ',
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                    ),
                    validator: (v) => amountField(v, 'amount'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'e.g. $_category bill for ${fmtMonthShort(_date)}',
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DateField(
                    label: 'Date',
                    value: _date,
                    onChanged: (d) => setState(() => _date = d),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _note,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
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
