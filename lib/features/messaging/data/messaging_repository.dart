import 'package:supabase_flutter/supabase_flutter.dart';

class MessagingRepository {
  MessagingRepository(this._client);

  final SupabaseClient _client;

  Future<String> startDirectConversation({
    required String currentUserId,
    required String otherUserId,
  }) async {
    if (currentUserId == otherUserId) {
      throw const InvalidConversationException();
    }

    final conversationId = await _client.rpc(
      'create_direct_conversation',
      params: {'p_other_user_id': otherUserId},
    );
    return conversationId as String;
  }

  Future<List<InboxConversation>> fetchInbox(String currentUserId) async {
    final membershipRows = await _client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', currentUserId);
    final ids = membershipRows
        .map((row) => row['conversation_id'] as String)
        .toList();
    if (ids.isEmpty) return const [];

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
          .limit(1000),
    ]);
    final messageByConversation = <String, Map<String, dynamic>>{};
    for (final message in results[1]) {
      messageByConversation.putIfAbsent(
        message['conversation_id'] as String,
        () => message,
      );
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
  });

  final String id;
  final String type;
  final String displayName;
  final String? avatarUrl;
  final String lastMessage;
  final DateTime? lastMessageAt;
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

class InvalidConversationException implements Exception {
  const InvalidConversationException();
}

class InvalidMessageException implements Exception {
  const InvalidMessageException();
}
