import 'package:flutter/material.dart';
import 'package:pg_hostel_management/core/database/app_database.dart';
import 'core/securestorage/securestorage_service.dart';
import 'core/router/app_router.dart';
import 'core/password_gate.dart';
import 'features/home/home_screen.dart';

class PGHostelApp extends StatelessWidget {
  final bool isPasswordVerified;
  final AppDatabase database;

  const PGHostelApp({
    super.key,
    required this.isPasswordVerified,
    required this.database,
  });

  @override
  Widget build(BuildContext context) {
    // If developer password is verified, go directly to home (no activation needed)
    if (isPasswordVerified) {
      return MaterialApp.router(
        title: 'PG Hostel Manager',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        routerDelegate: AppRouter.router.delegate,
        routeInformationProvider: AppRouter.router.routeInformationProvider,
        routeInformationProviderCallback: AppRouter.router.routeInformationProviderCallback,
        routeErrorProvider: AppRouter.router.routeErrorProvider,
        localizationsDelegates: const [
          GlobalMaterialLocalization.delegate,
          GlobalCupertinoLocalization.delegate,
          appLocalizationsDelegate,
        ],
        supportedLocales: const [
          Locale('en', ''),
        ],
        home: const HomeScreen(),
      );
    }

    // If password not verified, show password gate
    // (We don't show OTP activation - just the password gate)
    return const PasswordGate();
  }
}