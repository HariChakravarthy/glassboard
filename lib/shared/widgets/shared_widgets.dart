import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';

/// ── GlassCard ─────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  final double borderLeftWidth;
  final Color? borderLeftColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.borderLeftWidth = 0,
    this.borderLeftColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          left: BorderSide(
            color: borderLeftColor ?? Colors.transparent,
            width: borderLeftWidth > 0 ? borderLeftWidth : 0,
          ),
          top:    BorderSide(color: borderColor ?? AppTheme.border),
          right:  BorderSide(color: borderColor ?? AppTheme.border),
          bottom: BorderSide(color: borderColor ?? AppTheme.border),
        ),
      ),
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(0),
        child: card,
      );
    }
    return card;
  }
}

/// ── StatusBadge ────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        border: Border.all(color: color.withAlpha(102)),
      ),
      child: Text(label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          fontFamily: 'Space Mono',
        ),
      ),
    );
  }
}

/// ── PriorityBadge ─────────────────────────────────────────────────
class PriorityBadge extends StatelessWidget {
  final String priority;
  const PriorityBadge({super.key, required this.priority});

  Color get _color => switch (priority) {
    'BLOCKER' => AppTheme.danger,
    'HIGH'    => AppTheme.orange,
    'MEDIUM'  => AppTheme.warning,
    _         => AppTheme.textMuted,
  };

  @override
  Widget build(BuildContext context) =>
    StatusBadge(label: priority, color: _color);
}

/// ── SectionHeader ─────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String label;
  final String title;
  final Color accentColor;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.label,
    required this.title,
    this.accentColor = AppTheme.primary,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                style: TextStyle(
                  color: accentColor, fontSize: 11,
                  letterSpacing: 3, fontFamily: 'Space Mono',
                ),
              ),
              const SizedBox(height: 4),
              Text(title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// ── GlassProgressBar ──────────────────────────────────────────────
class GlassProgressBar extends StatelessWidget {
  final double value; // 0–100
  final Color color;
  final double height;

  const GlassProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.border,
        borderRadius: BorderRadius.circular(height),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: (value / 100).clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(height),
            boxShadow: [BoxShadow(color: color.withAlpha(102), blurRadius: 6)],
          ),
        ),
      ),
    );
  }
}

/// ── LoadingSkeleton ────────────────────────────────────────────────
class LoadingSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const LoadingSkeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surface,
      highlightColor: AppTheme.surface2,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// ── LoadingCardSkeleton ────────────────────────────────────────────
class LoadingCardSkeleton extends StatelessWidget {
  const LoadingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (_) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LoadingSkeleton(height: 14, width: 120),
            const SizedBox(height: 10),
            const LoadingSkeleton(height: 10),
            const SizedBox(height: 6),
            LoadingSkeleton(height: 10, width: MediaQuery.of(context).size.width * 0.6),
          ],
        ),
      )),
    );
  }
}

/// ── GlassAppBar ────────────────────────────────────────────────────
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final Color? accentColor;

  const GlassAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.accentColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: AppTheme.bg,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          if (leading != null) leading!
          else if (Navigator.of(context).canPop())
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).pop(),
              color: AppTheme.textSecondary,
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16, fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(subtitle!,
                    style: const TextStyle(
                      color: AppTheme.textDim, fontSize: 11, letterSpacing: 1.5,
                    ),
                  ),
              ],
            ),
          ),
          if (actions != null) ...actions!,
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// ── EmptyState ────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.textDim),
            const SizedBox(height: 16),
            Text(title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
