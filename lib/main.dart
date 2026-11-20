import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'campus_services_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Fichier .env non trouvé.');
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
    throw StateError(
      'Variables Supabase manquantes. Vérifie la configuration.',
    );
  }

  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);

  runApp(const ProviderScope(child: CampusServicesApp()));
}
