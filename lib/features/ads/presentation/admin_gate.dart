import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ad_providers.dart';

class AdminGate extends ConsumerWidget {
  const AdminGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(isAdminProvider);
    return access.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const Center(
        child: Text('Impossible de vérifier les droits administrateur.'),
      ),
      data: (isAdmin) => isAdmin
          ? child
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Accès réservé à l’administration.'),
              ),
            ),
    );
  }
}
