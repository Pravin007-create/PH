import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pg_hostel_management/core/app.dart';
import 'package:pg_hostel_management/core/router.dart';
import 'package:pg_hostel_management/core/securestorage/securestorage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final passwordVerified =
      await SecureStorageService().read(key: 'developer_password_verified');
  AuthState.passwordVerified = passwordVerified == 'true';

  runApp(const ProviderScope(child: PGHostelApp()));
}
