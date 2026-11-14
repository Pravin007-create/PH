import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Export / import of every record in the app as one JSON file.

const backupFormat = 'pg-hostel-backup';
const backupVersion = 1;

/// List keys in SharedPreferences and how to check each record.
final Map<String, Object Function(Map<String, dynamic>)> _listKeys = {
  'rooms': Room.fromJson,
  'tenants': Tenant.fromJson,
  'payments': Payment.fromJson,
  'expenses': Expense.fromJson,
  'deleted_payments': DeletedPayment.fromJson,
  'electricity_bills': ElectricityBill.fromJson,
};

List<dynamic> _readList(SharedPreferences prefs, String key) {
  final raw = prefs.getString(key);
  if (raw == null) return [];
  try {
    return jsonDecode(raw) as List;
  } catch (_) {
    return [];
  }
}

/// All app data as a pretty-printed JSON string.
String exportBackup(SharedPreferences prefs, {DateTime? now}) {
  final profileRaw = prefs.getString('profile');
  return const JsonEncoder.withIndent('  ').convert({
    'format': backupFormat,
    'version': backupVersion,
    'exportedAt': (now ?? DateTime.now()).toIso8601String(),
    'profile': profileRaw == null ? null : jsonDecode(profileRaw),
    for (final key in _listKeys.keys) key: _readList(prefs, key),
  });
}

class BackupSummary {
  const BackupSummary(this.counts, this.exportedAt, this.pgName);
  final Map<String, int> counts;
  final DateTime? exportedAt;
  final String pgName;

  int get rooms => counts['rooms'] ?? 0;
  int get tenants => counts['tenants'] ?? 0;
  int get payments => counts['payments'] ?? 0;
  int get expenses => counts['expenses'] ?? 0;
}

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

Map<String, dynamic> _parse(String json) {
  final Object? data;
  try {
    data = jsonDecode(json);
  } catch (_) {
    throw BackupException('This is not a valid backup file.');
  }
  if (data is! Map || data['format'] != backupFormat) {
    throw BackupException('This file is not a PG Management backup.');
  }
  final map = Map<String, dynamic>.from(data);
  // Check every record can be read before anything is replaced.
  for (final e in _listKeys.entries) {
    final list = map[e.key] ?? const [];
    if (list is! List) throw BackupException('Backup is damaged (${e.key}).');
    for (final item in list) {
      try {
        e.value(Map<String, dynamic>.from(item as Map));
      } catch (_) {
        throw BackupException('Backup is damaged (${e.key}).');
      }
    }
  }
  final profile = map['profile'];
  if (profile != null) {
    try {
      PgProfile.fromJson(Map<String, dynamic>.from(profile as Map));
    } catch (_) {
      throw BackupException('Backup is damaged (PG details).');
    }
  }
  return map;
}

/// Checks a backup file and says what's in it, without changing anything.
BackupSummary readBackup(String json) {
  final map = _parse(json);
  final profile = map['profile'];
  return BackupSummary(
    {for (final k in _listKeys.keys) k: ((map[k] ?? const []) as List).length},
    DateTime.tryParse((map['exportedAt'] ?? '') as String),
    profile is Map ? (profile['pgName'] ?? '') as String : '',
  );
}

/// Replaces all app data with the backup. Throws [BackupException] (and
/// changes nothing) if the file is invalid.
Future<BackupSummary> importBackup(SharedPreferences prefs, String json) async {
  final summary = readBackup(json);
  final map = _parse(json);
  for (final key in _listKeys.keys) {
    await prefs.setString(key, jsonEncode(map[key] ?? const []));
  }
  if (map['profile'] == null) {
    await prefs.remove('profile');
  } else {
    await prefs.setString('profile', jsonEncode(map['profile']));
  }
  return summary;
}
