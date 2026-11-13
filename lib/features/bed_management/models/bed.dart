import 'package:equatable/equatable';

enum BedStatus { available, occupied, maintenance, deactivated }

extension BedStatusExtension on BedStatus {
  String get value {
    switch (this) {
      case BedStatus.available:
        return 'Available';
      case BedStatus.occupied:
        return 'Occupied';
      case BedStatus.maintenance:
        return 'Under Maintenance';
      case BedStatus.deactivated:
        return 'Deactivated';
    }
  }
}

class Bed extends Equatable {
  final String bedNumber;
  final String roomNumber;
  final BedStatus status;
  final String? tenantName;
  final DateTime? moveInDate;

  const Bed({
    required this.bedNumber,
    required this.roomNumber,
    required this.status,
    this.tenantName,
    this.moveInDate,
  });

  Bed copyWith({
    String? bedNumber,
    String? roomNumber,
    BedStatus? status,
    String? tenantName,
    DateTime? moveInDate,
  }) {
    return Bed(
      bedNumber: bedNumber ?? this.bedNumber,
      roomNumber: roomNumber ?? this.roomNumber,
      status: status ?? this.status,
      tenantName: tenantName ?? this.tenantName,
      moveInDate: moveInDate ?? this.moveInDate,
    );
  }

  @override
  List<Object> get props => [bedNumber, roomNumber, status, tenantName, moveInDate?.toIso8601String()];
}