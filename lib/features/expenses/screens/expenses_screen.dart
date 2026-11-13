import 'package:flutter/material.dart';
import 'package:pg_hostel_management/core/theme/app_theme.dart';
import 'package:pg_hostel_management/features/expenses/models/expense.dart';
import 'package:pg_hostel_management/features/expenses/providers/expense_provider.dart';
import 'package:pg_hostel_management/core/securestorage/securestorage_service.dart';
import 'package:pg_hostel_management/core/router/app_router.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState;
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  final _categoryController = TextEditingController();
  final _searchController = TextEditingController();

  late final ExpenseNotifier _notifier;
  late final SecureStorageService _storage;
  List<Expense> _expenses = [];
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _storage = SecureStorageService();
    _notifier = context.read<ExpenseNotifier>();
    _loadExpenses();
    _initializeCategory();
    _initializeDate();
  }

  void _initializeCategory() {
    _categoryController.text = AppConstants.expenseCategories.first;
  }

  void _initializeDate() {
    final now = DateTime.now();
    _dateController.text = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadExpenses() async {
    final saved = await _storage.read(key: 'saved_expenses');
    if (saved != null) {
      // Parse expenses from stored data
    }
    setState(() {
      _expenses = [];
    });
  }

  void _addExpense() {
    if (_formKey.currentState!.validate()) {
      final expense = Expense(
        description: _descriptionController.text,
        amount: double.tryParse(_amountController.text) ?? 0.0,
        date: _dateController.text,
        category: _categoryController.text,
      );

      _notifier.addExpense(expense);
      _descriptionController.clear();
      _amountController.clear();
      _dateController.text = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      
      _loadExpenses(); // Refresh the list
    }
  }

  void _editExpense(Expense expense) {
    _descriptionController.text = expense.description;
    _amountController.text = expense.amount.toString();
    _dateController.text = expense.date;
    _categoryController.text = expense.category;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Expense'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      ValidationUtils.validateName(value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType(editor: TextInputType.number),
                  validator: (value) =>
                      ValidationUtils.validateExpenseAmount(value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  onTap: () async {
                    // Open date picker
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _categoryController.text.isNotEmpty ? _categoryController.text : AppConstants.expenseCategories.first,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: AppConstants.expenseCategories.map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  )).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      _categoryController.text = newValue;
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedExpense = expense.copyWith(
                description: _descriptionController.text,
                amount: double.tryParse(_amountController.text) ?? expense.amount,
                date: _dateController.text,
                category: _categoryController.text,
              );
              _notifier.updateExpense(updatedExpense);
              Navigator.of(context).pop();
              _loadExpenses();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteExpense(String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _notifier.removeExpense(description);
              Navigator.of(context).pop();
              _loadExpenses();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Expense deleted successfully'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalExpenses = _expenses.fold(0.0, (sum, e) => sum + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addExpense,
          ),
        ],
      ),
      body: Column(
        children: [
          // Total expenses summary
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children [
                    Text(
                      'Total Expenses',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    Text(
                      '\$${totalExpenses.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Expenses',
                border: OutlineInputBorder(),
                hintText: 'Enter description to search',
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Expenses list
          Expanded(
            child: _expenses.isEmpty
                ? const Center(
                    child: Text(
                      'No expense records found. Add an expense to get started.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _expenses.length,
                    itemBuilder: (context, index) {
                      final expense = _expenses[index];
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text('${expense.description}'),
                          subtitle: Text(
                            'Amount: \$${expense.amount.toStringAsFixed(2)} | Category: ${expense.category} | Date: ${expense.date}',
                          ),
                          trailing: Text(
                            '\$${expense.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}