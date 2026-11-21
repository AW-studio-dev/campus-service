import 'dart:typed_data';

import 'package:campus_service/campus_services_app.dart';
import 'package:campus_service/core/router/app_router.dart';
import 'package:campus_service/core/providers/supabase_provider.dart';
import 'package:campus_service/core/utils/image_upload_validation.dart';
import 'package:campus_service/features/auth/data/auth_repository.dart';
import 'package:campus_service/features/auth/presentation/auth_error_presenter.dart';
import 'package:campus_service/features/auth/presentation/verify_otp_page.dart';
import 'package:campus_service/features/feed/data/post_repository.dart';
import 'package:campus_service/shared/widgets/custom_text_field.dart';
import 'package:campus_service/shared/widgets/post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('unauthenticated users are redirected from private routes', (
    tester,
  ) async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [supabaseClientProvider.overrideWithValue(client)],
        child: const CampusServicesApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bienvenue sur CampusServices'), findsOneWidget);

    final context = tester.element(find.byType(CampusServicesApp));
    final router = ProviderScope.containerOf(context).read(appRouterProvider);
    router.go('/');
    await tester.pumpAndSettle();
    expect(find.text('Bienvenue sur CampusServices'), findsOneWidget);

    router.go('/login');
    await tester.pumpAndSettle();
    expect(find.text('Adresse e-mail'), findsOneWidget);

    router.go('/register');
    await tester.pumpAndSettle();
    expect(find.text('Confirmer le mot de passe'), findsOneWidget);
    final registerButton = find.widgetWithText(
      FilledButton,
      'Créer mon compte',
    );
    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    await tester.pumpAndSettle();
    expect(find.text('Veuillez accepter les conditions.'), findsOneWidget);

    router.go('/home');
    await tester.pumpAndSettle();

    expect(
      find.text('Votre espace CampusServices sera disponible ici.'),
      findsNothing,
    );
    expect(find.text('Bienvenue sur CampusServices'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    client.auth.stopAutoRefresh();
  });

  testWidgets('custom text field displays validation errors', (tester) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: CustomTextField(
              label: 'E-mail',
              controller: controller,
              validator: AppValidators.email,
            ),
          ),
        ),
      ),
    );

    formKey.currentState!.validate();
    await tester.pump();

    expect(find.text('Saisissez votre adresse e-mail.'), findsOneWidget);
    controller.dispose();
  });

  test('avatar validation accepts JPEG and PNG signatures only', () {
    expect(
      AuthRepository.imageMimeType(
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
      ),
      'image/png',
    );
    expect(
      AuthRepository.imageMimeType(Uint8List.fromList([0xFF, 0xD8, 0xFF])),
      'image/jpeg',
    );
    expect(AuthRepository.imageMimeType(Uint8List.fromList([0, 1, 2])), isNull);
  });

  test('image uploads enforce JPEG/PNG signatures and the 5 MB limit', () {
    final png = Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);
    expect(isValidImageUpload(png), isTrue);
    expect(isValidImageUpload(Uint8List.fromList([1, 2, 3])), isFalse);
    final oversizedPng = Uint8List(5 * 1024 * 1024 + 1)
      ..setRange(0, png.length, png);
    expect(isValidImageUpload(oversizedPng), isFalse);
  });

  testWidgets('post card displays content and invokes its like action', (
    tester,
  ) async {
    var likeCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            post: FeedPost(
              id: 'post-id',
              authorId: 'author-id',
              authorName: 'Étudiante',
              avatarUrl: null,
              body: 'Publication de test',
              postType: 'general',
              createdAt: DateTime.now(),
              imageUrl: null,
              likeCount: 2,
              commentCount: 1,
              isLikedByCurrentUser: false,
              isSavedByCurrentUser: false,
            ),
            onLike: () async {
              likeCount++;
            },
            onSave: () async {},
            onCommentsChanged: () {},
          ),
        ),
      ),
    );

    expect(find.text('Publication de test'), findsOneWidget);
    expect(find.text('2 J’aime'), findsOneWidget);
    await tester.tap(find.text('J’aime'));
    await tester.pumpAndSettle();
    expect(likeCount, 1);
  });

  test(
    'auth errors show safe diagnostic codes without raw server messages',
    () {
      final message = authErrorMessage(
        const AuthException(
          'private backend response',
          statusCode: '500',
          code: 'unexpected_failure',
        ),
        operation: AuthOperation.signUp,
      );

      expect(message, contains('unexpected_failure'));
      expect(message, isNot(contains('private backend response')));
    },
  );

  test('email rate-limit message advises waiting one hour', () {
    final message = authErrorMessage(
      const AuthException(
        'private backend response',
        statusCode: '429',
        code: 'over_email_send_rate_limit',
      ),
      operation: AuthOperation.signUp,
    );

    expect(message, contains('une heure'));
    expect(message, isNot(contains('private backend response')));
  });

  testWidgets('OTP page starts with resend disabled for 60 seconds', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProviderScope(
          child: const VerifyOtpPage(
            email: 'student@example.com',
            startResendCooldown: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Un code de vérification a été envoyé à student@example.com.'),
      findsOneWidget,
    );
    expect(find.text('Renvoyer dans 01:00'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
