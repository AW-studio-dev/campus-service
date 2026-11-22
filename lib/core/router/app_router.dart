import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../layout/main_layout.dart';
import '../providers/supabase_provider.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/onboarding_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/reset_password_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/auth/presentation/welcome_page.dart';
import '../../features/feed/presentation/create_post_page.dart';
import '../../features/feed/presentation/home_page.dart';
import '../../features/marketplace/presentation/marketplace_page.dart';
import '../../features/marketplace/presentation/product_detail_page.dart';
import '../../features/business/presentation/business_dashboard_page.dart';
import '../../features/business/presentation/business_storefront_page.dart';
import '../../features/business/presentation/create_business_page.dart';
import '../../features/requests/presentation/help_request_page.dart';
import '../../features/profile/presentation/edit_profile_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/messaging/presentation/chat_page.dart';
import '../../features/messaging/presentation/inbox_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/search/presentation/search_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/ads/presentation/admin_dashboard_page.dart';
import '../../features/ads/presentation/manage_ads_page.dart';
import '../../features/ads/presentation/create_ad_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final router = GoRouter(
    navigatorKey: AppConfig.navigatorKey,
    initialLocation: '/welcome',
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/welcome'),
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
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminDashboardPage(),
          ),
          GoRoute(
            path: '/admin/ads',
            builder: (context, state) => const ManageAdsPage(),
          ),
          GoRoute(
            path: '/admin/ads/create',
            builder: (context, state) => const CreateAdPage(),
          ),
          GoRoute(path: '/home', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/create-post',
            builder: (context, state) => const CreatePostPage(),
          ),
          GoRoute(
            path: '/help-request',
            builder: (context, state) => const HelpRequestPage(),
          ),
          GoRoute(
            path: '/marketplace',
            builder: (context, state) => const MarketplacePage(),
          ),
          GoRoute(
            path: '/marketplace/item/:listingId',
            builder: (context, state) => ProductDetailPage(
              listingId: state.pathParameters['listingId']!,
              isProduct: state.uri.queryParameters['kind'] != 'service',
            ),
          ),
          GoRoute(
            path: '/business/create',
            builder: (context, state) => const CreateBusinessPage(),
          ),
          GoRoute(
            path: '/business/manage',
            builder: (context, state) => const BusinessDashboardPage(),
          ),
          GoRoute(
            path: '/business/:businessId',
            builder: (context, state) => BusinessStorefrontPage(
              businessId: state.pathParameters['businessId']!,
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/profile/edit',
            builder: (context, state) => const EditProfilePage(),
          ),
          GoRoute(
            path: '/profile/:profileId',
            builder: (context, state) =>
                ProfilePage(profileId: state.pathParameters['profileId']),
          ),
          GoRoute(
            path: '/messages',
            builder: (context, state) => const InboxPage(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchPage(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: '/chat/new',
            builder: (context, state) =>
                ChatPage(recipientUserId: state.uri.queryParameters['userId']),
          ),
          GoRoute(
            path: '/chat/:conversationId',
            builder: (context, state) => ChatPage(
              conversationId: state.pathParameters['conversationId'],
            ),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final isAuthenticated = supabase.auth.currentSession != null;
      final location = state.matchedLocation;
      const publicRoutes = {
        '/splash',
        '/welcome',
        '/login',
        '/register',
        '/reset-password',
      };
      const authRoutes = {'/welcome', '/login', '/register'};

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
