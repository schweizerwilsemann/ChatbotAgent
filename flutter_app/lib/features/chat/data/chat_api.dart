import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/constants/api_constants.dart';
import 'package:sports_venue_chatbot/core/network/dio_client.dart';
import 'package:sports_venue_chatbot/features/chat/data/chat_models.dart';

final chatApiProvider = Provider<ChatApi>((ref) {
  return ChatApi(ref.watch(dioClientProvider));
});

class ChatApi {
  final DioClient _dioClient;

  ChatApi(this._dioClient);

  /// Send a message to the AI chatbot and receive a response
  Future<ChatResponse> sendMessage(String message, String? sessionId,
      {Map<String, dynamic>? context}) async {
    try {
      final request =
          ChatRequest(message: message, sessionId: sessionId, context: context);

      final response = await _dioClient.post<Map<String, dynamic>>(
        ApiConstants.chatEndpoint,
        data: request.toJson(),
      );

      if (response.data == null) {
        throw Exception('Empty response from server');
      }

      return ChatResponse.fromJson(response.data!);
    } catch (e) {
      rethrow;
    }
  }

  /// Send a message with streaming response using SSE
  Stream<StreamChunk> sendMessageStream(
    String message,
    String? sessionId, {
    Map<String, dynamic>? context,
  }) async* {
    final request =
        ChatRequest(message: message, sessionId: sessionId, context: context);

    try {
      final response = await _dioClient.dio.post(
        ApiConstants.chatStreamEndpoint,
        data: request.toJson(),
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );

      final stream = response.data as ResponseBody;
      String buffer = '';

      await for (final chunk in stream.stream) {
        buffer += utf8.decode(chunk);

        // Process complete SSE events
        while (buffer.contains('\n\n')) {
          final eventEnd = buffer.indexOf('\n\n');
          final event = buffer.substring(0, eventEnd);
          buffer = buffer.substring(eventEnd + 2);

          if (event.startsWith('data: ')) {
            final data = event.substring(6).trim();

            if (data == '[DONE]') {
              yield const StreamChunk(content: '', isDone: true);
              return;
            }

            // Check for session marker (not JSON)
            if (data.startsWith('__SESSION__:')) {
              final sessionId = data.substring(12);
              yield StreamChunk(content: '', sessionId: sessionId);
              continue;
            }

            yield* _parseChunk(data);
          }
        }
      }

      // If there's remaining data in buffer
      if (buffer.isNotEmpty && buffer.startsWith('data: ')) {
        final data = buffer.substring(6).trim();
        if (data != '[DONE]') {
          yield* _parseChunk(data);
        }
      }
    } catch (e) {
      yield StreamChunk(content: '', error: e.toString(), isDone: true);
    }
  }

  Stream<StreamChunk> _parseChunk(String data) async* {
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      yield StreamChunk.fromJson(json);
    } catch (e) {
      // Check for metadata marker
      if (data.startsWith('__METADATA__:')) {
        final metaJson = data.substring(13);
        try {
          final metadata = jsonDecode(metaJson) as Map<String, dynamic>;
          yield StreamChunk(content: '', metadata: metadata);
        } catch (_) {
          yield StreamChunk(content: data);
        }
      } else {
        // If not valid JSON, treat as plain text chunk
        yield StreamChunk(content: data);
      }
    }
  }

  /// Get chat history for a session
  Future<List<ChatMessage>> getChatHistory(String sessionId) async {
    try {
      final response = await _dioClient.get<List<dynamic>>(
        '${ApiConstants.chatEndpoint}/history',
        queryParameters: {'session_id': sessionId},
      );

      if (response.data == null) {
        return [];
      }

      return response.data!
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a chat session
  Future<void> deleteSession(String sessionId) async {
    try {
      await _dioClient.delete(
        '${ApiConstants.chatEndpoint}/session/$sessionId',
      );
    } catch (e) {
      rethrow;
    }
  }
}
