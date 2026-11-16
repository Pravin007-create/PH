import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// App languages. English text is the key; Tamil comes from [_ta].
/// Text without a Tamil entry falls back to English.
enum AppLanguage {
  en('English', 'English'),
  ta('Tamil', 'தமிழ்');

  const AppLanguage(this.label, this.nativeLabel);
  final String label;
  final String nativeLabel;

  Locale get locale => Locale(name, 'IN');
}

class AppStrings {
  const AppStrings(this.languageCode);
  final String languageCode;

  /// Translates [en]; `{name}` placeholders are filled from [args].
  String t(String en, [Map<String, Object?> args = const {}]) {
    var s = languageCode == 'ta' ? (_ta[en] ?? en) : en;
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      const AppStrings('en');

  static const delegate = _AppStringsDelegate();
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLanguage.values.any((l) => l.name == locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture(AppStrings(locale.languageCode));

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

extension Tr on BuildContext {
  /// `context.tr('Rooms')`, `context.tr('{n} vacant', {'n': 2})`
  String tr(String en, [Map<String, Object?> args = const {}]) =>
      AppStrings.of(this).t(en, args);
}

const _ta = <String, String>{
  // Navigation
  'Home': 'முகப்பு',
  'Rooms': 'அறைகள்',
  'Tenants': 'குடியிருப்போர்',
  'Payments': 'பணம்',
  'More': 'மேலும்',

  // Common
  'Collect': 'வசூல்',
  'Paid': 'செலுத்தியது',
  'Save': 'சேமி',
  'Cancel': 'ரத்து',
  'Delete': 'நீக்கு',
  'Edit': 'திருத்து',
  'See all': 'அனைத்தும்',
  'Search': 'தேடு',
  'Room {n}': 'அறை {n}',
  'No room': 'அறை இல்லை',
  'Rent': 'வாடகை',
  'Electricity': 'மின்சாரம்',
  'MONTH': 'மாதம்',
  'Previous month': 'முந்தைய மாதம்',
  'Next month': 'அடுத்த மாதம்',

  // Due status
  'Overdue {n} days': '{n} நாள் தாமதம்',
  'Overdue 1 day': '1 நாள் தாமதம்',
  'Due today': 'இன்று கடைசி நாள்',
  'Due by {d}': '{d} க்குள் செலுத்த',
  'From {d}': '{d} முதல்',
  'Partly paid': 'பகுதி செலுத்தியது',

  // Home
  'Overview': 'சுருக்கம்',
  'Quick actions': 'விரைவு செயல்கள்',
  'Beds occupied': 'நிரம்பிய படுக்கைகள்',
  '{n} vacant': '{n} காலி',
  'Active tenants': 'தற்போதைய குடியிருப்போர்',
  '{n} rooms': '{n} அறைகள்',
  'Pending rent': 'நிலுவை வாடகை',
  '{n} tenants': '{n} பேர்',
  '{n} overdue': '{n} தாமதம்',
  'Expenses': 'செலவுகள்',
  'Add Tenant': 'குடியிருப்போர் சேர்',
  'Record Payment': 'பணம் பதிவு',
  'Add Expense': 'செலவு சேர்',
  'Add Room': 'அறை சேர்',
  'Reports': 'அறிக்கைகள்',
  'PG Details': 'PG விவரங்கள்',
  'Pending rent · {m}': 'நிலுவை வாடகை · {m}',
  'Add tenants to start tracking rent.':
      'வாடகையை கண்காணிக்க குடியிருப்போரை சேர்க்கவும்.',
  'All rent collected for this month.': 'இந்த மாத வாடகை முழுவதும் வசூலானது.',
  'Recent payments': 'சமீபத்திய பணம்',
  'Payments you record will appear here.':
      'நீங்கள் பதிவு செய்யும் பணம் இங்கே தெரியும்.',
  'Upcoming vacancies ({n})': 'விரைவில் காலியாகும் ({n})',
  '1 bed free from {d}': '{d} முதல் 1 படுக்கை காலி',
  'Left {d} · complete move-out':
      '{d} அன்று விலகினார் · வெளியேற்றத்தை முடிக்கவும்',
  'Electricity to collect · {a}': 'வசூலிக்க வேண்டிய மின்கட்டணம் · {a}',
  'Rent for {m} · due {d}': '{m} வாடகை · கடைசி நாள் {d}',
  'Collected': 'வசூலானது',
  'of {a}': '{a} இல்',
  'Get started in 3 steps': '3 படிகளில் தொடங்குங்கள்',
  'View overdue': 'தாமதத்தைப் பார்',
  'Collect now': 'இப்போது வசூலி',

  // Payments
  'Rent status': 'வாடகை நிலை',
  'Electricity bills': 'மின் கட்டணங்கள்',
  'Payments received': 'பெற்ற பணம்',
  'Deleted payments': 'நீக்கப்பட்ட பணம்',
  'Rent collected': 'வசூலான வாடகை',
  '{p}% of {a}': '{a} இல் {p}%',
  'Collect from {a} · due by {b}': '{a} முதல் வசூல் · {b} க்குள்',
  '{n} overdue · {a} not paid after {d}':
      '{n} தாமதம் · {d} க்குப் பிறகு {a} செலுத்தவில்லை',
  'Electricity collected': 'வசூலான மின்கட்டணம்',
  'Electricity pending': 'நிலுவை மின்கட்டணம்',
  'of {a} billed': '{a} கட்டணத்தில்',
  'Received this month': 'இந்த மாதம் பெற்றது',
  '{n} payments': '{n} பணப்பதிவுகள்',
  'Rent received': 'பெற்ற வாடகை',
  'Other received': 'பிற வரவு',
  'Electricity, deposit, other': 'மின்சாரம், முன்பணம், பிற',
  'Paid {a} of {b}': '{b} இல் {a} செலுத்தியது',
  'No tenants this month': 'இந்த மாதம் குடியிருப்போர் இல்லை',
  'No payments in {m}': '{m} இல் பணம் இல்லை',
  'Room {r} · share {a}': 'அறை {r} · பங்கு {a}',
  'Pending from earlier months · {a}': 'முந்தைய மாத நிலுவை · {a}',
  'No electricity bills for {m}': '{m} க்கு மின் கட்டணம் இல்லை',
  'Bill {a}': 'கட்டணம் {a}',
  'Deleted tenant': 'நீக்கப்பட்டவர்',

  // Rooms
  'All': 'அனைத்தும்',
  'Has vacancy': 'காலி உள்ளது',
  'Vacating soon': 'விரைவில் காலி',
  'Full': 'நிரம்பியது',
  'Bill pending': 'கட்டணம் நிலுவை',
  'AC & Non-AC': 'AC & AC இல்லாதது',
  'Non-AC': 'AC இல்லை',
  'Single': 'ஒற்றை',
  '{n}-sharing': '{n} பேர் பகிர்வு',
  'Search room number or floor': 'அறை எண் அல்லது தளம் தேடு',
  '{n} of {b} beds filled': '{b} படுக்கைகளில் {n} நிரம்பியது',
  '{a} / bed': '{a} / படுக்கை',
  '1 vacant from {d}': '{d} முதல் 1 காலி',
  'Move-out pending': 'வெளியேற்றம் நிலுவை',
  '⚡ Bill {a} pending': '⚡ கட்டணம் {a} நிலுவை',
  'Floor {f}': 'தளம் {f}',
  'Clear filters': 'வடிகட்டியை நீக்கு',

  // Tenants
  'Staying ({n})': 'தங்கியுள்ளோர் ({n})',
  'Moved out ({n})': 'வெளியேறியோர் ({n})',
  'Moved out': 'வெளியேறினார்',
  'Overdue': 'தாமதம்',
  'Search name, phone or room': 'பெயர், கைபேசி அல்லது அறை தேடு',
  'Documents pending ({n})': 'ஆவணம் நிலுவை ({n})',
  'ID proof not submitted': 'அடையாள ஆவணம் தரவில்லை',
  'Document proof not submitted': 'ஆவண சான்று சமர்ப்பிக்கவில்லை',
  'Leaving {d}': '{d} அன்று விலகல்',

  // More / settings
  'PG details': 'PG விவரங்கள்',
  'Name, owner, phone, rent collection':
      'பெயர், உரிமையாளர், கைபேசி, வாடகை வசூல்',
  'Download monthly PDF reports': 'மாதாந்திர PDF அறிக்கைகள்',
  'Electricity, water, salary and more':
      'மின்சாரம், தண்ணீர், சம்பளம் மற்றும் பல',
  'Log of deleted payments': 'நீக்கப்பட்ட பணப் பதிவு',
  'Backup & restore': 'காப்பு & மீட்பு',
  'Export all data': 'அனைத்து தரவையும் ஏற்றுமதி',
  'All data + tenant documents in one .zip file':
      'அனைத்து தரவும் ஆவணங்களும் ஒரே .zip கோப்பில்',
  'Import data': 'தரவை இறக்குமதி',
  'Restore from an exported backup file': 'காப்பு கோப்பிலிருந்து மீட்டெடு',
  'Language': 'மொழி',
  'App language': 'செயலி மொழி',
};
