import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app.dart';
import 'core/router.dart';
import 'core/securestorage/securestorage_service.dart';
import 'data/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final passwordVerified =
      await SecureStorageService().read(key: 'developer_password_verified');
  AuthState.passwordVerified = passwordVerified == 'true';

  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const PGHostelApp(),
  ));
}
