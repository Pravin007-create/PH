import 'package:equatable/equatable.dart';

class RentPayment extends Equatable {
  final int id;
  final String tenantName;
  final String roomNumber;
  final String bedNumber;
  final double amount;
  final String paymentDate;
  final String month;

  const RentPayment({
    this.id = 0,
    required this.tenantName,
    required this.roomNumber,
    required this.bedNumber,
    required this.amount,
    required this.paymentDate,
    required this.month,
  });

  RentPayment copyWith({
    int? id,
    String? tenantName,
    String? roomNumber,
    String? bedNumber,
    double? amount,
    String? paymentDate,
    String? month,
  }) {
    return RentPayment(
      id: id ?? this.id,
      tenantName: tenantName ?? this.tenantName,
      roomNumber: roomNumber ?? this.roomNumber,
      bedNumber: bedNumber ?? this.bedNumber,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      month: month ?? this.month,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_name': tenantName,
      'room_number': roomNumber,
      'bed_number': bedNumber,
      'amount': amount,
      'payment_date': paymentDate,
      'month': month,
    };
  }

  factory RentPayment.fromMap(Map<String, dynamic> map) {
    return RentPayment(
      id: map['id'] as int,
      tenantName: map['tenant_name'] as String,
      roomNumber: map['room_number'] as String,
      bedNumber: map['bed_number'] as String,
      amount: (map['amount'] as num).toDouble(),
      paymentDate: map['payment_date'] as String,
      month: map['month'] as String,
    );
  }

  @override
  List<Object?> get props => [tenantName, roomNumber, bedNumber, amount, paymentDate, month];
}