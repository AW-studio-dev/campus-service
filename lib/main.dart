import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'campus_services_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: _requiredEnvironmentVariable('SUPABASE_URL'),
    publishableKey: _requiredEnvironmentVariable('SUPABASE_ANON_KEY'),
  );

  runApp(const ProviderScope(child: CampusServicesApp()));
}

String _requiredEnvironmentVariable(String name) {
  final value = dotenv.env[name]?.trim();
  if (value == null || value.isEmpty) {
    throw StateError('Missing required environment variable: $name');
  }
  return value;
}
