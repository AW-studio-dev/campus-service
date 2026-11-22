import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _welcomeNavy = Color(0xFF0B1F44);
const _welcomeOrange = Color(0xFFFF7900);

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  static const _slides = [
    _OnboardingSlide(
      title: 'Bienvenue sur CampusServices',
      description:
          'Une plateforme dédiée aux étudiants en Algérie pour découvrir, '
          'partager et accéder à des services au sein de leur communauté '
          'universitaire.',
    ),
    _OnboardingSlide(
      title: 'Connecte-toi avec ta communauté',
      description:
          "Échange avec d'autres étudiants, partage tes compétences et trouve "
          'facilement les services dont tu as besoin.',
    ),
    _OnboardingSlide(
      title: 'Développe tes projets',
      description:
          'Présente tes projets, propose tes services et transforme tes '
          'compétences en opportunités.',
    ),
  ];

  final _pageController = PageController();
  int _currentSlide = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectSlide(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'university_algeria.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          ColoredBox(color: Colors.black.withValues(alpha: 0.50)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1024;
                final isWide = constraints.maxWidth >= 768;
                final isCompact = constraints.maxHeight < 650;
                final logoSize = isCompact
                    ? isWide
                          ? 136.0
                          : (constraints.maxWidth * 0.38)
                                .clamp(110.0, 140.0)
                                .toDouble()
                    : isDesktop
                    ? 230.0
                    : isWide
                    ? 200.0
                    : (constraints.maxWidth * 0.48)
                          .clamp(138.0, 190.0)
                          .toDouble();

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isWide ? 32 : 24,
                        isCompact ? 8 : 20,
                        isWide ? 32 : 24,
                        isCompact ? 10 : 20,
                      ),
                      child: Column(
                        children: [
                          Image.asset(
                            width: logoSize,
                            height: logoSize,
                            'logo.png',
                            fit: BoxFit.contain,
                            semanticLabel: 'CampusServices',
                          ),
                          SizedBox(height: isCompact ? 8 : 18),
                          Expanded(
                            child: PageView.builder(
                              key: const ValueKey('welcome-carousel'),
                              controller: _pageController,
                              itemCount: _slides.length,
                              onPageChanged: (index) {
                                setState(() => _currentSlide = index);
                              },
                              itemBuilder: (context, index) {
                                return _SlideContent(
                                  slide: _slides[index],
                                  isDesktop: isDesktop,
                                );
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _slides.length,
                              (index) => _SlideIndicator(
                                key: ValueKey('onboarding-dot-$index'),
                                selected: index == _currentSlide,
                                onTap: () => _selectSlide(index),
                                label: 'Aller à la diapositive ${index + 1}',
                              ),
                            ),
                          ),
                          SizedBox(height: isCompact ? 8 : 18),
                          if (isWide)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 204,
                                  height: 54,
                                  child: _SignInButton(
                                    onPressed: () => context.go('/login'),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                SizedBox(
                                  width: 204,
                                  height: 54,
                                  child: _SignUpButton(
                                    onPressed: () => context.go('/register'),
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: isCompact ? 48 : 52,
                                  child: _SignInButton(
                                    onPressed: () => context.go('/login'),
                                  ),
                                ),
                                SizedBox(height: isCompact ? 8 : 10),
                                SizedBox(
                                  height: isCompact ? 48 : 52,
                                  child: _SignUpButton(
                                    onPressed: () => context.go('/register'),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({required this.title, required this.description});

  final String title;
  final String description;
}

class _SlideContent extends StatelessWidget {
  const _SlideContent({required this.slide, required this.isDesktop});

  final _OnboardingSlide slide;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              slide.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: isDesktop ? 30 : 24,
                fontWeight: FontWeight.w700,
                height: 1.2,
                shadows: const [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              slide.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.94),
                fontSize: isDesktop ? 17 : 14,
                height: 1.45,
                shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideIndicator extends StatelessWidget {
  const _SlideIndicator({
    required this.selected,
    required this.onTap,
    required this.label,
    super.key,
  });

  final bool selected;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? _welcomeOrange : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _welcomeNavy,
        foregroundColor: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('Se connecter'),
    );
  }
}

class _SignUpButton extends StatelessWidget {
  const _SignUpButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _welcomeNavy,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _welcomeNavy, width: 1.5),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text("S'inscrire"),
    );
  }
}
