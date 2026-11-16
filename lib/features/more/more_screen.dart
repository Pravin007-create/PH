import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/backup.dart';
import '../../data/documents.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  /// One .zip with all data + tenant document photos/PDFs.
  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final stamp = DateTime.now();
    final name = 'PG_backup_${stamp.year}-${_two(stamp.month)}-'
        '${_two(stamp.day)}_${_two(stamp.hour)}${_two(stamp.minute)}.zip';
    messenger.showSnackBar(const SnackBar(content: Text('Preparing backup…')));
    try {
      final docsDir = await ref.read(docsDirProvider.future);
      final bytes = await exportBackupZip(ref.read(prefsProvider), docsDir);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      messenger.hideCurrentSnackBar();
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/zip', name: name)],
        subject: 'PG Management backup',
        text: 'PG Management backup (data + tenant documents) – keep this '
            'file safe. Use "Import data" in the app to restore it.',
      ));
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not export data: $e')));
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final Uint8List bytes;
    try {
      // No type filter: some phones don't tag .zip/.json files correctly.
      final file = await openFile();
      if (file == null) return;
      bytes = await file.readAsBytes();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!context.mounted) return;
    await importFromBytes(context, ref, bytes);
  }

  /// English / தமிழ் – applied immediately and remembered.
  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final current = ref.read(profileProvider).language;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Language / மொழி',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final l in AppLanguage.values)
              ListTile(
                leading: CircleAvatar(
                  child: Text(l == AppLanguage.ta ? 'அ' : 'A',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                title: Text(l.nativeLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: l == AppLanguage.ta ? const Text('Tamil') : null,
                trailing: l.name == current
                    ? const Icon(Icons.check_circle_rounded,
                        color: AppColors.success)
                    : null,
                onTap: () => Navigator.pop(ctx, l.name),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || picked == current) return;
    ref
        .read(profileProvider.notifier)
        .save(ref.read(profileProvider).copyWith(language: picked));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deleted = ref.watch(deletedPaymentsProvider).length;
    final language = ref.watch(profileProvider.select((p) => p.language));
    Widget tile(IconData icon, Color color, String title, String sub,
            VoidCallback onTap) =>
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: IconBadge(icon: icon, color: color),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(sub),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('More'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Column(children: [
                    tile(
                        Icons.download_rounded,
                        AppColors.seed,
                        context.tr('Reports'),
                        context.tr('Download monthly PDF reports'),
                        () => context.push('/reports')),
                    const Divider(height: 1),
                    tile(
                        Icons.receipt_long_rounded,
                        AppColors.pink,
                        context.tr('Expenses'),
                        context.tr('Electricity, water, salary and more'),
                        () => context.push('/expenses')),
                    const Divider(height: 1),
                    tile(
                        Icons.history_rounded,
                        AppColors.info,
                        context.tr('Deleted payments'),
                        deleted == 0
                            ? context.tr('Log of deleted payments')
                            : '$deleted deleted payment${deleted == 1 ? '' : 's'}',
                        () => context.push('/payments/deleted')),
                  ]),
                ),
                const SizedBox(height: 12),
                Card(
                  child: tile(
                      Icons.translate_rounded,
                      AppColors.success,
                      // Shown in both languages so anyone can find it.
                      'Language / மொழி',
                      language == 'ta' ? 'தமிழ்' : 'English',
                      () => _pickLanguage(context, ref)),
                ),
                const SizedBox(height: 12),
                Card(
                  child: tile(
                      Icons.storefront_rounded,
                      AppColors.warning,
                      context.tr('PG details'),
                      context.tr('Name, owner, phone, rent collection'),
                      () => context.push('/profile')),
                ),
                SectionHeader(context.tr('Backup & restore')),
                Card(
                  child: Column(children: [
                    tile(
                        Icons.upload_file_rounded,
                        AppColors.success,
                        context.tr('Export all data'),
                        context
                            .tr('All data + tenant documents in one .zip file'),
                        () => _export(context, ref)),
                    const Divider(height: 1),
                    tile(
                        Icons.file_download_outlined,
                        AppColors.purple,
                        context.tr('Import data'),
                        context.tr('Restore from an exported backup file'),
                        () => _import(context, ref)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    'Data is stored only on this phone. Export regularly and '
                    'keep the file in Google Drive, WhatsApp or email.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 24),
                Text('PG Management · v1.0.0',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Shows what's in the backup (.zip or old .json), asks to confirm, then
/// replaces all data and document files.
Future<void> importFromBytes(
    BuildContext context, WidgetRef ref, Uint8List bytes) async {
  final BackupSummary summary;
  try {
    summary = readBackupFile(bytes);
  } on BackupException catch (e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.message)));
    return;
  }
  final ok = await confirmDialog(
    context,
    title: 'Replace all data?',
    message: [
      if (summary.pgName.isNotEmpty) summary.pgName,
      if (summary.exportedAt != null)
        'Backup from ${fmtDate(summary.exportedAt!)}',
      '${summary.rooms} rooms · ${summary.tenants} tenants · '
          '${summary.payments} payments · ${summary.expenses} expenses',
      summary.documentFiles > 0
          ? '${summary.documentFiles} tenant document files'
          : 'No document files in this backup',
      '',
      'Everything currently in the app will be replaced by this backup.',
    ].join('\n'),
    confirmLabel: 'Import',
  );
  if (!ok || !context.mounted) return;
  try {
    final docsDir = await ref.read(docsDirProvider.future);
    await importBackupFile(ref.read(prefsProvider), bytes, docsDir);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
    return;
  }
  ref
    ..invalidate(roomsProvider)
    ..invalidate(tenantsProvider)
    ..invalidate(paymentsProvider)
    ..invalidate(expensesProvider)
    ..invalidate(deletedPaymentsProvider)
    ..invalidate(electricityBillsProvider)
    ..invalidate(profileProvider);
  if (context.mounted) {
    showSaved(
        context,
        'Data imported · ${summary.rooms} rooms, ${summary.tenants} tenants'
        '${summary.documentFiles > 0 ? ', ${summary.documentFiles} documents' : ''}');
  }
}
