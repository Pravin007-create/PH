import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import '../../core/securestorage/securestorage_service.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  Future<void> _lock(BuildContext context) async {
    final ok = await confirmDialog(context,
        title: 'Lock the app?',
        message: 'You will need the app password to open it again.',
        confirmLabel: 'Lock',
        destructive: false);
    if (!ok) return;
    await SecureStorageService().delete(key: 'developer_password_verified');
    AuthState.passwordVerified = false;
    if (context.mounted) context.go('/password');
  }

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, Color color, String title, String sub,
            VoidCallback onTap) =>
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: IconBadge(icon: icon, color: color),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                    tile(Icons.download_rounded, AppColors.seed, 'Reports',
                        'Download monthly PDF reports',
                        () => context.push('/reports')),
                    const Divider(height: 1),
                    tile(Icons.receipt_long_rounded, AppColors.pink, 'Expenses',
                        'Electricity, water, salary and more',
                        () => context.push('/expenses')),
                  ]),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(children: [
                    tile(Icons.storefront_rounded, AppColors.warning,
                        'PG details', 'Name, owner, phone and address',
                        () => context.push('/profile')),
                    const Divider(height: 1),
                    tile(Icons.lock_outline_rounded, AppColors.info,
                        'Lock app', 'Ask for password next time',
                        () => _lock(context)),
                  ]),
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
