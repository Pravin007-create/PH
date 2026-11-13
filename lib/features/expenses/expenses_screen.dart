import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../widgets/common.dart';

IconData expenseIcon(String category) => switch (category) {
      'Electricity' => Icons.bolt_rounded,
      'Water' => Icons.water_drop_rounded,
      'Maintenance' => Icons.build_rounded,
      'Groceries' => Icons.shopping_basket_rounded,
      'Salary' => Icons.badge_rounded,
      'Internet' => Icons.wifi_rounded,
      'Rent / Lease' => Icons.home_work_rounded,
      _ => Icons.receipt_rounded,
    };

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  DateTime _month = monthOf(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final expenses = ref
        .watch(expensesProvider)
        .where((e) => sameMonth(e.date, _month))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = expenses.fold<double>(0, (s, e) => s + e.amount);
    final byCategory = <String, double>{};
    for (final e in expenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    final categories = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: AddButton(
          label: 'Add Expense',
          onPressed: () => context.push('/expenses/new')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          PageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MonthSwitcher(
                    month: _month,
                    onChanged: (m) => setState(() => _month = m)),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const IconBadge(
                              icon: Icons.account_balance_wallet_rounded,
                              color: AppColors.pink),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total spent'),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(money(total),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ),
                        ]),
                        if (categories.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          for (final c in categories)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(children: [
                                Row(children: [
                                  Icon(expenseIcon(c.key), size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(c.key)),
                                  Text(money(c.value),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ]),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: total == 0 ? 0 : c.value / total,
                                    minHeight: 5,
                                    color: AppColors.pink,
                                    backgroundColor:
                                        AppColors.pink.withValues(alpha: 0.1),
                                  ),
                                ),
                              ]),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (expenses.isEmpty)
                  EmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No expenses in ${fmtMonth(_month)}',
                    message:
                        'Record electricity, water, groceries, salaries and other costs.',
                    actionLabel: 'Add Expense',
                    onAction: () => context.push('/expenses/new'),
                  ),
                for (final e in expenses) ...[
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      onTap: () => context.push('/expenses/${e.id}'),
                      leading: IconBadge(
                          icon: expenseIcon(e.category), color: AppColors.pink),
                      title: Text(e.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${e.category} · ${fmtDate(e.date)}'),
                      trailing: Text(money(e.amount),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.pink)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
