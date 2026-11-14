import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/format.dart';
import 'models.dart';

/// Tenant document files are copied into `<app documents>/tenant_docs/`.
/// Only the file name is stored in the tenant record ([TenantDocument.path]),
/// so the data stays valid if the app's base folder changes.

const docsFolderName = 'tenant_docs';

/// Absolute path of the tenant_docs folder (created if missing).
/// Overridden in tests with a temporary folder.
final docsDirProvider = FutureProvider<String>((ref) async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}/$docsFolderName');
  if (!dir.existsSync()) await dir.create(recursive: true);
  return dir.path;
});

/// Full path of a stored document.
String docFilePath(String docsDir, TenantDocument d) => '$docsDir/${d.path}';

String _extensionOf(String path, {String fallback = 'jpg'}) {
  final name = path.split(RegExp(r'[\\/]')).last;
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return fallback;
  return name.substring(dot + 1).toLowerCase();
}

/// Copies [sourcePath] into the tenant_docs folder and returns the record.
/// File name: `<tenantId>_<unique id>.<ext>`.
Future<TenantDocument> storeDocument({
  required String docsDir,
  required String tenantId,
  required String sourcePath,
  required String label,
}) async {
  final id = newId();
  final fileName = '${tenantId}_$id.${_extensionOf(sourcePath)}';
  await Directory(docsDir).create(recursive: true);
  await File(sourcePath).copy('$docsDir/$fileName');
  return TenantDocument(
      id: id, label: label, path: fileName, addedAt: DateTime.now());
}

/// Deletes the stored files (missing files are ignored).
Future<void> deleteDocumentFiles(
    String docsDir, Iterable<TenantDocument> docs) async {
  for (final d in docs) {
    final f = File(docFilePath(docsDir, d));
    try {
      // Small files: delete synchronously so the UI updates right away.
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}
