import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/primary_button.dart';
import '../application/messaging_providers.dart';
import '../data/messaging_repository.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({this.conversationId, this.recipientUserId, super.key});

  final String? conversationId;
  final String? recipientUserId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  RealtimeChannel? _channel;
  String? _conversationId;
  bool _isStartingConversation = false;
  bool _isSending = false;
  String? _lastRenderedMessageId;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    if (_conversationId != null) {
      _listenForMessages(_conversationId!);
      return;
    }
    if (widget.recipientUserId == null || _isStartingConversation) return;
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) {
      _showMessage('Connectez-vous pour envoyer un message.');
      return;
    }

    setState(() => _isStartingConversation = true);
    try {
      final id = await ref
          .read(messagingRepositoryProvider)
          .startDirectConversation(
            currentUserId: userId,
            otherUserId: widget.recipientUserId!,
          );
      if (!mounted) return;
      context.go('/chat/$id');
    } on Exception {
      _showMessage('Impossible de démarrer la conversation.');
    } finally {
      if (mounted) setState(() => _isStartingConversation = false);
    }
  }

  void _listenForMessages(String conversationId) {
    final client = ref.read(supabaseClientProvider);
    _channel = client
        .channel('messages-$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            if (mounted) {
              ref.invalidate(conversationMessagesProvider(conversationId));
              ref.invalidate(inboxProvider);
            }
          },
        )
        .subscribe();

    _refreshTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (mounted) {
        ref.invalidate(conversationMessagesProvider(conversationId));
        ref.invalidate(inboxProvider);
      }
    });
  }

  Future<void> _send() async {
    final conversationId = _conversationId;
    final body = _messageController.text.trim();
    final senderId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (conversationId == null ||
        senderId == null ||
        body.isEmpty ||
        _isSending) {
      return;
    }
    if (body.length > 5000) {
      _showMessage('Le message ne peut pas dépasser 5 000 caractères.');
      return;
    }

    setState(() => _isSending = true);
    try {
      await ref
          .read(messagingRepositoryProvider)
          .sendMessage(
            conversationId: conversationId,
            senderId: senderId,
            body: body,
          );
      if (!mounted) return;
      _messageController.clear();
      ref.invalidate(conversationMessagesProvider(conversationId));
      ref.invalidate(inboxProvider);
    } on InvalidMessageException {
      _showMessage('Le message est vide ou trop long.');
    } on Exception {
      _showMessage('Message impossible à envoyer. Réessayez.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    final channel = _channel;
    if (channel != null) {
      unawaited(ref.read(supabaseClientProvider).removeChannel(channel));
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final conversationId = _conversationId;
    final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
    final messages = conversationId == null
        ? null
        : ref.watch(conversationMessagesProvider(conversationId));
    final title = conversationId == null
        ? null
        : ref.watch(conversationTitleProvider(conversationId));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Retour aux messages',
                onPressed: () => context.go('/messages'),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  title?.when(
                        loading: () => 'Conversation',
                        error: (error, stackTrace) => 'Conversation',
                        data: (name) =>
                            name ??
                            (widget.recipientUserId == null
                                ? 'Conversation'
                                : 'Nouvelle conversation'),
                      ) ??
                      (widget.recipientUserId == null
                          ? 'Conversation'
                          : 'Nouvelle conversation'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isStartingConversation
              ? const Center(child: CircularProgressIndicator())
              : messages == null
              ? const Center(child: Text('Conversation indisponible.'))
              : messages.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Impossible de charger les messages.'),
                        TextButton(
                          onPressed: () => ref.invalidate(
                            conversationMessagesProvider(conversationId!),
                          ),
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                  data: (items) {
                    if (items.isNotEmpty &&
                        items.last.id != _lastRenderedMessageId) {
                      final isFirstList = _lastRenderedMessageId == null;
                      final shouldScroll =
                          isFirstList ||
                          !_scrollController.hasClients ||
                          _scrollController.position.maxScrollExtent -
                                  _scrollController.position.pixels <
                              120;
                      _lastRenderedMessageId = items.last.id;
                      if (shouldScroll) _scrollToLatest();
                    }
                    if (items.isEmpty) {
                      return const Center(
                        child: Text('Envoyez le premier message.'),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final message = items[index];
                        final isMine = message.senderId == userId;
                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.72,
                            ),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? AppColors.primary
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: isMine
                                  ? null
                                  : Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              message.body,
                              style: TextStyle(
                                color: isMine
                                    ? AppColors.surface
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 5000,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    enabled: conversationId != null && !_isSending,
                    decoration: const InputDecoration(
                      hintText: 'Écrire un message…',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PrimaryButton(
                  label: 'Envoyer',
                  isLoading: _isSending,
                  expand: false,
                  onPressed: conversationId == null ? null : _send,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      unawaited(
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    });
  }
}
