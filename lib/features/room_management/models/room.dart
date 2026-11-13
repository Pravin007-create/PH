import 'package:equatable/equatable.dart';

class Room extends Equatable {
  final String roomNumber;
  final String floor;
  final bool isAC;
  final String sharingType;
  final int totalCapacity;
  final int numberOfBeds;
  final String roomFacilities;
  final double monthlyRent;
  final String electricityBillingType;
  final String roomStatus;

  const Room({
    required this.roomNumber,
    required this.floor,
    required this.isAC,
    required this.sharingType,
    required this.totalCapacity,
    required this.numberOfBeds,
    required this.roomFacilities,
    required this.monthlyRent,
    required this.electricityBillingType,
    required this.roomStatus,
  });

  Room copyWith({
    String? roomNumber,
    String? floor,
    bool? isAC,
    String? sharingType,
    int? totalCapacity,
    int? numberOfBeds,
    String? roomFacilities,
    double? monthlyRent,
    String? electricityBillingType,
    String? roomStatus,
  }) {
    return Room(
      roomNumber: roomNumber ?? this.roomNumber,
      floor: floor ?? this.floor,
      isAC: isAC ?? this.isAC,
      sharingType: sharingType ?? this.sharingType,
      totalCapacity: totalCapacity ?? this.totalCapacity,
      numberOfBeds: numberOfBeds ?? this.numberOfBeds,
      roomFacilities: roomFacilities ?? this.roomFacilities,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      electricityBillingType: electricityBillingType ?? this.electricityBillingType,
      roomStatus: roomStatus ?? this.roomStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomNumber': roomNumber,
      'floor': floor,
      'isAC': isAC,
      'sharingType': sharingType,
      'totalCapacity': totalCapacity,
      'numberOfBeds': numberOfBeds,
      'roomFacilities': roomFacilities,
      'monthlyRent': monthlyRent,
      'electricityBillingType': electricityBillingType,
      'roomStatus': roomStatus,
    };
  }

  @override
  List<Object?> get props => [
        roomNumber,
        floor,
        isAC,
        sharingType,
        totalCapacity,
        numberOfBeds,
        roomFacilities,
        monthlyRent,
        electricityBillingType,
        roomStatus,
      ];
}