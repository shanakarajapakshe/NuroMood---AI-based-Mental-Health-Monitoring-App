import 'package:flutter/material.dart';

class NeuroColors {
  static const mint = Color(0xFF7CCBA2);
  static const teal = Color(0xFF3FE6E4);
  static const aqua = Color(0xFFCDEFEA);
  static const sky = Color(0xFFDCEBFF);
  static const lavender = Color(0xFFC064FF);
  static const electricPink = Color(0xFFFF5FD2);
  static const blush = Color(0xFFFFE5D6);
  static const ink = Color(0xFF1F2A2E);
  static const muted = Color(0xFF6E7E84);
  static const dark = Color(0xFF07131F);
  static const darkCard = Color(0xFF102638);
}

class NeuroBreakpoints {
  static const mobile = 600.0;
  static const tablet = 900.0;
  static const desktop = 1100.0;
}

EdgeInsets neuroPagePadding(double width) {
  if (width < NeuroBreakpoints.mobile) {
    return const EdgeInsets.fromLTRB(14, 12, 14, 104);
  }
  if (width < NeuroBreakpoints.desktop) {
    return const EdgeInsets.fromLTRB(22, 18, 22, 96);
  }
  return const EdgeInsets.all(22);
}

class NeuroShell extends StatelessWidget {
  const NeuroShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [
                      Color(0xFF06121C),
                      Color(0xFF082538),
                      Color(0xFF251047),
                    ]
                  : const [
                      Color(0xFFE5F4FF),
                      Color(0xFFDDF4EC),
                      Color(0xFFF8EFE8),
                    ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
        if (dark) const Positioned.fill(child: _NeonGridBackground()),
        Positioned.fill(child: Padding(padding: padding, child: child)),
      ],
    );
  }
}

class _NeonGridBackground extends StatelessWidget {
  const _NeonGridBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _NeonGridPainter());
  }
}

class _NeonGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = NeuroColors.teal.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    const step = 38.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          NeuroColors.electricPink.withValues(alpha: 0.22),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.82, size.height * 0.16),
        radius: size.shortestSide * 0.52,
      ));
    canvas.drawRect(Offset.zero & size, glowPaint);

    final tealGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          NeuroColors.teal.withValues(alpha: 0.16),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.12, size.height * 0.72),
        radius: size.shortestSide * 0.62,
      ));
    canvas.drawRect(Offset.zero & size, tealGlow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class NeuroCard extends StatelessWidget {
  const NeuroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark
            ? NeuroColors.darkCard.withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: dark
              ? NeuroColors.teal.withValues(alpha: 0.28)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: dark
                ? NeuroColors.electricPink.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: dark ? 30 : 24,
            offset: const Offset(0, 14),
          ),
          if (dark)
            BoxShadow(
              color: NeuroColors.teal.withValues(alpha: 0.10),
              blurRadius: 18,
              spreadRadius: 1,
            ),
        ],
      ),
      child: child,
    );
  }
}

class NeuroGlowFrame extends StatelessWidget {
  const NeuroGlowFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: dark
            ? [
                BoxShadow(
                  color: NeuroColors.electricPink.withValues(alpha: 0.28),
                  blurRadius: 34,
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: NeuroColors.teal.withValues(alpha: 0.20),
                  blurRadius: 26,
                  spreadRadius: -6,
                ),
              ]
            : const [],
      ),
      child: child,
    );
  }
}

class NeuroSectionLabel extends StatelessWidget {
  const NeuroSectionLabel({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
        ],
        Text(
          text.toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class NeuroAuthPanel extends StatelessWidget {
  const NeuroAuthPanel({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF073044), Color(0xFF0B6E84), Color(0xFF7034B8)],
        ),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: NeuroColors.electricPink.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: NeuroColors.teal.withValues(alpha: 0.5)),
              ),
              child:
                  const Icon(Icons.spa_rounded, color: Colors.white, size: 30),
            ),
            const Spacer(),
            Text(
              title,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.86),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 26),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _AuthSignal(icon: Icons.lock_rounded, label: "Private"),
                _AuthSignal(icon: Icons.mood_rounded, label: "Mood"),
                _AuthSignal(icon: Icons.insights_rounded, label: "Insights"),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthSignal extends StatelessWidget {
  const _AuthSignal({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class MoodBrand extends StatelessWidget {
  const MoodBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 34 : 42,
          height: compact ? 34 : 42,
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.90),
            border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.spa_rounded, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Text(
          'NeuroMood',
          style: (compact
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.headlineSmall)
              ?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

ButtonStyle neuroFilledButton(BuildContext context) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  return FilledButton.styleFrom(
    backgroundColor: dark ? NeuroColors.teal : const Color(0xFF177E89),
    foregroundColor: dark ? const Color(0xFF06121C) : Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: const TextStyle(fontWeight: FontWeight.w900),
    elevation: 0,
  );
}
