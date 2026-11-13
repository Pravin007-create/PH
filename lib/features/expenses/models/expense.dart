import 'package:equatable/equatable.dart';

class Expense extends Equatable {
  final int id;
  final String description;
  final double amount;
  final String date;
  final String category;

  const Expense({
    this.id = 0,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
  });

  Expense copyWith({
    int? id,
    String? description,
    double? amount,
    String? date,
    String? category,
  }) {
    return Expense(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'date': date,
      'category': category,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
      category: map['category'] as String,
    );
  }

  @override
  List<Object?> get props => [description, amount, date, category];
}