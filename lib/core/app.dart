import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import 'l10n.dart';
import 'router.dart';
import 'theme.dart';

class PGHostelApp extends ConsumerStatefulWidget {
  const PGHostelApp({super.key});

  @override
  ConsumerState<PGHostelApp> createState() => _PGHostelAppState();
}

class _PGHostelAppState extends ConsumerState<PGHostelApp> {
  late final GoRouter _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(profileProvider.select((p) => p.language));
    return MaterialApp.router(
      title: 'PG Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: _router,
      // Changing the language in PG Details rebuilds every screen.
      locale: language == 'ta' ? AppLanguage.ta.locale : AppLanguage.en.locale,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'IN'),
        Locale('en'),
        Locale('ta', 'IN'),
      ],
    );
  }
}
