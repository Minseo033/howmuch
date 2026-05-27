import 'package:flutter/material.dart';
import 'package:howmuch/shared/widgets/howmuch_button.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    super.key,
    required this.figmaId,
    required this.icon,
    required this.title,
    required this.description,
    required this.highlights,
    required this.step,
    required this.totalSteps,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.onSkipPressed,
  });

  final String figmaId;
  final IconData icon;
  final String title;
  final String description;
  final List<String> highlights;
  final int step;
  final int totalSteps;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final VoidCallback? onSkipPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (onSkipPressed != null)
            TextButton(onPressed: onSkipPressed, child: const Text('건너뛰기')),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                figmaId,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 44,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              for (final item in highlights) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item)),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              const Spacer(),
              Row(
                children: List.generate(totalSteps, (index) {
                  final selected = index == step;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: selected ? 28 : 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 18),
              HowmuchButton(
                label: primaryLabel,
                icon: Icons.arrow_forward,
                onPressed: onPrimaryPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
