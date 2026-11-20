import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/supabase_provider.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/onboarding_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/auth/presentation/verify_otp_page.dart';
import '../../features/auth/presentation/welcome_page.dart';
import '../../features/home/presentation/home_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final email = state.extra;
          if (email is VerifyOtpRouteArgs) {
            return VerifyOtpPage(
              email: email.email,
              startResendCooldown: email.startResendCooldown,
            );
          }
          return const VerifyOtpPage(email: '');
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
    ],
    redirect: (context, state) {
      final isAuthenticated = supabase.auth.currentSession != null;
      final location = state.matchedLocation;
      const publicRoutes = {
        '/splash',
        '/welcome',
        '/login',
        '/register',
        '/verify-otp',
      };
      const authRoutes = {'/welcome', '/login', '/register', '/verify-otp'};

      if (!isAuthenticated && !publicRoutes.contains(location)) {
        return '/welcome';
      }
      if (isAuthenticated && authRoutes.contains(location)) {
        return '/splash';
      }
      return null;
    },
  );

  ref.listen(authStateChangesProvider, (previous, next) {
    router.refresh();
  });
  ref.onDispose(router.dispose);

  return router;
});
