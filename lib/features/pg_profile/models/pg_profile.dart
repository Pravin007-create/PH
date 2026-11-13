import 'package:equatable/equatable.dart';

class PGProfile extends Equatable {
  final String ownerName;
  final String pgName;
  final String address;
  final String mobileNumber;
  final String email;
  final int numberOfRooms;
  final String facilities;
  final String billingPreferences;
  final bool isActivated;
  final String? activationOTP;
  final String? activationOTPExpiry;

  const PGProfile({
    required this.ownerName,
    required this.pgName,
    required this.address,
    required this.mobileNumber,
    required this.email,
    required this.numberOfRooms,
    required this.facilities,
    required this.billingPreferences,
    required this.isActivated,
    this.activationOTP,
    this.activationOTPExpiry,
  });

  PGProfile copyWith({
    String? ownerName,
    String? pgName,
    String? address,
    String? mobileNumber,
    String? email,
    int? numberOfRooms,
    String? facilities,
    String? billingPreferences,
    bool? isActivated,
    String? activationOTP,
    String? activationOTPExpiry,
  }) {
    return PGProfile(
      ownerName: ownerName ?? this.ownerName,
      pgName: pgName ?? this.pgName,
      address: address ?? this.address,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      numberOfRooms: numberOfRooms ?? this.numberOfRooms,
      facilities: facilities ?? this.facilities,
      billingPreferences: billingPreferences ?? this.billingPreferences,
      isActivated: isActivated ?? this.isActivated,
      activationOTP: activationOTP ?? this.activationOTP,
      activationOTPExpiry: activationOTPExpiry ?? this.activationOTPExpiry,
    );
  }

  @override
  List<Object> get props => [
        ownerName,
        pgName,
        address,
        mobileNumber,
        email,
        numberOfRooms,
        facilities,
        billingPreferences,
        isActivated,
        activationOTP ?? '',
        activationOTPExpiry ?? '',
      ];
}