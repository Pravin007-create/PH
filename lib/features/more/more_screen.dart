import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/backup.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final json = exportBackup(ref.read(prefsProvider));
    final stamp = DateTime.now();
    final name = 'PG_backup_${stamp.year}-${_two(stamp.month)}-'
        '${_two(stamp.day)}_${_two(stamp.hour)}${_two(stamp.minute)}.json';
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsString(json);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json', name: name)],
        subject: 'PG Hostel backup',
        text: 'PG Hostel backup – keep this file safe. '
            'Use "Import data" in the app to restore it.',
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not export data: $e')));
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final String json;
    try {
      // No type filter: some phones don't tag .json files correctly.
      final file = await openFile();
      if (file == null) return;
      json = utf8.decode(await file.readAsBytes());
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
      return;
    }
    if (!context.mounted) return;
    await importFromJson(context, ref, json);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deleted = ref.watch(deletedPaymentsProvider).length;
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
      appBar: AppBar(title: const Text('More')),
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
                        'Reports',
                        'Download monthly PDF reports',
                        () => context.push('/reports')),
                    const Divider(height: 1),
                    tile(
                        Icons.receipt_long_rounded,
                        AppColors.pink,
                        'Expenses',
                        'Electricity, water, salary and more',
                        () => context.push('/expenses')),
                    const Divider(height: 1),
                    tile(
                        Icons.history_rounded,
                        AppColors.info,
                        'Deleted payments',
                        deleted == 0
                            ? 'Log of deleted payments'
                            : '$deleted deleted payment${deleted == 1 ? '' : 's'}',
                        () => context.push('/payments/deleted')),
                  ]),
                ),
                const SizedBox(height: 12),
                Card(
                  child: tile(
                      Icons.storefront_rounded,
                      AppColors.warning,
                      'PG details',
                      'Name, owner, phone, rent collection',
                      () => context.push('/profile')),
                ),
                const SectionHeader('Backup & restore'),
                Card(
                  child: Column(children: [
                    tile(
                        Icons.upload_file_rounded,
                        AppColors.success,
                        'Export all data',
                        'Save rooms, tenants, payments & expenses to a file',
                        () => _export(context, ref)),
                    const Divider(height: 1),
                    tile(
                        Icons.file_download_outlined,
                        AppColors.purple,
                        'Import data',
                        'Restore from an exported backup file',
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
                Text('PG Hostel Manager · v1.0.0',
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

/// Shows what's in the backup, asks to confirm, then replaces all data.
Future<void> importFromJson(
    BuildContext context, WidgetRef ref, String json) async {
  final BackupSummary summary;
  try {
    summary = readBackup(json);
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
      '',
      'Everything currently in the app will be replaced by this backup.',
    ].join('\n'),
    confirmLabel: 'Import',
  );
  if (!ok || !context.mounted) return;
  await importBackup(ref.read(prefsProvider), json);
  ref
    ..invalidate(roomsProvider)
    ..invalidate(tenantsProvider)
    ..invalidate(paymentsProvider)
    ..invalidate(expensesProvider)
    ..invalidate(deletedPaymentsProvider)
    ..invalidate(electricityBillsProvider)
    ..invalidate(profileProvider);
  if (context.mounted) {
    showSaved(context,
        'Data imported · ${summary.rooms} rooms, ${summary.tenants} tenants');
  }
}
