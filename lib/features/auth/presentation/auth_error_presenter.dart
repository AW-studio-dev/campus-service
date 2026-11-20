import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthOperation { signIn, signUp, verifyOtp, resendOtp, passwordReset }

String authErrorMessage(
  AuthException error, {
  required AuthOperation operation,
}) {
  final code = error.code;
  if (kDebugMode) {
    debugPrint(
      'Supabase Auth ${operation.name} failed: '
      'status=${error.statusCode ?? 'none'}, code=${code ?? 'none'}',
    );
  }

  if (error.statusCode == null && code == null) {
    final message = switch (operation) {
      AuthOperation.signIn =>
        'Impossible de joindre le serveur. Vérifiez votre connexion et '
            'réessayez.',
      AuthOperation.signUp =>
        'Impossible de joindre le serveur. Vérifiez votre connexion et '
            'réessayez.',
      AuthOperation.passwordReset =>
        'Impossible de joindre le serveur. Vérifiez votre connexion et '
            'réessayez.',
      AuthOperation.verifyOtp =>
        'Impossible de joindre le serveur. Vérifiez votre connexion et '
            'réessayez.',
      AuthOperation.resendOtp =>
        'Impossible de joindre le serveur. Vérifiez votre connexion et '
            'réessayez.',
    };
    return _withDiagnostic(message, error);
  }

  final message = switch (code) {
    'email_not_confirmed' =>
      'Confirmez votre adresse e-mail avant de vous connecter.',
    'over_email_send_rate_limit' =>
      'Trop de demandes d’email. Veuillez patienter une heure avant de '
          'réessayer.',
    'over_request_rate_limit' =>
      'Trop de tentatives. Patientez avant de réessayer.',
    'email_provider_disabled' =>
      'L’inscription par e-mail est désactivée côté serveur.',
    'signup_disabled' => 'Les inscriptions sont désactivées côté serveur.',
    'weak_password' =>
      'Mot de passe trop faible. Choisissez un mot de passe plus robuste.',
    'otp_expired' => 'Code invalide ou expiré. Demandez un nouveau code.',
    'validation_failed' =>
      operation == AuthOperation.verifyOtp
          ? 'Code invalide. Vérifiez les six chiffres et réessayez.'
          : 'Certaines informations sont invalides. Vérifiez les champs.',
    _ => switch (operation) {
      AuthOperation.signIn =>
        'Connexion impossible. Vérifiez vos identifiants et la confirmation '
            'de votre adresse e-mail.',
      AuthOperation.signUp =>
        'Création du compte impossible pour le moment. Réessayez plus tard.',
      AuthOperation.verifyOtp =>
        'Code invalide. Vérifiez les six chiffres et réessayez.',
      AuthOperation.resendOtp =>
        'Impossible de renvoyer le code pour le moment.',
      AuthOperation.passwordReset =>
        'Impossible d’envoyer le lien pour le moment.',
    },
  };

  return _withDiagnostic(message, error);
}

String _withDiagnostic(String message, AuthException error) {
  if (!kDebugMode) return message;

  final diagnostic =
      error.code ??
      (error.statusCode == null ? 'réseau' : 'HTTP ${error.statusCode}');
  return '$message\nCode diagnostic : $diagnostic';
}
