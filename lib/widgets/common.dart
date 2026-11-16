import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/l10n.dart';

export '../core/l10n.dart';

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
    this.glass = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final Color color;
  final VoidCallback? onTap;

  /// Liquid-glass style (dashboard).
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
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
    );
    if (glass) return LiquidGlass(onTap: onTap, child: content);
    return Card(child: InkWell(onTap: onTap, child: content));
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
      final cols = ((c.maxWidth + spacing) / (minItemWidth + spacing))
          .floor()
          .clamp(2, 6);
      final w = (c.maxWidth - spacing * (cols - 1)) / cols;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: w, child: child)
        ],
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
/// [prominent] = filled brand-colour bar with a "MONTH" label, for screens
/// where the month drives everything below (pinned at the top).
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onChanged,
    this.prominent = false,
  });
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final isCurrent = sameMonth(month, DateTime.now());
    // Fixed brand colours (same as the logo) so it reads well in dark mode.
    final fg = prominent ? Colors.white : null;
    final row = Row(
      children: [
        IconButton(
          tooltip: 'Previous month',
          color: fg,
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => onChanged(addMonths(month, -1)),
        ),
        Expanded(
          child: prominent
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('MONTH',
                      style: TextStyle(
                          color: fg!.withValues(alpha: 0.75),
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700)),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.calendar_month_rounded, size: 18, color: fg),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        fmtMonth(month),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: fg,
                            fontSize: 17,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ]),
                ])
              : Text(
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
          color: fg,
          disabledColor: fg?.withValues(alpha: 0.35),
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: isCurrent ? null : () => onChanged(addMonths(month, 1)),
        ),
      ],
    );
    if (!prominent) return Card(child: row);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: row,
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

/// Date field that can be left empty (shows [emptyText]) and cleared.
class OptionalDateField extends StatelessWidget {
  const OptionalDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.emptyText = 'Not set',
    this.helperText,
    this.firstDate,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String emptyText;
  final String? helperText;
  final DateTime? firstDate;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final now = DateTime.now();
          final first = firstDate ?? DateTime(2015);
          var initial = value ?? now;
          if (initial.isBefore(first)) initial = first;
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: first,
            lastDate: now.add(const Duration(days: 730)),
          );
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            helperText: helperText,
            prefixIcon: const Icon(Icons.event_busy_rounded),
            suffixIcon: value == null
                ? null
                : IconButton(
                    tooltip: 'Clear $label',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => onChanged(null),
                  ),
          ),
          child: Text(
            value == null ? emptyText : fmtDate(value!),
            style: value == null
                ? TextStyle(color: Theme.of(context).hintColor)
                : null,
          ),
        ),
      );
}

/// Amber "₹ Collect" button – same colour and icon everywhere so it's easy
/// to recognise without reading.
class CollectButton extends StatelessWidget {
  const CollectButton({super.key, required this.onPressed, this.amount});
  final VoidCallback onPressed;

  /// Shown after the label when given: "Collect ₹500".
  final double? amount;

  static const color = Color(0xFFF59E0B); // amber
  static const onColor = Color(0xFF3B2300); // dark brown text, high contrast

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: onColor,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.payments_rounded, size: 18),
        label: Text(amount == null
            ? context.tr('Collect')
            : '${context.tr('Collect')} ${money(amount!)}'),
      );
}

/// Apple-style frosted glass look for a screen: a soft, blurred colourful
/// background with translucent cards (white border, no hard shadow) on top.
/// Every [Card] inside [child] picks up the glass style automatically.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // Soft colour glows drawn as radial gradients. (A real blur filter
    // looked the same but cost a lot on every frame.)
    Widget glow(Color c, double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                c,
                c.withValues(alpha: c.a * 0.45),
                c.withValues(alpha: 0)
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
        );
    final glassCard = CardThemeData(
      color: dark
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.white.withValues(alpha: 0.62),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
            color: Colors.white.withValues(alpha: dark ? 0.12 : 0.75)),
      ),
    );
    return Stack(children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: ColoredBox(
            // Cool, low-colour mist so the glass reads as clear.
            color: dark ? const Color(0xFF0B1220) : const Color(0xFFD5DEE8),
            child: Stack(clipBehavior: Clip.hardEdge, children: [
              Positioned(
                  top: -220,
                  left: -200,
                  child: glow(
                      (dark ? const Color(0xFF334155) : const Color(0xFF94A3B8))
                          .withValues(alpha: 0.75),
                      600)),
              Positioned(
                  top: 0,
                  right: -240,
                  child: glow(
                      (dark ? const Color(0xFF1E3A5F) : const Color(0xFF7DA2C1))
                          .withValues(alpha: 0.65),
                      580)),
              Positioned(
                  top: 380,
                  left: -220,
                  child: glow(
                      (dark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))
                          .withValues(alpha: dark ? 0.40 : 0.85),
                      560)),
              Positioned(
                  bottom: -220,
                  right: -200,
                  child: glow(
                      (dark ? const Color(0xFF164E63) : const Color(0xFFA5C4C9))
                          .withValues(alpha: dark ? 0.35 : 0.45),
                      540)),
            ]),
          ),
        ),
      ),
      Theme(data: theme.copyWith(cardTheme: glassCard), child: child),
    ]);
  }
}

/// Apple "Liquid Glass" style panel: a translucent fill, a light sheen across
/// the top, a bright edge that fades around the shape, and a soft shadow.
/// No real-time blur (that dropped scrolling to ~20 fps); the background is
/// already soft, so the look is almost the same and scrolling stays smooth.
/// [tint] colours the glass.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 24,
    this.tint,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final br = BorderRadius.circular(radius);
    final List<Color> fill = tint != null
        ? [
            tint!.withValues(alpha: 0.88),
            Color.lerp(tint, const Color(0xFF9333EA), 0.55)!
                .withValues(alpha: 0.80),
          ]
        : dark
            ? [
                Colors.white.withValues(alpha: 0.16),
                Colors.white.withValues(alpha: 0.06),
              ]
            : [
                Colors.white.withValues(alpha: 0.80),
                Colors.white.withValues(alpha: 0.48),
              ];
    final sheen = Colors.white
        .withValues(alpha: tint != null ? 0.22 : (dark ? 0.10 : 0.50));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: (tint ?? const Color(0xFF0F172A))
                .withValues(alpha: tint != null ? 0.22 : (dark ? 0.30 : 0.07)),
            blurRadius: 18,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: _GlassEdgePainter(radius, dark: dark),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: br,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: br,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: fill,
                ),
              ),
              // Sheen across the top, painted inside the rounded shape
              // (no clipping layer needed).
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: br,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [sheen, sheen.withValues(alpha: 0)],
                    stops: const [0, 0.32],
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bright rim at top-left fading to faint at bottom-right, like light
/// catching the edge of glass.
class _GlassEdgePainter extends CustomPainter {
  _GlassEdgePainter(this.radius, {required this.dark});
  final double radius;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
        rect.deflate(0.75), Radius.circular(radius - 0.75));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: dark ? 0.45 : 0.95),
          Colors.white.withValues(alpha: dark ? 0.06 : 0.25),
          Colors.white.withValues(alpha: dark ? 0.20 : 0.70),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GlassEdgePainter old) =>
      old.radius != radius || old.dark != dark;
}
