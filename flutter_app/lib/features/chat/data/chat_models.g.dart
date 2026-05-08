// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
  id: json['id'] as String,
  role: json['role'] as String,
  content: json['content'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  toolsUsed: (json['tools_used'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  sessionId: json['session_id'] as String?,
  isStreaming: json['is_streaming'] as bool? ?? false,
);

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'role': instance.role,
      'content': instance.content,
      'timestamp': instance.timestamp.toIso8601String(),
      'tools_used': instance.toolsUsed,
      'session_id': instance.sessionId,
      'is_streaming': instance.isStreaming,
    };

ChatResponse _$ChatResponseFromJson(Map<String, dynamic> json) => ChatResponse(
  response: json['response'] as String,
  sessionId: json['session_id'] as String?,
  toolsUsed: (json['tools_used'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  context: json['context'] as String?,
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ChatResponseToJson(ChatResponse instance) =>
    <String, dynamic>{
      'response': instance.response,
      'session_id': instance.sessionId,
      'tools_used': instance.toolsUsed,
      'context': instance.context,
      'metadata': instance.metadata,
    };

ChatRequest _$ChatRequestFromJson(Map<String, dynamic> json) => ChatRequest(
  message: json['message'] as String,
  sessionId: json['session_id'] as String?,
  userId: json['user_id'] as String?,
  context: json['context'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ChatRequestToJson(ChatRequest instance) =>
    <String, dynamic>{
      'message': instance.message,
      'session_id': instance.sessionId,
      'user_id': instance.userId,
      'context': instance.context,
    };

StreamChunk _$StreamChunkFromJson(Map<String, dynamic> json) => StreamChunk(
  content: json['content'] as String,
  isDone: json['is_done'] as bool? ?? false,
  toolName: json['tool_name'] as String?,
  error: json['error'] as String?,
);

Map<String, dynamic> _$StreamChunkToJson(StreamChunk instance) =>
    <String, dynamic>{
      'content': instance.content,
      'is_done': instance.isDone,
      'tool_name': instance.toolName,
      'error': instance.error,
    };
