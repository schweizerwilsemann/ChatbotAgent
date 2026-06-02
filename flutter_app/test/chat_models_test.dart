import 'package:flutter_test/flutter_test.dart';
import 'package:sports_venue_chatbot/features/chat/data/chat_models.dart';

void main() {
  group('Chat JSON contract', () {
    test('serializes request fields using backend snake_case keys', () {
      final json = const ChatRequest(
        message: 'oke',
        sessionId: 'session-123',
        context: {'venue_id': 'venue-1'},
      ).toJson();

      expect(json['session_id'], 'session-123');
      expect(json['context'], {'venue_id': 'venue-1'});
      expect(json.containsKey('sessionId'), isFalse);
    });

    test('parses response fields returned by backend', () {
      final response = ChatResponse.fromJson({
        'response': 'Đặt sân thành công',
        'session_id': 'session-123',
        'tools_used': ['book_court'],
      });

      expect(response.sessionId, 'session-123');
      expect(response.toolsUsed, ['book_court']);
    });
  });
}
