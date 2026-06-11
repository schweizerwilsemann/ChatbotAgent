import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sports_venue_chatbot/core/network/api_exception.dart';
import 'package:sports_venue_chatbot/features/chat/data/chat_models.dart';
import 'package:sports_venue_chatbot/features/chat/domain/chat_repository.dart';
import 'package:sports_venue_chatbot/features/venue/presentation/selected_venue_provider.dart';
import 'package:uuid/uuid.dart';

/// State class for chat
class ChatState {
  final List<ChatMessage> messages;
  final String? sessionId;
  final bool isLoading;
  final bool isStreaming;
  final String? error;
  final String streamingContent;

  const ChatState({
    this.messages = const [],
    this.sessionId,
    this.isLoading = false,
    this.isStreaming = false,
    this.error,
    this.streamingContent = '',
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    String? sessionId,
    bool? isLoading,
    bool? isStreaming,
    String? error,
    String? streamingContent,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      sessionId: sessionId ?? this.sessionId,
      isLoading: isLoading ?? this.isLoading,
      isStreaming: isStreaming ?? this.isStreaming,
      error: clearError ? null : (error ?? this.error),
      streamingContent: streamingContent ?? this.streamingContent,
    );
  }
}

/// Chat StateNotifier managing the chat state
class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _repository;
  final Ref _ref;
  StreamSubscription<StreamChunk>? _streamSubscription;
  static const _uuid = Uuid();

  ChatNotifier(this._repository, this._ref) : super(const ChatState());

  Map<String, dynamic>? _buildVenueContext() {
    final venue = _ref.read(selectedVenueProvider);
    if (venue == null) return null;
    return {
      'venue_id': venue.id,
      'venue_name': venue.name,
    };
  }

  /// Send a message and receive a response
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    // Add user message to the list
    final userMessage = ChatMessage.user(
      content: content,
      sessionId: state.sessionId,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
      clearError: true,
    );

    try {
      final response = await _repository.sendMessage(
        content,
        state.sessionId,
        context: _buildVenueContext(),
      );

      final assistantMessage = ChatMessage.assistant(
        content: response.response,
        toolsUsed: response.toolsUsed,
        sessionId: response.sessionId,
        metadata: response.metadata,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        sessionId: response.sessionId ?? state.sessionId,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Đã xảy ra lỗi không xác định. Vui lòng thử lại.',
      );
    }
  }

  /// Send one voice-agent turn and return the assistant response for TTS.
  Future<String?> sendVoiceTurn(String content) async {
    if (content.trim().isEmpty) return null;

    final userMessage = ChatMessage.user(
      content: content,
      sessionId: state.sessionId,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      error: null,
      clearError: true,
    );

    try {
      final context = {
        ...?_buildVenueContext(),
        'input_mode': 'voice_agent',
      };
      final response = await _repository.sendMessage(
        content,
        state.sessionId,
        context: context,
      );

      final assistantMessage = ChatMessage.assistant(
        content: response.response,
        toolsUsed: response.toolsUsed,
        sessionId: response.sessionId,
        metadata: response.metadata,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        sessionId: response.sessionId ?? state.sessionId,
        isLoading: false,
      );
      return response.response;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return null;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Đã xảy ra lỗi không xác định. Vui lòng thử lại.',
      );
      return null;
    }
  }

  /// Send a message with streaming response
  Future<void> sendMessageStream(String content) async {
    if (content.trim().isEmpty) return;

    // Cancel any existing stream
    await _streamSubscription?.cancel();

    // Add user message
    final userMessage = ChatMessage.user(
      content: content,
      sessionId: state.sessionId,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isStreaming: true,
      streamingContent: '',
      error: null,
      clearError: true,
    );

    final buffer = StringBuffer();
    List<String> toolsUsed = [];
    Map<String, dynamic>? metadata;

    _streamSubscription = _repository
        .sendMessageStream(content, state.sessionId,
            context: _buildVenueContext())
        .listen(
      (chunk) {
        if (chunk.isDone) {
          // Finalize the streaming message
          final assistantMessage = ChatMessage(
            id: _uuid.v4(),
            role: 'assistant',
            content: buffer.toString(),
            timestamp: DateTime.now(),
            toolsUsed: toolsUsed.isNotEmpty ? toolsUsed : null,
            sessionId: state.sessionId,
            metadata: metadata,
          );

          state = state.copyWith(
            messages: [...state.messages, assistantMessage],
            isStreaming: false,
            streamingContent: '',
          );
          return;
        }

        if (chunk.error != null) {
          state = state.copyWith(
            isStreaming: false,
            streamingContent: '',
            error: chunk.error,
          );
          return;
        }

        // Save session_id from backend
        if (chunk.sessionId != null && chunk.sessionId!.isNotEmpty) {
          state = state.copyWith(sessionId: chunk.sessionId);
        }

        if (chunk.toolName != null) {
          toolsUsed.add(chunk.toolName!);
        }

        // Capture metadata from chunk
        if (chunk.metadata != null) {
          metadata = chunk.metadata;
        }

        buffer.write(chunk.content);
        state = state.copyWith(streamingContent: buffer.toString());
      },
      onError: (error) {
        state = state.copyWith(
          isStreaming: false,
          streamingContent: '',
          error: error is ApiException
              ? error.message
              : 'Đã xảy ra lỗi khi nhận phản hồi.',
        );
      },
      onDone: () {
        // Ensure streaming is marked as complete
        if (state.isStreaming) {
          if (buffer.isNotEmpty) {
            String content = buffer.toString();
            Map<String, dynamic>? finalMetadata = metadata;

            // Parse metadata from content if marker is present
            if (content.contains('__METADATA__:')) {
              final metaIndex = content.indexOf('__METADATA__:');
              final metaJson = content.substring(metaIndex + 13);
              try {
                finalMetadata = jsonDecode(metaJson) as Map<String, dynamic>;
              } catch (_) {}
              content = content.substring(0, metaIndex).trim();
            }

            final assistantMessage = ChatMessage(
              id: _uuid.v4(),
              role: 'assistant',
              content: content,
              timestamp: DateTime.now(),
              toolsUsed: toolsUsed.isNotEmpty ? toolsUsed : null,
              sessionId: state.sessionId,
              metadata: finalMetadata,
            );

            state = state.copyWith(
              messages: [...state.messages, assistantMessage],
              isStreaming: false,
              streamingContent: '',
            );
          } else {
            state = state.copyWith(
              isStreaming: false,
              streamingContent: '',
            );
          }
        }
      },
    );
  }

  /// Clear all messages and start a new session
  void clearChat() {
    _streamSubscription?.cancel();
    state = const ChatState();
  }

  /// Clear the error message
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Update payment_status in metadata for messages matching [orderId].
  void updatePaymentStatus(String orderId, String paymentStatus) {
    final updated = state.messages.map((msg) {
      if (msg.metadata == null) return msg;
      if (msg.metadata!['id'] != orderId) return msg;
      return msg.copyWith(
        metadata: {...msg.metadata!, 'payment_status': paymentStatus},
      );
    }).toList();
    state = state.copyWith(messages: updated);
  }

  /// Update booking status and time in metadata for messages matching [bookingId].
  void updateBookingStatus(
    String bookingId,
    String status, {
    String? startTime,
    String? endTime,
  }) {
    final updated = state.messages.map((msg) {
      if (msg.metadata == null) return msg;
      if (msg.metadata!['id'] != bookingId) return msg;
      final newMeta = {...msg.metadata!, 'status': status};
      if (startTime != null && endTime != null) {
        newMeta['time'] = '$startTime - $endTime';
      }
      return msg.copyWith(metadata: newMeta);
    }).toList();
    state = state.copyWith(messages: updated);
  }

  /// Retry the last message
  Future<void> retryLastMessage() async {
    if (state.messages.isEmpty) return;

    // Find the last user message
    final lastUserMessage = state.messages.lastWhere(
      (msg) => msg.isUser,
      orElse: () => state.messages.first,
    );

    // Remove messages after the last user message
    final lastUserIndex = state.messages.lastIndexOf(lastUserMessage);
    final messagesBefore = state.messages.sublist(0, lastUserIndex + 1);

    state = state.copyWith(
      messages: messagesBefore,
      error: null,
      clearError: true,
    );

    await sendMessage(lastUserMessage.content);
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for the ChatNotifier
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.watch(chatRepositoryProvider), ref);
});

/// Provider for sending a single message (FutureProvider.family)
final sendMessageProvider = FutureProvider.family<ChatResponse, String>((
  ref,
  message,
) async {
  final repository = ref.watch(chatRepositoryProvider);
  final sessionId = ref.watch(chatProvider).sessionId;
  final venue = ref.watch(selectedVenueProvider);
  final context =
      venue != null ? {'venue_id': venue.id, 'venue_name': venue.name} : null;
  return repository.sendMessage(message, sessionId, context: context);
});
