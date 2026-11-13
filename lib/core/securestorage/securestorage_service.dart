import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  SecureStorageService._internal();

  factory SecureStorageService() => _instance;

  final _storage = const FlutterSecureStorage();

  Future<void> init() async {
    // Initialization - FlutterSecureStorage does not require explicit init
  }

  Future<String?> read({required String key}) async {
    return await _storage.read(key: key);
  }

  Future<void> write({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }

  // Activation status
  Future<void> saveActivationStatus({
    required bool isActivated,
    required String ownerName,
    required String pgName,
    required String mobileNumber,
  }) async {
    await write(key: 'is_activated', value: isActivated.toString());
    await write(key: 'owner_name', value: ownerName);
    await write(key: 'pg_name', value: pgName);
    await write(key: 'mobile_number', value: mobileNumber);
  }

  Future<bool> isActivated() async {
    final status = await read(key: 'is_activated');
    return status != null && status == 'true';
  }

  Future<String?> getOwnerName() async {
    return await read(key: 'owner_name');
  }

  Future<String?> getPGName() async {
    return await read(key: 'pg_name');
  }

  Future<String?> getMobileNumber() async {
    return await read(key: 'mobile_number');
  }

  // OTP storage
  Future<void> saveOTP({
    required String otp,
    required String expiry,
  }) async {
    await write(key: 'activation_otp', value: otp);
    await write(key: 'activation_otp_expiry', value: expiry);
  }

  Future<String?> getOTP() async {
    return await read(key: 'activation_otp');
  }

  Future<String?> getOTPExpiry() async {
    return await read(key: 'activation_otp_expiry');
  }

  Future<void> clearOTP() async {
    await delete(key: 'activation_otp');
    await delete(key: 'activation_otp_expiry');
  }
}