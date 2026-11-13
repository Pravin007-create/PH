import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'router.dart';
import 'theme.dart';

class PGHostelApp extends StatefulWidget {
  const PGHostelApp({super.key});

  @override
  State<PGHostelApp> createState() => _PGHostelAppState();
}

class _PGHostelAppState extends State<PGHostelApp> {
  late final GoRouter _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PG Hostel Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: _router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'IN'), Locale('en')],
    );
  }
}
