import 'package:flutter/material.dart';

import '../config/theme.dart';

class NutritionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  const NutritionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
    color: color,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class NutritionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const NutritionHeading(this.title, {super.key, this.subtitle, this.trailing});
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 8), trailing!],
    ],
  );
}

class NutritionIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  const NutritionIcon(this.icon, {super.key, this.color, this.size = 48});
  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: tint, size: size * .48),
    );
  }
}

class NutritionStatus extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool gold;
  const NutritionStatus(this.label, {super.key, this.icon, this.gold = false});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = gold
        ? (dark ? AppTheme.premiumGold : const Color(0xFF805214))
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: gold
            ? AppTheme.premiumGold.withValues(alpha: dark ? .16 : .35)
            : color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NutritionEmptyState extends StatelessWidget {
  final IconData icon;
  final String title, message;
  final Widget? action;
  const NutritionEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  @override
  Widget build(BuildContext context) => NutritionCard(
    child: Column(
      children: [
        NutritionIcon(icon, size: 64),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

class NutritionBrand extends StatelessWidget {
  const NutritionBrand({super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        Icons.eco_outlined,
        color: Theme.of(context).colorScheme.primary,
        size: 32,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'NutriSalud',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    ],
  );
}
