import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../features/feed/application/post_providers.dart';
import '../../features/feed/data/post_repository.dart';
import '../../features/report/presentation/report_modal.dart';
import 'app_avatar.dart';
import 'social_card.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    required this.post,
    required this.onLike,
    required this.onSave,
    required this.onCommentsChanged,
    super.key,
  });

  final FeedPost post;
  final Future<void> Function() onLike;
  final Future<void> Function() onSave;
  final VoidCallback onCommentsChanged;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiking = false;

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    setState(() => _isLiking = true);
    try {
      await widget.onLike();
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  Future<void> _share() async {
    await Clipboard.setData(ClipboardData(text: widget.post.body));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Texte de la publication copié.')),
      );
  }

  Future<void> _openComments() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (context) => _PostCommentsSheet(post: widget.post),
    );
    if (mounted) widget.onCommentsChanged();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return SocialCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppAvatar(
                imageUrl: post.avatarUrl,
                name: post.authorName,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _relativeDate(post.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Signaler la publication',
                onPressed: () => ReportModal.show(
                  context,
                  targetType: 'post',
                  targetId: post.id,
                ),
                icon: const Icon(Icons.more_horiz),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SelectableText(post.body),
          if (post.imageUrl != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                post.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Center(
                    child: Icon(Icons.broken_image_outlined, size: 36),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${post.likeCount} J’aime',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                '${post.commentCount} commentaires',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _PostAction(
                  icon: post.isLikedByCurrentUser
                      ? Icons.favorite
                      : Icons.favorite_border,
                  label: 'J’aime',
                  isActive: post.isLikedByCurrentUser,
                  isLoading: _isLiking,
                  onPressed: _toggleLike,
                ),
              ),
              Expanded(
                child: _PostAction(
                  icon: Icons.mode_comment_outlined,
                  label: 'Commenter',
                  onPressed: _openComments,
                ),
              ),
              Expanded(
                child: _PostAction(
                  icon: Icons.share_outlined,
                  label: 'Partager',
                  onPressed: _share,
                ),
              ),
              Expanded(
                child: _PostAction(
                  icon: post.isSavedByCurrentUser
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  label: 'Enregistrer',
                  isActive: post.isSavedByCurrentUser,
                  onPressed: widget.onSave,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _relativeDate(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'À l’instant';
    if (difference.inHours < 1) return 'Il y a ${difference.inMinutes} min';
    if (difference.inDays < 1) return 'Il y a ${difference.inHours} h';
    if (difference.inDays < 7) return 'Il y a ${difference.inDays} j';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isActive = false,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isActive;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.textSecondary;
    return TextButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 19, color: color),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color),
      ),
    );
  }
}

class _PostCommentsSheet extends ConsumerStatefulWidget {
  const _PostCommentsSheet({required this.post});

  final FeedPost post;

  @override
  ConsumerState<_PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends ConsumerState<_PostCommentsSheet> {
  final _commentController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty || body.length > 1000 || _isSending) return;
    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      _showMessage('Connectez-vous pour commenter.');
      return;
    }

    setState(() => _isSending = true);
    try {
      await ref
          .read(postRepositoryProvider)
          .addComment(postId: widget.post.id, authorId: userId, body: body);
      if (!mounted) return;
      _commentController.clear();
      ref.invalidate(postCommentsProvider(widget.post.id));
    } on Exception {
      _showMessage('Commentaire impossible à envoyer. Réessayez.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(postCommentsProvider(widget.post.id));
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Commentaires',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: comments.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => _CommentsError(
                  onRetry: () =>
                      ref.invalidate(postCommentsProvider(widget.post.id)),
                ),
                data: (items) => items.isEmpty
                    ? const Center(
                        child: Text('Aucun commentaire pour le moment.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final comment = items[index];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppAvatar(
                                imageUrl: comment.avatarUrl,
                                name: comment.authorName,
                                size: 36,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        comment.authorName,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(comment.body),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendComment(),
                      decoration: const InputDecoration(
                        labelText: 'Écrire un commentaire',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Envoyer',
                    onPressed: _isSending ? null : _sendComment,
                    icon: _isSending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentsError extends StatelessWidget {
  const _CommentsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Impossible de charger les commentaires.'),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
