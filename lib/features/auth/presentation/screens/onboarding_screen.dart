import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;

  final _pages = [
    const _OnboardPage(
      accent: AppTheme.primary,
      icon: Icons.hub_outlined,
      title: 'Module Handoffs\nMade Airtight',
      body:
          'Glassboard tracks every deliverable across your org\'s modules — no more "I thought you had it" moments.',
    ),
    const _OnboardPage(
      accent: AppTheme.warning,
      icon: Icons.handshake_outlined,
      title: 'Digital Handshake\nProtocol',
      body:
          'Attach proof, hit send. The receiving lead accepts or rejects with a timestamped, immutable record.',
    ),
    const _OnboardPage(
      accent: AppTheme.purple,
      icon: Icons.history_edu_outlined,
      title: 'Every Action\nAudit-Logged',
      body:
          'From task completions to file versions — every change is append-only. Nothing gets lost, nothing gets hidden.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _pages[i],
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => AnimatedContainer(
                duration: 200.ms,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 24 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _page == i ? _pages[i].accent : AppTheme.border2,
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
            ),
            const SizedBox(height: 32),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('GET STARTED'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('CREATE AN ACCOUNT'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String title;
  final String body;

  const _OnboardPage({
    required this.accent,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: accent.withAlpha(26),
              border: Border.all(color: accent.withAlpha(102)),
            ),
            child: Icon(icon, color: accent, size: 36),
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.2, end: 0),
          const SizedBox(height: 32),
          Text(title,
            style: Theme.of(context)
                .textTheme
                .displaySmall!
                .copyWith(color: AppTheme.textPrimary, height: 1.2),
          )
              .animate()
              .fadeIn(delay: 100.ms, duration: 500.ms)
              .slideY(begin: 0.2, end: 0),
          const SizedBox(height: 16),
          Text(body,
            style: Theme.of(context)
                .textTheme
                .bodyLarge!
                .copyWith(color: AppTheme.textSecondary, height: 1.7),
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 500.ms),
        ],
      ),
    );
  }
}
