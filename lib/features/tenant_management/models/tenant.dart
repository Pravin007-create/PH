import 'package:equatable/equatable';
import 'package:pg_hostel_management/core/database/app_database.dart';

class Tenant extends Equatable {
  final int id;
  final String name;
  final String mobileNumber;
  final String email;
  final String address;
  final String roomNumber;
  final String bedNumber;
  final String moveInDate;
  final String? moveOutDate;
  final double rentPaid;
  final double depositPaid;
  final double outstandingBalance;

  const Tenant({
    this.id = 0,
    required this.name,
    required this.mobileNumber,
    required this.email,
    required this.address,
    required this.roomNumber,
    required this.bedNumber,
    required this.moveInDate,
    this.moveOutDate,
    required this.rentPaid,
    required this.depositPaid,
    required this.outstandingBalance,
  });

  Tenant copyWith({
    int? id,
    String? name,
    String? mobileNumber,
    String? email,
    String? address,
    String? roomNumber,
    String? bedNumber,
    String? moveInDate,
    String? moveOutDate,
    double? rentPaid,
    double? depositPaid,
    double? outstandingBalance,
  }) {
    return Tenant(
      id: id ?? this.id,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      roomNumber: roomNumber ?? this.roomNumber,
      bedNumber: bedNumber ?? this.bedNumber,
      moveInDate: moveInDate ?? this.moveInDate,
      moveOutDate: moveOutDate ?? this.moveOutDate,
      rentPaid: rentPaid ?? this.rentPaid,
      depositPaid: depositPaid ?? this.depositPaid,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mobile_number': mobileNumber,
      'email': email,
      'address': address,
      'room_number': roomNumber,
      'bed_number': bedNumber,
      'move_in_date': moveInDate,
      'move_out_date': moveOutDate,
      'rent_paid': rentPaid,
      'deposit_paid': depositPaid,
      'outstanding_balance': outstandingBalance,
    };
  }

  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      id: map['id'] as int,
      name: map['name'] as String,
      mobileNumber: map['mobile_number'] as String,
      email: map['email'] as String,
      address: map['address'] as String,
      roomNumber: map['room_number'] as String,
      bedNumber: map['bed_number'] as String,
      moveInDate: map['move_in_date'] as String,
      moveOutDate: map['move_out_date'] as String?,
      rentPaid: (map['rent_paid'] as num).toDouble(),
      depositPaid: (map['deposit_paid'] as num).toDouble(),
      outstandingBalance: (map['outstanding_balance'] as num).toDouble(),
    );
  }

  @override
  List<Object> get props => [
        name,
        mobileNumber,
        email,
        address,
        roomNumber,
        bedNumber,
        moveInDate,
        moveOutDate ?? '',
        rentPaid,
        depositPaid,
        outstandingBalance,
      ];
}