import 'dart:convert';

import 'package:pg_hostel_management/features/expenses/models/expense.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pg_hostel_management/core/securestorage/securestorage_service.dart';

final expenseProvider = StateNotifierProvider<ExpenseNotifier, List<Expense>>((ref) {
  final storage = SecureStorageService();
  return ExpenseNotifier(storage);
});

class ExpenseNotifier extends StateNotifier<List<Expense>> {
  final SecureStorageService _storage;

  ExpenseNotifier(this._storage) : super(const []);

  void addExpense(Expense expense) {
    state = [...state, expense];
    _saveExpenses();
  }

  void updateExpense(Expense expense) {
    final index = state.indexWhere((e) => e.description == expense.description);
    if (index >= 0) {
      state = [...state]..[index] = expense;
      _saveExpenses();
    }
  }

  void removeExpense(String description) {
    state = state.where((e) => e.description != description).toList();
    _saveExpenses();
  }

  List<Expense> getExpensesByCategory(String category) {
    return state.where((e) => e.category == category).toList();
  }

  double getTotalExpenses() {
    return state.fold(0.0, (sum, e) => sum + e.amount);
  }

  double getTotalExpensesByCategory(String category) {
    return state.where((e) => e.category == category).fold(0.0, (sum, e) => sum + e.amount);
  }

  void _saveExpenses() {
    final expenseData = state.map((expense) => expense.toMap()).toList();
    _storage.write(key: 'saved_expenses', value: jsonEncode(expenseData));
  }
}