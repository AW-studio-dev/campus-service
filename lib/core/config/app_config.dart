import 'package:flutter/widgets.dart';

class AppConfig {
  const AppConfig._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String baseUrl =
      'https://campus-service-6345e.web.app/';

  static String businessUrl(String slug) =>
      '${baseUrl}business/${Uri.encodeComponent(slug)}';

  static const String passwordResetUrl =
      'https://campus-service-6345e.web.app/#/reset-password';
}
