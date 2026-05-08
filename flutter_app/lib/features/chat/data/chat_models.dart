import 'package:json_annotation/json_annotation.dart';

part 'chat_models.g.dart';

@JsonSerializable()
class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final List<String>? toolsUsed;
  final String? sessionId;
  final bool isStreaming;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.toolsUsed,
    this.sessionId,
    this.isStreaming = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    List<String>? toolsUsed,
    String? sessionId,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      toolsUsed: toolsUsed ?? this.toolsUsed,
      sessionId: sessionId ?? this.sessionId,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isSystem => role == 'system';

  static ChatMessage user({required String content, String? sessionId}) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
      sessionId: sessionId,
    );
  }

  static ChatMessage assistant({
    required String content,
    List<String>? toolsUsed,
    String? sessionId,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'assistant',
      content: content,
      timestamp: DateTime.now(),
      toolsUsed: toolsUsed,
      sessionId: sessionId,
    );
  }
}

@JsonSerializable()
class ChatResponse {
  final String response;
  final String? sessionId;
  final List<String>? toolsUsed;
  final String? context;
  final Map<String, dynamic>? metadata;

  const ChatResponse({
    required this.response,
    this.sessionId,
    this.toolsUsed,
    this.context,
    this.metadata,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) =>
      _$ChatResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ChatResponseToJson(this);
}

@JsonSerializable()
class ChatRequest {
  final String message;
  final String? sessionId;
  final String? userId;
  final Map<String, dynamic>? context;

  const ChatRequest({
    required this.message,
    this.sessionId,
    this.userId,
    this.context,
  });

  factory ChatRequest.fromJson(Map<String, dynamic> json) =>
      _$ChatRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ChatRequestToJson(this);
}

@JsonSerializable()
class StreamChunk {
  final String content;
  final bool isDone;
  final String? toolName;
  final String? error;

  const StreamChunk({
    required this.content,
    this.isDone = false,
    this.toolName,
    this.error,
  });

  factory StreamChunk.fromJson(Map<String, dynamic> json) =>
      _$StreamChunkFromJson(json);

  Map<String, dynamic> toJson() => _$StreamChunkToJson(this);
}
