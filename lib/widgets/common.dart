import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';

/// Centers content and limits its width on tablets / landscape.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child, this.maxWidth = 760});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        // Only as tall as the child — otherwise it fills all available height
        // (e.g. inside a Scaffold's bottomNavigationBar).
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

/// Labelled "+ Add ..." button shown bottom-right on list screens.
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        heroTag: label,
        onPressed: onPressed,
        icon: const Icon(Icons.add_rounded),
        label: Text(label),
      );
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.caption,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(icon: icon, color: color),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (caption != null)
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge(
      {super.key, required this.icon, required this.color, this.size = 40});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(icon, color: color, size: size * 0.55),
      );
}

/// Lays children out in a responsive grid with natural (non-fixed) heights.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 150,
    this.spacing = 12,
  });
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols =
          ((c.maxWidth + spacing) / (minItemWidth + spacing)).floor().clamp(2, 6);
      final w = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [for (final child in children) SizedBox(width: w, child: child)],
      );
    });
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (action != null)
              TextButton(onPressed: onAction, child: Text(action!)),
          ],
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(icon: icon, color: theme.colorScheme.primary, size: 72),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// "‹  November 2026  ›" month picker.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.onChanged});
  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final isCurrent = sameMonth(month, DateTime.now());
    return Card(
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => onChanged(addMonths(month, -1)),
          ),
          Expanded(
            child: Text(
              fmtMonth(month),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: isCurrent ? null : () => onChanged(addMonths(month, 1)),
          ),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
}

/// Big "Save" button pinned to the bottom of form pages.
class SaveBar extends StatelessWidget {
  const SaveBar({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: PageBody(
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.check_rounded),
                label: Text(label),
              ),
            ),
          ),
        ),
      );
}

/// Form section title with spacing.
class FormLabel extends StatelessWidget {
  const FormLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}

String? requiredField(String? v, String name) =>
    (v == null || v.trim().isEmpty) ? 'Please enter $name' : null;

String? amountField(String? v, String name) {
  if (v == null || v.trim().isEmpty) return 'Please enter $name';
  final n = double.tryParse(v.trim());
  if (n == null || n < 0) return 'Enter a valid amount';
  return null;
}

String? phoneField(String? v) {
  if (v == null || v.trim().isEmpty) return 'Please enter mobile number';
  if (!RegExp(r'^[0-9]{10}$').hasMatch(v.trim())) {
    return 'Enter a 10-digit mobile number';
  }
  return null;
}

final digitsOnly = [FilteringTextInputFormatter.digitsOnly];
final decimalOnly = [
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
];

/// Tappable field that opens a date picker.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value,
            firstDate: DateTime(2015),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today_rounded),
          ),
          child: Text(fmtDate(value)),
        ),
      );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  minimumSize: const Size(0, 40))
              : FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showSaved(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ]),
    ));
}
