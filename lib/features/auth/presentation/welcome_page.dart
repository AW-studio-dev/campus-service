import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bannerHeight = (constraints.maxHeight * 0.38)
                .clamp(210.0, 340.0)
                .toDouble();

            return Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: bannerHeight,
                  child: Image.asset(
                    'university_algeria.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Bienvenue sur CampusServices',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontSize: 25,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Votre communauté étudiante en Algérie',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            const Spacer(),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _OnboardingDot(active: true),
                                SizedBox(width: 9),
                                _OnboardingDot(),
                                SizedBox(width: 9),
                                _OnboardingDot(),
                              ],
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              height: 54,
                              child: FilledButton(
                                onPressed: () => context.go('/login'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Se connecter'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 54,
                              child: OutlinedButton(
                                onPressed: () => context.go('/register'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text("S'inscrire"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OnboardingDot extends StatelessWidget {
  const _OnboardingDot({this.active = false});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? AppColors.primary : AppColors.border,
      ),
    );
  }
}
