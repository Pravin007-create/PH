import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/database/app_database.dart';
import 'core/securestorage/securestorage_service.dart';
import 'core/password_gate.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize secure storage
  await SecureStorageService.init();

  // Initialize database
  final db = AppDatabase();
  await db.init();

  // Check if developer password has been verified
  final passwordVerified = await SecureStorageService().read(key: 'developer_password_verified');
  
  // If password verified, go directly to home (no OTP activation)
  // If not verified, show password gate first
  final shouldShowPasswordGate = passwordVerified != 'true';

  runApp(
    PGHostelApp(
      isPasswordVerified: passwordVerified == 'true',
      database: db,
      showPasswordGate: shouldShowPasswordGate,
    ),
  );
}