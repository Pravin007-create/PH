import 'package:pg_hostel_management/features/pg_profile/models/pg_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/securestorage/securestorage_service.dart';

final pgProfileProvider = StateNotifierProvider<PGProfileNotifier, PGProfile>((ref) {
  final storage = SecureStorageService();
  final initialProfile = PGProfile(
    ownerName: '',
    pgName: '',
    address: '',
    mobileNumber: '',
    email: '',
    numberOfRooms: 0,
    facilities: '',
    billingPreferences: '',
    isActivated: storage.isActivated() ?? false,
    activationOTP: storage.getOTP(),
    activationOTPExpiry: storage.getOTPExpiry(),
  );
  return PGProfileNotifier(initialProfile, storage);
});

class PGProfileNotifier extends StateNotifier<PGProfile> {
  final SecureStorageService _storage;

  PGProfileNotifier(PGProfile initialState, this._storage)
      : super(initialState);

  void updateProfile({
    String? ownerName,
    String? pgName,
    String? address,
    String? mobileNumber,
    String? email,
    int? numberOfRooms,
    String? facilities,
    String? billingPreferences,
    bool? isActivated,
  }) {
    state = state.copyWith(
      ownerName: ownerName,
      pgName: pgName,
      address: address,
      mobileNumber: mobileNumber,
      email: email,
      numberOfRooms: numberOfRooms,
      facilities: facilities,
      billingPreferences: billingPreferences,
      isActivated: isActivated ?? state.isActivated,
    );
    _saveToStorage();
  }

  void activatePG({
    required String otp,
    required String otpExpiry,
  }) {
    // Verify OTP - in a real app, this would be sent to a server
    // For now, we accept any 6-digit OTP
    final isValid = otp.length == 6 && otp.containsOnlyDigits();
    if (isValid) {
      state = state.copyWith(isActivated: true);
      _storage.saveActivationStatus(
        isActivated: true,
        ownerName: state.ownerName,
        pgName: state.pgName,
        mobileNumber: state.mobileNumber,
      );
    }
  }

  void saveOTP({
    required String otp,
    required String expiry,
  }) {
    _storage.saveOTP(otp: otp, expiry: expiry);
    state = state.copyWith(activationOTP: otp, activationOTPExpiry: expiry);
  }

  void clearOTP() {
    _storage.clearOTP();
    state = state.copyWith(activationOTP: null, activationOTPExpiry: null);
  }

  void reset() {
    state = PGProfile(
      ownerName: '',
      pgName: '',
      address: '',
      mobileNumber: '',
      email: '',
      numberOfRooms: 0,
      facilities: '',
      billingPreferences: '',
      isActivated: false,
    );
    _clearStorage();
  }

  void _saveToStorage() {
    _storage.saveActivationStatus(
      isActivated: state.isActivated,
      ownerName: state.ownerName,
      pgName: state.pgName,
      mobileNumber: state.mobileNumber,
    );
  }

  void _clearStorage() {
    _storage.delete(key: 'is_activated');
    _storage.delete(key: 'owner_name');
    _storage.delete(key: 'pg_name');
    _storage.delete(key: 'mobile_number');
  }
}