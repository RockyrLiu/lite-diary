import 'package:lite_diary/database/database.dart';
import 'package:lite_diary/providers/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'conversation_provider.g.dart';

@riverpod
Future<List<Conversation>> allConversations(AllConversationsRef ref) {
  return ref.watch(databaseProvider).getAllConversations();
}

@riverpod
Future<List<Message>> messagesByConversation(MessagesByConversationRef ref, int conversationId) {
  return ref.watch(databaseProvider).getMessagesByConversation(conversationId);
}
