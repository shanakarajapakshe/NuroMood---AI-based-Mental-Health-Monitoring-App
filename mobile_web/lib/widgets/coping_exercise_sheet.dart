import 'package:flutter/material.dart';

import '../models/journal_analysis.dart';

class CopingExerciseSheet extends StatefulWidget {
  const CopingExerciseSheet({
    super.key,
    required this.plan,
  });

  final CopingPlan plan;

  static Future<void> show(BuildContext context, CopingPlan plan) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CopingExerciseSheet(plan: plan),
    );
  }

  @override
  State<CopingExerciseSheet> createState() => _CopingExerciseSheetState();
}

class _CopingExerciseSheetState extends State<CopingExerciseSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.68, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final breathing = widget.plan.exercise.contains('breathing');
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(Icons.self_improvement, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.plan.title,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(widget.plan.message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
            if (breathing)
              Center(
                child: AnimatedBuilder(
                  animation: _scale,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scale.value,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withValues(alpha: 0.14),
                          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.45), width: 2),
                        ),
                        child: Center(
                          child: Text(
                            _scale.value > 0.9 ? 'Exhale' : 'Inhale',
                            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 18),
            ...widget.plan.steps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(step)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
