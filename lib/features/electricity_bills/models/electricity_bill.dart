import 'package:equatable/equatable';

class ElectricityBill extends Equatable {
  final int id;
  final String tenantName;
  final String roomNumber;
  final String bedNumber;
  final double amount;
  final String billDate;
  final String month;

  const ElectricityBill({
    this.id = 0,
    required this.tenantName,
    required this.roomNumber,
    required this.bedNumber,
    required this.amount,
    required this.billDate,
    required this.month,
  });

  ElectricityBill copyWith({
    int? id,
    String? tenantName,
    String? roomNumber,
    String? bedNumber,
    double? amount,
    String? billDate,
    String? month,
  }) {
    return ElectricityBill(
      id: id ?? this.id,
      tenantName: tenantName ?? this.tenantName,
      roomNumber: roomNumber ?? this.roomNumber,
      bedNumber: bedNumber ?? this.bedNumber,
      amount: amount ?? this.amount,
      billDate: billDate ?? this.billDate,
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
      'bill_date': billDate,
      'month': month,
    };
  }

  factory ElectricityBill.fromMap(Map<String, dynamic> map) {
    return ElectricityBill(
      id: map['id'] as int,
      tenantName: map['tenant_name'] as String,
      roomNumber: map['room_number'] as String,
      bedNumber: map['bed_number'] as String,
      amount: (map['amount'] as num).toDouble(),
      billDate: map['bill_date'] as String,
      month: map['month'] as String,
    );
  }

  @override
  List<Object> get props => [tenantName, roomNumber, bedNumber, amount, billDate, month];
}