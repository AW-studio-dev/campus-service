import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'campus_services_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Cloud builds may provide the same values through --dart-define.
  }

  const envUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  const envKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  final supabaseUrl = envUrl.isNotEmpty
      ? envUrl
      : (dotenv.env['SUPABASE_URL'] ?? '');

  final supabaseKey = envKey.isNotEmpty
      ? envKey
      : (dotenv.env['SUPABASE_ANON_KEY'] ?? '');

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    runApp(
      const _StartupErrorApp(
        message:
            'Configuration Supabase manquante. Configure SUPABASE_URL et '
            'SUPABASE_ANON_KEY dans .env ou dans les paramètres de build.',
      ),
    );
    return;
  }

  try {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  } on Exception {
    runApp(
      const _StartupErrorApp(
        message:
            'La connexion à Supabase n’a pas pu être initialisée. Vérifiez '
            'l’URL du projet et sa clé publique.',
      ),
    );
    return;
  }

  runApp(const ProviderScope(child: CampusServicesApp()));
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusServices',
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 48,
                    color: Color(0xFF0B1F45),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'CampusServices ne peut pas démarrer',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
