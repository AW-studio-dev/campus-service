import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_avatar.dart';
import '../../../shared/widgets/social_card.dart';
import '../../ads/application/ad_providers.dart';
import '../application/search_providers.dart';
import '../data/search_repository.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _queryController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _kind = 'all';

  static const _filters = [
    ('all', 'Tout'),
    ('user', 'Étudiants'),
    ('post', 'Publications'),
    ('business', 'Businesses'),
    ('product', 'Produits'),
    ('request', 'Demandes'),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _openResult(SearchResult result) {
    switch (result.type) {
      case 'user':
        context.go('/profile/${result.relatedId}');
      case 'business':
        context.go('/business/${result.relatedId}');
      case 'product':
        context.go('/marketplace/item/${result.id}?kind=product');
      case 'post':
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(result.title),
            content: SingleChildScrollView(child: Text(result.description)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/profile/${result.relatedId}');
                },
                child: const Text('Voir le profil'),
              ),
            ],
          ),
        );
      case 'request':
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(result.title),
            content: SingleChildScrollView(
              child: Text(
                result.description.isEmpty
                    ? 'Aucune description.'
                    : result.description,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go(
                    '/chat/new?userId=${Uri.encodeComponent(result.relatedId)}',
                  );
                },
                child: const Text('Contacter'),
              ),
            ],
          ),
        );
    }
  }

  Future<void> _openTrackedResult(SearchResult result) async {
    final campaignId = result.campaignId;
    if (campaignId != null) {
      try {
        await ref
            .read(adRepositoryProvider)
            .recordEvent(campaignId: campaignId, eventType: 'click');
      } on Exception {
        _showMessage('Le clic sur l’annonce n’a pas pu être comptabilisé.');
      }
    }
    if (mounted) _openResult(result);
  }

  @override
  Widget build(BuildContext context) {
    final filter = SearchFilter(query: _query, kind: _kind);
    final results = ref.watch(searchResultsProvider(filter));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Recherche',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _queryController,
                autofocus: true,
                onChanged: _onQueryChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Étudiants, publications, services…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _queryController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer',
                          onPressed: () {
                            _queryController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            children: [
              for (final (kind, label) in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _query.length < 2
              ? const Center(
                  child: Text(
                    'Saisissez au moins 2 caractères pour rechercher.',
                  ),
                )
              : results.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('La recherche a échoué. Réessayez.'),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(searchResultsProvider(filter)),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                  data: (items) => items.isEmpty
                      ? const Center(child: Text('Aucun résultat trouvé.'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return SocialCard(
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                leading: AppAvatar(
                                  imageUrl: item.imageUrl,
                                  name: item.title,
                                  size: 44,
                                ),
                                title: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _typeLabel(item.type),
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (item.isSponsored)
                                      const Text(
                                        'Sponsorisé',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    if (item.description.isNotEmpty)
                                      Text(
                                        item.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                                isThreeLine: item.description.isNotEmpty,
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _openTrackedResult(item),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    );
  }

  String _typeLabel(String type) => switch (type) {
    'user' => 'Étudiant',
    'post' => 'Publication',
    'business' => 'Business',
    'product' => 'Produit',
    'request' => 'Demande d’aide',
    _ => 'Résultat',
  };

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
