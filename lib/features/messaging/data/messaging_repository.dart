import 'package:supabase_flutter/supabase_flutter.dart';

class MessagingRepository {
  MessagingRepository(this._client);

  final SupabaseClient _client;

  Future<String> startDirectConversation({
    required String currentUserId,
    required String otherUserId,
    String? listingId,
    String? listingTitle,
    String? listingType,
  }) async {
    if (currentUserId == otherUserId) {
      throw const InvalidConversationException();
    }

    try {
      final conversationId = await _client.rpc(
        'create_direct_conversation',
        params: {
          'p_other_user_id': otherUserId,
          'p_listing_id': listingId,
          'p_listing_title': listingTitle,
          'p_listing_type': listingType,
        },
      );
      return conversationId as String;
    } on PostgrestException {
      // Compatibilité tant que la migration de contexte d'offre n'est pas
      // appliquée sur la base distante.
      final conversationId = await _client.rpc(
        'create_direct_conversation',
        params: {'p_other_user_id': otherUserId},
      );
      return conversationId as String;
    }
  }

  Future<ConversationContext?> fetchConversationContext(
    String conversationId,
  ) async {
    try {
      final row = await _client
          .from('conversations')
          .select('listing_id, listing_title, listing_type')
          .eq('id', conversationId)
          .maybeSingle();
      if (row == null) return null;
      final title = row['listing_title'] as String?;
      if (title == null || title.trim().isEmpty) return null;
      return ConversationContext(
        listingId: row['listing_id'] as String?,
        title: title,
        type: row['listing_type'] as String?,
      );
    } on PostgrestException {
      // Les colonnes n'existent pas encore : le chat reste utilisable.
      return null;
    }
  }

  Future<List<InboxConversation>> fetchInbox(String currentUserId) async {
    final membershipRows = await _client
        .from('conversation_members')
        .select('conversation_id, last_read_at')
        .eq('user_id', currentUserId);
    final ids = membershipRows
        .map((row) => row['conversation_id'] as String)
        .toList();
    if (ids.isEmpty) return const [];
    final lastReadByConversation = {
      for (final row in membershipRows)
        row['conversation_id'] as String: DateTime.tryParse(
          row['last_read_at'] as String? ?? '',
        ),
    };

    final results = await Future.wait([
      _client
          .from('conversations')
          .select(
            'id, type, conversation_members(user_id, profiles(display_name, avatar_path))',
          )
          .inFilter('id', ids)
          .order('last_message_at', ascending: false),
      _client
          .from('messages')
          .select('conversation_id, sender_id, body, created_at')
          .inFilter('conversation_id', ids)
          .order('created_at', ascending: false)
          .limit(5000),
    ]);
    final messageByConversation = <String, Map<String, dynamic>>{};
    final unreadByConversation = <String, int>{};
    for (final message in results[1]) {
      final conversationId = message['conversation_id'] as String;
      messageByConversation.putIfAbsent(conversationId, () => message);
      if (message['sender_id'] == currentUserId) continue;
      final createdAt = DateTime.tryParse(
        message['created_at'] as String? ?? '',
      );
      final lastReadAt = lastReadByConversation[conversationId];
      if (createdAt == null) continue;
      if (lastReadAt == null || createdAt.isAfter(lastReadAt)) {
        unreadByConversation.update(
          conversationId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final items = <InboxConversation>[];
    for (final row in results[0]) {
      final conversationId = row['id'] as String;
      final rawMembers = row['conversation_members'];
      final members = rawMembers is List
          ? rawMembers.whereType<Map<String, dynamic>>().toList()
          : <Map<String, dynamic>>[];
      final otherMember = members.cast<Map<String, dynamic>?>().firstWhere(
        (member) => member?['user_id'] != currentUserId,
        orElse: () => null,
      );
      final rawProfile = otherMember?['profiles'];
      final profile = rawProfile is Map<String, dynamic>
          ? rawProfile
          : const <String, dynamic>{};
      final message = messageByConversation[conversationId];
      items.add(
        InboxConversation(
          id: conversationId,
          type: row['type'] as String,
          displayName: profile['display_name'] as String? ?? 'Conversation',
          avatarUrl: _publicAvatarUrl(profile['avatar_path'] as String?),
          lastMessage: message?['body'] as String? ?? 'Aucun message',
          lastMessageAt: DateTime.tryParse(
            message?['created_at'] as String? ?? '',
          ),
          unreadCount: unreadByConversation[conversationId] ?? 0,
        ),
      );
    }
    items.sort((a, b) {
      final aDate = a.lastMessageAt;
      final bDate = b.lastMessageAt;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return items;
  }

  Future<void> markConversationRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _client.rpc(
        'mark_conversation_read',
        params: {'p_conversation_id': conversationId},
      );
      return;
    } on PostgrestException {
      // Repli si la fonction serveur n'est pas encore déployée.
    }

    // On se cale sur l'horodatage serveur du dernier message : cela évite
    // qu'un décalage d'horloge client laisse des messages comptés comme non lus.
    final latest = await _client
        .from('messages')
        .select('created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final latestAt = DateTime.tryParse(latest?['created_at'] as String? ?? '');
    if (latestAt == null) return;

    await _client
        .from('conversation_members')
        .update({'last_read_at': latestAt.toUtc().toIso8601String()})
        .eq('conversation_id', conversationId)
        .eq('user_id', userId);
  }

  Future<List<ChatMessage>> fetchMessages(String conversationId) async {
    final rows = await _client
        .from('messages')
        .select('id, sender_id, body, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(500);
    return rows
        .map(
          (row) => ChatMessage(
            id: row['id'] as String,
            senderId: row['sender_id'] as String,
            body: row['body'] as String,
            createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          ),
        )
        .toList()
        .reversed
        .toList();
  }

  Future<String?> fetchOtherMemberName({
    required String conversationId,
    required String currentUserId,
  }) async {
    final row = await _client
        .from('conversation_members')
        .select('profiles(display_name)')
        .eq('conversation_id', conversationId)
        .neq('user_id', currentUserId)
        .limit(1)
        .maybeSingle();
    final rawProfile = row?['profiles'];
    if (rawProfile is! Map<String, dynamic>) return null;
    return rawProfile['display_name'] as String?;
  }

  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String body,
  }) async {
    final message = body.trim();
    if (message.isEmpty || message.length > 5000) {
      throw const InvalidMessageException();
    }
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'body': message,
    });
  }

  String? _publicAvatarUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return _client.storage.from('avatars').getPublicUrl(path);
  }
}

class InboxConversation {
  const InboxConversation({
    required this.id,
    required this.type,
    required this.displayName,
    required this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
  });

  final String id;
  final String type;
  final String displayName;
  final String? avatarUrl;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
}

class ConversationContext {
  const ConversationContext({
    required this.listingId,
    required this.title,
    required this.type,
  });

  final String? listingId;
  final String title;
  final String? type;
}

class InvalidConversationException implements Exception {
  const InvalidConversationException();
}

class InvalidMessageException implements Exception {
  const InvalidMessageException();
}
