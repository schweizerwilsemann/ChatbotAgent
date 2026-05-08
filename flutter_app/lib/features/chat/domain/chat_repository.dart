import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/chat/data/chat_api.dart';
import 'package:sports_venue_chatbot/features/chat/data/chat_models.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(chatApiProvider));
});

/// Abstract chat repository interface
abstract class IChatRepository {
  Future<ChatResponse> sendMessage(String message, String? sessionId);
  Stream<StreamChunk> sendMessageStream(String message, String? sessionId);
  Future<List<ChatMessage>> getChatHistory(String sessionId);
  Future<void> deleteSession(String sessionId);
}

/// Concrete implementation of the chat repository
class ChatRepository implements IChatRepository {
  final ChatApi _chatApi;

  ChatRepository(this._chatApi);

  @override
  Future<ChatResponse> sendMessage(String message, String? sessionId) async {
    try {
      if (message.trim().isEmpty) {
        throw ValidationException(message: 'Tin nhắn không được để trống');
      }
      return await _chatApi.sendMessage(message.trim(), sessionId);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể gửi tin nhắn. Vui lòng thử lại.',
        statusCode: 500,
      );
    }
  }

  @override
  Stream<StreamChunk> sendMessageStream(String message, String? sessionId) {
    if (message.trim().isEmpty) {
      return Stream.error(
        ValidationException(message: 'Tin nhắn không được để trống'),
      );
    }
    return _chatApi.sendMessageStream(message.trim(), sessionId);
  }

  @override
  Future<List<ChatMessage>> getChatHistory(String sessionId) async {
    try {
      return await _chatApi.getChatHistory(sessionId);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể tải lịch sử chat.',
        statusCode: 500,
      );
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    try {
      await _chatApi.deleteSession(sessionId);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'Không thể xóa phiên chat.',
        statusCode: 500,
      );
    }
  }
}
