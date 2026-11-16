import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

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
  const BackupSummary(this.counts, this.exportedAt, this.pgName,
      {this.documentFiles = 0});
  final Map<String, int> counts;
  final DateTime? exportedAt;
  final String pgName;

  /// Document photos/PDFs included in a .zip backup.
  final int documentFiles;

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

// ---------------------------------------------------------------------------
// .zip backup: backup.json + tenant_docs/<files>
// ---------------------------------------------------------------------------

const backupJsonName = 'backup.json';
const backupDocsFolder = 'tenant_docs/';

/// File names of every document referenced by tenants in [prefs].
Set<String> _referencedDocs(SharedPreferences prefs) {
  final names = <String>{};
  for (final t in _readList(prefs, 'tenants')) {
    for (final d in ((t as Map)['documents'] ?? const []) as List) {
      final path = (d as Map)['path'];
      if (path is String && !path.contains('/') && !path.contains('\\')) {
        names.add(path);
      }
    }
  }
  return names;
}

/// All data + document files as one zip. Missing files are skipped.
Future<Uint8List> exportBackupZip(SharedPreferences prefs, String docsDir,
    {DateTime? now}) async {
  final archive = Archive()
    ..addFile(
        ArchiveFile.string(backupJsonName, exportBackup(prefs, now: now)));
  for (final name in _referencedDocs(prefs)) {
    final f = File('$docsDir/$name');
    if (!f.existsSync()) continue;
    final bytes = await f.readAsBytes();
    // Photos/PDFs are already compressed: store them as-is (faster).
    archive.addFile(
        ArchiveFile.noCompress('$backupDocsFolder$name', bytes.length, bytes));
  }
  return ZipEncoder().encodeBytes(archive);
}

bool _isZip(Uint8List bytes) =>
    bytes.length > 3 && bytes[0] == 0x50 && bytes[1] == 0x4B; // "PK"

/// Reads a backup file (.zip, or an old .json) and returns its JSON text and
/// document files, without changing anything.
({String json, Map<String, Uint8List> docs}) _unpack(Uint8List bytes) {
  if (!_isZip(bytes)) {
    try {
      return (json: utf8.decode(bytes), docs: const {});
    } catch (_) {
      throw BackupException('This is not a valid backup file.');
    }
  }
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw BackupException('The backup file is damaged.');
  }
  final jsonFile = archive.findFile(backupJsonName);
  if (jsonFile == null) {
    throw BackupException('This zip is not a PG Management backup.');
  }
  final docs = <String, Uint8List>{};
  for (final f in archive.files) {
    if (!f.isFile || !f.name.startsWith(backupDocsFolder)) continue;
    final name = f.name.substring(backupDocsFolder.length);
    // Only plain file names – never write outside the docs folder.
    if (name.isEmpty ||
        name.contains('/') ||
        name.contains('\\') ||
        name.startsWith('.')) {
      continue;
    }
    docs[name] = f.content;
  }
  return (json: utf8.decode(jsonFile.content), docs: docs);
}

/// What's inside a backup file (zip or json), without importing it.
BackupSummary readBackupFile(Uint8List bytes) {
  final u = _unpack(bytes);
  final s = readBackup(u.json);
  return BackupSummary(s.counts, s.exportedAt, s.pgName,
      documentFiles: u.docs.length);
}

/// Replaces all data and document files with the backup.
/// Documents of the old data that aren't in the backup are removed.
/// Throws [BackupException] (changing nothing) if the file is invalid.
Future<BackupSummary> importBackupFile(
    SharedPreferences prefs, Uint8List bytes, String docsDir) async {
  final u = _unpack(bytes);
  readBackup(u.json); // validate everything first
  final dir = Directory(docsDir);
  await dir.create(recursive: true);
  for (final e in u.docs.entries) {
    await File('$docsDir/${e.key}').writeAsBytes(e.value, flush: true);
  }
  final summary = await importBackup(prefs, u.json);
  // Remove files no tenant uses any more (from the replaced data).
  final keep = _referencedDocs(prefs);
  for (final f in dir.listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    if (!keep.contains(name)) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
  }
  return BackupSummary(summary.counts, summary.exportedAt, summary.pgName,
      documentFiles: u.docs.length);
}
