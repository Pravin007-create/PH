import 'package:flutter/foundation.dart';

class AppLocalizationsDelegate extends GlobalMaterialLocalizationDelegate {
  @override
  Iterable<Locale> get supportedLocales => const [Locale('en', '')];
}